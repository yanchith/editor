//
// The lexer in this file is started its life as the tokenizer in the focus editor,
// but was considerably dumbed down since then.
//
// https://github.com/focus-editor/focus
//


LANG_C_LINE_COMMENT        :: "//";
LANG_C_BLOCK_COMMENT_START :: "/*";
LANG_C_BLOCK_COMMENT_END   :: "*/";
LANG_C_BLOCK_COMMENTS_CAN_NEST :: false;

LANG_C_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

LANG_C_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

lang_c_update_tokens :: (document: *Document) {
    ProfileZone("lang_c_update_tokens");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.tokens);

    // TODO(jt): @Speed @Memory This always copies the entire text buffer. This is bad! Instead
    // split the lexing loop into two and lex on the contents of the gap buffer.
    start := Text_Location.{ 0, 0 };
    end   := text_buffer_get_end_of_line(document.buffer, document.buffer.line_count - 1);
    contents := text_buffer_make_view_for_interval(document.buffer, start, end,, temp);

    lexer: Lexer;
    lexer.input = contents;

    while 1 {
        token := get_next_token(*lexer);

        if lexer.reported_error  break;
        if token.type == .EOF    break;

        // We currently don't (and can't) handle these, so don't send them down the pipe.
        if token.type == .UNINITIALIZED  continue;
        if token.type == .IDENTIFIER     continue;
        if token.type == .PUNCTUATION    continue;

        array_add(*document.tokens, token);
    }
}

#scope_file

USERDATA__IS_INCLUDE_DIRECTIVE: u32 : 0x01;

get_next_token :: (lexer: *Lexer) -> Token {
    lexer_eat_whitespace(lexer);

    token: Token;
    lexer_set_token_start(lexer, *token);
    lexer_set_token_end(lexer, *token);

    if lexer.input.count == 0 {
        token.type = .EOF;
        lexer_write_recent_token(lexer, token);

        return token;
    }

    c := lexer.input[0];

    if is_digit(c) {
        parse_number(lexer, *token);
    } else if is_alpha(c) || c == "_" {
        parse_identifier_or_keyword(lexer, *token);
    } else if c == {
        case ":";   parse_simple(lexer, *token);
        case "?";   parse_simple(lexer, *token);

        case "=";   parse_equal(lexer, *token);
        case "-";   parse_minus(lexer, *token);
        case "+";   parse_plus(lexer, *token);
        case "*";   parse_asterisk(lexer, *token);
        case "<";   parse_less_than_or_include(lexer, *token);
        case ">";   parse_greater_than(lexer, *token);
        case "!";   parse_bang(lexer, *token);
        case "#";   parse_directive(lexer, *token);
        case "\"";  parse_string_literal(lexer, *token);
        case "'";   parse_char_literal(lexer, *token);
        case "/";   parse_slash_or_comment(lexer, *token);
        case "&";   parse_ampersand(lexer, *token);
        case "|";   parse_pipe(lexer, *token);
        case "%";   parse_percent(lexer, *token);
        case "^";   parse_caret(lexer, *token);

        case ";";   parse_simple(lexer, *token);
        case "\\";  parse_simple(lexer, *token);
        case ",";   parse_simple(lexer, *token);
        case ".";   parse_simple(lexer, *token);
        case "{";   parse_simple(lexer, *token);
        case "}";   parse_simple(lexer, *token);
        case "(";   parse_simple(lexer, *token);
        case ")";   parse_simple(lexer, *token);
        case "[";   parse_simple(lexer, *token);
        case "]";   parse_simple(lexer, *token);

        case "~";   parse_simple(lexer, *token);
        case "`";   parse_simple(lexer, *token);

        case; {
            lexer_advance_horizontally(lexer);

            token.type = .INVALID;
            lexer_set_token_end(lexer, *token);
        }
    }

    lexer_write_recent_token(lexer, token);

    return token;
}

parse_simple :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    token.byte1 = lexer.byte_index;
    token.loc1.x = lexer.column_index;
    token.loc1.y = lexer.line_index;
}

parse_number :: (lexer: *Lexer, token: *Token) {
    start_c := lexer.input[0];

    token.type = .NUMBER_LITERAL;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if is_digit(c) || c == "." {

            parsed_decimal_point := false;

            // Parse decimal
            is_digit_or_point :: (b: u8) -> bool {
                return is_digit(b) || b == ".";
            }

            while lexer.input.count && lexer_next_char_matches(lexer, is_digit_or_point) {
                if c == "." {
                    if parsed_decimal_point {
                        break;
                    }
                    parsed_decimal_point = true;
                }

                lexer_advance_horizontally(lexer);
            }

            // Parse exponent
            if lexer.input.count {
                if lexer_next_char_is_any(lexer, "eE") {
                    lexer_advance_horizontally(lexer);

                    if lexer.input.count && lexer_next_char_is_any(lexer, "+-") {
                        lexer_advance_horizontally(lexer);
                    }

                    while lexer.input.count && lexer_next_char_matches(lexer, is_digit) {
                        lexer_advance_horizontally(lexer);
                    }
                }

                if parsed_decimal_point {
                    if lexer_next_char_is_any(lexer, "fFdD") {
                        lexer_advance_horizontally(lexer);
                    }
                } else {
                    if lexer_next_char_is_any(lexer, "lL") {
                        lexer_advance_horizontally(lexer); // l
                        if lexer_next_char_is_any(lexer, "lL") {
                            lexer_advance_horizontally(lexer); // ll
                            if lexer_next_char_is_any(lexer, "uU") {
                                lexer_advance_horizontally(lexer); // llu
                            }
                        } else if lexer_next_char_is_any(lexer, "uU") {
                            lexer_advance_horizontally(lexer); // lu
                        }
                    } else if lexer_next_char_is_any(lexer, "uU") {
                        lexer_advance_horizontally(lexer); // u
                        if lexer_next_char_is_any(lexer, "lL") {
                            lexer_advance_horizontally(lexer); // ul
                            if lexer_next_char_is_any(lexer, "lL") {
                                lexer_advance_horizontally(lexer); // ull
                            }
                        }
                    }
                }
            }
        } else if start_c == "0" {
            if c == "x" || c == "X" {
                lexer_advance_horizontally(lexer);
                while lexer.input.count && lexer_next_char_matches(lexer, is_hex) {
                    lexer_advance_horizontally(lexer);
                }
            } else if c == "b" || c == "B" {
                lexer_advance_horizontally(lexer);
                while lexer.input.count && lexer_next_char_is_any(lexer, "01") {
                    lexer_advance_horizontally(lexer);
                }
            }
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_identifier_or_keyword :: (lexer: *Lexer, token: *Token) -> ident: string {
    ident: string;
    ident.data = lexer.input.data;
    ident.count = 1;

    token.type = .IDENTIFIER;
    lexer_advance_horizontally(lexer);

    // TODO(jt): @Incomplete Unicode identifiers.
    while lexer.input.count && lexer_next_char_matches(lexer, is_alnum) {
        lexer_advance_horizontally(lexer);
        ident.count += 1;
    }

    if is_keyword(ident) {
        token.type = .KEYWORD;
    }

    lexer_set_token_end(lexer, token);

    return ident;
}

parse_equal :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_minus :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
            case ">";  lexer_advance_horizontally(lexer);
            case "-";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_plus :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
            case "+";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_asterisk :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_less_than_or_include :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        recent := lexer_read_recent_token(lexer);
        if recent.type == .DIRECTIVE && recent.userdata & USERDATA__IS_INCLUDE_DIRECTIVE {
            token.type = .STRING_LITERAL;

            while lexer.input.count {
                c := lexer.input[0];
                if c == "\n" {
                    break;
                }

                lexer_advance_horizontally(lexer);

                if c == ">" {
                    break;
                }
            }
        } else {
            c := lexer.input[0];
            if c == {
                case "=";  lexer_advance_horizontally(lexer);
                case "<";  lexer_advance_horizontally(lexer);
            }
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_greater_than :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_bang :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_directive :: (lexer: *Lexer, token: *Token) {
    lexer_advance_horizontally(lexer);

    lexer_eat_whitespace(lexer);

    // TODO(jt): @Cleanup @Hack extract read_identifier, so we don't need to overwrite.
    ident := parse_identifier_or_keyword(lexer, token);
    token.type = .DIRECTIVE;
    if ident == "include" {
        token.userdata |= USERDATA__IS_INCLUDE_DIRECTIVE;
    }
}

parse_string_literal :: (lexer: *Lexer, token: *Token) {
    token.type = .STRING_LITERAL;
    lexer_advance_horizontally(lexer);

    escape := false;
    while lexer.input.count {
        c := lexer.input[0];
        if c == "\"" && !escape {
            lexer_advance_horizontally(lexer);
            break;
        }

        escape = !escape && c == "\\";

        lexer_advance_horizontally(lexer);
    }

    lexer_set_token_end(lexer, token);
}

parse_char_literal :: (lexer: *Lexer, token: *Token) {
    token.type = .CHAR_LITERAL;

    Advance :: () #expand {
        lexer_advance_horizontally(lexer);
        if lexer.input.count == 0 {
            lexer_set_token_end(lexer, token);
            `return;
        }
        c = lexer.input[0];
    }

    escape := false;
    c: u8;

    Advance(); // The starting '

    if c == "\\" {
        escape = true;
        Advance(); // The escape
    }

    if c == "'" && !escape {
        token.type == .INVALID;
        Advance(); // The ending '

        lexer_set_token_end(lexer, token);
        return;
    }

    Advance(); // The character itself

    if c != "'" {
        token.type == .INVALID;
    }
    Advance(); // The ending '

    lexer_set_token_end(lexer, token);
}

parse_slash_or_comment :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
            case "/"; {
                token.type = .LINE_COMMENT;
                lexer_eat_until_newline(lexer);
            }
            case "*"; {
                token.type = .BLOCK_COMMENT;
                lexer_advance_horizontally(lexer);

                while lexer.input.count {
                    c0 := lexer.input[0];
                    if c0 == "*" {
                        if lexer.input.count > 1 {
                            c1 := lexer.input[1];
                            if c1 == "/" {
                                lexer_advance_horizontally(lexer);
                                lexer_advance_horizontally(lexer);
                                break;
                            }
                        }
                    }

                    lexer_advance(lexer);
                }
            }
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_ampersand :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
            case "&";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_pipe :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
            case "|";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_percent :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

parse_caret :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

is_keyword :: (ident: string) -> bool {
    // TODO(jt): @Speed Accelerate! Could be a lookup table, or perhaps just a
    // length-based narrowing like Jai_Lexer does.
    found := array_find(KEYWORDS, ident);
    return found;
}

// https://cppreference.com/c/keyword
KEYWORDS :: string.[
    "alignas", "alignof", "auto", "bool", "break", "case", "char", "const", "constexpr",
    "continue", "default", "do", "double", "else", "enum",
    "extern", "false", "float", "for", "goto", "if", "inline", "int", "long", "nullptr", "register",
    "restrict", "return", "short", "signed",
    "sizeof", "static", "static_assert", "struct", "switch", "thread_local", "true", "typedef",
    "typeof", "typeof_unqual", "union", "unsigned", "void", "volatile", "while",
    "_Alignas", "_Alignof", "_Atomic", "_BitInt", "_Bool", "_Complex", "_Decimal128", "_Decimal32",
    "_Decimal64", "_Generic", "_Imaginary", "_Noreturn", "_Static_assert", "_Thread_local",
];
