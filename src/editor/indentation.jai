// nocheckin maybe this is only going to be for parentheses highlight, so rename accordingly
update_indentation_scopes :: (document: *Document) {
    ProfileZone("update_indentation_scopes");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    // TODO(jt): @Bug Do something else if the buffer is binary.
    indentation_pairs: [] Paren_Pair;
    if #complete document.mode == {
        case .PLAIN_TEXT;  indentation_pairs = PLAIN_TEXT_INDENTATION_PAIRS;
        case .JAI;         indentation_pairs = LANG_JAI_INDENTATION_PAIRS;
    }

    array_reset_keeping_memory(*document.indentation_scopes);
    if document.buffer.binary_mode {
        return; // Don't recreate indentation data if we entered binary mode.
    }

    parent_index  := document.indentation_scopes.count;
    sibling_index := -1;
    {
        scope := array_add(*document.indentation_scopes);
        scope.loc0 = text_buffer_get_start(document.buffer);
        scope.loc1 = text_buffer_get_end(document.buffer);
        scope.nesting_depth = 0;
    }

    // See :IncrementalGapBufferIndices
    gb_index := 0;
    for line_index: 0..document.buffer.line_bytes.count - 1 {
        gb_count := document.buffer.line_bytes[line_index];

        // TODO(jt): @Speed SIMDify looking for parentheses!
        line := gap_buffer_make_view(document.buffer.gb, gb_index, gb_count,, temp);
        for byte, byte_index: line {
            for paren_pair: indentation_pairs {
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
                    // close_paren is set when we find the closing paren
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

                        scope.close_paren = byte;

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

// nocheckin explain and maybe just return an index, also maybe we need to fix this
find_indentation_scope_for_location :: (document: Document, loc: Text_Location) -> *Document.Indentation_Scope {
    ProfileZone("find_indentation_scope_for_location");

    log("nocheckin find scope for %", loc);

    if !document.indentation_scopes.count {
        return null;
    }

    current_index := 0;
    current := *document.indentation_scopes[current_index];
    while current_index != -1 {
        current = *document.indentation_scopes[current_index];
        current_index = -1;

        if current.first_child_index != -1 {
            child := *document.indentation_scopes[current.first_child_index];

            if loc.y > child.loc0.y && loc.y < child.loc1.y {
                current_index = current.first_child_index;
            }

            while current_index == -1 && child.next_sibling_index != -1 {
                index := child.next_sibling_index;
                child = *document.indentation_scopes[index];

                if loc.y > child.loc0.y && loc.y < child.loc1.y {
                    current_index = index;
                }
            }
        }
    }

    return current;
}

// Very basic parenthesis based indentation. Emulates Emacs. Supports these:
//
// procedure_call(a);
// procedure_call( a );
//
// procedure_call(
//     a, b,
//     c, d,
// );
// procedure_call(
//     a,
//     b,
// )
//
// procedure_call(a, b
//                c);
// procedure_call(a,
//                b, c, d)
// procedure_call(a b c
//                d e f)
// procedure_call( a b c
//                 d );
//
// procedure_call( a b another_procedure_call (
//     a
//     b
// ) );
// procedure_call ( a b another( a,
//                               b ) );
//
// {
//     ({
//         thing
//     })
// }
//
// call(a, b, {
//     c;
// })
// call({( asdfasdf,
//         asfdasdf )})
//
// block({
//  if a { // Intentionally possible to misalign
//      a;
//      b;
//  }
// })
//
determine_line_indentation_level :: (document: Document, line_index: s64) -> s64 {
    INDENT_STEP :: 4; // TODO(jt): Make this configurable. :Config

    if line_index == 0 {
        return 0;
    }

    indentation_pairs: [] Paren_Pair;
    if #complete document.mode == {
        case .PLAIN_TEXT;  indentation_pairs = PLAIN_TEXT_INDENTATION_PAIRS;
        case .JAI;         indentation_pairs = LANG_JAI_INDENTATION_PAIRS;
    }

    previous_line_view         := text_buffer_make_view_for_line(document.buffer, line_index - 1,, temp);
    previous_line_view_trimmed := String.trim_right(previous_line_view);

    current_line_view         := text_buffer_make_view_for_line(document.buffer, line_index,, temp);
    current_line_view_trimmed := String.trim_left(current_line_view);

    // Not calling this on the trimmed version, because the line could be all whitespace!
    previous_line_indent := count_leading_whitespace_chars(previous_line_view); // TODO(jt): Handle tabs!

    previous_line_ends_with_open_paren := false;
    previous_line_contains_open_paren  := false;
    previous_line_open_paren_index     := -1;

    previous_line_contains_close_paren := false;
    previous_line_close_paren_index    := -1;

    if previous_line_view_trimmed.count {
        // TODO(jt): @Incomplete Decode ascii instead of of looking at the first byte.
        for byte, byte_index: previous_line_view_trimmed {
            for indentation_pairs {
                if it.open == byte  {
                    previous_line_contains_open_paren = true;
                    previous_line_open_paren_index = byte_index;
                }

                if it.close == byte {
                    previous_line_contains_close_paren = true;
                    previous_line_close_paren_index = byte_index;
                }
            }
        }

        if previous_line_open_paren_index == previous_line_view_trimmed.count - 1 {
            previous_line_ends_with_open_paren = true;
        }
    }

    if previous_line_contains_close_paren {
        indentation_level := 0;
        if document.indentation_scopes.count {
            scope := find_indentation_scope_for_location(document, { 0, line_index - 1 });
            if scope {
                // TODO(jt): Do explicit stack recursion instead!
                indentation_level := determine_line_indentation_level(document, scope.loc0.y);
            }
        }

        log("nocheckin Recursion branch returning %!", indentation_level);
        return indentation_level;
    } else if previous_line_contains_open_paren && !previous_line_ends_with_open_paren {
        indentation_level := previous_line_open_paren_index + 1;
        while indentation_level < previous_line_view_trimmed.count && String.is_any(previous_line_view_trimmed[indentation_level], String.DEFAULT_SPACES) {
            indentation_level += 1;
        }

        log("nocheckin Microsoft branch returning %!", indentation_level);
        return indentation_level;
    } else {
        current_line_starts_with_close_paren := false;
        if current_line_view_trimmed.count {
            // TODO(jt): @Incomplete Decode ascii instead of of looking at the first byte.
            first_byte := current_line_view_trimmed[0];
            for indentation_pairs {
                if it.close == first_byte {
                    current_line_starts_with_close_paren = true;
                }
            }
        }

        indentation_level := previous_line_indent;
        if previous_line_ends_with_open_paren    indentation_level += INDENT_STEP;
        if current_line_starts_with_close_paren  indentation_level -= INDENT_STEP;

        log("nocheckin Regular branch returning %!", indentation_level);
        return indentation_level;
    }
}
