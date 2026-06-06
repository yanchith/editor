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

find_indentation_level :: (document: Document) -> s64 {
    // TODO(jt): @Bug This fails to indent an empty line.
    // TODO(jt): @Bug Our parentheses parser does not skip comments. Should it?

    // TODO(jt): Make indent amount configurable, or maybe detect it fron content :Config.
    INDENT :: 4;

    cursor := document.buffer.cursor0;

    indentation_level := 0;
    current_index     := 0;
    while current_index != -1 {
        current := *document.indentation_scopes[current_index];
        indentation_level = current.nesting_depth * INDENT;

        current_index = -1;
        if current.first_child_index != -1 {
            child := *document.indentation_scopes[current.first_child_index];

            if cursor.y > child.loc0.y && cursor.y < child.loc1.y {
                current_index = current.first_child_index;
            }

            while current_index == -1 && child.next_sibling_index != -1 {
                index := child.next_sibling_index;
                child = *document.indentation_scopes[index];

                if cursor.y > child.loc0.y && cursor.y < child.loc1.y {
                    current_index = index;
                }
            }
        }
    }

    return indentation_level;
}
