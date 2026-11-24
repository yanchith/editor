CONFIG_VERSION :: 1; // Increment for backwards incompatible changes. Since 0.0.3, the parser ignores unknown sections and keys.

parse_and_apply_config :: (editor: *Editor, platform: Platform, _input: string) -> success: bool {
    success := true;

    lexer: Config_Lexer;
    lexer.input = _input;

    success=, version := parse_version(*lexer);
    if !success {
        editor_log(editor, "Error: Failed to parse version on line %", lexer.line_index + 1, show = true);
        return false;
    }

    if version != CONFIG_VERSION {
        editor_log(editor, "Error: Invalid config version: % (supported is %)", version, CONFIG_VERSION, show = true);
        return false;
    }

    config_theme: string;
    config_project_search_ignore_directories: string;

    config_macos_search_path: string;

    config_keybinds_panel:       [..] Keybind_Pair(Panel_Action);
    config_keybinds_document:    [..] Keybind_Pair(Document_Action);
    config_keybinds_compilation: [..] Keybind_Pair(Compilation_Action);
    config_keybinds_listing:     [..] Keybind_Pair(Listing_Action);
    config_keybinds_mp:          [..] Keybind_Pair(Mini_Panel_Action);
    config_keybinds_mi:          [..] Keybind_Pair(Modal_Interaction_Action);

    config_keybinds_panel.allocator = temp;
    config_keybinds_document.allocator = temp;
    config_keybinds_compilation.allocator = temp;
    config_keybinds_listing.allocator = temp;
    config_keybinds_mp.allocator = temp;
    config_keybinds_mi.allocator = temp;

    section := Config_Section.GLOBAL;

    while 1 {
        eat_whitespace(*lexer);

        if lexer.input.count == 0 {
            break;
        }

        if String.begins_with(lexer.input, "[") {
            success= , parsed_section := parse_section(*lexer);
            if !success {
                editor_log(editor, "Error: Failed to parse section on line %", lexer.line_index + 1, show = true);
                return false;
                
            }

            if parsed_section == {
                case "macos";                       section = .MACOS;
                case "keybinds.panel";              section = .KEYBINDS_PANEL;
                case "keybinds.document";           section = .KEYBINDS_DOCUMENT;
                case "keybinds.compilation";        section = .KEYBINDS_COMPILATION;
                case "keybinds.listing";            section = .KEYBINDS_LISTING;
                case "keybinds.mini_panel";         section = .KEYBINDS_MINI_PANEL;
                case "keybinds.modal_interaction";  section = .KEYBINDS_MODAL_INTERACTION;
                case; {
                    editor_log(editor, "Warning: Ignoring contents of unknown section '%' on line %", parsed_section, lexer.line_index + 1, show = true);
                    section = .UNKNOWN;
                }
            }
        } else {
            if #complete section == {
                case .UNKNOWN; {
                    eat_line(*lexer);
                }
                
                case .GLOBAL; {
                    success=, key, value := parse_pair(*lexer);
                    if !success {
                        editor_log(editor, "Error: Failed to parse key-value pair on line %", lexer.line_index + 1, show = true);
                        return false;
                    }

                    if key == {
                        case "theme";                              config_theme = value;
                        case "project_search_ignore_directories";  config_project_search_ignore_directories = value;
                        case;                                      editor_log(editor, "Warning: Ignoring unknown key '%' on line %", key, lexer.line_index + 1, show = true);
                    }
                }

                case .MACOS; {
                    success=, key, value := parse_pair(*lexer);
                    if !success {
                        editor_log(editor, "Error: Failed to parse key-value pair on line %", lexer.line_index + 1, show = true);
                        return false;
                    }

                    if key == {
                        case "search_path";  config_macos_search_path = value;
                        case;                editor_log(editor, "Warning: Ignoring unknown key '%' on line %", key, lexer.line_index + 1, show = true);
                    }
                }

                case .KEYBINDS_PANEL;        #through;
                case .KEYBINDS_DOCUMENT;     #through;
                case .KEYBINDS_COMPILATION;  #through;
                case .KEYBINDS_LISTING;      #through;
                case .KEYBINDS_MINI_PANEL;   #through;
                case .KEYBINDS_MODAL_INTERACTION; {
                    success=, _shortcut, _action := parse_pair(*lexer);
                    if !success {
                        editor_log(editor, "Error: Failed to parse keybind pair on line %", lexer.line_index + 1, show = true);
                        return false;
                    }

                    success=, shortcut := shortcut_parse(_shortcut);
                    if !success {
                        editor_log(editor, "Error: Failed to parse keyboard shortcut on line %", lexer.line_index + 1, show = true);
                        return false;
                    }

                    if section == {
                        case .KEYBINDS_PANEL;              success = verify_and_add_keybind(*config_keybinds_panel, shortcut, _action);
                        case .KEYBINDS_DOCUMENT;           success = verify_and_add_keybind(*config_keybinds_document, shortcut, _action);
                        case .KEYBINDS_COMPILATION;        success = verify_and_add_keybind(*config_keybinds_compilation, shortcut, _action);
                        case .KEYBINDS_LISTING;            success = verify_and_add_keybind(*config_keybinds_listing, shortcut, _action);
                        case .KEYBINDS_MINI_PANEL;         success = verify_and_add_keybind(*config_keybinds_mp, shortcut, _action);
                        case .KEYBINDS_MODAL_INTERACTION;  success = verify_and_add_keybind(*config_keybinds_mi, shortcut, _action);
                        case;                              assert(false);
                    }

                    if !success {
                        editor_log(editor, "Warning: Ignoring unknown keybind action '%' on line %", _action, lexer.line_index + 1, show = true);
                    }
                }
            }
        }
    }

    if config_theme.count {
        change_theme(editor, config_theme);
    }
    
    set_project_search_ignore_directories(editor, config_project_search_ignore_directories);

    #if OS == .MACOS {
        platform.clear_search_path();
        if config_macos_search_path.count {
            platform.add_search_path(config_macos_search_path);
        }
    }

    // TODO(jt): By nuking everything from the keymaps, we may make the editor unusable, e.g. if the config misses keybinds for elementary things
    // like confirm/cancel and movement. Perhaps these should be always inserted to the keymaps regardless?
    key_map_reset_keeping_memory(*editor.panel_key_map);
    key_map_reset_keeping_memory(*editor.document_key_map);
    key_map_reset_keeping_memory(*editor.compilation_key_map);
    key_map_reset_keeping_memory(*editor.listing_key_map);
    key_map_reset_keeping_memory(*editor.mini_panel.key_map);
    key_map_reset_keeping_memory(*editor.modal_interaction.key_map);
    
    RegisterKeybinds :: (label: string, key_map: *Key_Map, keybinds: [] Keybind_Pair) #expand {
        for keybinds {
            if !key_map_add(key_map, it.shortcut, it.action) {
                editor_log(editor, "Warning: Ignoring conflicting % keybind: %", label, shortcut_tprint(it.shortcut), show = true);
            }
        }
    }
    
    RegisterKeybinds("panel", *editor.panel_key_map, config_keybinds_panel);
    RegisterKeybinds("document", *editor.document_key_map, config_keybinds_document);
    RegisterKeybinds("compilation", *editor.compilation_key_map, config_keybinds_compilation);
    RegisterKeybinds("listing", *editor.listing_key_map, config_keybinds_listing);
    RegisterKeybinds("minipanel", *editor.mini_panel.key_map, config_keybinds_mp);
    RegisterKeybinds("modal interaction", *editor.modal_interaction.key_map, config_keybinds_mi);

    return true;
}

// In case we fail to load a config, this is a minimal set of commands people can use to fix the problem.
apply_emergency_config :: (editor: *Editor) {
    change_theme(editor, "abulafia"); // TODO(jt): Emergency theme.

    key_map_reset_keeping_memory(*editor.panel_key_map);
    key_map_reset_keeping_memory(*editor.document_key_map);
    key_map_reset_keeping_memory(*editor.compilation_key_map);
    key_map_reset_keeping_memory(*editor.listing_key_map);
    key_map_reset_keeping_memory(*editor.mini_panel.key_map);
    key_map_reset_keeping_memory(*editor.modal_interaction.key_map);

    {
        km := *editor.panel_key_map;

        key_map_add(km, "M-x",                .SHOW_COMMANDS);
        key_map_add(km, "C-S-p",              .SHOW_COMMANDS);

        key_map_add(km, "C-x C-f",            .OPEN_FILE_OR_DIRECTORY);
        key_map_add(km, "C-x b",              .SWITCH_VIEW);
        key_map_add(km, "C-x k",              .CLOSE_VIEW);
    }

    {
        km := *editor.document_key_map;

        key_map_add(km, "C-p",                .MOVE_UP);
        key_map_add(km, "<up>",               .MOVE_UP);
        key_map_add(km, "C-n",                .MOVE_DOWN);
        key_map_add(km, "<down>",             .MOVE_DOWN);
        key_map_add(km, "C-f",                .MOVE_FORWARD);
        key_map_add(km, "<right>",            .MOVE_FORWARD);
        key_map_add(km, "C-b",                .MOVE_BACKWARD);
        key_map_add(km, "<left>",             .MOVE_BACKWARD);

        key_map_add(km, "C-x C-s",            .SAVE_DOCUMENT);
        key_map_add(km, "C-x C-r",            .RELOAD_DOCUMENT);

        key_map_add(km, "C-d",                .DELETE_FORWARD);
        key_map_add(km, "<delete>",           .DELETE_FORWARD);
        key_map_add(km, "<backspace>",        .DELETE_BACKWARD);

        key_map_add(km, "C-m",                .INSERT_LINE_BEFORE);
        key_map_add(km, "<enter>",            .INSERT_LINE_BEFORE);

        key_map_add(km, "M-w",                .COPY);
        key_map_add(km, "C-w",                .CUT);
        key_map_add(km, "C-y",                .PASTE);
    }

    {
        km := *editor.compilation_key_map;

        key_map_add(km, "C-p",                .MOVE_UP);
        key_map_add(km, "<up>",               .MOVE_UP);
        key_map_add(km, "C-n",                .MOVE_DOWN);
        key_map_add(km, "<down>",             .MOVE_DOWN);
        key_map_add(km, "C-f",                .MOVE_FORWARD);
        key_map_add(km, "<right>",            .MOVE_FORWARD);
        key_map_add(km, "C-b",                .MOVE_BACKWARD);
        key_map_add(km, "<left>",             .MOVE_BACKWARD);

        key_map_add(km, "M-w",                .COPY);
        key_map_add(km, "C-w",                .COPY);
    }

    {
        km := *editor.listing_key_map;

        key_map_add(km, "C-p",                .MOVE_UP);
        key_map_add(km, "p",                  .MOVE_UP);
        key_map_add(km, "<up>",               .MOVE_UP);
        key_map_add(km, "C-n",                .MOVE_DOWN);
        key_map_add(km, "n",                  .MOVE_DOWN);
        key_map_add(km, "<down>",             .MOVE_DOWN);

        key_map_add(km, "C-m",                .OPEN);
        key_map_add(km, "<enter>",            .OPEN);
    }

    {
        km := *editor.mini_panel.key_map;

        key_map_add(km, "C-p",                .MOVE_UP);
        key_map_add(km, "<up>",               .MOVE_UP);
        key_map_add(km, "C-n",                .MOVE_DOWN);
        key_map_add(km, "<down>",             .MOVE_DOWN);
        key_map_add(km, "C-f",                .MOVE_FORWARD);
        key_map_add(km, "<right>",            .MOVE_FORWARD);
        key_map_add(km, "C-b",                .MOVE_BACKWARD);
        key_map_add(km, "<left>",             .MOVE_BACKWARD);

        key_map_add(km, "C-d",                .DELETE_FORWARD);
        key_map_add(km, "<delete>",           .DELETE_FORWARD);
        key_map_add(km, "<backspace>",        .DELETE_BACKWARD);

        key_map_add(km, "M-w",                .COPY);
        key_map_add(km, "C-w",                .CUT);
        key_map_add(km, "C-y",                .PASTE);

        key_map_add(km, "C-m",                .CONFIRM);
        key_map_add(km, "<enter>",            .CONFIRM);

        key_map_add(km, "C-g",                .CANCEL_OR_STOP_SELECTING);
        key_map_add(km, "<escape>",           .CANCEL_OR_STOP_SELECTING);
    }

    {
        km := *editor.modal_interaction.key_map;

        key_map_add(km, "C-f",                .MOVE_FORWARD);
        key_map_add(km, "<right>",            .MOVE_FORWARD);
        key_map_add(km, "C-b",                .MOVE_BACKWARD);
        key_map_add(km, "<left>",             .MOVE_BACKWARD);

        key_map_add(km, "C-d",                .DELETE_FORWARD);
        key_map_add(km, "<delete>",           .DELETE_FORWARD);
        key_map_add(km, "<backspace>",        .DELETE_BACKWARD);

        key_map_add(km, "M-w",                .COPY);
        key_map_add(km, "C-w",                .CUT);
        key_map_add(km, "C-y",                .PASTE);

        key_map_add(km, "C-m",                .CONFIRM);
        key_map_add(km, "<enter>",            .CONFIRM);

        key_map_add(km, "C-g",                .CANCEL_OR_STOP_SELECTING);
        key_map_add(km, "<escape>",           .CANCEL_OR_STOP_SELECTING);
    }
}

#scope_file

Config_Section :: enum {
    UNKNOWN;

    GLOBAL;
    MACOS;
    KEYBINDS_PANEL;
    KEYBINDS_DOCUMENT;
    KEYBINDS_COMPILATION;
    KEYBINDS_LISTING;
    KEYBINDS_MINI_PANEL;
    KEYBINDS_MODAL_INTERACTION;
}

Config_Lexer :: struct {
    input: string;

    line_index: s64;
    column_index: s64;
}

parse_version :: (lexer: *Config_Lexer) -> success: bool, s64 {
    line := eat_line(lexer);

    token, success := String.parse_token(*line);

    version: s64;
    if success {
        version, success = string_to_int(token, T = s64);
    }

    return success, version;
}

parse_section :: (lexer: *Config_Lexer) -> success: bool, string {
    line := eat_line(lexer);

    found_index := String.find_index_from_left(line, #char "]", 1);
    if found_index == -1 {
        return false, "";
    }

    section_identifier_count := found_index - 1;
    if section_identifier_count <= 0 {
        return false, "";
    }

    section_identifier := String.slice(line, 1, section_identifier_count);
    return true, section_identifier;
}

parse_pair :: (lexer: *Config_Lexer) -> success: bool, key: string, value: string {
    line := eat_line(lexer);

    // Split from right, so it also works on shortcuts that can contain '=' in the left part.
    found, left, right := String.split_from_right(line, #char "=");
    if !found {
        return false, "", "";
    }

    key   := String.trim(left);
    value := String.trim(right);

    return true, key, value;
}

eat_line :: (lexer: *Config_Lexer) -> string {
    result: string;
    result.data = lexer.input.data;

    while lexer.input.count {
        if lexer.input[0] == "\n" {
            break;
        }

        if !result.count && lexer.input[0] == "#" {
            result.count = lexer.input.data - result.data;
        }

        lexer.column_index += 1;
        advance(*lexer.input);
    }

    if !result.count {
        result.count = lexer.input.data - result.data;
    }

    return result;
}

eat_whitespace :: (lexer: *Config_Lexer) {
    while lexer.input.count {
        if lexer.input[0] == "#" {
            while lexer.input.count {
                if lexer.input[0] == "\n" {
                    break;
                }

                lexer.column_index += 1;
                advance(*lexer.input);
            }
        }

        if !is_space(lexer.input[0]) {
            break;
        }

        if lexer.input[0] == "\n" {
            lexer.column_index = 0;
            lexer.line_index += 1;
        } else {
            lexer.column_index += 1;
        }
        advance(*lexer.input);
    }
}

Keybind_Pair :: struct (T: Type) {
    shortcut: Shortcut;
    action: T;
}

verify_and_add_keybind :: (keybinds: *[..] Keybind_Pair($T), shortcut: Shortcut, _action: string) -> success: bool
#modify {
    ti := cast(*Type_Info, T);
    return ti.type == .ENUM;
}
{
    // TODO(jt): @Speed Don't re-create names and values arrays each time through!
    names  := enum_names(T);
    values := enum_values_as_enum(T);

    found, found_index := array_find(names, _action, String.equal_nocase);
    if found {
        action := values[found_index];
        array_add(keybinds, { shortcut, action });
    }

    return found;
}

#if OS == .WINDOWS {
    PATHLIST_SEPARATOR :: PATHLIST_SEPARATOR_WINDOWS;
} else #if OS_IS_UNIX {
    PATHLIST_SEPARATOR :: PATHLIST_SEPARATOR_UNIX;
}

PATHLIST_SEPARATOR_WINDOWS :: #char ";";
PATHLIST_SEPARATOR_UNIX    :: #char ":";

// Fill a list of paths from a string separated by ';' on Windows and ';' or ':' on Unix.
// If people want a crossplatform config, they have to write it Windows-style. (The alternative
// would be to pick neither and use our own separator, or make up our own syntax completely.)
set_project_search_ignore_directories :: (editor: *Editor, _paths: string) {
    array_reset_keeping_memory(*editor.project_search_ignore_directories);
    if !_paths.count {
        return;
    }
    
    paths: string;
    #if OS_IS_UNIX {
        paths = copy_string(_paths,, temp);
        String.replace_chars(paths, ";", #char ":");
    } else {
        paths = _paths;
    }
    
    found, left, right := String.split_from_left(paths, PATHLIST_SEPARATOR);
    
    left = String.trim(left);
    if left.count {
        array_add(*editor.project_search_ignore_directories, copy_string(left,, arena_allocator(editor.perm_arena)));
    }
    
    while found {
        found, left, right = String.split_from_left(right, PATHLIST_SEPARATOR);
        left = String.trim(left);
        if left.count {
            array_add(*editor.project_search_ignore_directories, copy_string(left,, arena_allocator(editor.perm_arena)));
        }
    }
}