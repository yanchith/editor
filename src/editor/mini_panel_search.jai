mini_panel_search_get_action_text:      Mini_Panel_Get_Action_Text_Proc      = get_action_text;
mini_panel_search_can_select_text_line: Mini_Panel_Can_Select_Text_Line_Proc = can_select_text_line;
mini_panel_search_init:                 Mini_Panel_Init_Proc                 = init;
mini_panel_search_update:               Mini_Panel_Update_Proc               = update;
mini_panel_search_autocomplete:         Mini_Panel_Autocomplete_Proc         = autocomplete;
mini_panel_search_confirm:              Mini_Panel_Confirm_Proc              = confirm;
mini_panel_search_cancel:               Mini_Panel_Cancel_Proc               = cancel;

#scope_file

Search_Userdata :: struct {
    original_cursor0: Cursor;
}

Search_Item_Userdata :: struct {
    cursor: Cursor;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("% Search: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return false;
}

init :: (editor: *Editor, platform: Platform, input: Input) {
    mini_panel   := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    userdata := arena_push(editor.mini_panel.userdata_arena, Search_Userdata);
    userdata.original_cursor0 = active_panel.document.buffer.cursor0;
    mini_panel.userdata = userdata;
}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_search_update_proc");

    mini_panel   := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        if active_panel && active_panel.document {
            document := active_panel.document;

            array_reset_keeping_memory(*active_panel.highlights);
            active_panel.highlight_index = -1;

            old_cursor_y   := document.buffer.cursor0.y;
            new_item_index := -1;

            search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
            search_text_char_count := mini_panel.buffer.line_chars[0];

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

                found_index := find_index_from_left_nocase(line_text, search_text);
                if found_index != -1 {
                    s := "";
                    line_number_prefix_length := 0;

                    if line_text.count {
                        line_number_prefix := temp_right_pad(tprint("[%]", it + 1), 10);

                        s = sprint("%%", line_number_prefix, line_text,, arena_allocator(mini_panel.items_arena));
                        line_number_prefix_length = line_number_prefix.count;
                    }

                    x0 := found_index;
                    if !document.buffer.binary_mode {
                        x0 = count_utf8_chars(String.slice(line_text, 0, found_index));
                    }
                    x1 := x0 + search_text_char_count;

                    highlight := array_add(*active_panel.highlights);
                    highlight.cursor_x0 = x0;
                    highlight.cursor_x1 = x1;
                    highlight.cursor_y  = it;

                    item_index := mini_panel.items.count;
                    item := array_add(*mini_panel.items);
                    item.text = s;
                    if document.buffer.binary_mode {
                        item.flags |= .BINARY;
                    }
                    item.highlight_x0 = line_number_prefix_length + x0;
                    item.highlight_x1 = line_number_prefix_length + x1;

                    userdata := arena_push(mini_panel.items_arena, Search_Item_Userdata);
                    userdata.cursor = { x0, it };

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
                active_panel.highlight_index = new_item_index;
                selected_item_changed = true;
            }
        }

        mini_panel.item_index = clamp(mini_panel.item_index, 0, mini_panel.items.count - 1);
    }

    if selected_item_changed {
        active_panel.highlight_index = mini_panel.item_index;

        // Changing the mini panel buffer OR the selected item can put the index to -1 (in case
        // of search, -1 can only be achieved by changing the buffer), so in general we don't
        // want to assert the index points to the array.
        if mini_panel.item_index >= 0 {
            item := *mini_panel.items[mini_panel.item_index];

            userdata: *Search_Item_Userdata = item.userdata;
            x := userdata.cursor.x;
            y := userdata.cursor.y;

            document := active_panel.document;

            text_buffer_move_cursor_to(*document.buffer, x, y, false);
            recenter_active_panel(editor, input, true);
        }
    }
}

autocomplete :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    return false;
}

confirm :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel   := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    if mini_panel.items.count {
        assert(mini_panel.item_index >= 0);
        if active_panel && active_panel.document {
            item := *mini_panel.items[mini_panel.item_index];

            userdata := cast(*Search_Item_Userdata, item.userdata);
            x := userdata.cursor.x;
            y := userdata.cursor.y;

            text_buffer_move_cursor_to(*active_panel.document.buffer, x, y, false);
            recenter_active_panel(editor, input, true);
        }
    }

    if active_panel {
        array_reset_keeping_memory(*active_panel.highlights);
        active_panel.highlight_index = -1;
    }

    close_mini_panel(editor, platform, input);

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    mini_panel   := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    if active_panel {
        array_reset_keeping_memory(*active_panel.highlights);
        active_panel.highlight_index = -1;

        userdata: *Search_Userdata = editor.mini_panel.userdata;
        x := userdata.original_cursor0.x;
        y := userdata.original_cursor0.y;

        if active_panel.document {
            text_buffer_move_cursor_to(*active_panel.document.buffer, x, y, active_panel.selecting);
        }

        active_panel.flags |= .CLAMP_SCROLL_TO_CURSOR;
    }

    close_mini_panel(editor, platform, input);
}
