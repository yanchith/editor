mini_panel_open_file_procs: Mini_Panel_Procs = {
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

Open_File_Item_Userdata :: struct {
    full_file_path: string;
    file_is_directory: bool; // TODO(jt): Use this to highlight directories. (Currently unused.)
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("%  Open file: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return true;
}

init :: (editor: *Editor, platform: Platform, input: Input) {
    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    starting_path: string;
    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            document := view.document;

            if document.backing_directory_path.count {
                sanity_assert(!String.ends_with(document.backing_directory_path, "/"));
                starting_path = tprint("%/", document.backing_directory_path);
            }
        }
        case .LISTING; {
            view := *panel.view._listing;
            listing := view.listing;

            if listing.backing_directory_path.count {
                sanity_assert(!String.ends_with(listing.backing_directory_path, "/"));
                starting_path = tprint("%/", listing.backing_directory_path);
            }
        }
    }

    if starting_path.count == 0 {
        success, path := platform.get_absolute_path(".",, temp);
        if success {
            String.path_overwrite_separators(path, "/");
            if !String.ends_with(path, "/") {
                path = tprint("%/", path);
            }

            starting_path = path;
        }
    }

    mini_panel := *editor.mini_panel;

    text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, starting_path);
}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_open_file_update_proc");

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

        path_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        path_text_char_count := mini_panel.buffer.line_chars[0];

        path_prefix, _, _, filename := String.path_decomp(path_text);
        path_prefix = String.trim_right(path_prefix, "/");

        filename_parts, smartcase := line_search_prepare_parts(filename,, temp);
        filename_part1_char_count := ifx filename_parts.count then count_utf8_chars(filename_parts[0]) else 0;

        if String.ends_with(path_text, "/") || filename == "." {
            self_dir := array_add(*mini_panel.items);
            self_dir.text = ".";
            self_dir.highlight_x0 = 0;
            self_dir.highlight_x1 = filename.count;

            userdata := arena_push(mini_panel.items_arena, Open_File_Item_Userdata);
            userdata.full_file_path = path_prefix;
            userdata.file_is_directory = true;

            self_dir.userdata = userdata;
        }

        if String.ends_with(path_text, "/") || filename == "." || filename == ".." {
            success, _full_file_path := platform.get_absolute_path(tprint("%/..", path_prefix),, temp);
            if success {
                // TODO(jt): @Cleanup We do additional manual copy into our arena here, because MEMORY_DEBUGGER otherwise
                // flags this as 'an allocation for an address that the memory debugging system thought was still live'.
                // See :MemoryDebuggerVsArenas.
                full_file_path := arena_push_string(mini_panel.items_arena, _full_file_path);

                parent_dir := array_add(*mini_panel.items);
                parent_dir.text = "..";
                parent_dir.highlight_x0 = 0;
                parent_dir.highlight_x1 = filename.count;

                userdata := arena_push(mini_panel.items_arena, Open_File_Item_Userdata);
                userdata.full_file_path = full_file_path;
                userdata.file_is_directory = true;

                parent_dir.userdata = userdata;
            }
        }

        file_list := platform.list_directory(path_prefix, recursive = false, files = true, directories = true,, temp);
        for file_list {
            listed_file_path := it.absolute_path;
            listed_filename := String.path_filename(it.absolute_path);

            found, found_indices := line_search(listed_filename, filename_parts, smartcase);
            if found {
                found_index := found_indices[0]; // TODO(jt): @Incomplete Highlight all found parts.

                s := "";
                if listed_filename.count {
                    s = arena_push_string(mini_panel.items_arena, listed_filename);
                }

                x0 := count_utf8_chars(String.slice(listed_filename, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + filename_part1_char_count;
                item.userdata = null;

                if it.absolute_path.count {
                    full_file_path := arena_push_string(mini_panel.items_arena, it.absolute_path);

                    userdata := arena_push(mini_panel.items_arena, Open_File_Item_Userdata);
                    userdata.full_file_path = full_file_path;
                    userdata.file_is_directory = it.is_directory;

                    item.userdata = userdata;
                }
            }
        }

        mini_panel.item_index = clamp(mini_panel.item_index, -1, mini_panel.items.count - 1);
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
        last_byte := gb[gb.count - 1];
        if last_byte == "/" {
            buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
            buffer_text.count -= 1; // The trailing '/', so that path_strip_filename can treat the last segment as a filename.

            dir_path := String.path_strip_filename(buffer_text);

            text_buffer_delete_all(*mini_panel.buffer, *mini_panel.cursors);
            text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, dir_path);
        } else {
            text_buffer_delete_backward(*mini_panel.buffer, *mini_panel.cursors);
        }

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

    item_index := -1;
    if mini_panel.items.count {
        if mini_panel.item_index >= 0 {
            item_index = mini_panel.item_index;
        } else if mini_panel.items.count == 1 { // If we have the editable text line selected, and there is only one item.
            item_index = 0;
        }
    }

    if item_index >= 0 {
        userdata: *Open_File_Item_Userdata = mini_panel.items[item_index].userdata;
        if userdata.full_file_path.count {
            completion_text := String.path_filename(mini_panel.items[item_index].text);
            buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
            buffer_path, _, _, buffer_filename := String.path_decomp(buffer_text);

            completion_filename := String.path_filename(completion_text);

            recomposed_path := tprint("%%", buffer_path, completion_filename);

            text_buffer_delete_all(*mini_panel.buffer, *mini_panel.cursors);
            text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, recomposed_path);

            if platform.file_is_directory(recomposed_path) {
                text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, "/");
            }

            return true;
        }
    }

    return false;
}

confirm :: (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    file_path: string;
    if mini_panel.item_index == -1 {
        file_path = text_buffer_make_view_for_line(editor.mini_panel.buffer, 0,, temp);
    } else if mini_panel.items.count {
        userdata: *Open_File_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        file_path = userdata.full_file_path;
    }

    open_file(editor, platform, input, file_path);

    close_mini_panel(editor, platform, input);

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
