LANG_JAI_LINE_COMMENT        :: "//";
LANG_JAI_BLOCK_COMMENT_START :: "/*";
LANG_JAI_BLOCK_COMMENT_END   :: "*/";
LANG_JAI_BLOCK_COMMENTS_CAN_NEST :: true;

LANG_JAI_STRING_START_AND_END :: "\"";

LANG_JAI_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

LANG_JAI_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

lang_jai_update_tokens :: (document: *Document) {
    ProfileZone("lang_jai_update_tokens");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.tokens);

    // TODO(jt): @Memory It's possible that cached_make_atom inside the Lexer leaks memory. Maybe we
    // want to pass in temp as the context allocator when we call the lexer? Maybe we want to audit
    // the lexer code a bit.
    lexer: JL.Lexer;

    // TODO(jt): @Speed @Memory This always copies the entire text buffer. This is bad! Instead
    // split the lexing loop into two and lex on the contents of the gap buffer.
    start := Text_Location.{ 0, 0 };
    end   := text_buffer_get_end_of_line(document.buffer, document.buffer.line_count - 1);
    contents := text_buffer_make_view_for_interval(document.buffer, start, end,, temp);

    JL.set_input_from_string(*lexer, contents);

    last_token_is_pound  := false;
    last_token_is_dollar := false;
    last_token_is_double_dollar := false;
    while 1 {
        // The lexer has a MAX_CONCURRENT_TOKENS, which is how many you can still access before they
        // get overwritten. Pretty cool.
        jl_token := JL.peek_next_token(*lexer,, temp);
        JL.eat_token(*lexer,, temp);

        if jl_token.type == .END_OF_INPUT  break;
        if lexer.reported_error            break;

        token: Token;
        // The highlight token interval is inclusive on both sides. This is sort of an arbitrary
        // choice we can revisit. Note that Jai_Lexer produces end-exclusive horizontal
        // range and end-inclusive vertical range due to the way set_end_of_token works. To correct
        // for this, we subtract 2 from c1.
        //
        // TODO(jt): @Audit @Bug c0 and c1 are likely counting in bytes,
        // but our locations are in characters. Fix!
        token.loc0.x = jl_token.c0 - 1;
        token.loc0.y = jl_token.l0 - 1;
        token.loc1.x = jl_token.c1 - 2;
        token.loc1.y = jl_token.l1 - 1;

        // TODO(jt): Modify font to be able to mix in multiple font weights in a single atlas
        // (regular, bold, italic, etc.) and make use of this.

        if jl_token.type == {
            case .IDENT; {
                if last_token_is_pound || last_token_is_dollar {
                    token.type = .DIRECTIVE;
                    token.loc0.x -= 1;
                } else if last_token_is_double_dollar {
                    token.type = .DIRECTIVE;
                    token.loc0.x -= 2;
                }
            }

            case .NUMBER;        token.type = .NUMBER_LITERAL;
            case .STRING;        token.type = .STRING_LITERAL;
            case .TRIPLE_MINUS;  token.type = .DIRECTIVE;

            case .NOTE; {
                token.type = .ATTRIBUTE;
                token.loc0.x -= 1;
            }

            case .COMMENT;        token.type = .LINE_COMMENT;
            case .BLOCK_COMMENT;  token.type = .BLOCK_COMMENT;

            case; {
                if jl_token.type >= .__FIRST_KEYWORD && jl_token.type <= .__LAST_KEYWORD {
                    if last_token_is_pound {
                        token.type = .DIRECTIVE;
                        token.loc0.x -= 1;
                    } else {
                        token.type = .KEYWORD;
                    }
                }
            }
        }

        last_token_is_pound  = jl_token.type == #char "#";
        last_token_is_dollar = jl_token.type == DOLLAR;
        last_token_is_double_dollar = jl_token.type == .DOUBLE_DOLLAR;

        if token.type != .UNINITIALIZED {
            array_add(*document.tokens, token);
        }
    }
}

#scope_file

JL :: #import "Jai_Lexer"; // This is our modified version. See :ModifiedJaiLexerModule.

DOLLAR :: #char "$"; // Thank you Emacs!
