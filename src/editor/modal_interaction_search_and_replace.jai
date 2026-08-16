// TODO(jt): @Bug @Incomplete respect READONLY.
// TODO(jt): @Bug In the X/Y text Y counts every match, even ones above the cursor when we started the search.

// TODO(jt): Preserve capitalization when replacing - our match text can be all lowercase, which
// will match all sorts of text, but we want to preserve at least CamelCase, UPPER_CASE, etc.

modal_interaction_search_and_replace_procs: Modal_Interaction_Procs = {
    get_action_text,
    init,
    handle_event,
    advance,
    cancel,
};

#scope_file

Search_And_Replace_Userdata :: struct {
    // Everything in here is valid when zero-initialized, but the key map will want its allocator set!

    state: State;

    input_to_search: string;
    input_to_replace: string;

    replacing_key_map: Key_Map(Action);

    found_count:     s64;
    replaced_count:  s64;
    processed_count: s64;

    State :: enum {
        INPUT_TO_SEARCH   :: 0;
        INPUT_TO_REPLACE  :: 1;
        REPLACING         :: 2;
    }

    Action :: enum {
        NONE;

        YES;
        NO;
        CANCEL;
    }
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage or Static */ string {
    modal_interaction := *editor.modal_interaction;
    sanity_assert(modal_interaction.open);
    if !modal_interaction.open {
        return "";
    }

    userdata: *Search_And_Replace_Userdata = modal_interaction.userdata;
    if #complete userdata.state == {
        case .INPUT_TO_SEARCH;   return "Text to replace: ";
        case .INPUT_TO_REPLACE;  return tprint("Replace % with: ", userdata.input_to_search);
        case .REPLACING;         return tprint("Replacing % with % (%/%)", userdata.input_to_search, userdata.input_to_replace, userdata.processed_count + 1, userdata.found_count);
    }
}

init :: (editor: *Editor, platform: Platform, input: Input) {
    modal_interaction := *editor.modal_interaction;
    sanity_assert(modal_interaction.open);
    if !modal_interaction.open {
        return;
    }

    arena := modal_interaction.userdata_arena;

    userdata := arena_push(arena, Search_And_Replace_Userdata);
    userdata.replacing_key_map.allocator = arena_allocator(arena);
    key_map_reserve(*userdata.replacing_key_map, 8);

    key_map_add(*userdata.replacing_key_map, "y",   .YES);
    key_map_add(*userdata.replacing_key_map, "n",   .NO);
    key_map_add(*userdata.replacing_key_map, "q",   .CANCEL);
    key_map_add(*userdata.replacing_key_map, "C-g", .CANCEL);

    modal_interaction.userdata = userdata;
}

handle_event :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) -> handled: bool {
    modal_interaction := *editor.modal_interaction;
    sanity_assert(modal_interaction.open);
    if !modal_interaction.open {
        return false;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return false;
    }

    // Search and replace only works for DOCUMENT views.
    if panel.view.kind != .DOCUMENT {
        return false;
    }

    view := *panel.view._document;

    userdata: *Search_And_Replace_Userdata = modal_interaction.userdata;
    if #complete userdata.state == {
        case .INPUT_TO_SEARCH;   return false;
        case .INPUT_TO_REPLACE;  return false;
        case .REPLACING; {
            sanity_assert(panel.highlights.count > 0);

            buffered, action := key_map_input(*userdata.replacing_key_map, event);
            if action == {
                case .YES; #through;
                case .NO; {
                    if action == .YES {
                        highlight := panel.highlights[panel.highlight_index];
                        x0 := highlight.x0;
                        x1 := highlight.x1;
                        y  := highlight.y;

                        document := view.document;

                        // If we ever do anything that changes the buffer while the
                        // search&replace is open, these cursors will not be valid anymore
                        // and we need to somehow handle that. At the moment I am writing
                        // this, nothing like that exists in the editor.
                        view.cursors.c0 = { x0, y };
                        view.cursors.c1 = { x1, y };
                        text_buffer_insert(*document.buffer, *view.cursors, userdata.input_to_replace, .NONE);

                        document.flags |= .MODIFIED_THIS_FRAME;
                        document.flags |= .MODIFIED;

                        // Instead of advancing the index we contract the array.
                        array_ordered_remove_by_index(*panel.highlights, panel.highlight_index);

                        //
                        // If there are additional highlights on the same line, we need to
                        // adjust them based on the lengths of the text we removed and added:
                        //
                        remove_count := count_utf8_chars(userdata.input_to_search);
                        insert_count := count_utf8_chars(userdata.input_to_replace);
                        if remove_count != insert_count {
                            delta := insert_count - remove_count;

                            index := panel.highlight_index;
                            while index < panel.highlights.count {
                                highlight := *panel.highlights[index];
                                if highlight.y > y {
                                    break;
                                }

                                highlight.x0 += delta;
                                highlight.x1 += delta;

                                index += 1;
                            }
                        }

                        userdata.replaced_count += 1;
                        userdata.processed_count += 1;
                    } else if action == .NO {
                        panel.highlight_index += 1;
                        userdata.processed_count += 1;
                    }

                    if panel.highlight_index >= panel.highlights.count {
                        array_reset_keeping_memory(*panel.highlights);
                        panel.highlight_index = -1;

                        editor_log(editor, "Done! Replaced % matches", userdata.replaced_count);
                        close_modal_interaction(editor, platform, input);
                    } else {
                        highlight := panel.highlights[panel.highlight_index];
                        x := highlight.x0;
                        y := highlight.y;

                        text_buffer_move_cursor_to(view.document.buffer, *view.cursors, x, y, false);
                        view.flags |= .CLAMP_SCROLL_TO_CURSOR;
                        view.flags |= .RECEIVED_INDIRECT_KEYBOARD_INTERACTION;
                    }
                }
                case .CANCEL; {
                    array_reset_keeping_memory(*panel.highlights);
                    panel.highlight_index = -1;

                    editor_log(editor, "Cancel! Replaced % matches", userdata.replaced_count);
                    close_modal_interaction(editor, platform, input);
                }
            }

            return true;
        }
    }
}

advance :: (editor: *Editor, platform: Platform, input: Input) {
    ProfileZone("modal_interaction_search_and_replace_advance_proc");

    modal_interaction := *editor.modal_interaction;
    sanity_assert(modal_interaction.open);
    if !modal_interaction.open {
        return;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    // Search and replace only works for DOCUMENT views.
    if panel.view.kind != .DOCUMENT {
        return;
    }

    view := *panel.view._document;

    arena := modal_interaction.userdata_arena;

    userdata: *Search_And_Replace_Userdata = modal_interaction.userdata;
    if #complete userdata.state == {
        case .INPUT_TO_SEARCH; {
            userdata.input_to_search = text_buffer_make_view_for_line(modal_interaction.buffer, 0, force_allocate = true,, arena_allocator(arena));
            text_buffer_delete_all(*modal_interaction.buffer, *modal_interaction.cursors);

            userdata.state = .INPUT_TO_REPLACE;
        }
        case .INPUT_TO_REPLACE; {
            userdata.input_to_replace = text_buffer_make_view_for_line(modal_interaction.buffer, 0, force_allocate = true,, arena_allocator(arena));
            text_buffer_delete_all(*modal_interaction.buffer, *modal_interaction.cursors);

            document := view.document;

            array_reset_keeping_memory(*panel.highlights);
            panel.highlight_index = -1;

            old_cursor_y := view.cursors.c0.y;
            new_highlight_index := -1;

            search_text := userdata.input_to_search;
            search_text_char_count := ifx document.buffer.binary_mode then search_text.count else count_utf8_chars(search_text);

            // TODO(jt): @Speed This causes us to miss frames above 4MB buffers. It is serviceable
            // up to about 64MB, but this definitely needs to be 100x faster. An easy win would be
            // fan-out & collect threading, but we should also do SIMD.
            gb_index := 0;
            for 0..document.buffer.line_bytes.count - 1 {
                gb_count := document.buffer.line_bytes[it];

                // :IncrementalGapBufferIndices
                //
                // We go straight to the gap buffer and count its indices manually, so that
                // we avoid the quadratic behavior of calling get_gb_index_for_line each
                // time through the loop.
                //
                // Note that even though we pass in temp, making of the view will only
                // allocate for one of the lines - the one that crosses the gap.
                line_bytes := gap_buffer_make_view(document.buffer.gb, gb_index, gb_count,, temp);
                line_text  := cast(string, line_bytes);

                // This is number of bytes if we are in binary mode, otherwise number of characters.
                processed_chars: s64 = 0;

                found_index := find_index_from_left_nocase(line_text, search_text);
                while found_index != -1 && line_text.count {
                    x0 := processed_chars + found_index;
                    if !document.buffer.binary_mode {
                        x0 = processed_chars + count_utf8_chars(String.slice(line_text, 0, found_index));
                    }
                    x1 := x0 + search_text_char_count;
                    y  := it;

                    highlight_index := panel.highlights.count;

                    highlight := array_add(*panel.highlights);
                    highlight.x0 = x0;
                    highlight.x1 = x1;
                    highlight.y  = it;

                    if new_highlight_index == -1 && it >= old_cursor_y {
                        new_highlight_index = highlight_index;
                    }

                    if document.buffer.binary_mode {
                        processed_chars += found_index + search_text.count;
                    } else {
                        processed_chars += count_utf8_chars(String.slice(line_text, 0, found_index + search_text.count));
                    }
                    advance(*line_text, found_index + search_text.count);

                    found_index = find_index_from_left_nocase(line_text, search_text);
                }

                gb_index += gb_count;
            }

            if new_highlight_index != -1 {
                panel.highlight_index = new_highlight_index;

                highlight := panel.highlights[new_highlight_index];
                x := highlight.x0;
                y := highlight.y;

                text_buffer_move_cursor_to(document.buffer, *view.cursors, x, y, false);

                view.flags |= .CLAMP_SCROLL_TO_CURSOR;
                view.flags |= .RECEIVED_INDIRECT_KEYBOARD_INTERACTION;
            }

            if panel.highlights.count && new_highlight_index != -1 {
                userdata.state = .REPLACING;

                userdata.found_count = panel.highlights.count;
                userdata.replaced_count = 0;
                userdata.processed_count = 0;
            } else {
                array_reset_keeping_memory(*panel.highlights);
                panel.highlight_index = -1;

                editor_log(editor, "No matches found");
                close_modal_interaction(editor, platform, input);
            }
        }
        case .REPLACING; assert(false);
    }
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    array_reset_keeping_memory(*panel.highlights);
    panel.highlight_index = -1;

    close_modal_interaction(editor, platform, input);
}
