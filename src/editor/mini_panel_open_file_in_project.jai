mini_panel_open_file_in_project_procs: Mini_Panel_Procs = {
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
    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return "";
    }

    userdata: *Open_Project_File_Userdata = mp.userdata;
    is_project := userdata.working_directory_is_project;

    return tprint("%  Open file in %: ", temp_right_pad(tprint("%", mp.items.count), 4), ifx is_project then "project" else "directory");
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return false;
}

init :: (editor: *Editor, platform: Platform, input: Input) {
    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return;
    }

    success, working_directory, working_directory_is_project := get_working_directory_for_active_view(editor, search_for_project = true);
    if !success {
        editor_log(editor, "Failed to get working directory for open project file");
        close_mini_panel(editor, platform, input);
        return;
    }

    userdata := arena_push(mp.arena, Open_Project_File_Userdata);
    userdata.working_directory = arena_push_string(mp.arena, working_directory);
    userdata.working_directory_is_project = working_directory_is_project;

    mp.userdata = userdata;
}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_open_project_file_update_proc");

    mp := *editor.mini_panel;
    sanity_assert(mp.open);
    if !mp.open {
        return;
    }

    if buffer_changed {
        array_reset(*mp.items);
        arena_reset(mp.items_arena);

        filename := text_buffer_make_view_for_line(mp.buffer, 0,, temp);
        filename_char_count := mp.buffer.line_chars[0];

        filename_parts, smartcase := line_search_prepare_parts(filename,, temp);
        filename_part1_char_count := ifx filename_parts.count then count_utf8_chars(filename_parts[0]) else 0;

        working_directory: string;
        {
            userdata: *Open_Project_File_Userdata = mp.userdata;
            working_directory = userdata.working_directory;
        }

        file_list := platform.list_directory(working_directory, recursive = true, list_files = true, list_directories = false, ignore_directories = editor.project_search_ignore_directories,, temp);
        for file_list {
            found, found_indices := line_search(it.absolute_path, filename_parts, smartcase,, temp);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                s := "";
                if it.absolute_path.count {
                    s = arena_push_string(mp.items_arena, it.absolute_path);
                }

                x0 := count_utf8_chars(String.slice(it.absolute_path, 0, found_index));

                item := array_add(*mp.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + filename_part1_char_count;
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

    if mp.items.count {
        assert(mp.item_index >= 0);
        file_path := mp.items[mp.item_index].text;

        open_file(editor, platform, input, file_path);
    }

    close_mini_panel(editor, platform, input);

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
