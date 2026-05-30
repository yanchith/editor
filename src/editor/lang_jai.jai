JL :: #import "Jai_Lexer";

lang_jai_update_syntax_highlights :: (editor: *Editor, document: *Document, platform: Platform, input: Input) {
    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.syntax_highlight_tokens);

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
        token := JL.peek_next_token(*lexer);
        JL.eat_token(*lexer);

        if token.type == .END_OF_INPUT  break;
        if lexer.reported_error         break;

        highlight_token: Document.Syntax_Highlight_Token;
        highlight_token.x0 = token.c0 - 1; // TODO(jt): @Audit is c0 and c1 counting in unicode or bytes?
        highlight_token.x1 = token.c1 - 1;
        highlight_token.y  = token.l0 - 1;

        // TODO(jt): Things until we are somewhat satisfied with this:
        //
        // - Modify lexer to output comments
        // - Modify font to be able to mix in multiple font weights in a single atlas (regular, bold, italic, etc.) and make use of this.

        if token.type == {
            case .IDENT; {
                if last_token_is_pound || last_token_is_dollar {
                    highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                    highlight_token.x0 -= 1;
                } else if last_token_is_double_dollar {
                    highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                    highlight_token.x0 -= 2;
                }
            }

            case .NUMBER;               highlight_token.type = .NUMBER_LITERAL;
            case .STRING;               highlight_token.type = .STRING_LITERAL;
            case .TRIPLE_MINUS;         highlight_token.type = .PREPROCESSOR_DIRECTIVE;

            case .NOTE; {
                highlight_token.type = .ATTRIBUTE;
                highlight_token.x0 -= 1;
            }

            case; {
                if token.type >= .__FIRST_KEYWORD && token.type <= .__LAST_KEYWORD {
                    if last_token_is_pound {
                        highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                        highlight_token.x0 -= 1;
                    } else {
                        highlight_token.type = .KEYWORD;
                    }
                }
            }
        }

        last_token_is_pound  = token.type == #char "#";
        last_token_is_dollar = token.type == DOLLAR;
        last_token_is_double_dollar = token.type == .DOUBLE_DOLLAR;
        if highlight_token.type == .UNINITIALIZED {
            continue;
        }

        array_add(*document.syntax_highlight_tokens, highlight_token);
    }
}

DOLLAR :: #char "$"; // Thank you Emacs!
