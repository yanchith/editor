// This file provides basic support for the Rust Programming language.
//
// The lexer is not yet very well tested, so expect bugs.

LANG_RUST_LINE_COMMENT        :: "//";
LANG_RUST_BLOCK_COMMENT_START :: "/*";
LANG_RUST_BLOCK_COMMENT_END   :: "*/";
LANG_RUST_BLOCK_COMMENTS_CAN_NEST :: false;

LANG_RUST_SINGLE_LINE_STRING :: "\"";
LANG_RUST_MULTI_LINE_STRING  :: "";

LANG_RUST_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

LANG_RUST_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

lang_rust_update_tokens :: (document: *Document) {
    ProfileZone("lang_rust_update_tokens");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.tokens);

    // TODO(jt): @Speed @Memory This always copies the entire text buffer. While this is bad,
    // it is also much faster than the actual lexing for the sizes of buffers we support lexing for.
    // When I tried lexing on noncontiguous data (a stripped down gap buffer), this brought additional
    // complications, such as branching on each index operator, and complicated reconstruction of strings
    // in lexer_eat_identifier, if those strings crossed the gap.
    contents := gap_buffer_make_view(document.buffer.gb, 0, document.buffer.gb.count,, temp);

    lexer: Lexer;
    lexer.input = cast(string, contents);

    while 1 {
        token := get_next_token(*lexer);

        if lexer.reported_error          break;
        if token.type == .END_OF_INPUT   break;

        if token.type == .UNINITIALIZED  continue;
        if token.type == .INVALID        continue;
        // We currently don't have special handling for these, so don't send them down the pipe.
        if token.type == .IDENTIFIER     continue;
        if token.type == .PUNCTUATION    continue;

        if token.loc0 == token.loc1      continue; // Empty token.

        array_add(*document.tokens, token);
    }
}

#scope_file

//
// The lexer in this file is a modified version of the C lexer from lang_c.jai.
//
// TODO(jt): @Audit I didn't properly clean this up, there might be some C remnants in here, like ++, --, ~.
// TODO(jt): Missing features: attribute highlighting, multiline strings.

get_next_token :: (lexer: *Lexer) -> Token {
    lexer_eat_whitespace(lexer);

    token: Token;
    lexer_set_token_start(lexer, *token);
    lexer_set_token_end(lexer, *token);

    if lexer.input.count == 0 {
        token.type = .END_OF_INPUT;
        lexer_write_recent_token(lexer, token);

        return token;
    }

    c := lexer.input[0];

    if is_digit(c) {
        parse_number(lexer, *token);
    } else if is_alpha(c) || c == "_" {
        parse_identifier_keyword_or_macro_invocation(lexer, *token);
    } else if c == {
        case ":";   parse_simple(lexer, *token);
        case "?";   parse_simple(lexer, *token);

        case "=";   parse_equal(lexer, *token);
        case "-";   parse_minus(lexer, *token);
        case "+";   parse_plus(lexer, *token);
        case "*";   parse_asterisk(lexer, *token);
        case "<";   parse_less_than(lexer, *token);
        case ">";   parse_greater_than(lexer, *token);
        case "!";   parse_bang(lexer, *token);
        case "#";   parse_attribute(lexer, *token);
        case "\"";  parse_string_literal(lexer, *token);
        case "'";   parse_char_literal_or_lifetime(lexer, *token);
        case "/";   parse_slash_or_comment(lexer, *token);
        case "&";   parse_ampersand(lexer, *token);
        case "|";   parse_pipe(lexer, *token);
        case "%";   parse_percent(lexer, *token);
        case "^";   parse_caret(lexer, *token);

        case ";";   parse_simple(lexer, *token);
        case "\\";  parse_simple(lexer, *token);
        case ",";   parse_simple(lexer, *token);
        case "{";   parse_simple(lexer, *token);
        case "}";   parse_simple(lexer, *token);
        case "(";   parse_simple(lexer, *token);
        case ")";   parse_simple(lexer, *token);
        case "[";   parse_simple(lexer, *token);
        case "]";   parse_closing_square_bracket_or_end_of_attribute(lexer, *token);

        case "~";   parse_simple(lexer, *token);
        case "`";   parse_simple(lexer, *token);

        case; {
            token.type = .INVALID;
            lexer_advance_horizontally(lexer);
        }
    }

    lexer_write_recent_token(lexer, token);

    return token;
}

parse_simple :: (lexer: *Lexer, token: *Token) {
    if has_userdata_flag(lexer, .INSIDE_ATTRIBUTE) {
        token.type = .DIRECTIVE;
    } else {
        token.type = .PUNCTUATION;
    }

    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);
}

parse_number :: (lexer: *Lexer, token: *Token) {
    /*
    Integers:

    <numbers>(<int_suffix>)
    0x<hex_numbers>(<int_suffix>)
    0b<binary_numbers>(<int_suffix>)

    Floats:

    <numbers>.<numbers><float_suffix>
    <numbers>e<numbers><float_suffix>
    <numbers><float_suffix>

    <numbers>: 0-9 + _
    <binary_numbers>: 0-1 + _
    <hex_numbers>: 0-f + _
    */
    start_c := lexer.input[0];

    token.type = .NUMBER_LITERAL;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        if start_c == "0" && lexer_byte_is_any(lexer, "bB") {
            // Binary integer literal
            lexer_advance_horizontally(lexer);
            while lexer.input.count && lexer_byte_is_any(lexer, "01_") {
                lexer_advance_horizontally(lexer);
            }

            if String.begins_with(lexer.input, "u8") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u16") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u32") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u64") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u128") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "usize") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if  String.begins_with(lexer.input, "i8")  {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i16") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i32") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i64") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i128") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "isize") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            }

            lexer_set_token_end(lexer, token);
        } else if start_c == "0" && lexer_byte_is_any(lexer, "xX") {
            // Hex integer literal
            lexer_advance_horizontally(lexer);
            while lexer.input.count && lexer_byte_is_any(lexer, "0123456789aAbBcCdDeEfF_") {
                lexer_advance_horizontally(lexer);
            }

            if String.begins_with(lexer.input, "u8") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u16") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u32") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u64") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "u128") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "usize") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if  String.begins_with(lexer.input, "i8")  {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i16") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i32") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i64") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "i128") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            } else if String.begins_with(lexer.input, "isize") {
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
                lexer_advance_horizontally(lexer);
            }

            lexer_set_token_end(lexer, token);
        } else {
            // Any numeric literal
            while lexer.input.count && lexer_byte_is_any(lexer, "0123456789_") {
                lexer_advance_horizontally(lexer);
            }

            must_be_float := false;

            if lexer_byte_equals(lexer, ".") {
                must_be_float = true;

                lexer_advance_horizontally(lexer);

                while lexer.input.count && lexer_byte_is_any(lexer, "0123456789_") {
                    lexer_advance_horizontally(lexer);
                }
            }

            if lexer_byte_is_any(lexer, "eE") {
                must_be_float = true;

                lexer_advance_horizontally(lexer);

                while lexer.input.count && lexer_byte_is_any(lexer, "0123456789_") {
                    lexer_advance_horizontally(lexer);
                }
            }

            if must_be_float {
                if String.begins_with(lexer.input, "f32") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "f64") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                }
            } else {
                if String.begins_with(lexer.input, "u8") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "u16") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "u32") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "u64") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "u128") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "usize") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if  String.begins_with(lexer.input, "i8")  {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "i16") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "i32") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "i64") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "i128") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "isize") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "f32") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                } else if String.begins_with(lexer.input, "f64") {
                    lexer_advance_horizontally(lexer);
                    lexer_advance_horizontally(lexer);
                }
            }

            lexer_set_token_end(lexer, token);
        }
    }
}

parse_identifier_keyword_or_macro_invocation :: (lexer: *Lexer, token: *Token) {
    ident := lexer_eat_identifier(lexer);

    token.type = .IDENTIFIER;

    if lexer_is_keyword(ident, RUST_KEYWORDS) {
        token.type = .KEYWORD;
    } else if lexer.input.count && lexer.input[0] == "!" {
        lexer_advance_horizontally(lexer);
        token.type = .DIRECTIVE;
    } else if has_userdata_flag(lexer, .INSIDE_ATTRIBUTE) {
        token.type = .DIRECTIVE;
    }

    lexer_set_token_end(lexer, token);
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
            case "=";  #through;
            case ">";  #through;
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
            case "=";  #through;
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

parse_less_than :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";  #through;
            case "<";  lexer_advance_horizontally(lexer);
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
            case "=";  #through;
            case ">";  lexer_advance_horizontally(lexer);
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

parse_attribute :: (lexer: *Lexer, token: *Token) {
    token.type = .INVALID;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    lexer_eat_whitespace(lexer);

    if lexer.input.count && lexer.input[0] == "[" || lexer.input.count > 1 && lexer.input[0] == "!" && lexer.input[1] == "[" {
        token.type = .DIRECTIVE;

        // Handle inner attributes
        if lexer.input[0] == "!" {
            lexer_advance_horizontally(lexer);
        }

        lexer_advance_horizontally(lexer);
        lexer_set_token_end(lexer, token);

        if lexer.input.count {
            ident := lexer_eat_identifier(lexer);
            if ident.count  {
                lexer_set_token_end(lexer, token);
                add_userdata_flag(lexer, .INSIDE_ATTRIBUTE);
            }
        }
    }
}

parse_closing_square_bracket_or_end_of_attribute :: (lexer: *Lexer, token: *Token) {
    if has_userdata_flag(lexer, .INSIDE_ATTRIBUTE) {
        token.type = .DIRECTIVE;
        remove_userdata_flag(lexer, .INSIDE_ATTRIBUTE);
    } else {
        token.type = .PUNCTUATION;
    }

    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);
}

parse_string_literal :: (lexer: *Lexer, token: *Token) {
    token.type = .STRING_LITERAL;
    lexer_advance_horizontally(lexer);

    escape := false;
    while lexer.input.count {
        c := lexer.input[0];
        if c == "\n" {
            lexer_advance(lexer);
            break;
        }

        if c == "\"" && !escape {
            lexer_advance_horizontally(lexer);
            break;
        }

        escape = !escape && c == "\\";

        lexer_advance_horizontally(lexer);
    }

    lexer_set_token_end(lexer, token);
}

parse_char_literal_or_lifetime :: (lexer: *Lexer, token: *Token) {
    /*
    character: 'a'
    liftime:   'a
     */

    Advance :: () #expand {
        lexer_advance(lexer);
        if lexer.input.count == 0 {
            `return;
        }
        c = lexer.input[0];
    }

    AdvanceHorizontally :: () #expand {
        lexer_advance_horizontally(lexer);
        if lexer.input.count == 0 {
            `return;
        }
        c = lexer.input[0];
    }

    token.type = .CHAR_LITERAL;

    escape := false;
    c: u8;

    AdvanceHorizontally(); // Consume starting '

    if c == "\\" {
        escape = true;
        AdvanceHorizontally(); // Consume escape
    }

    if c == "'" && !escape {
        token.type = .INVALID;
        AdvanceHorizontally(); // Consume invalid ending '
        lexer_set_token_end(lexer, token);

        return;
    }

    Advance(); // Consume the character itself. This can be a newline in invalid inputs.

    if c == "'" {
        AdvanceHorizontally(); // The ending '
    } else {
        // TODO(jt): We can attempt to parse a lifetime identifier here, in case
        // we'd like that highlighted in the future.
        token.type = .INVALID;
    }
    lexer_set_token_end(lexer, token);
}

parse_slash_or_comment :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
            }
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
            case "=";  #through;
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
            case "=";  #through;
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
        if lexer.input[0] == {
            case "=";  lexer_advance_horizontally(lexer);
        }
    }

    lexer_set_token_end(lexer, token);
}

Userdata_Flags :: enum_flags u64 {
    NONE :: 0;

    INSIDE_ATTRIBUTE :: 0x01;
}

add_userdata_flag :: inline (lexer: *Lexer, flag: Userdata_Flags) {
    flags := cast(Userdata_Flags, lexer.userdata);
    flags |= flag;
    lexer.userdata = cast(*void, flags);
}

has_userdata_flag :: inline (lexer: *Lexer, flag: Userdata_Flags) -> bool {
    flags := cast(Userdata_Flags, lexer.userdata);
    return cast(bool, flags & flag);
}

remove_userdata_flag :: inline (lexer: *Lexer, flag: Userdata_Flags) {
    flags := cast(Userdata_Flags, lexer.userdata);
    flags &= ~flag;
    lexer.userdata = cast(*void, flags);
}

RUST_KEYWORDS :: string.[
    //
    // Unconditional keywords
    //
    "_",
    "as", "async", "await",
    "break",
    "const", "continue", "crate",
    "dyn",
    "else", "enum", "extern",
    "false", "fn", "for",
    "if", "impl", "in",
    "let", "loop",
    "match", "mod", "move", "mut",
    "pub",
    "ref", "return",
    "self", "Self", "static", "struct", "super",
    "trait", "true", "type",
    "unsafe", "use",
    "where", "while",

    //
    // Weak keywords
    //
    // (Not all weak keywords are included here, because some are just not used in the wild,
    // or we have other rules to highlight them)
    //
    "union",
    "raw",
];
