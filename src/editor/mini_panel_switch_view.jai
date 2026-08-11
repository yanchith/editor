mini_panel_switch_view_procs: Mini_Panel_Procs = {
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

Switch_View_Item_Userdata :: struct {
    kind: View_Kind;
    pointer: *void;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("%  Switch view: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
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
        search_parts, smartcase := line_search_prepare_parts(search_text,, temp);
        search_part1_char_count := ifx search_parts.count then count_utf8_chars(search_parts[0]) else 0;

        max_time_of_last_interaction: Apollo_Time;

        current_thing: *void = null;
        if #complete panel.view.kind == {
            case .DOCUMENT;  current_thing = panel.view._document.document;
            case .LISTING;   current_thing = panel.view._listing.listing;
        }

        for * editor.documents {
            document_name: string;
            if #complete it.kind == {
                case .SCRATCH;      document_name = "*scratch*";
                case .COMPILATION;  document_name = "*compilation*";
                case .FILE;         document_name = it.backing_file_path; // TODO(jt): Strip path prefix common for all items.
            }

            found, found_indices := line_search(document_name, search_parts, smartcase);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                // Select the most recent document, except the one pointed to by the currently active panel.
                if current_thing != it && it.time_of_last_interaction > max_time_of_last_interaction {
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
                item.flags = ifx it.flags & .MODIFIED then .WARNING;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_part1_char_count;

                userdata := arena_push(mini_panel.items_arena, Switch_View_Item_Userdata);
                userdata.kind = .DOCUMENT;
                userdata.pointer = it;

                item.userdata = userdata;
            }
        }

        for * editor.listings {
            listing_name: string = it.backing_directory_path;

            found, found_indices := line_search(listing_name, search_parts, smartcase);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                // Select the most recent listing, except the one pointed to by the currently active panel.
                if current_thing != it && it.time_of_last_interaction > max_time_of_last_interaction {
                    max_time_of_last_interaction = it.time_of_last_interaction;
                    mini_panel.item_index = mini_panel.items.count;
                }

                s := "";
                if listing_name.count {
                    s = arena_push_string(mini_panel.items_arena, listing_name);
                }

                x0 := count_utf8_chars(String.slice(listing_name, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_part1_char_count;

                userdata := arena_push(mini_panel.items_arena, Switch_View_Item_Userdata);
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

        userdata: *Switch_View_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        if #complete userdata.kind == {
            case .DOCUMENT; {
                document: *Document = userdata.pointer;
                panel_set_document(panel, editor, document);
            }

            case .LISTING; {
                listing: *Listing = userdata.pointer;
                panel_set_listing(panel, editor, listing);
            }
        }

        recenter_panel(panel, editor, input, force_center = true, skip_interpolation = true);
    }

    close_mini_panel(editor, platform, input);
    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
