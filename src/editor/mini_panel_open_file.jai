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
    return tprint("%  Open file: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4));
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

    active_panel := get_panel_for_active_view(editor);
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
        file_list := platform.list_directory(path_prefix,, temp);
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
                item.text_color = MINI_PANEL_ITEM_TEXT_COLOR;
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
            text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, dir_path);
        } else {
            text_buffer_delete_backward(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1);
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
        if userdata && userdata.full_file_path.count {
            completion_text := String.path_filename(mini_panel.items[item_index].text);
            buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
            buffer_path, _, _, buffer_filename := String.path_decomp(buffer_text);

            completion_filename := String.path_filename(completion_text);

            recomposed_path := tprint("%%", buffer_path, completion_filename);

            /* nocheckin
c:/Users/yanchith/workspace/editor/src/editor/text_buffer.jai:1831,5: Assertion failed!

Stack trace:
C:/Users/yanchith/workspace/jai/modules/Runtime_Support.jai:103: runtime_support_assertion_failed
C:/Users/yanchith/workspace/jai/modules/Basic/module.jai:86: assert_helper
c:/Users/yanchith/workspace/editor/src/editor/text_buffer.jai:1831: assert_location_valid_for_writes
c:/Users/yanchith/workspace/editor/src/editor/text_buffer.jai:1718: assert_valid_cursors
c:/Users/yanchith/workspace/editor/src/editor/text_buffer.jai:1714: assert_valid
c:/Users/yanchith/workspace/editor/src/editor/text_buffer.jai:218: text_buffer_insert
c:/Users/yanchith/workspace/editor/src/editor/mini_panel_open_file.jai:152: autocomplete
c:/Users/yanchith/workspace/editor/src/editor/editor.jai:2021: route_event_to_mini_panel
c:/Users/yanchith/workspace/editor/src/editor/editor.jai:845: update_and_render
c:/Users/yanchith/workspace/editor/src/main.jai:698: main
*/

            text_buffer_reset(*mini_panel.buffer);
            text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, recomposed_path);

            if platform.file_is_directory(recomposed_path) {
                text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, "/");
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

    active_panel := get_panel_for_active_view(editor);
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
        completion_text := String.path_filename(mini_panel.items[mini_panel.item_index].text);
        buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
        buffer_path, _, _, buffer_filename := String.path_decomp(buffer_text);

        completion_filename := String.path_filename(completion_text);

        recomposed_path := tprint("%%", buffer_path, completion_filename);

        text_buffer_reset(*mini_panel.buffer);
        text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, recomposed_path);

        if platform.file_is_directory(recomposed_path) {
            text_buffer_insert(*mini_panel.buffer, *mini_panel.cursor0, *mini_panel.cursor1, "/");
        }

        return true;
    } else {
        success, file_absolute_path := platform.get_absolute_path(file_path,, temp);
        if success {
            String.path_overwrite_separators(file_absolute_path, "/");

            document, document_newly_created := find_or_add_document(editor, platform, .FILE, file_absolute_path);
            if document_newly_created {
                if file_exists {
                    editor_log(editor, "Opening file: %", file_absolute_path);

                    document.backing_file_exists = true;
                    document.backing_file_time_of_last_sync = input.time;

                    // Unlike when we save a file, we assume the modification time here is mostly
                    // stabilized. We still may be wrong, in which case we should also save the hash
                    // of the file for later comparisons.
                    _, modification_time, size := platform.file_modification_time_and_size(document.backing_file_path);
                    document.backing_file_last_synced_modification_time = modification_time;
                    document.backing_file_last_synced_size = size;

                    success, file_contents := platform.read_file(file_absolute_path,, temp);
                    if success {
                        // TODO(jt): @Speed This is slow, because we are going over the data
                        // twice. Once to make the hash, and the second time to insert into the text
                        // buffer. We should probably do it in a single pass, or in a chunked
                        // manner, so we can read from L1.
                        document.backing_file_last_synced_hash = hash_file_contents(file_contents);

                        text_buffer_insert(*document.buffer, *document.cursor0, *document.cursor1, file_contents, .OMIT);
                        text_buffer_move_cursor_to(document.buffer, *document.cursor0, *document.cursor1, 0, 0, false);

                        update_parenthesized_scopes(document);
                        update_syntax_highlights(editor, document, platform, input);

                        watch_file(editor, platform, input, document.backing_file_path);

                        if active_panel {
                            panel_set_document(active_panel, editor, document);
                            recenter_active_panel(editor, input, true);
                        }
                    }
                } else {
                    editor_log(editor, "Opening new file with path: %", file_absolute_path);
                    if active_panel {
                        panel_set_document(active_panel, editor, document);
                    }
                }
            } else {
                if active_panel {
                    panel_set_document(active_panel, editor, document);
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
