mini_panel_close_document_get_action_text:      Mini_Panel_Get_Action_Text_Proc      = get_action_text;
mini_panel_close_document_can_select_text_line: Mini_Panel_Can_Select_Text_Line_Proc = can_select_text_line;
mini_panel_close_document_init:                 Mini_Panel_Init_Proc                 = init;
mini_panel_close_document_update:               Mini_Panel_Update_Proc               = update;
mini_panel_close_document_autocomplete:         Mini_Panel_Autocomplete_Proc         = autocomplete;
mini_panel_close_document_confirm:              Mini_Panel_Confirm_Proc              = confirm;
mini_panel_close_document_cancel:               Mini_Panel_Cancel_Proc               = cancel;

#scope_file

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("% Close document: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return false;
}

init :: (editor: *Editor, platform: Platform, input: Input) {}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    mini_panel := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        search_text_char_count := mini_panel.buffer.line_chars[0];

        for * editor.documents {
            if mini_panel.action == .CLOSE_DOCUMENT && it.kind == .SCRATCH {
                continue;
            }

            document_name: string;
            if it.kind == {
                case .SCRATCH;  document_name = "*scratch*";
                case .FILE;     document_name = it.backing_file_path; // TODO(jt): Strip path prefix common for all items.
            }

            found_index, found := String.index_of_string_nocase(document_name, search_text);
            if found {
                s := "";
                if document_name.count {
                    s = arena_push_string(mini_panel.items_arena, document_name);
                }

                x0 := count_utf8_chars(String.slice(document_name, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_text_char_count;
                item.userdata = it;
            }
        }

        mini_panel.item_index = clamp(mini_panel.item_index, 0, mini_panel.items.count - 1);
    }
}

autocomplete :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    if mini_panel.items.count == 1 {
        // TODO(jt): The reset also nukes the edit history of the mini panel buffer... maybe
        // we don't want that?
        text_buffer_reset(*mini_panel.buffer);
        text_buffer_insert(*mini_panel.buffer, mini_panel.items[0].text);

        return true;
    } else if mini_panel.items.count > 1 {
        // TODO(jt): The reset also nukes the edit history of the mini panel buffer... maybe
        // we don't want that?
        text_buffer_reset(*mini_panel.buffer);
        text_buffer_insert(*mini_panel.buffer, mini_panel.items[mini_panel.item_index].text);

        return true;
    }

    return false;
}

confirm :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    if mini_panel.items.count {
        assert(mini_panel.item_index >= 0);
        item := *mini_panel.items[mini_panel.item_index];

        document := cast(*Document, item.userdata);
        close_document(editor, document);
    }

    close_mini_panel(editor, platform, input);
    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
