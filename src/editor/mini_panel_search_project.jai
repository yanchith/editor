mini_panel_search_project_procs: Mini_Panel_Procs = {
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

Search_Project_Userdata :: struct {
    working_directory: string;
    working_directory_is_project: bool;
}

Search_Project_Item_Userdata :: struct {
    file_path: string;
    line_number: s64;
    column_number: s64;
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

    userdata: *Search_Project_Userdata = mini_panel.userdata;
    is_project := userdata.working_directory_is_project;

    return tprint("%  Search %%: ", temp_right_pad(tprint("%", editor.mini_panel.items.count), 4), ifx is_project then "project" else "directory" ,help_text);
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

    if working_directory.count == 0 {
        editor_log(editor, "Failed to get working directory to search");
        close_mini_panel(editor, platform, input);
        return;
    }

    userdata := arena_push(mini_panel.userdata_arena, Search_Project_Userdata);
    userdata.working_directory = arena_push_string(mini_panel.userdata_arena, working_directory);
    userdata.working_directory_is_project = working_directory_is_project;

    mini_panel.userdata = userdata;
}

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
            // TODO(jt): Add multiple backends, so people can choose what they usually have
            // installed: git grep, baregrep, GNU grep.

            // --smart-case    matches both upper and lower case chars, if input is lowercase
            // --max-columns   limits output if line too long
            // --color never   just disables color codes, because we don't have a use for them
            // --with-filename --no-heading --line-number --column: outputs something easy to parse: <filename>:<line-number>:<line-content>
            RG_BASE_COMMAND :: "rg --smart-case --max-columns 500 --with-filename --no-heading --line-number --column --color never";

            search_regexp := line_search_prepare_regexp(search_text,, temp);

            // ripgrep doesn't normally need the search directory explicitly, but if we don't
            // provide, it will detect stdin on Windows and try to read stuff from there, never
            // returning. This is some weird interaction between JAI's run_command (with
            // capture_and_return_output=true) and ripgrep. I should probably debug that.
            //
            //     -jt, 6 August 2026
            args := tprint("% \"%\" ./", RG_BASE_COMMAND, search_regexp);

            userdata: *Search_Project_Userdata = mini_panel.userdata;
            working_directory := userdata.working_directory;

            exit_code, output, error := platform.run_in_process(args, working_directory,, temp);
            if exit_code != 0 {
                // It can fail because it didn't find anything. Not necessarily an error.
                return;
            }

            // Easier to parse the human readable output than json. How the turntables.
            found, line, rest := String.split_from_left(output, "\n");
            while found {
                defer {
                    found, line, rest = String.split_from_left(rest, "\n");
                }

                s := "";
                if line.count {
                    // Assume success and proactively copy to our memory, so that we can run splits on that.
                    s = arena_push_string(mini_panel.items_arena, line);
                }

                // Already splitting our memory, so canonicalize_path doesn't need to run twice.
                success, file_path, numbers_and_match := String.split_from_left(s, ":");
                if !success {
                    continue;
                }

                success=, _line_number, column_number_and_match := String.split_from_left(numbers_and_match, ":");
                if !success {
                    continue;
                }

                success=, _column_number, match := String.split_from_left(column_number_and_match, ":");
                if !success {
                    continue;
                }

                line_number:, success = string_to_int(_line_number, T = s64);
                if !success {
                    continue;
                }

                column_number:, success = string_to_int(_column_number, T = s64);
                if !success {
                    continue;
                }

                canonicalize_path(*file_path);

                item := array_add(*mini_panel.items);
                item.text = s;
                // TODO(jt): @Incomplete Scan output to find highlights.
                item.highlight_x0 = 0;
                item.highlight_x1 = 0;

                userdata := arena_push(mini_panel.items_arena, Search_Project_Item_Userdata);
                userdata.file_path = file_path; // Same allocation as s.
                userdata.line_number = line_number;
                userdata.column_number = column_number;

                item.userdata = userdata;
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

        userdata: *Search_Project_Userdata = mini_panel.userdata;
        working_directory := userdata.working_directory;

        item_userdata: *Search_Project_Item_Userdata = mini_panel.items[mini_panel.item_index].userdata;
        relative_path := item_userdata.file_path;

        file_path := String.path_join(working_directory, relative_path,, temp);

        panel := open_file(editor, platform, input, file_path);
        if panel {
            sanity_assert(panel.view.kind == .DOCUMENT);
            if panel.view.kind == .DOCUMENT {
                view := *panel.view._document;
                document := view.document;

                x := item_userdata.column_number - 1;
                y := item_userdata.line_number - 1;

                text_buffer_move_cursor_to(document.buffer, *view.cursors, x, y, false);
                view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            }
        }
    }

    close_mini_panel(editor, platform, input);
    return false;
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
