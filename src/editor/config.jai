apply_config :: (editor: *Editor, _input: string) {
    success := true;

    lexer: Config_Lexer;
    lexer.input = _input;

    success=, version := parse_version(*lexer);
    if !success {
        editor_log(editor, "Failed to parse version at %:%", lexer.line_index + 1, lexer.column_index + 1);
        return;
    }

    section := Section.Global;

    while 1 {
        eat_until_newline(*lexer);
        eat_whitespace(*lexer);

        if lexer.input.count == 0 {
            break;
        }

        if String.starts_with(input, SECTION_OPEN) {
            success, section = parse_section(*lexer);
            if !success {
                editor_log(editor, "Failed to parse section at %:%", lexer.line_index + 1, lexer.column_index + 1);
                return;
            }

            if section == {
                case "keybinds";  section = .KEYBINDS;
                case; {
                    editor_log(editor, "Invalid section at %:%", lexer.line_index + 1, lexer.column_index + 1);
                    return;
                }
            }
        } else {
            if section == {
                case .GLOBAL; {
                    success=, pairs := parse_pair(*lexer);
                    if !success {
                        editor_log(editor, "Failed to parse value at %:%", lexer.line_index + 1, lexer.column_index + 1);
                        return;
                    }

                }
                case .KEYBINDS;
            }
        }
    }
}

#scope_file

Config_Lexer :: struct {
    input: string;

    line_index: s64;
    column_index: s64;
}

parse_version :: (lexer: *Config_Lexer) -> success: bool, s64 {
    line := eat_until_newline(lexer);

    token, success := String.parse_token(line);

    version: s64;
    if success {
        version, success = string_to_int(token, T = s64);
    }

    return success, version;
}

parse_section :: (lexer: *Config_Lexer) -> success: bool, string {
    line := eat_until_newline(lexer);

    found_index := String.find_index_from_left(line, #char "]", 1);
    if found_index == -1 {
        return false, "";
    }

    section_identifier_count := found_index - 2;
    if section_identifier_count <= 0 {
        return false, "";
    }

    section_identifier := String.slice(line, 1, section_identifier_count);
    return true, section_identifier;
}

eat_until_newline :: (lexer: *Config_Lexer) -> string {
    result: string;
    result.data = lexer.input.data;

    while lexer.input.count {
        c := lexer.input[0];
        if c == "\n" {
            break;
        }

        lexer.line_index += 1;
        advance(*lexer.input);
    }

    result.count = lexer.input.data - result.data;

    return result;
}

eat_whitespace :: (lexer: *Config_Lexer) -> string {
    result: string;
    result.data = lexer.input.data;

    while input.count {
        c := lexer.input[0];
        if !is_space(c) {
            break;
        }

        if c == "\n" {
            lexer.line_index = 0;
            lexer.column_index += 1;
        } else {
            lexer.line_index += 1;
        }
        advance(*lexer.input);
    }

    result.count = input.data - result.data;

    return result;
}

Section :: enum {
    GLOBAL;
    KEYBINDS_PANEL;
    KEYBINDS_DOCUMENT;
    KEYBINDS_COMPILATION;
    KEYBINDS_LISTING;
}

GLOBAL_SECTION_KEYS: [] string : .[
    "theme",
];
GLOBAL_SECTION_VALUES: [][] string : .[
    .["abulafia", "naysayer", "handmade", "stb", "zenburn", "visual_studio_light"]
]

// TODO(jt): @Hack Our scope parse doesn't support strings, so we put this down here...
SECTION_OPEN :: #char "[";
SECTION_CLOSE :: #char "]";