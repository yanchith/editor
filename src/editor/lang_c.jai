// This file provides basic support for the C Programming language.
//
// The lexer is not yet very well tested, so expect bugs.
//
// Apart for supporting C, this file also supports some basic C++.
// Some C++ tokens (like ::) are not lexed properly, but this is hard to notice
// until we'd enable syntax highlighting for these (which we currently don't support)
//   -jt 30 August 2026

// TODO(jt): @Bug 0ull is not highlighted.

LANG_C_LINE_COMMENT        :: "//";
LANG_C_BLOCK_COMMENT_START :: "/*";
LANG_C_BLOCK_COMMENT_END   :: "*/";
LANG_C_BLOCK_COMMENTS_CAN_NEST :: false;

LANG_C_SINGLE_LINE_STRING :: "\"";
LANG_C_MULTI_LINE_STRING  :: "";

LANG_C_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
    { #char "'", #char "'" },
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

    // TODO(jt): @Speed @Memory This always copies the entire text buffer. While this is bad,
    // it is also much faster than the actual lexing for the sizes of buffers we support lexing for.
    // When I tried lexing on noncontiguous data (a stripped down gap buffer), this brought additional
    // complications, such as branching on each index operator, and complicated recunstruction of strings
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
// The lexer in this file was created by looking at the tokenizer in the Focus editor for C language reference.
// Structural similarities are not accidental. Thank you, Focus developers. (https://github.com/focus-editor/focus)
//
// However, we preserve less information on our tokens than Focus does, so we did away with some things.
// For example, almost every token here is PUNCTUATION, we don't distinguish operators, etc.
//
// Additionally, I did find some bugs in the the focus implementation, which I fixed here (like the missing case for double_greater_than).
// There might be more bugs.
//

USERDATA__IS_INCLUDE_DIRECTIVE: u16 : 0x01;

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

    if c == "." || is_digit(c) {
        parse_number_or_period(lexer, *token);
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
        case "{";   parse_simple(lexer, *token);
        case "}";   parse_simple(lexer, *token);
        case "(";   parse_simple(lexer, *token);
        case ")";   parse_simple(lexer, *token);
        case "[";   parse_simple(lexer, *token);
        case "]";   parse_simple(lexer, *token);

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
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);
}

parse_number_or_period :: (lexer: *Lexer, token: *Token) {
    start_c := lexer.input[0];
    parsed_decimal_point := start_c == ".";

    token.type = .NUMBER_LITERAL;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if parsed_decimal_point && !is_digit(c) {
            // Not a number literal after all.
            token.type = .PUNCTUATION;
        } else if start_c == "0" {
            if c == "x" || c == "X" {
                lexer_advance_horizontally(lexer);
                while lexer.input.count && lexer_byte_matches(lexer, is_hex) {
                    lexer_advance_horizontally(lexer);
                }
                
                lexer_set_token_end(lexer, token);
            } else if c == "b" || c == "B" {
                lexer_advance_horizontally(lexer);
                while lexer.input.count && lexer_byte_is_any(lexer, "01") {
                    lexer_advance_horizontally(lexer);
                }
                
                lexer_set_token_end(lexer, token);
            }
        } else {
            // Parse decimal
            is_digit_or_point :: (b: u8) -> bool {
                return is_digit(b) || b == ".";
            }

            while lexer.input.count && lexer_byte_matches(lexer, is_digit_or_point) {
                if lexer_byte_equals(lexer, ".") {
                    if parsed_decimal_point {
                        break;
                    }
                    parsed_decimal_point = true;
                }

                lexer_advance_horizontally(lexer);
            }
            
            lexer_set_token_end(lexer, token);

            // Parse exponent
            if lexer_byte_is_any(lexer, "eE") {
                lexer_advance_horizontally(lexer);

                if lexer.input.count && lexer_byte_is_any(lexer, "+-") {
                    lexer_advance_horizontally(lexer);
                }

                while lexer.input.count && lexer_byte_matches(lexer, is_digit) {
                    lexer_advance_horizontally(lexer);
                }

                lexer_set_token_end(lexer, token);
            }

            // Parse suffixes
            if parsed_decimal_point {
                if lexer_byte_is_any(lexer, "fFdD") {
                    lexer_advance_horizontally(lexer);
                    lexer_set_token_end(lexer, token);
                }
            } else {
                if lexer_byte_is_any(lexer, "lL") {
                    lexer_advance_horizontally(lexer);
                    lexer_set_token_end(lexer, token); // l
                    if lexer_byte_is_any(lexer, "lL") {
                        lexer_advance_horizontally(lexer);
                        lexer_set_token_end(lexer, token); // ll
                        if lexer_byte_is_any(lexer, "uU") {
                            lexer_advance_horizontally(lexer);
                            lexer_set_token_end(lexer, token); // llu
                        }
                    } else if lexer_byte_is_any(lexer, "uU") {
                        lexer_advance_horizontally(lexer);
                        lexer_set_token_end(lexer, token); // lu
                    }
                } else if lexer_byte_is_any(lexer, "uU") {
                    lexer_advance_horizontally(lexer);
                    lexer_set_token_end(lexer, token); // u
                    if lexer_byte_is_any(lexer, "lL") {
                        lexer_advance_horizontally(lexer);
                        lexer_set_token_end(lexer, token); // ul
                        if lexer_byte_is_any(lexer, "lL") {
                            lexer_advance_horizontally(lexer);
                            lexer_set_token_end(lexer, token); // ull
                        }
                    }
                }
            }
        }
    }
}

parse_identifier_or_keyword :: (lexer: *Lexer, token: *Token) {
    ident := lexer_eat_identifier(lexer);

    token.type = .IDENTIFIER;
    lexer_set_token_end(lexer, token);

    if lexer_is_keyword(ident, KEYWORDS) {
        token.type = .KEYWORD;
    }
}

parse_equal :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_minus :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case ">"; #through;
            case "-"; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_plus :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "+"; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_asterisk :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_less_than_or_include :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        recent := lexer_read_recent_token(lexer);
        if recent.type == .DIRECTIVE && recent.userdata & USERDATA__IS_INCLUDE_DIRECTIVE {
            token.type = .STRING_LITERAL;

            while lexer.input.count && !lexer_byte_equals(lexer, "\n") {
                lexer_advance_horizontally(lexer);

                if lexer_byte_equals(lexer, ">") {
                    lexer_advance_horizontally(lexer);
                    break;
                }
            }
            
            lexer_set_token_end(lexer, token);
        } else {
            c := lexer.input[0];
            if c == {
                case "="; #through;
                case "<"; {
                    lexer_advance_horizontally(lexer);
                    lexer_set_token_end(lexer, token);
                }
            }
        }
    }
}

parse_greater_than :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "=";
            case ">"; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_bang :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_directive :: (lexer: *Lexer, token: *Token) {
    lexer_advance_horizontally(lexer);
    lexer_eat_whitespace(lexer);
    
    ident := lexer_eat_identifier(lexer);
    if ident.count  {
        token.type = .DIRECTIVE;
        lexer_set_token_end(lexer, token);
        
        if ident == "include" {
            token.userdata |= USERDATA__IS_INCLUDE_DIRECTIVE;
        }
    }
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

parse_char_literal :: (lexer: *Lexer, token: *Token) {
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
        token.type == .INVALID;
        AdvanceHorizontally(); // Consume invalid ending '
        lexer_set_token_end(lexer, token);

        return;
    }

    Advance(); // Consume the character itself. This can be a newline in invalid inputs.

    if c == "'" {
        AdvanceHorizontally(); // The ending '
    } else {
        token.type == .INVALID;
    }
    lexer_set_token_end(lexer, token);
}

parse_slash_or_comment :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
            case "/"; {
                token.type = .LINE_COMMENT;
                lexer_eat_until_newline(lexer);
                lexer_set_token_end(lexer, token);
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
                                lexer_set_token_end(lexer, token);
                                break;
                            }
                        }
                    }

                    lexer_advance(lexer);
                }
            }
        }
    }
}

parse_ampersand :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "&"; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_pipe :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "|"; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_percent :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

parse_caret :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_advance_horizontally(lexer);
    lexer_set_token_end(lexer, token);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_advance_horizontally(lexer);
                lexer_set_token_end(lexer, token);
            }
        }
    }
}

KEYWORDS :: string.[
    //
    // These are the official keywords as of C23 (https://cppreference.com/c/keyword)
    //
    "alignas", "alignof", "auto", "bool", "break", "case", "char", "const", "constexpr",
    "continue", "default", "do", "double", "else", "enum",
    "extern", "false", "float", "for", "goto", "if", "inline", "int", "long", "nullptr", "register",
    "restrict", "return", "short", "signed",
    "sizeof", "static", "static_assert", "struct", "switch", "thread_local", "true", "typedef",
    "typeof", "typeof_unqual", "union", "unsigned", "void", "volatile", "while",
    "_Alignas", "_Alignof", "_Atomic", "_BitInt", "_Bool", "_Complex", "_Decimal128", "_Decimal32",
    "_Decimal64", "_Generic", "_Imaginary", "_Noreturn", "_Static_assert", "_Thread_local",

    // These are some additional C++ keywords that may appear in C-like C++ codebases.
    "asm", "class", "const_cast", "decltype", "namespace", "noexcept", "operator", "private", "protected", "public",
    "reinterpret_cast", "static_cast", "template", "typename", "using", "virtual",
];
