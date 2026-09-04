Scope :: struct {
    loc0: Text_Location;
    loc1: Text_Location;

    open_paren_char:  u32;
    close_paren_char: u32;

    indentation_flags: Indentation_Flags;
    indentation_level: s64;

    parent_index:       s64 = -1;
    first_child_index:  s64 = -1;
    next_sibling_index: s64 = -1;

    Indentation_Flags :: enum_flags u32 {
        NONE :: 0;

        HANGING  :: 0x01; // Casey-style scope, e.g. 'hwnd = CreateWindowExW(0,' (continues on the next line).
        PREFIXED :: 0x02; // The scope opening paren has text before it, e.g. 'for {'. Not actually read, but maybe it will be useful later?
    }
}

// TODO(jt): @Bug If a comment starts in a string, it continues. Need to track strings.

// TODO(jt): @Speed When we indent the entirety of a 10000-line document, this takes ~8 seconds. Even if
// we SIMD this, it will traverse the whole document contents too many times. We need an incremental
// version, or perhaps some cooperative version that can work well with indenting large regions.
//
// TODO(jt): @Speed For documents above ~2MB, this also causes us to miss frames for every edit.
// The problem is 2MB isn't really that large. This needs to become 10x faster AND we should also
// think about doing an incremental thing.
update_scopes :: (document: *Document) {
    ProfileZone("update_scopes");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.scopes);

    if document.buffer.binary_mode                         return;
    if document.buffer.gb.count > INDENTATION_CUTOFF_SIZE  return;


    indentation_pairs: [] Paren_Pair;
    line_comment: string;
    block_comment_start: string;
    block_comment_end: string;
    block_comments_can_nest: bool;

    if #complete document.lang == {
        case .PLAIN_TEXT; {
            indentation_pairs = PLAIN_TEXT_INDENTATION_PAREN_PAIRS;
        }
        case .C; {
            indentation_pairs       = LANG_C_INDENTATION_PAREN_PAIRS;
            line_comment            = LANG_C_LINE_COMMENT;
            block_comment_start     = LANG_C_BLOCK_COMMENT_START;
            block_comment_end       = LANG_C_BLOCK_COMMENT_END;
            block_comments_can_nest = LANG_C_BLOCK_COMMENTS_CAN_NEST;
        }
        case .JAI; {
            indentation_pairs       = LANG_JAI_INDENTATION_PAREN_PAIRS;
            line_comment            = LANG_JAI_LINE_COMMENT;
            block_comment_start     = LANG_JAI_BLOCK_COMMENT_START;
            block_comment_end       = LANG_JAI_BLOCK_COMMENT_END;
            block_comments_can_nest = LANG_JAI_BLOCK_COMMENTS_CAN_NEST;
        }
        case .GLSL; {
            indentation_pairs       = LANG_GLSL_INDENTATION_PAREN_PAIRS;
            line_comment            = LANG_GLSL_LINE_COMMENT;
            block_comment_start     = LANG_GLSL_BLOCK_COMMENT_START;
            block_comment_end       = LANG_GLSL_BLOCK_COMMENT_END;
            block_comments_can_nest = LANG_GLSL_BLOCK_COMMENTS_CAN_NEST;
        }
    }

    parent_index  := document.scopes.count;
    sibling_index := -1;
    {
        scope := array_add(*document.scopes);
        scope.loc0 = text_buffer_get_start(document.buffer);
        scope.loc1 = text_buffer_get_end(document.buffer);
        scope.indentation_level = 0;
    }

    block_comment_depth := 0;

    for :text_buffer_lines line_text, line_index: document.buffer {
        // TODO(jt): @Cleanup @Speed This loop became a little gnarly. Also probably slow. Clean it up, so we can SIMD later.
        skip_due_to_block_comment_open_or_close := 0; // TODO(jt): @Cleanup This would normally just be a string advance, but our loop is structured unfortunately.

        for byte, byte_index: line_text {
            if skip_due_to_block_comment_open_or_close > 0 {
                skip_due_to_block_comment_open_or_close -= 1;
                continue;
            }

            //
            // Comment detection
            //

            // Note that we are comparing bytes with bytes in the comment detection code, but it shouldn't matter!
            if line_comment.count {
                is_line_comment := block_comment_depth == 0 && String.starts_with(String.slice(line_text, byte_index, line_text.count - byte_index), line_comment);
                if is_line_comment {
                    continue line_index;
                }
            }

            if block_comment_start.count {
                is_block_comment_start := (block_comment_depth == 0 || block_comments_can_nest) && String.starts_with(String.slice(line_text, byte_index, line_text.count - byte_index), block_comment_start);
                if is_block_comment_start {
                    block_comment_depth += 1;

                    skip_due_to_block_comment_open_or_close = block_comment_start.count - 1;
                    continue;
                }
            }

            if block_comment_end.count {
                is_block_comment_end := block_comment_depth > 0 && String.starts_with(String.slice(line_text, byte_index, line_text.count - byte_index), block_comment_end);
                if is_block_comment_end {
                    if block_comments_can_nest {
                        block_comment_depth -= 1;
                        sanity_assert(block_comment_depth >= 0);
                        block_comment_depth = max(block_comment_depth, 0);
                    } else {
                        block_comment_depth = 0;
                    }

                    skip_due_to_block_comment_open_or_close = block_comment_end.count - 1;
                    continue;
                }
            }

            if block_comment_depth > 0 {
                continue;
            }

            //
            // Parentheses detection
            //

            for paren_pair: indentation_pairs {
                if byte == paren_pair.open {
                    index := document.scopes.count;
                    parent := *document.scopes[parent_index];

                    scope: Scope;
                    scope.loc0.x = count_utf8_chars(String.slice(line_text, 0, byte_index));
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

                    scope.indentation_level = scope.loc0.x + INDENTATION_STEP;

                    for 0..byte_index - 1 {
                        // TODO(jt): @Speed We could SIMD this.
                        if !String.is_any(line_text[it], String.DEFAULT_SPACES) {
                            scope.indentation_flags |= .PREFIXED;
                            scope.indentation_level = it + INDENTATION_STEP; // DEFAULT_SPACES are all single-byte.
                            break;
                        }
                    }

                    for byte_index + 1..line_text.count - 1 {
                        // TODO(jt): @Speed We could SIMD this.
                        if !String.is_any(line_text[it], String.DEFAULT_SPACES) {
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
                        sibling := *document.scopes[sibling_index];
                        sibling.next_sibling_index = index;
                    }

                    array_add(*document.scopes, scope); // We potentially invalidate pointers here, careful!

                    parent_index = index;
                    sibling_index = -1;

                    continue byte;
                } else if byte == paren_pair.close {
                    scope_index := parent_index;
                    scope := *document.scopes[scope_index];
                    if paren_pair.open == scope.open_paren_char {
                        // TODO(jt): @Speed Maintain count so we don't have to rescan the line?
                        scope.loc1.x = count_utf8_chars(String.slice(cast(string, line_text), 0, byte_index));
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

find_scope_for_location :: (document: Document, loc: Text_Location, start_x_inclusive := true, end_x_inclusive := true, start_y_inclusive := true, end_y_inclusive := true) -> *Scope {
    ProfileZone("find_scope_for_location");

    scopes := document.scopes;
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
    scope := find_scope_for_location(document, loc, start_y_inclusive = false);
    if !scope {
        return 0;
    }

    sanity_assert(scope.indentation_level >= 0);
    level := scope.indentation_level;

    // If this is the last line of the scope (and it is not a HANGING indentation style),
    // indent to the parent scope's level, if it exists.
    if scope.loc1.y == loc.y && !(scope.indentation_flags & .HANGING) {
        if scope.parent_index >= 0 {
            parent := *document.scopes[scope.parent_index];
            sanity_assert(parent.indentation_level >= 0);

            level = parent.indentation_level;
        }
    }

    return level;
}

#scope_file

// TODO(jt): @Cleanup This could be unified with Font_Text_Range in font.jai.
contains :: (scope: Scope, loc: Text_Location, start_x_inclusive: bool, end_x_inclusive: bool, start_y_inclusive: bool, end_y_inclusive: bool) -> bool {
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
