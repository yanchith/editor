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
    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    if buffer_changed {
        array_reset(*mp.items);
        arena_reset(mp.items_arena);

        search_text := text_buffer_make_view_for_line(mp.buffer, 0,, temp);
        search_parts, smartcase := line_search_prepare_parts(search_text,, temp);
        search_part1_char_count := ifx search_parts.count then count_utf8_chars(search_parts[0]) else 0;

        max_time_of_last_activation: Apollo_Time;

        current_thing: *void = null;
        if #complete panel.view.kind == {
            case .DOCUMENT;  current_thing = panel.view._document.document;
            case .LISTING;   current_thing = panel.view._listing.listing;
        }

        for * editor.documents {
            if it.kind == .SCRATCH   continue;
            if it.kind == .MESSAGES  continue;

            document_name := get_document_name(editor, it); // TODO(jt): @Speed The name deduplication is quadratic!

            found, found_indices := line_search(document_name, search_parts, smartcase,, temp);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                // Select the most recent document. (This is hopefully the current view.)
                if it.time_of_last_activation > max_time_of_last_activation {
                    max_time_of_last_activation = it.time_of_last_activation;
                    mp.item_index = mp.items.count;
                }

                s := "";
                if document_name.count {
                    s = arena_push_string(mp.items_arena, document_name);
                }

                x0 := count_utf8_chars(String.slice(document_name, 0, found_index));

                item := array_add(*mp.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_part1_char_count;

                userdata := arena_push(mp.items_arena, Close_View_Item_Userdata);
                userdata.kind = .DOCUMENT;
                userdata.pointer = it;

                item.userdata = userdata;
            }
        }

        for * editor.listings {
            // Select the most recent listing. (This is hopefully the current view.)
            if it.time_of_last_activation > max_time_of_last_activation {
                max_time_of_last_activation = it.time_of_last_activation;
                mp.item_index = mp.items.count;
            }

            listing_name := get_listing_name(editor, it); // TODO(jt): @Speed The name deduplication is quadratic!

            found, found_indices := line_search(listing_name, search_parts, smartcase,, temp);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                s := "";
                if listing_name.count {
                    s = arena_push_string(mp.items_arena, listing_name);
                }

                x0 := count_utf8_chars(String.slice(listing_name, 0, found_index));

                item := array_add(*mp.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + search_part1_char_count;

                userdata := arena_push(mp.items_arena, Close_View_Item_Userdata);
                userdata.kind = .LISTING;
                userdata.pointer = it;

                item.userdata = userdata;
            }
        }

        mp.item_index = clamp(mp.item_index, 0, mp.items.count - 1);
    }
}

delete_backward :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return false;
    }

    gb := mp.buffer.gb;
    if gb.count {
        text_buffer_delete_backward(*mp.buffer, *mp.cursors);
        return true;
    }

    return false;
}

autocomplete :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return false;
    }

    if mp.items.count == 1 {
        text_buffer_delete_all(*mp.buffer, *mp.cursors);
        text_buffer_insert(*mp.buffer, *mp.cursors, mp.items[0].text);

        return true;
    } else if mp.items.count > 1 {
        text_buffer_delete_all(*mp.buffer, *mp.cursors);
        text_buffer_insert(*mp.buffer, *mp.cursors, mp.items[mp.item_index].text);

        return true;
    }

    return false;
}

confirm :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return false;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return false;
    }

    if mp.items.count {
        assert(mp.item_index >= 0);
        item := *mp.items[mp.item_index];

        userdata: *Close_View_Item_Userdata = mp.items[mp.item_index].userdata;
        if #complete userdata.kind == {
            case .DOCUMENT; {
                document: *Document = userdata.pointer;

                if document.flags & .MODIFIED {
                    // Close after confirmation
                    params := arena_push(editor.modal_interaction.arena, Modal_Interaction_Confirm_Params); // Lives until we call close_modal_interaction!
                    params.text = "File modified, confirm again to close";
                    params.proc = (editor: *Editor, platform: Platform, input: Input, userdata: *void) {
                        document: *Document = userdata;

                        unwatch_file(editor, platform, input, document.backing_file_path);
                        close_document(editor, input, document);
                    };
                    params.userdata = document;

                    open_modal_interaction(editor, platform, input, modal_interaction_confirm_procs, params);
                } else {
                    // Close immediately
                    unwatch_file(editor, platform, input, document.backing_file_path);
                    close_document(editor, input, document);
                }
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
