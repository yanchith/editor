JL :: #import "Jai_Lexer";

LANG_JAI_SURROUND_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

lang_jai_update_indentation_scopes :: (editor: *Editor, document: *Document, platform: Platform, input: Input) {
    ProfileZone("lang_jai_update_syntax_highlights");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.indentation_scopes);

    parent_index  := document.indentation_scopes.count;
    sibling_index := -1;
    {
        scope := array_add(*document.indentation_scopes);
        scope.loc0 = { 0, 0 };
        scope.loc1 = { document.buffer.line_count - 1, document.buffer.line_chars[document.buffer.line_count - 1] };
        scope.nesting_depth = 0;
    }

    // See :IncrementalGapBufferIndices
    gb_index := 0;
    for line_index: 0..document.buffer.line_bytes.count - 1 {
        gb_count := document.buffer.line_bytes[line_index];

        // TODO(jt): @Speed SIMDify looking for parentheses!
        line := gap_buffer_make_view(document.buffer.gb, gb_index, gb_count,, temp);
        for byte, byte_index: line {
            for paren_pair: INDENTATION_PARENS {
                if byte == paren_pair.open {
                    index := document.indentation_scopes.count;
                    parent := *document.indentation_scopes[parent_index];

                    scope: Document.Indentation_Scope;
                    scope.loc0.x = count_utf8_chars(String.slice(cast(string, line), 0, byte_index));
                    scope.loc0.y = line_index;

                    // loc1 is properly set when we find the closing paren, but until then we set it
                    // to the end of the document, so that it forms a non-empty interval that can be
                    // found when someone searches the tree.
                    scope.loc1 = text_buffer_get_end(document.buffer);

                    scope.open_paren = byte;
                    scope.nesting_depth = parent.nesting_depth + 1;
                    scope.parent_index = parent_index;

                    if sibling_index == -1 {
                        assert(parent.first_child_index == -1);
                        parent.first_child_index = index;
                    } else {
                        sibling := *document.indentation_scopes[sibling_index];
                        sibling.next_sibling_index = index;
                    }

                    array_add(*document.indentation_scopes, scope); // We potentially invalidate pointers here, careful!

                    parent_index = index;
                    sibling_index = -1;

                    continue byte;
                } else if byte == paren_pair.close {
                    scope_index := parent_index;
                    scope := *document.indentation_scopes[scope_index];
                    if paren_pair.open == scope.open_paren {
                        // TODO(jt): @Speed Maintain count so we don't have to rescan the line?
                        scope.loc1.x = count_utf8_chars(String.slice(cast(string, line), 0, byte_index));
                        scope.loc1.y = line_index;

                        parent_index = scope.parent_index;
                        parent := *document.indentation_scopes[parent_index];

                        sibling_index = scope_index;
                    }

                    // Ignoring mismatching closing parens is an alright behavior, but maybe there
                    // is something better we can do?

                    continue byte;
                }
            }
        }

        gb_index += gb_count;
    }
}

lang_jai_update_syntax_highlights :: (editor: *Editor, document: *Document, platform: Platform, input: Input) {
    ProfileZone("lang_jai_update_syntax_highlights");

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
        // The highlight token interval is inclusive on both sides. This is sort of an arbitrary
        // choice we can revisit. Note however, that Jai_Lexer produces end-exclusive horizontal
        // range and end-inclusive vertical range due to the way set_end_of_token works. To correct
        // for this, we subtract 2 from c1.
        //
        // TODO(jt): @Audit is c0 and c1 counting in unicode or bytes?
        highlight_token.loc0.x = token.c0 - 1;
        highlight_token.loc0.y = token.l0 - 1;
        highlight_token.loc1.x = token.c1 - 2;
        highlight_token.loc1.y = token.l1 - 1;

        // TODO(jt): Modify font to be able to mix in multiple font weights in a single atlas
        // (regular, bold, italic, etc.) and make use of this.

        if token.type == {
            case .IDENT; {
                if last_token_is_pound || last_token_is_dollar {
                    highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                    highlight_token.loc0.x -= 1;
                } else if last_token_is_double_dollar {
                    highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                    highlight_token.loc0.x -= 2;
                }
            }

            case .NUMBER;               highlight_token.type = .NUMBER_LITERAL;
            case .STRING;               highlight_token.type = .STRING_LITERAL;
            case .TRIPLE_MINUS;         highlight_token.type = .PREPROCESSOR_DIRECTIVE;

            case .NOTE; {
                highlight_token.type = .ATTRIBUTE;
                highlight_token.loc0.x -= 1;
            }

            case .COMMENT;        #through;
            case .BLOCK_COMMENT;  highlight_token.type = .COMMENT;

            case; {
                if token.type >= .__FIRST_KEYWORD && token.type <= .__LAST_KEYWORD {
                    if last_token_is_pound {
                        highlight_token.type = .PREPROCESSOR_DIRECTIVE;
                        highlight_token.loc0.x -= 1;
                    } else {
                        highlight_token.type = .KEYWORD;
                    }
                }
            }
        }

        last_token_is_pound  = token.type == #char "#";
        last_token_is_dollar = token.type == DOLLAR;
        last_token_is_double_dollar = token.type == .DOUBLE_DOLLAR;

        if highlight_token.type != .UNINITIALIZED {
            array_add(*document.syntax_highlight_tokens, highlight_token);
        }
    }
}

#scope_file

INDENTATION_PARENS :: Paren_Pair.[
    { #char "(", #char ")" },
    { #char "{", #char "}" },
    { #char "[", #char "]" },
];

DOLLAR :: #char "$"; // Thank you Emacs!
