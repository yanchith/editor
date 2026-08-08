mini_panel_show_commands_procs: Mini_Panel_Procs = {
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

PANEL_ACTION_NAMES  :: #run enum_names(Panel_Action);
PANEL_ACTION_VALUES :: #run enum_values_as_s64(Panel_Action);

DOCUMENT_ACTION_NAMES  :: #run enum_names(Document_Action);
DOCUMENT_ACTION_VALUES :: #run enum_values_as_s64(Document_Action);

LISTING_ACTION_NAMES  :: #run enum_names(Listing_Action);
LISTING_ACTION_VALUES :: #run enum_values_as_s64(Listing_Action);

Show_Commands_Item_Userdata :: struct {
    kind:  enum { UNINITIALIZED; PANEL; DOCUMENT; LISTING; };
    value: s64;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("% Show commands: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
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

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        search_text_char_count := mini_panel.buffer.line_chars[0];

        actions_to_search_names: [..] string;
        actions_to_search_names.allocator = temp;

        actions_to_search_values: [..] s64;
        actions_to_search_values.allocator = temp;

        array_reserve(*actions_to_search_names, actions_to_search_names.count + PANEL_ACTION_NAMES.count);
        array_reserve(*actions_to_search_values, actions_to_search_values.count + PANEL_ACTION_NAMES.count);
        for PANEL_ACTION_NAMES {
            if it != "NONE" {
                array_add(*actions_to_search_names, it);
                array_add(*actions_to_search_values, PANEL_ACTION_VALUES[it_index]);
            }
        }
        assert(actions_to_search_names.count == actions_to_search_values.count);

        panel_actions_low:  s64 = 0;
        panel_actions_high: s64 = actions_to_search_names.count;

        document_actions_low:  s64 = actions_to_search_names.count;
        document_actions_high: s64 = actions_to_search_names.count;

        listing_actions_low:  s64 = actions_to_search_names.count;
        listing_actions_high: s64 = actions_to_search_names.count;

        if panel.view.kind == {
            case .DOCUMENT; {
                array_reserve(*actions_to_search_names, actions_to_search_names.count + DOCUMENT_ACTION_NAMES.count);
                array_reserve(*actions_to_search_values, actions_to_search_values.count + DOCUMENT_ACTION_NAMES.count);
                for DOCUMENT_ACTION_NAMES {
                    if it != "NONE" {
                        array_add(*actions_to_search_names, it);
                        array_add(*actions_to_search_values, DOCUMENT_ACTION_VALUES[it_index]);
                    }
                }
                assert(actions_to_search_names.count == actions_to_search_values.count);

                document_actions_high = actions_to_search_names.count;
            }
            case .LISTING; {
                array_reserve(*actions_to_search_names, actions_to_search_names.count + LISTING_ACTION_NAMES.count);
                array_reserve(*actions_to_search_values, actions_to_search_values.count + LISTING_ACTION_NAMES.count);
                for LISTING_ACTION_NAMES {
                    if it != "NONE" {
                        array_add(*actions_to_search_names, it);
                        array_add(*actions_to_search_values, LISTING_ACTION_VALUES[it_index]);
                    }
                }
                assert(actions_to_search_names.count == actions_to_search_values.count);

                listing_actions_high = actions_to_search_names.count;
            }
        }

        for actions_to_search_names {
            found_index, found := String.index_of_string_nocase(it, search_text);
            if found {
                x0 := count_utf8_chars(String.slice(it, 0, found_index));

                s := arena_push_string(mini_panel.items_arena, it);
                String.to_lower_in_place(s);

                item := array_add(*mini_panel.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_text_char_count;

                userdata := arena_push(mini_panel.items_arena, Show_Commands_Item_Userdata);
                userdata.kind = .UNINITIALIZED;
                userdata.value = actions_to_search_values[it_index];

                if it_index >= panel_actions_low && it_index < panel_actions_high {
                    userdata.kind = .PANEL;
                } else if it_index >= document_actions_low && it_index < document_actions_high {
                    userdata.kind = .DOCUMENT;
                } else if it_index >= listing_actions_low && it_index < listing_actions_high {
                    userdata.kind = .LISTING;
                }

                item.userdata = userdata;
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
        text_buffer_delete_backward(*mini_panel.buffer, *mini_panel.cursors);
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
        text_buffer_delete_all(*mini_panel.buffer, *mini_panel.cursors);
        text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, mini_panel.items[0].text);

        return true;
    } else if mini_panel.items.count > 1 {
        text_buffer_delete_all(*mini_panel.buffer, *mini_panel.cursors);
        text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, mini_panel.items[mini_panel.item_index].text);

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

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return false;
    }

    if mini_panel.items.count {
        assert(mini_panel.item_index >= 0);

        // IMPORTANT! Because actions can open the mini panel, we have to close it before we
        // execute. However, this means we release all arenas etc., so if there is something we
        // need, we need to make a copy now.
        userdata_pointer: *Show_Commands_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        userdata := userdata_pointer.*;

        close_mini_panel(editor, platform, input);

        if #complete userdata.kind == {
            case .UNINITIALIZED;  sanity_assert(false);

            case .PANEL; {
                action := cast(Panel_Action, userdata.value);
                execute_panel_action(editor, platform, input, panel, action);
            }

            case .DOCUMENT; {
                action := cast(Document_Action, userdata.value);

                sanity_assert(panel.view.kind == .DOCUMENT);
                view := *panel.view._document;
                document := view.document;

                execute_document_action(editor, platform, input, panel, view, document, action);
            }

            case .LISTING; {
                action := cast(Listing_Action, userdata.value);

                sanity_assert(panel.view.kind == .LISTING);
                view := *panel.view._listing;
                listing := view.listing;

                execute_listing_action(editor, platform, input, panel, view, listing, action);
            }
        }
    } else {
        close_mini_panel(editor, platform, input);
    }

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
