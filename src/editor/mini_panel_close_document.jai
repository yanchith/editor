mini_panel_close_document_procs: Mini_Panel_Procs = {
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

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("%  Close document: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return false;
}

init :: (editor: *Editor, platform: Platform, input: Input) {}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    active_panel := get_panel_for_active_view(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        search_text_char_count := mini_panel.buffer.line_chars[0];

        max_time_of_last_interaction: Apollo_Time;

        for * editor.documents {
            if it.kind == .SCRATCH {
                continue;
            }

            document_name: string;
            if it.kind == {
                case .SCRATCH;  document_name = "*scratch*";
                case .FILE;     document_name = it.backing_file_path; // TODO(jt): Strip path prefix common for all items.
            }

            found_index, found := String.index_of_string_nocase(document_name, search_text);
            if found {
                // Select the most recent document. Once we are out of this loop, it should be more
                // often than not the document pointed to by the active panel. Currently, the
                // *scratch* buffer is the exception.
                if it.time_of_last_interaction > max_time_of_last_interaction {
                    max_time_of_last_interaction = it.time_of_last_interaction;
                    mini_panel.item_index = mini_panel.items.count;
                }

                s := "";
                if document_name.count {
                    s = arena_push_string(mini_panel.items_arena, document_name);
                }

                x0 := count_utf8_chars(String.slice(document_name, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.text_color = ifx it.flags & .MODIFIED then MINI_PANEL_ITEM_WARNING_TEXT_COLOR else MINI_PANEL_ITEM_TEXT_COLOR;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_text_char_count;
                item.userdata = it;
            }
        }

        mini_panel.item_index = clamp(mini_panel.item_index, 0, mini_panel.items.count - 1);
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
        text_buffer_delete_backward(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1);
        return true;
    }

    return false;
}

autocomplete :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    // TODO(jt): The reset also nukes the edit history of the mini panel buffer... maybe
    // we don't want that?
    if mini_panel.items.count == 1 {
        text_buffer_reset(*mini_panel.buffer);
        text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, mini_panel.items[0].text);

        return true;
    } else if mini_panel.items.count > 1 {
        text_buffer_reset(*mini_panel.buffer);
        text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, mini_panel.items[mini_panel.item_index].text);

        return true;
    }

    return false;
}

confirm :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    active_panel := get_panel_for_active_view(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return false;
    }

    if mini_panel.items.count {
        assert(mini_panel.item_index >= 0);
        item := *mini_panel.items[mini_panel.item_index];

        document := cast(*Document, item.userdata);

        unwatch_file(editor, platform, input, document.backing_file_path);
        close_document(editor, document);
    }

    close_mini_panel(editor, platform, input);
    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
