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

// TODO(jt): Support indentation like this:
// (
//     asdfasdfdfas)
//
// (This is how things can look when we switch from a single-line parenthesized block to a multiline one.)

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

    if #complete document.lang == {
        case .TEXT; {
            _update_scopes(document, TEXT_INDENTATION_PAREN_PAIRS,
                           "",
                           "", "", false,
                           "", "");
        }
        case .C; {
            _update_scopes(document, LANG_C_INDENTATION_PAREN_PAIRS,
                           LANG_C_LINE_COMMENT,
                           LANG_C_BLOCK_COMMENT_START, LANG_C_BLOCK_COMMENT_END, LANG_C_BLOCK_COMMENTS_CAN_NEST,
                           LANG_C_SINGLE_LINE_STRING, LANG_C_MULTI_LINE_STRING);
        }
        case .JAI; {
            _update_scopes(document, LANG_JAI_INDENTATION_PAREN_PAIRS,
                           LANG_JAI_LINE_COMMENT,
                           LANG_JAI_BLOCK_COMMENT_START, LANG_JAI_BLOCK_COMMENT_END, LANG_JAI_BLOCK_COMMENTS_CAN_NEST,
                           LANG_JAI_SINGLE_LINE_STRING, LANG_JAI_MULTI_LINE_STRING);
        }
        case .GLSL; {
            _update_scopes(document, LANG_GLSL_INDENTATION_PAREN_PAIRS,
                           LANG_GLSL_LINE_COMMENT,
                           LANG_GLSL_BLOCK_COMMENT_START, LANG_GLSL_BLOCK_COMMENT_END, LANG_GLSL_BLOCK_COMMENTS_CAN_NEST,
                           LANG_GLSL_SINGLE_LINE_STRING, LANG_GLSL_MULTI_LINE_STRING);
        }
        case .RUST; {
            _update_scopes(document, LANG_RUST_INDENTATION_PAREN_PAIRS,
                           LANG_RUST_LINE_COMMENT,
                           LANG_RUST_BLOCK_COMMENT_START, LANG_RUST_BLOCK_COMMENT_END, LANG_RUST_BLOCK_COMMENTS_CAN_NEST,
                           LANG_RUST_SINGLE_LINE_STRING, LANG_RUST_MULTI_LINE_STRING);
        }
    }
}

find_scope_for_location :: (document: Document, loc: Text_Location, x0_inclusive := true, x1_inclusive := true, y0_inclusive := true, y1_inclusive := true) -> *Scope {
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
            if contains(sibling, loc, x0_inclusive, x1_inclusive, y0_inclusive, y1_inclusive) {
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
    // the closing paren depending on whether the scope has regular or HANGING indentation,
    // while the opening paren always belongs to its parent scope, so we exclude it.
    scope := find_scope_for_location(document, loc, y0_inclusive = false);
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

contains :: (scope: Scope, loc: Text_Location, x0_inclusive: bool, x1_inclusive: bool, y0_inclusive: bool, y1_inclusive: bool) -> bool {
    test_top    := ifx y0_inclusive then loc.y >= scope.loc0.y else loc.y > scope.loc0.y;
    test_bottom := ifx y1_inclusive then loc.y <= scope.loc1.y else loc.y < scope.loc1.y;
    test_left   := ifx x0_inclusive then loc.x >= scope.loc0.x else loc.x > scope.loc0.x;
    test_right  := ifx x1_inclusive then loc.x <= scope.loc1.x else loc.x < scope.loc1.x;

    if test_top && test_bottom {
        if scope.loc0.y == scope.loc1.y {
            return test_left && test_right;
        } else if scope.loc0.y == loc.y {
            return test_left;
        } else if scope.loc1.y == loc.y {
            return test_right;
        } else {
            return true;
        }
    }

    return false;
}

// This autobake monstrosity is my piggy attempt to make scope parsing faster.
// It is exactly the same code as before, but bakes everything it can.
//
// In the best case, this allows you to skip entire blocks of code. In the worst case, it still moves
// some branches to compile-time, putting less stress on the the optimizer, branch predictor, etc.
//
// The downside is that this code will make a polymorph instantiation for every language.
// The speed gains are real, however. Just moving the conditions to compile time cause 2.5x speed boost.
//   -jt, 21 September 2026
_update_scopes :: (document: *Document, indentation_pairs: [] Paren_Pair,
                   $line_comment: string,
                   $block_comment_start: string, $block_comment_end: string, $block_comments_can_nest: bool,
                   $single_line_string: string, $multi_line_string: string)
{
    parent_index  := 0;
    sibling_index := -1;
    {
        scope := array_add(*document.scopes);
        scope.loc0 = text_buffer_get_start(document.buffer);
        scope.loc1 = text_buffer_get_end(document.buffer);
        scope.indentation_level = 0;
    }

    inside_block_comment      := 0;
    inside_single_line_string := false;
    inside_multi_line_string  := false;

    for :text_buffer_temp_lines line_text, line_index: document.buffer {
        for byte_index: 0..line_text.count - 1 {
            if !inside_single_line_string && !inside_multi_line_string {
                #if line_comment.count {
                    if inside_block_comment == 0 {
                        if String.begins_with(slice(line_text, byte_index), line_comment) {
                            break; // Skip this line entirely.
                        }
                    }
                }
                
                #if block_comment_start.count && block_comment_end.count {
                    #if block_comments_can_nest {
                        if String.begins_with(slice(line_text, byte_index), block_comment_start) {
                            inside_block_comment += 1;
                            
                            byte_index += block_comment_start.count - 1; // Advance over the block comment start.
                            continue;
                        }
                    } else {
                        if inside_block_comment == 0 {
                            if String.begins_with(slice(line_text, byte_index), block_comment_start) {
                                inside_block_comment += 1;
                                
                                byte_index += block_comment_start.count - 1; // Advance over the block comment start.
                                continue;
                            }
                        }
                    }
                    
                    if String.begins_with(slice(line_text, byte_index), block_comment_end) {
                        #if block_comments_can_nest {
                            inside_block_comment -= 1;
                            inside_block_comment = max(inside_block_comment, 0);
                        } else {
                            inside_block_comment = 0;
                        }
                        
                        byte_index += block_comment_end.count - 1; // Advance over the block comment end.
                        continue;
                    }
                }
            }
            
            if inside_block_comment > 0 {
                continue;
            }
            
            #if single_line_string.count {
                if !inside_multi_line_string {
                    if String.begins_with(slice(line_text, byte_index), single_line_string) {
                        if inside_single_line_string {
                            prev_is_backslash     := byte_index >= 1 && line_text[byte_index - 1] == "\\";
                            prevprev_is_backslash := byte_index >= 2 && line_text[byte_index - 2] == "\\";
                            
                            if !prev_is_backslash || prev_is_backslash && prevprev_is_backslash {
                                inside_single_line_string = false;
                            }
                        } else {
                            inside_single_line_string = true;
                        }
                    }
                }
            }
            
            #if multi_line_string.count {
                if !inside_single_line_string {
                    if String.begins_with(slice(line_text, byte_index), multi_line_string) {
                        if inside_multi_line_string {
                            prev_is_backslash     := byte_index >= 1 && line_text[byte_index - 1] == "\\";
                            prevprev_is_backslash := byte_index >= 2 && line_text[byte_index - 2] == "\\";
                            
                            if !prev_is_backslash || prev_is_backslash && prevprev_is_backslash {
                                inside_single_line_string = false;
                            }
                        } else {
                            inside_multi_line_string = true;
                        }
                    }
                }
            }
            
            if inside_single_line_string || inside_multi_line_string {
                continue;
            }
            
            byte := line_text[byte_index];
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
                    
                    break;
                } else if byte == paren_pair.close {
                    scope_index := parent_index;
                    scope := *document.scopes[scope_index];
                    if paren_pair.open == scope.open_paren_char {
                        // TODO(jt): @Speed Maintain count so we don't have to rescan the line?
                        scope.loc1.x = count_utf8_chars(String.slice(line_text, 0, byte_index));
                        scope.loc1.y = line_index;
                        
                        scope.close_paren_char = byte;
                        
                        parent_index  = scope.parent_index;
                        sibling_index = scope_index;
                    }
                    
                    // Ignoring mismatching closing parens is an alright behavior, but maybe there
                    // is something better we can do?
                    
                    break;
                }
            }
        }
    }
}