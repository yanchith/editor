mini_panel_search_procs: Mini_Panel_Procs = {
    get_action_text,
    can_select_text_line,
    init,
    update,
    delete_backward,
    autocomplete,
    confirm,
    cancel,
};

#scope_file

Search_Userdata :: struct {
    original_x: s64; // Not used for listings.
    original_y: s64;
}

Search_Item_Userdata :: struct {
    x: s64;
    y: s64;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("%  Search: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return false;
}

init :: (editor: *Editor, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    userdata := arena_push(mini_panel.userdata_arena, Search_Userdata);

    if #complete panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            userdata.original_x = view.cursors.c0.x;
            userdata.original_y = view.cursors.c0.y;
        }
        case .LISTING; {
            view := *panel.view._listing;
            userdata.original_x = 0;
            userdata.original_y = view.item_index;
        }
    }

    mini_panel.userdata = userdata;
}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_search_update_proc");

    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        array_reset_keeping_memory(*panel.highlights);
        panel.highlight_index = -1;

        search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        search_parts, smartcase := line_search_prepare_parts(search_text,, temp);
        search_part1_char_count := ifx search_parts.count then count_utf8_chars(search_parts[0]) else 0;

        if panel.view.kind == {
            case .DOCUMENT; {
                view := *panel.view._document;
                document := view.document;

                if document {
                    old_cursor_y   := view.cursors.c0.y;
                    new_item_index := -1;

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
                        //
                        // UPDATE: Could we have a for_expansion that just does this line-oriented iteration
                        // for us (including the manual gap buffer index counting?)
                        line_bytes := gap_buffer_make_view(document.buffer.gb, gb_index, gb_count,, temp);
                        line_text  := cast(string, line_bytes);

                        found, found_indices := line_search(line_text, search_parts, smartcase,, temp);
                        if found {
                            found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                            line_number_prefix := temp_right_pad(tprint("%  ", it + 1), 4);

                            // TODO(jt): @Cleanup We do additional manual copy into our arena here, because MEMORY_DEBUGGER otherwise
                            // flags this as 'an allocation for an address that the memory debugging system thought was still live'.
                            // See :MemoryDebuggerVsArenas.
                            _s := tprint("%%", line_number_prefix, line_text);
                            s := arena_push_string(mini_panel.items_arena, _s);

                            x0 := found_index;
                            if !document.buffer.binary_mode {
                                x0 = count_utf8_chars(String.slice(line_text, 0, found_index));
                            }
                            x1 := x0 + search_part1_char_count;

                            highlight := array_add(*panel.highlights);
                            highlight.x0 = x0;
                            highlight.x1 = x1;
                            highlight.y  = it;

                            item_index := mini_panel.items.count;
                            item := array_add(*mini_panel.items);
                            item.text = s;
                            if document.buffer.binary_mode {
                                item.flags |= .BINARY;
                            }
                            item.highlight_x0 = line_number_prefix.count + x0;
                            item.highlight_x1 = line_number_prefix.count + x1;

                            userdata := arena_push(mini_panel.items_arena, Search_Item_Userdata);
                            userdata.x = x0;
                            userdata.y = it;

                            item.userdata = userdata;

                            if new_item_index == -1 && it >= old_cursor_y {
                                new_item_index = item_index;
                            }
                        }

                        gb_index += gb_count;
                    }

                    if new_item_index == -1 {
                        new_item_index = mini_panel.items.count - 1;
                    }

                    if new_item_index != -1 {
                        mini_panel.item_index = new_item_index;
                        panel.highlight_index = new_item_index;
                        selected_item_changed = true;
                    }
                }

            }

            case .LISTING; {
                view := *panel.view._listing;
                listing := view.listing;

                if listing {
                    // TODO(jt): @Cleanup We call it old_cursor_y here to disambiguate from
                    // item_index... because both a listing panel and the minipanel have them.
                    old_cursor_y   := view.item_index;
                    new_item_index := -1;

                    for listing.items {
                        found, found_indices := line_search(it.text, search_parts, smartcase,, temp);
                        if found {
                            found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                            line_number_prefix := temp_right_pad(tprint("%  ", it_index + 1), 4);
                            s := sprint("%%", line_number_prefix, it.text,, arena_allocator(mini_panel.items_arena));

                            x0 := found_index;
                            x1 := x0 + search_part1_char_count;

                            highlight := array_add(*panel.highlights);
                            highlight.x0 = x0;
                            highlight.x1 = x1;
                            highlight.y  = it_index;

                            item_index := mini_panel.items.count;
                            item := array_add(*mini_panel.items);
                            item.text = s;
                            item.highlight_x0 = line_number_prefix.count + x0;
                            item.highlight_x1 = line_number_prefix.count + x1;

                            userdata := arena_push(mini_panel.items_arena, Search_Item_Userdata);
                            userdata.x = 0;
                            userdata.y = it_index;

                            item.userdata = userdata;

                            if new_item_index == -1 && it_index >= old_cursor_y {
                                new_item_index = item_index;
                            }
                        }
                    }

                    if new_item_index == -1 {
                        new_item_index = mini_panel.items.count - 1;
                    }

                    if new_item_index != -1 {
                        mini_panel.item_index = new_item_index;
                        panel.highlight_index = new_item_index;
                        selected_item_changed = true;
                    }
                }
            }
        }

        mini_panel.item_index = clamp(mini_panel.item_index, 0, mini_panel.items.count - 1);
    }

    if selected_item_changed {
        panel.highlight_index = mini_panel.item_index;

        // Changing the mini panel buffer OR the selected item can put the index to -1 (in case
        // of search, -1 can only be achieved by changing the buffer), so in general we don't
        // want to assert the index points to the array.
        if mini_panel.item_index >= 0 {
            item := *mini_panel.items[mini_panel.item_index];

            userdata: *Search_Item_Userdata = item.userdata;
            x := userdata.x;
            y := userdata.y;

            if panel.view.kind == {
                case .DOCUMENT; {
                    view := *panel.view._document;
                    document := view.document;

                    text_buffer_move_cursor_to(document.buffer, *view.cursors, x, y, false);

                    view.flags |= .CLAMP_SCROLL_TO_CURSOR;
                    view.flags |= .RECEIVED_INDIRECT_KEYBOARD_INTERACTION;
                }

                case .LISTING; {
                    view := *panel.view._listing;
                    listing := view.listing;

                    view.item_index = clamp(y, 0, listing.items.count);

                    view.flags |= .CLAMP_SCROLL_TO_ITEM_INDEX;
                    // TODO(jt): @Incomplete Allow the selected lister line to animate:
                    // view.flags |= .RECEIVED_INDIRECT_KEYBOARD_INTERACTION;
                }
            }
        }
    }
}

delete_backward :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    gb := mini_panel.buffer.gb;
    if gb.count {
        text_buffer_delete_backward(*mini_panel.buffer, *mini_panel.cursors);
        return true;
    }

    return false;
}

autocomplete :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    return false;
}

confirm :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return false;
    }

    if mini_panel.items.count {
        assert(mini_panel.item_index >= 0);
        item := *mini_panel.items[mini_panel.item_index];

        userdata := cast(*Search_Item_Userdata, item.userdata);
        x := userdata.x;
        y := userdata.y;

        if panel.view.kind == {
            case .DOCUMENT; {
                view := *panel.view._document;
                document := view.document;

                if document {
                    text_buffer_move_cursor_to(document.buffer, *view.cursors, x, y, false);
                    view.flags |= .CLAMP_SCROLL_TO_CURSOR;
                }
            }

            case .LISTING; {
                view := *panel.view._listing;
                listing := view.listing;

                if listing {
                    view.item_index = clamp(y, 0, listing.items.count - 1);
                    view.flags |= .CLAMP_SCROLL_TO_ITEM_INDEX;
                }
            }
        }
    }

    array_reset_keeping_memory(*panel.highlights);
    panel.highlight_index = -1;

    close_mini_panel(editor, platform, input);

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    userdata: *Search_Userdata = editor.mini_panel.userdata;
    x := userdata.original_x;
    y := userdata.original_y;

    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            document := view.document;

            if document {
                text_buffer_move_cursor_to(document.buffer, *view.cursors, x, y, view.selecting);
            }

            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
        }

        case .LISTING; {
            view := *panel.view._listing;
            listing := view.listing;

            if listing {
                view.item_index = clamp(y, 0, listing.items.count);
            }

            view.flags |= .CLAMP_SCROLL_TO_ITEM_INDEX;
        }
    }

    array_reset_keeping_memory(*panel.highlights);
    panel.highlight_index = -1;

    close_mini_panel(editor, platform, input);
}
