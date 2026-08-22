mini_panel_open_project_file_procs: Mini_Panel_Procs = {
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

Open_Project_File_Userdata :: struct {
    working_directory: string;
    working_directory_is_project: bool;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return "";
    }

    userdata: *Open_Project_File_Userdata = mini_panel.userdata;
    is_project := userdata.working_directory_is_project;

    return tprint("%  Open file in %: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4), ifx is_project then "project" else "directory");
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

    working_directory := editor.project_directory;
    working_directory_is_project := true;

    if working_directory.count == 0 {
        panel := get_panel_for_active_view(editor);
        sanity_assert(panel != null);
        if !panel {
            return;
        }

        if #complete panel.view.kind == {
            case .DOCUMENT;  working_directory = panel.view._document.document.backing_directory_path;
            case .LISTING;   working_directory = panel.view._listing.listing.backing_directory_path;
        }

        working_directory_is_project = false;
    }

    userdata := arena_push(mini_panel.userdata_arena, Open_Project_File_Userdata);
    userdata.working_directory = arena_push_string(mini_panel.userdata_arena, working_directory);
    userdata.working_directory_is_project = working_directory_is_project;

    mini_panel.userdata = userdata;
}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_open_project_file_update_proc");

    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        filename := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        filename_char_count := mini_panel.buffer.line_chars[0];

        filename_parts, smartcase := line_search_prepare_parts(filename,, temp);
        filename_part1_char_count := ifx filename_parts.count then count_utf8_chars(filename_parts[0]) else 0;

        working_directory: string;
        {
            userdata: *Open_Project_File_Userdata = mini_panel.userdata;
            working_directory = userdata.working_directory;
        }

        file_list := platform.list_directory(working_directory, recursive = true, files = true, directories = false,, temp);
        for file_list {
            found, found_indices := line_search(it.absolute_path, filename_parts, smartcase,, temp);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                s := "";
                if it.absolute_path.count {
                    s = arena_push_string(mini_panel.items_arena, it.absolute_path);
                }

                x0 := count_utf8_chars(String.slice(it.absolute_path, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + filename_part1_char_count;
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

    if mini_panel.items.count {
        assert(mini_panel.item_index >= 0);
        file_path := mini_panel.items[mini_panel.item_index].text;

        open_file(editor, platform, input, file_path);
    }

    close_mini_panel(editor, platform, input);

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
