DEFAULT_INDENTATION_STEP :: 4; // TODO(jt): Make this configurable (also per project). :Config

// TODO(jt): @Speed When we indent the entirety of a 10000 document, this takes ~8 seconds. Even if
// we SIMD this, it will traverse the whole document contents too many times. We need an incremental
// version, or perhaps some cooperative version that can work well with indenting large regions.
//
// UPDATE: For documents above ~2MB, this also causes us to miss frames for every edit. So need that
// incremental version for this reason also.
update_parenthesized_scopes :: (document: *Document) {
    ProfileZone("update_parenthesized_scopes");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    indentation_pairs: [] Paren_Pair;
    line_comment            := "";
    block_comment_start     := "";
    block_comment_end       := "";
    block_comments_can_nest := false;

    if #complete document.mode == {
        case .PLAIN_TEXT; {
            indentation_pairs = PLAIN_TEXT_INDENTATION_PAREN_PAIRS;
        }
        case .JAI; {
            indentation_pairs       = LANG_JAI_INDENTATION_PAREN_PAIRS;
            line_comment            = LANG_JAI_LINE_COMMENT;
            block_comment_start     = LANG_JAI_BLOCK_COMMENT_START;
            block_comment_end       = LANG_JAI_BLOCK_COMMENT_END;
            block_comments_can_nest = LANG_JAI_BLOCK_COMMENTS_CAN_NEST;
        }
    }

    array_reset_keeping_memory(*document.parenthesized_scopes);
    if document.buffer.binary_mode {
        return; // Don't recreate indentation data if we entered binary mode.
    }

    parent_index  := document.parenthesized_scopes.count;
    sibling_index := -1;
    {
        scope := array_add(*document.parenthesized_scopes);
        scope.loc0 = text_buffer_get_start(document.buffer);
        scope.loc1 = text_buffer_get_end(document.buffer);
        scope.indentation_level = 0;
    }

    block_comment_depth := 0;

    // See :IncrementalGapBufferIndices
    gb_index := 0;
    for line_index: 0..document.buffer.line_count - 1 {
        gb_count := document.buffer.line_bytes[line_index];
        defer {
            gb_index += gb_count;
        }

        // TODO(jt): @Cleanup @Speed This loop became a little gnarly. Also probably slow. Clean it up, so we can SIMD later.
        line := cast(string, gap_buffer_make_view(document.buffer.gb, gb_index, gb_count,, temp));
        skip := 0; // TODO(jt): @Cleanup This would normally just be a string advance, but our loop is structured unfortunately.

        for byte, byte_index: line {
            if skip > 0 {
                skip -= 1;
                continue;
            }

            //
            // Comment detection
            //

            // Note that we are comparing bytes with bytes in the comment detection code, but it shouldn't matter!
            is_line_comment := block_comment_depth == 0 && String.starts_with(String.slice(line, byte_index, line.count - byte_index), line_comment);
            if is_line_comment {
                continue line_index;
            }

            is_block_comment_start := (block_comment_depth == 0 || block_comments_can_nest) && String.starts_with(String.slice(line, byte_index, line.count - byte_index), block_comment_start);
            if is_block_comment_start {
                block_comment_depth += 1;

                skip = block_comment_start.count - 1;
                continue;
            }

            is_block_comment_end := block_comment_depth > 0 && String.starts_with(String.slice(line, byte_index, line.count - byte_index), block_comment_end);
            if is_block_comment_end {
                if block_comments_can_nest {
                    block_comment_depth -= 1;
                    sanity_assert(block_comment_depth >= 0);
                    block_comment_depth = max(block_comment_depth, 0);
                } else {
                    block_comment_depth = 0;
                }

                skip = block_comment_end.count - 1;
                continue;
            }

            if block_comment_depth > 0 {
                continue;
            }

            //
            // Parentheses detection
            //

            for paren_pair: indentation_pairs {
                if byte == paren_pair.open {
                    index := document.parenthesized_scopes.count;
                    parent := *document.parenthesized_scopes[parent_index];

                    scope: Document.Parenthesized_Scope;
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
                            scope.indentation_flags |= .PREFIXED;
                            scope.indentation_level = it + DEFAULT_INDENTATION_STEP; // DEFAULT_SPACES are all single-byte.
                            break;
                        }
                    }

                    for byte_index + 1..line.count - 1 {
                        // TODO(jt): @Speed We could SIMD this.
                        if !String.is_any(line[it], String.DEFAULT_SPACES) {
                            // HANGING scopes are indented Casey-style (or is it Microsoft-style?)
                            scope.indentation_flags |= .HANGING;
                            scope.indentation_level = scope.loc0.x + it - byte_index; // DEFAULT_SPACES are all single-byte.
                            break;
                        }
                    }

                    scope.parent_index = parent_index;
                    if sibling_index == -1 {
                        assert(parent.first_child_index == -1);
                        parent.first_child_index = index;
                    } else {
                        sibling := *document.parenthesized_scopes[sibling_index];
                        sibling.next_sibling_index = index;
                    }

                    array_add(*document.parenthesized_scopes, scope); // We potentially invalidate pointers here, careful!

                    parent_index = index;
                    sibling_index = -1;

                    continue byte;
                } else if byte == paren_pair.close {
                    scope_index := parent_index;
                    scope := *document.parenthesized_scopes[scope_index];
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
    }
}

find_parenthesized_scope_for_location :: (document: Document, loc: Text_Location, start_x_inclusive := true, end_x_inclusive := true, start_y_inclusive := true, end_y_inclusive := true) -> *Document.Parenthesized_Scope {
    ProfileZone("find_parenthesized_scope_for_location");

    scopes := document.parenthesized_scopes;
    if !scopes.count {
        return null;
    }

    scope := *scopes[0];

    while scope.first_child_index != -1 {
        sibling_index := scope.first_child_index;

        while sibling_index != -1 {
            sibling := *scopes[sibling_index];
            if contains(sibling, loc, start_x_inclusive, end_x_inclusive, start_y_inclusive, end_y_inclusive) {
                // We found a sibling that contains our location. Set it as the current scope, so that we nest to it.
                scope = sibling;
                break;
            }

            sibling_index = sibling.next_sibling_index;
        }

        if sibling_index == -1 {
            // We did not find any sibling that contains our location. End.
            break;
        }
    }

    return scope;
}

find_indentation_level_for_location :: (document: Document, loc: Text_Location) -> s64 {
    // The Y range check is start-exclusive and end-inclusive by design: we indent the line of
    // the closing paren depending on whether the scope has REGULAR or HANGING indentation,
    // while the opening paren always belongs to its parent scope, so we exclude it.
    scope := find_parenthesized_scope_for_location(document, loc, start_y_inclusive = false);
    if !scope {
        return 0;
    }

    sanity_assert(scope.indentation_level >= 0);
    level := scope.indentation_level;

    // If this is the last line of the scope (and it is not a HANGING indentation style),
    // indent to the parent scope's level, if it exists.
    if scope.loc1.y == loc.y && !(scope.indentation_flags & .HANGING) {
        if scope.parent_index >= 0 {
            parent := *document.parenthesized_scopes[scope.parent_index];
            sanity_assert(parent.indentation_level >= 0);

            level = parent.indentation_level;
        }
    }

    return level;
}

#scope_file

contains :: (scope: Document.Parenthesized_Scope, loc: Text_Location, start_x_inclusive: bool, end_x_inclusive: bool, start_y_inclusive: bool, end_y_inclusive: bool) -> bool {
    test_top    := start_y_inclusive && loc.y >= scope.loc0.y || loc.y > scope.loc0.y;
    test_bottom := end_y_inclusive   && loc.y <= scope.loc1.y || loc.y < scope.loc1.y;
    test_left   := start_x_inclusive && loc.x >= scope.loc0.x || loc.x > scope.loc0.x;
    test_right  := end_x_inclusive   && loc.x <= scope.loc1.x || loc.x < scope.loc1.x;

    if test_top && test_bottom {
        if scope.loc0.y == scope.loc1.y { // Can only happen if it is y-inclusive.
            return test_left && test_right;
        } else if scope.loc0.y == loc.y { // Can only happen if it is y-inclusive.
            return test_left;
        } else if scope.loc1.y == loc.y { // Can only happen if it is y-inclusive.
            return test_right;
        } else {
            return true;
        }
    }

    return false;
}
