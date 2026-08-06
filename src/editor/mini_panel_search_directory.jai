mini_panel_search_directory_procs: Mini_Panel_Procs = {
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

MIN_SEARCH_TEXT_COUNT :: 3;

Search_Directory_Item_Userdata :: struct {
    file_path: string;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    mini_panel := *editor.mini_panel;
    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return "";
    }

    help_text := "";

    search_text_char_count := mini_panel.buffer.line_chars[0];
    if search_text_char_count < MIN_SEARCH_TEXT_COUNT {
        help_text = tprint(" (type % more)", MIN_SEARCH_TEXT_COUNT - search_text_char_count);
    }

    return tprint("%  Search directory%: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4), help_text);
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

        if search_text_char_count >= MIN_SEARCH_TEXT_COUNT {
            working_directory := get_panel_directory(editor, panel);
            if working_directory.count == 0 {
                close_mini_panel(editor, platform, input);
                editor_log(editor, "Failed to get directory for search");
                return;
            }

            // TODO(jt): Add multiple backends, so people can choose what they usually have
            // installed: git grep, baregrep, GNU grep.

            // ripgrep doesn't normally need the search directory explicitly, but if we don't
            // provide, it will detect stdin on Windows and try to read stuff from there, never
            // returning. This is some weird interaction between JAI's run_command (with
            // capture_and_return_output=true) and ripgrep. I should probably debug that.
            //
            //     -jt, 6 August 2026
            args := tprint("rg % ./", search_text);

            exit_code, output, error := platform.run_in_process(args, working_directory); // nocheckin output in temp?
            if exit_code != 0 {
                editor_log(editor, "Command % failed with code: %", args, exit_code);
                close_mini_panel(editor, platform, input);
                return;
            }

            // Easier to parse the human readable output than json. How the turntables.
            found, line, rest := String.split_from_left(output, "\n");
            while found {
                s := "";
                if line.count {
                    // We sort of assume success and proactively copy to our memory.
                    s = arena_push_string(mini_panel.items_arena, line);
                }

                // Already splitting our memory, so path_overwrite_separators doesn't need to run twice.
                success, file_path, match := String.split_from_left(s, ":");
                if success {
                    String.path_overwrite_separators(file_path, #char "/");

                    item := array_add(*mini_panel.items);
                    item.text = s;
                    item.text_color = MINI_PANEL_ITEM_TEXT_COLOR;
                    // TODO(jt): @Incomplete Scan output to find highlights.
                    item.highlight_x0 = 0;
                    item.highlight_x1 = 0;

                    userdata := arena_push(mini_panel.items_arena, Search_Directory_Item_Userdata);
                    userdata.file_path = file_path;

                    item.userdata = userdata;
                }

                found, line, rest = String.split_from_left(rest, "\n");
            }
        }
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

        userdata: *Search_Directory_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        open_file(editor, platform, input, userdata.file_path);
    }

    close_mini_panel(editor, platform, input);
    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
