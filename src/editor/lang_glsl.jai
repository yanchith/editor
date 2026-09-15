// This file provides basic support for the C Programming language.
//
// The lexer is not yet very well tested, so expect bugs.

LANG_GLSL_LINE_COMMENT        :: "//";
LANG_GLSL_BLOCK_COMMENT_START :: "/*";
LANG_GLSL_BLOCK_COMMENT_END   :: "*/";
LANG_GLSL_BLOCK_COMMENTS_CAN_NEST :: false;

LANG_GLSL_SINGLE_LINE_STRING :: "";
LANG_GLSL_MULTI_LINE_STRING  :: "";

LANG_GLSL_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

LANG_GLSL_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

lang_glsl_update_tokens :: (document: *Document) {
    ProfileZone("lang_glsl_update_tokens");

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

        if lexer.reported_error         break;
        if token.type == .END_OF_INPUT  break;

        if token.type == .UNINITIALIZED  continue;
        if token.type == .INVALID        continue;
        // We currently don't have special handling for these, so don't send them down the pipe.
        if token.type == .IDENTIFIER     continue;
        if token.type == .PUNCTUATION    continue;

        array_add(*document.tokens, token);
    }
}

#scope_file

//
// The lexer in this file is a modified version of the C lexer from lang_c.jai.
//

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
        case "<";   parse_less_than(lexer, *token);
        case ">";   parse_greater_than(lexer, *token);
        case "!";   parse_bang(lexer, *token);
        case "#";   parse_directive(lexer, *token);
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

        case; {
            token.type = .INVALID;
            lexer_set_token_end(lexer, *token);
            lexer_advance_horizontally(lexer);
        }
    }

    lexer_write_recent_token(lexer, token);

    return token;
}

parse_simple :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);
}

parse_number_or_period :: (lexer: *Lexer, token: *Token) {
    start_c := lexer.input[0];
    parsed_decimal_point := start_c == ".";

    token.type = .NUMBER_LITERAL;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if parsed_decimal_point && !is_digit(c) {
            // Not a number literal after all.
            token.type = .PUNCTUATION;
        } else if start_c == "0" {
            if c == "x" || c == "X" {
                // Hexadecimal
                lexer_advance_horizontally(lexer);
                while lexer.input.count && lexer_input_byte_matches(lexer, is_hex) {
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                }
            } else {
                // Octal
                while lexer.input.count && lexer_input_byte_is_any(lexer, "01234567") {
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                }
            }

            if lexer_input_byte_is_any(lexer, "uU") {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        } else {
            // Parse decimal
            is_digit_or_point :: (b: u8) -> bool {
                return is_digit(b) || b == ".";
            }

            while lexer.input.count && lexer_input_byte_matches(lexer, is_digit_or_point) {
                if lexer_input_byte_equals(lexer, ".") {
                    if parsed_decimal_point {
                        break;
                    }
                    parsed_decimal_point = true;
                }

                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }

            // Parse exponent
            if lexer_input_byte_is_any(lexer, "eE") {
                lexer_advance_horizontally(lexer);

                if lexer.input.count && lexer_input_byte_is_any(lexer, "+-") {
                    lexer_advance_horizontally(lexer);
                }

                while lexer.input.count && lexer_input_byte_matches(lexer, is_digit) {
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                }
            }

            // Parse suffixes
            if parsed_decimal_point {
                if lexer_input_byte_is_any(lexer, "fF") {
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                } else if lexer_input_byte_equals(lexer, "L") && lexer_input_byte_at_index_equals(lexer, "F", 1) {
                    lexer_advance_horizontally(lexer);
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                } else if lexer_input_byte_equals(lexer, "l") && lexer_input_byte_at_index_equals(lexer, "f", 1) {
                    lexer_advance_horizontally(lexer);
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                }
            } else {
                if lexer_input_byte_is_any(lexer, "uU") {
                    lexer_set_token_end(lexer, token);
                    lexer_advance_horizontally(lexer);
                }
            }
        }
    }
}

parse_identifier_or_keyword :: (lexer: *Lexer, token: *Token) -> ident: string {
    ident: string;
    ident.data = lexer.input.data;
    ident.count = 1;

    token.type = .IDENTIFIER;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    // The is_nonascii_utf8_char_boundary may be a little too lenient, and perhaps
    // C identifiers are more strict, but for syntax highlighting this is good enough.
    // We may want to switch this to a more robust unicode character detection -
    // either based on the unicode database, or a character heuristic like Focus does.
    while lexer.input.count && (lexer_input_byte_matches(lexer, is_alnum) || lexer_input_byte_matches(lexer, is_nonascii_utf8_char_boundary)) {
        lexer_set_token_end(lexer, token);
        bytes_advanced := lexer_advance_horizontally(lexer);
        ident.count += bytes_advanced;
    }

    if is_keyword(ident) {
        token.type = .KEYWORD;
    }

    return ident;
}

parse_equal :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_minus :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "-"; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_plus :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "+"; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_asterisk :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_less_than :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "<"; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_greater_than :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case ">"; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
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
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_directive :: (lexer: *Lexer, token: *Token) {
    lexer_advance_horizontally(lexer);

    lexer_eat_whitespace(lexer);

    // TODO(jt): @Cleanup @Hack extract read_identifier, so we don't need to overwrite.
    ident := parse_identifier_or_keyword(lexer, token);
    token.type = .DIRECTIVE;
}

parse_slash_or_comment :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
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
                                lexer_set_token_end(lexer, token);
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
}

parse_ampersand :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "&"; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_pipe :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; #through;
            case "|"; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_percent :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "="; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

parse_caret :: (lexer: *Lexer, token: *Token) {
    token.type = .PUNCTUATION;
    lexer_set_token_end(lexer, token);
    lexer_advance_horizontally(lexer);

    if lexer.input.count {
        c := lexer.input[0];
        if c == {
            case "^"; #through;
            case "="; {
                lexer_set_token_end(lexer, token);
                lexer_advance_horizontally(lexer);
            }
        }
    }
}

// TODO(jt): @Speed Accelerate! Could be a lookup table, or perhaps just a
// length-based narrowing before doing a strcomp, like Jai_Lexer does.
is_keyword :: (ident: string) -> bool {
    found := array_find(KEYWORDS, ident);
    return found;
}

KEYWORDS :: string.[
    //
    // From https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.60.html#keywords
    //
    // The following are the keywords in the language and (after preprocessing) can only be
    // used as described in this specification, or a compile-time error results:
    //
    "const", "uniform", "buffer", "shared", "attribute", "varying",
    "coherent", "volatile", "restrict", "readonly", "writeonly",
    "atomic_uint",
    "layout",
    "centroid", "flat", "smooth", "noperspective",
    "patch", "sample",
    "invariant", "precise",
    "break", "continue", "do", "for", "while", "switch", "case", "default",
    "if", "else",
    "subroutine",
    "in", "out", "inout",
    "int", "void", "bool", "true", "false", "float", "double",
    "discard", "return",
    "vec2", "vec3", "vec4", "ivec2", "ivec3", "ivec4", "bvec2", "bvec3", "bvec4",
    "uint", "uvec2", "uvec3", "uvec4",
    "dvec2", "dvec3", "dvec4",
    "mat2", "mat3", "mat4",
    "mat2x2", "mat2x3", "mat2x4",
    "mat3x2", "mat3x3", "mat3x4",
    "mat4x2", "mat4x3", "mat4x4",
    "dmat2", "dmat3", "dmat4",
    "dmat2x2", "dmat2x3", "dmat2x4",
    "dmat3x2", "dmat3x3", "dmat3x4",
    "dmat4x2", "dmat4x3", "dmat4x4",
    "lowp", "mediump", "highp", "precision",
    "sampler1D", "sampler1DShadow", "sampler1DArray", "sampler1DArrayShadow",
    "isampler1D", "isampler1DArray", "usampler1D", "usampler1DArray",
    "sampler2D", "sampler2DShadow", "sampler2DArray", "sampler2DArrayShadow",
    "isampler2D", "isampler2DArray", "usampler2D", "usampler2DArray",
    "sampler2DRect", "sampler2DRectShadow", "isampler2DRect", "usampler2DRect",
    "sampler2DMS", "isampler2DMS", "usampler2DMS",
    "sampler2DMSArray", "isampler2DMSArray", "usampler2DMSArray",
    "sampler3D", "isampler3D", "usampler3D",
    "samplerCube", "samplerCubeShadow", "isamplerCube", "usamplerCube",
    "samplerCubeArray", "samplerCubeArrayShadow",
    "isamplerCubeArray", "usamplerCubeArray",
    "samplerBuffer", "isamplerBuffer", "usamplerBuffer",
    "image1D", "iimage1D", "uimage1D",
    "image1DArray", "iimage1DArray", "uimage1DArray",
    "image2D", "iimage2D", "uimage2D",
    "image2DArray", "iimage2DArray", "uimage2DArray",
    "image2DRect", "iimage2DRect", "uimage2DRect",
    "image2DMS", "iimage2DMS", "uimage2DMS",
    "image2DMSArray", "iimage2DMSArray", "uimage2DMSArray",
    "image3D", "iimage3D", "uimage3D",
    "imageCube", "iimageCube", "uimageCube",
    "imageCubeArray", "iimageCubeArray", "uimageCubeArray",
    "imageBuffer", "iimageBuffer", "uimageBuffer",
    "struct",

    //
    // In addition, when targeting Vulkan, the following keywords also exist:
    //

    "texture1D", "texture1DArray",
    "itexture1D", "itexture1DArray", "utexture1D", "utexture1DArray",
    "texture2D", "texture2DArray",
    "itexture2D", "itexture2DArray", "utexture2D", "utexture2DArray",
    "texture2DRect", "itexture2DRect", "utexture2DRect",
    "texture2DMS", "itexture2DMS", "utexture2DMS",
    "texture2DMSArray", "itexture2DMSArray", "utexture2DMSArray",
    "texture3D", "itexture3D", "utexture3D",
    "textureCube", "itextureCube", "utextureCube",
    "textureCubeArray", "itextureCubeArray", "utextureCubeArray",
    "textureBuffer", "itextureBuffer", "utextureBuffer",
    "sampler", "samplerShadow",
    "subpassInput", "isubpassInput", "usubpassInput",
    "subpassInputMS", "isubpassInputMS", "usubpassInputMS",

    //
    // The following are the keywords reserved for future use. Using them will result in a
    // compile-time error:
    //

    "common", "partition", "active",
    "asm",
    "class", "union", "enum", "typedef", "template", "this",
    "resource",
    "goto",
    "inline", "noinline", "public", "static", "extern", "external", "interface",
    "long", "short", "half", "fixed", "unsigned", "superp",
    "input", "output",
    "hvec2", "hvec3", "hvec4", "fvec2", "fvec3", "fvec4",
    "filter",
    "sizeof", "cast",
    "namespace", "using",
    "sampler3DRect",
];
