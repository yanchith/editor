JL :: #import "Jai_Lexer";

lang_jai_update_syntax_highlights :: (editor: *Editor, document: *Document, platform: Platform, input: Input) {
    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.syntax_highlight_tokens);

    // TODO(jt): @Memory It's possible that cached_make_atom inside the Lexer leaks memory. Maybe we
    // want to pass in temp as the context allocator? Maybe we want to audit the lexer code a bit.
    lexer: JL.Lexer;

    // TODO(jt): @Speed @Memory This always copies the entire text buffer. This is bad! Instead
    // split the lexing loop into two and lex on the contents of the gap buffer.
    start := Text_Location.{ 0, 0 };
    end   := text_buffer_get_end_of_line(document.buffer, document.buffer.line_count - 1);
    contents := text_buffer_make_view_for_interval(document.buffer, start, end,, temp);

    JL.set_input_from_string(*lexer, contents);

    // last_token_is_pound := false;
    while 1 {
        // The lexer has a MAX_CONCURRENT_TOKENS, which is how many you can still access before they
        // get overwritten.
        token := JL.peek_next_token(*lexer);
        JL.eat_token(*lexer);

        if token.type == .END_OF_INPUT  break;
        if lexer.reported_error         break;

        highlight_token: Document.Syntax_Highlight_Token;
        highlight_token.loc0 = { token.c0 - 1, token.l0 - 1 };
        highlight_token.loc1 = { token.c1 - 1, token.l1 - 1 };

        if token.type == {
            // TODO(jt): Make a GENERIC_TYPENAME token type or something?
            // case DOLLAR;                highlight_token.type = .PREPROCESSOR_DIRECTIVE;
            // case .DOUBLE_DOLLAR;        highlight_token.type = .PREPROCESSOR_DIRECTIVE;

            case .IDENT; {
                // if last_token_is_pound {
                //     highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                //     highlight_token.loc0.x -= 1; // nocheckin Is there space between the # and the ident?
                // }
            }

            case .NUMBER;               highlight_token.type = .NUMBER_LITERAL;
            case .STRING;               highlight_token.type = .STRING_LITERAL;
            // case .KEYWORD_TRUE;         #through;
            // case .KEYWORD_FALSE;        highlight_token.type = .BOOLEAN_LITERAL;
            // case .TRIPLE_MINUS;         highlight_token.type = .PREPROCESSOR_DIRECTIVE; // TODO(jt): Make a OTHER_LITERAL or something?

            // case #char "+";             #through;
            // case #char "-";             #through;
            // case #char "*";             #through;
            // case #char "/";             #through;
            // case #char "%";             #through;
            // case .BITWISE_XOR;          #through;
            // case .BITWISE_NOT;          #through;
            // case .BITWISE_AND;          #through;
            // case .BITWISE_OR;           #through;
            // case .PLUSEQUALS;           #through;
            // case .MINUSEQUALS;          #through;
            // case .TIMESEQUALS;          #through;
            // case .DIVEQUALS;            #through;
            // case .MODEQUALS;            #through;
            // case .ISEQUAL;              #through;
            // case .ISNOTEQUAL;           #through;
            // case .LOGICAL_AND;          #through;
            // case .LOGICAL_OR;           #through;
            // case .LESSEQUALS;           #through;
            // case .GREATEREQUALS;        #through;
            // case .SHIFT_LEFT;           #through;
            // case .SHIFT_RIGHT;          #through;
            // case .ROTATE_LEFT;          #through;
            // case .ROTATE_RIGHT;         #through;
            // case .TRIPLE_EQUALS;        #through;
            // case .SHIFT_LEFT_EQUALS;    #through;
            // case .SHIFT_RIGHT_EQUALS;   #through;
            // case .ROTATE_LEFT_EQUALS;   #through;
            // case .ROTATE_RIGHT_EQUALS;  #through;
            // case .BITWISE_AND_EQUALS;   #through;
            // case .BITWISE_OR_EQUALS;    #through;
            // case .BITWISE_XOR_EQUALS;   #through;
            // case .LOGICAL_AND_EQUALS;   #through;
            // case .LOGICAL_OR_EQUALS;    #through;
            // // case .POINTER_DEREFERENCE;  #through; // TODO(jt): @Audit Does this still exist in JAI?
            // case .POSTFIX_DEREFERENCE;  highlight_token.type = .OPERATOR;

            // case .NOTE; {
            //     highlight_token.type = .ATTRIBUTE;
            //     highlight_token.loc0.x -= 1;
            // }

            case; {
                if token.type >= .__FIRST_KEYWORD && token.type <= .__LAST_KEYWORD {
                    highlight_token.type = .KEYWORD;
                }
            }
        }

        // last_token_is_pound = token.type == #char "#";
        if highlight_token.type == .UNINITIALIZED {
            continue;
        }

        array_add(*document.syntax_highlight_tokens, highlight_token);
    }

    log("nocheckin tokens: %", document.syntax_highlight_tokens);
}

DOLLAR :: #char "$";
