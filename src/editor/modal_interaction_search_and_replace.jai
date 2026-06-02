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

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Potentially Temporary_Storage*/ string {
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

    active_panel := get_active_panel(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return false;
    }

    userdata: *Search_And_Replace_Userdata = modal_interaction.userdata;
    if #complete userdata.state == {
        case .INPUT_TO_SEARCH;   return false;
        case .INPUT_TO_REPLACE;  return false;
        case .REPLACING; {
            sanity_assert(active_panel.highlights.count > 0);

            buffered, action := key_map_input(*userdata.replacing_key_map, event, editor.input_state.modifiers);
            if action == {
                case .YES; #through;
                case .NO; {
                    if action == .YES {
                        highlight := active_panel.highlights[active_panel.highlight_index];
                        x0 := highlight.x0;
                        x1 := highlight.x1;
                        y  := highlight.y;

                        document := active_panel.document;

                        // If we ever do anything that changes the buffer while the
                        // search&replace is open, these cursors will not be valid anymore
                        // and we need to somehow handle that. At the moment I am writing
                        // this, nothing like that exists in the editor.
                        document.buffer.cursor0 = { x0, y };
                        document.buffer.cursor1 = { x1, y };
                        text_buffer_insert(*document.buffer, userdata.input_to_replace, undo_barrier = true);

                        // Instead of advancing the index we contract the array.
                        array_ordered_remove_by_index(*active_panel.highlights, active_panel.highlight_index);

                        //
                        // If there are additional highlights on the same line, we need to
                        // adjust them based on the lengths of the text we removed and added:
                        //
                        remove_count := count_utf8_chars(userdata.input_to_search);
                        insert_count := count_utf8_chars(userdata.input_to_replace);
                        if remove_count != insert_count {
                            delta := insert_count - remove_count;

                            index := active_panel.highlight_index;
                            while index < active_panel.highlights.count {
                                highlight := *active_panel.highlights[index];
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
                        active_panel.highlight_index += 1;
                        userdata.processed_count += 1;
                    }

                    if active_panel.highlight_index >= active_panel.highlights.count {
                        array_reset_keeping_memory(*active_panel.highlights);
                        active_panel.highlight_index = -1;

                        editor_log(editor, "Done! Replaced % matches", userdata.replaced_count);
                        close_modal_interaction(editor, platform, input);
                    } else {
                        highlight := active_panel.highlights[active_panel.highlight_index];
                        x := highlight.x0;
                        y := highlight.y;

                        text_buffer_move_cursor_to(*active_panel.document.buffer, x, y, false);
                        recenter_active_panel(editor, input, true);
                    }
                }
                case .CANCEL; {
                    array_reset_keeping_memory(*active_panel.highlights);
                    active_panel.highlight_index = -1;

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

    active_panel := get_active_panel(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return;
    }

    arena := modal_interaction.userdata_arena;

    userdata: *Search_And_Replace_Userdata = modal_interaction.userdata;
    if #complete userdata.state == {
        case .INPUT_TO_SEARCH; {
            userdata.input_to_search = text_buffer_make_view_for_line(modal_interaction.buffer, 0, force_allocate = true,, arena_allocator(arena));
            text_buffer_reset(*modal_interaction.buffer);

            userdata.state = .INPUT_TO_REPLACE;
        }
        case .INPUT_TO_REPLACE; {
            userdata.input_to_replace = text_buffer_make_view_for_line(modal_interaction.buffer, 0, force_allocate = true,, arena_allocator(arena));
            text_buffer_reset(*modal_interaction.buffer);

            document := active_panel.document;

            array_reset_keeping_memory(*active_panel.highlights);
            active_panel.highlight_index = -1;

            old_cursor_y := document.buffer.cursor0.y;
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

                    highlight_index := active_panel.highlights.count;

                    highlight := array_add(*active_panel.highlights);
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
                active_panel.highlight_index = new_highlight_index;

                highlight := active_panel.highlights[new_highlight_index];
                x := highlight.x0;
                y := highlight.y;

                text_buffer_move_cursor_to(*document.buffer, x, y, false);
                recenter_active_panel(editor, input, true);
            }

            if active_panel.highlights.count && new_highlight_index != -1 {
                userdata.state = .REPLACING;

                userdata.found_count = active_panel.highlights.count;
                userdata.replaced_count = 0;
                userdata.processed_count = 0;
            } else {
                array_reset_keeping_memory(*active_panel.highlights);
                active_panel.highlight_index = -1;

                editor_log(editor, "No matches found");
                close_modal_interaction(editor, platform, input);
            }
        }
        case .REPLACING; assert(false);
    }
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    active_panel := get_active_panel(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return;
    }

    array_reset_keeping_memory(*active_panel.highlights);
    active_panel.highlight_index = -1;

    close_modal_interaction(editor, platform, input);
}
