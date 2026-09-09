CONFIG_VERSION :: 1;

parse_and_apply_config :: (editor: *Editor, _input: string) {
    success := true;

    lexer: Config_Lexer;
    lexer.input = _input;

    success=, version := parse_version(*lexer);
    if !success {
        editor_log(editor, "Failed to parse version on line %", lexer.line_index + 1);
        return;
    }

    if version != CONFIG_VERSION {
        editor_log(editor, "Invalid config version: % (supported is %)", version, CONFIG_VERSION);
        return;
    }

    config_theme: string;
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

    section := Section.GLOBAL;

    while 1 {
        eat_whitespace(*lexer);

        if lexer.input.count == 0 {
            break;
        }

        if String.starts_with(lexer.input, SECTION_OPEN) {
            success= , parsed_section := parse_section(*lexer);
            if !success {
                editor_log(editor, "Failed to parse section on line %", lexer.line_index + 1);
                return;
            }

            if parsed_section == {
                case "keybinds.panel";              section = .KEYBINDS_PANEL;
                case "keybinds.document";           section = .KEYBINDS_DOCUMENT;
                case "keybinds.compilation";        section = .KEYBINDS_COMPILATION;
                case "keybinds.listing";            section = .KEYBINDS_LISTING;
                case "keybinds.mini_panel";         section = .KEYBINDS_MINI_PANEL;
                case "keybinds.modal_interaction";  section = .KEYBINDS_MODAL_INTERACTION;
                case; {
                    editor_log(editor, "Invalid section on line %", lexer.line_index + 1);
                    return;
                }
            }
        } else {
            if #complete section == {
                case .GLOBAL; {
                    success=, key, value := parse_pair(*lexer);
                    if !success {
                        editor_log(editor, "Failed to parse key-value pair on line %", lexer.line_index + 1);
                        return;
                    }

                    if key == {
                        case "theme";  config_theme = value;
                        case; {
                            editor_log(editor, "Unknown key on line %", lexer.line_index + 1);
                            return;
                        }
                    }
                }

                case .KEYBINDS_PANEL;        #through;
                case .KEYBINDS_DOCUMENT;     #through;
                case .KEYBINDS_COMPILATION;  #through;
                case .KEYBINDS_LISTING;      #through;
                case .KEYBINDS_MINI_PANEL;   #through;
                case .KEYBINDS_MODAL_INTERACTION; {
                    success=, _shortcut, _action := parse_keybind_pair(*lexer);
                    if !success {
                        editor_log(editor, "Failed to parse keybind pair on line %", lexer.line_index + 1);
                        return;
                    }

                    success=, shortcut := shortcut_parse(_shortcut);
                    if !success {
                        editor_log(editor, "Failed to parse keyboard shortcut on line %", lexer.line_index + 1);
                        return;
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
                        editor_log(editor, "Failed to recognize keybind action on line %", lexer.line_index + 1);
                        return;
                    }
                }
            }
        }
    }

    if config_theme.count {
        change_theme(editor, config_theme);
    }

    // TODO(jt): By nuking everything from the keymaps, we may make the editor unusable, e.g. if the config misses keybinds for elementary things
    // like confirm/cancel and movement. Perhaps these should be always inserted to the keymaps regardless?
    key_map_reset_keeping_memory(*editor.panel_key_map);
    key_map_reset_keeping_memory(*editor.document_key_map);
    key_map_reset_keeping_memory(*editor.compilation_key_map);
    key_map_reset_keeping_memory(*editor.listing_key_map);
    key_map_reset_keeping_memory(*editor.mini_panel.key_map);
    key_map_reset_keeping_memory(*editor.modal_interaction.key_map);

    key_map_reserve(*editor.panel_key_map, 128);
    key_map_reserve(*editor.document_key_map, 128);
    key_map_reserve(*editor.compilation_key_map, 128);
    key_map_reserve(*editor.listing_key_map, 128);
    key_map_reserve(*editor.mini_panel.key_map, 128);
    key_map_reserve(*editor.modal_interaction.key_map, 128);

    for config_keybinds_panel        key_map_add(*editor.panel_key_map, it.shortcut, it.action);
    for config_keybinds_document     key_map_add(*editor.document_key_map, it.shortcut, it.action);
    for config_keybinds_compilation  key_map_add(*editor.compilation_key_map, it.shortcut, it.action);
    for config_keybinds_listing      key_map_add(*editor.listing_key_map, it.shortcut, it.action);
    for config_keybinds_mp           key_map_add(*editor.mini_panel.key_map, it.shortcut, it.action);
    for config_keybinds_mi           key_map_add(*editor.modal_interaction.key_map, it.shortcut, it.action);

    editor_log(editor, "Applied config");
}

#scope_file

Section :: enum {
    GLOBAL;
    KEYBINDS_PANEL;
    KEYBINDS_DOCUMENT;
    KEYBINDS_COMPILATION;
    KEYBINDS_LISTING;
    // TODO(jt): @Cleanup For the moment, modal interaction keybinds are a subset of the minipanel keybinds.
    // Maybe we should unify to a degree?
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

    found, left, right := String.split_from_left(line, #char "=");
    if !found {
        return false, "", "";
    }

    key   := String.trim(left);
    value := String.trim(right);

    return true, key, value;
}

// This is almost like parse_pair, but splits from right, so the shortcut can contain '='
parse_keybind_pair :: (lexer: *Config_Lexer) -> success: bool, shortcut: string, action: string {
    line := eat_line(lexer);

    found, left, right := String.split_from_right(line, #char "=");
    if !found {
        return false, "", "";
    }

    shortcut := String.trim(left);
    action   := String.trim(right);

    return true, shortcut, action;
}

eat_line :: (lexer: *Config_Lexer) -> string {
    result: string;
    result.data = lexer.input.data;

    while lexer.input.count {
        if lexer.input[0] == "\n" {
            break;
        }

        if lexer.input[0] == "#" {
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

verify_and_add_keybind :: (keybinds: *[..] Keybind_Pair($T), shortcut: Shortcut, _action: string) -> success: bool #modify {
    ti := cast(*Type_Info, T);
    return ti.type == .ENUM;
} {
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

// TODO(jt): @Hack Our scope parse doesn't support strings, so we put this down here...
SECTION_OPEN  :: "[";
SECTION_CLOSE :: "]";