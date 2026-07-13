DEFAULT_INDENTATION_STEP :: 4;

// TODO(jt): @Speed When we indent 10000 lines, this takes ~8 seconds. Even if we SIMD this, it will
// traverse the whole document contents too many times. We need an incremental version, or perhaps
// some cooperative version that can work well with indenting large regions.
update_indentation_scopes :: (document: *Document) {
    ProfileZone("update_indentation_scopes");

    sanity_assert(document != null);
    if document == null {
        return;
    }

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
        scope.indentation_level = 0;
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

                    scope.open_paren_char = byte;
                    // close_paren is set when we find the closing paren

                    //
                    // indentation_level is set based on kind of indentation scope this is. We
                    // detect that here by looking for nonwhitespace character before and after the
                    // opening paren.
                    //

                    scope.indentation_level = scope.loc0.x + DEFAULT_INDENTATION_STEP;

                    for 0..byte_index - 1 {
                        // TODO(jt): @Speed We could SIMD this.
                        if !String.is_any(line[it], String.DEFAULT_SPACES) {
                            scope.flags |= .PREFIXED;
                            scope.indentation_level = it + DEFAULT_INDENTATION_STEP; // DEFAULT_SPACES are all single-byte.
                            break;
                        }
                    }

                    for byte_index + 1..line.count - 1 {
                        // TODO(jt): @Speed We could SIMD this.
                        if !String.is_any(line[it], String.DEFAULT_SPACES) {
                            // HANGING scopes are indented Casey-style (or is it Microsoft-style?)
                            scope.flags |= .HANGING;
                            scope.indentation_level = scope.loc0.x + it - byte_index; // DEFAULT_SPACES are all single-byte.
                            break;
                        }
                    }

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
                    if paren_pair.open == scope.open_paren_char {
                        // TODO(jt): @Speed Maintain count so we don't have to rescan the line?
                        scope.loc1.x = count_utf8_chars(String.slice(cast(string, line), 0, byte_index));
                        scope.loc1.y = line_index;

                        scope.close_paren_char = byte;

                        parent_index  = scope.parent_index;
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

find_indentation_level :: (document: Document, loc: Text_Location) -> s64 {
    ProfileZone("find_indentation_level");

    indentation_level := 0;
    current_index     := 0;
    while current_index != -1 {
        current := *document.indentation_scopes[current_index];
        indentation_level = current.indentation_level;

        // Indent to match opening paren.
        if current.loc1.y == loc.y && !(current.flags & .HANGING) {
            indentation_level = current.indentation_level - DEFAULT_INDENTATION_STEP;
        }

        // In the loop below, we the range check is start-exclusive and end-inclusive by design: we
        // indent the closing paren specially (depending on whether the scope has REGULAR or HANGING
        // indentation), while the opening paren always just belongs to its parent scope, so we want
        // to exclude it.
        current_index = -1;
        if current.first_child_index != -1 {
            child := *document.indentation_scopes[current.first_child_index];

            if loc.y > child.loc0.y && loc.y <= child.loc1.y {
                current_index = current.first_child_index;
            }

            while current_index == -1 && child.next_sibling_index != -1 {
                index := child.next_sibling_index;
                child = *document.indentation_scopes[index];

                if loc.y > child.loc0.y && loc.y <= child.loc1.y {
                    current_index = index;
                }
            }
        }
    }

    return indentation_level;
}
