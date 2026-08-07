mini_panel_close_view_procs: Mini_Panel_Procs = {
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

Close_View_Item_Userdata :: struct {
    kind: View_Kind;
    pointer: *void;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("%  Close view: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
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

        max_time_of_last_interaction: Apollo_Time;

        current_thing: *void = null;
        if #complete panel.view.kind == {
            case .DOCUMENT;  current_thing = panel.view._document.document;
            case .LISTING;   current_thing = panel.view._listing.listing;
        }

        for * editor.documents {
            if it.kind == .SCRATCH {
                continue;
            }

            document_name: string;
            if it.kind == {
                case .SCRATCH;  document_name = "*scratch*"; // Should not happen, though!
                case .FILE;     document_name = it.backing_file_path; // TODO(jt): Strip path prefix common for all items.
            }

            found_index, found := String.index_of_string_nocase(document_name, search_text);
            if found {
                // Select the most recent document. (This is hopefully the current view.)
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
                item.text_color = ifx it.flags & .MODIFIED then editor.theme.mini_panel_item_warning_text_color else editor.theme.mini_panel_item_text_color;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_text_char_count;

                userdata := arena_push(mini_panel.items_arena, Close_View_Item_Userdata);
                userdata.kind = .DOCUMENT;
                userdata.pointer = it;

                item.userdata = userdata;
            }
        }

        for * editor.listings {
            // Select the most recent listing. (This is hopefully the current view.)
            if it.time_of_last_interaction > max_time_of_last_interaction {
                max_time_of_last_interaction = it.time_of_last_interaction;
                mini_panel.item_index = mini_panel.items.count;
            }

            listing_name: string = it.backing_directory_path;
            found_index, found := String.index_of_string_nocase(listing_name, search_text);
            if found {
                s := "";
                if listing_name.count {
                    s = arena_push_string(mini_panel.items_arena, listing_name);
                }

                x0 := count_utf8_chars(String.slice(listing_name, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.text_color = editor.theme.mini_panel_item_text_color;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_text_char_count;

                userdata := arena_push(mini_panel.items_arena, Close_View_Item_Userdata);
                userdata.kind = .LISTING;
                userdata.pointer = it;

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
        item := *mini_panel.items[mini_panel.item_index];

        userdata: *Close_View_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        if #complete userdata.kind == {
            case .DOCUMENT; {
                document: *Document = userdata.pointer;

                unwatch_file(editor, platform, input, document.backing_file_path);
                close_document(editor, input, document);
            }

            case .LISTING; {
                listing: *Listing = userdata.pointer;

                // TODO(jt): Unwatch directory, if we start watching them?
                close_listing(editor, input, listing);
            }
        }
    }

    close_mini_panel(editor, platform, input);
    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
