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
    file_is_directory: bool;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    return tprint("% Open file: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
}

can_select_text_line :: (editor: *Editor, platform: Platform, input: Input) -> bool {
    return true;
}

init :: (editor: *Editor, platform: Platform, input: Input) {}

update :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_open_file_update_proc");

    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    active_panel := get_active_panel(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        path_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        path_text_char_count := mini_panel.buffer.line_chars[0];

        path_prefix, _, _, filename := String.path_decomp(path_text);
        path_prefix = String.trim_right(path_prefix, "/");

        filename_char_count := count_utf8_chars(filename);

        // TODO(jt): @Speed Consider not listing these again unless the prefix changed?
        file_list := platform.list_files(path_prefix,, temp);
        for file_list {
            listed_file_path := it.name;
            listed_filename := String.path_filename(it.name);

            found_index, found := String.index_of_string_nocase(listed_filename, filename);
            if found {
                s := "";
                if it.name.count {
                    s = arena_push_string(mini_panel.items_arena, listed_filename);
                }

                x0 := count_utf8_chars(String.slice(listed_filename, 0, found_index));

                item := array_add(*mini_panel.items);
                item.text = s;
                item.highlight_x0 = x0;
                item.highlight_x1 = x0 + filename_char_count;
                item.userdata = null;

                if it.name.count {
                    full_file_path := arena_push_string(mini_panel.items_arena, it.name);

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

            text_buffer_reset(*mini_panel.buffer);
            text_buffer_insert(*mini_panel.buffer, dir_path);
        } else {
            text_buffer_delete_backward(*mini_panel.buffer);
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

    if mini_panel.items.count && mini_panel.item_index >= 0 {
        userdata: *Open_File_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        if userdata && userdata.full_file_path.count {
            completion_text := String.path_filename(mini_panel.items[mini_panel.item_index].text);
            buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
            buffer_path, _, _, buffer_filename := String.path_decomp(buffer_text);

            completion_filename := String.path_filename(completion_text);

            recomposed_path := tprint("%%", buffer_path, completion_filename);

            text_buffer_reset(*mini_panel.buffer);
            text_buffer_insert(*mini_panel.buffer, recomposed_path);

            if platform.file_is_directory(recomposed_path) {
                text_buffer_insert(*mini_panel.buffer, "/");
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

    active_panel := get_active_panel(editor);
    sanity_assert(active_panel != null);
    if !active_panel {
        return false;
    }

    file_path: string;
    file_exists: bool;
    file_is_directory: bool;
    if mini_panel.item_index == -1 {
        file_path = text_buffer_make_view_for_line(editor.mini_panel.buffer, 0,, temp);
        file_exists = platform.file_exists(file_path);
        file_is_directory = platform.file_is_directory(file_path);
    } else if mini_panel.items.count {
        userdata: *Open_File_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        if userdata {
            file_path = userdata.full_file_path;
            file_exists = true; // Unless deleted since we last looked.
            file_is_directory = userdata.file_is_directory;
        }
    }

    if file_is_directory {
        // TODO(jt): If we ever have directory listers, rip this out and open the directory in the lister.
        // TODO(jt): @Cleanup This is copypaste from mini_panel_autocomplete_proc
        completion_text := String.path_filename(mini_panel.items[mini_panel.item_index].text);
        buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
        buffer_path, _, _, buffer_filename := String.path_decomp(buffer_text);

        completion_filename := String.path_filename(completion_text);

        recomposed_path := tprint("%%", buffer_path, completion_filename);

        text_buffer_reset(*mini_panel.buffer);
        text_buffer_insert(*mini_panel.buffer, recomposed_path);

        if platform.file_is_directory(recomposed_path) {
            text_buffer_insert(*mini_panel.buffer, "/");
        }

        return true;
    } else {
        success, file_absolute_path := platform.get_absolute_path(file_path,, temp);
        if success {
            String.path_overwrite_separators(file_absolute_path, "/");

            document, document_newly_created := find_or_add_document(editor, platform, .FILE, file_absolute_path);
            document.backing_file_exists = file_exists;

            if document_newly_created {
                if file_exists {
                    editor_log(editor, "Opening file: %", file_absolute_path);

                    // TODO(jt): Detect/Watch file changes on disk!
                    success, file_contents := platform.read_file(file_absolute_path,, temp);
                    if success {
                        text_buffer_insert(*document.buffer, file_contents);
                        text_buffer_move_cursor_to(*document.buffer, 0, 0, false);

                        if active_panel {
                            set_panel_document(editor, active_panel, document);
                            recenter_active_panel(editor, input, true);
                        }

                        update_syntax_highlights(editor, document, platform, input);
                    }
                } else {
                    editor_log(editor, "Opening new file with path: %", file_absolute_path);
                    if active_panel {
                        set_panel_document(editor, active_panel, document);
                    }
                }
            } else {
                if active_panel {
                    set_panel_document(editor, active_panel, document);
                }
            }
        } else {
            log_error("Failed to get absolute path for %", file_path);
        }

        close_mini_panel(editor, platform, input);
    }

    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
