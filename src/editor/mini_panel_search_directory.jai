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
        search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
        search_text_char_count := mini_panel.buffer.line_chars[0];

        if search_text_char_count >= MIN_SEARCH_TEXT_COUNT {
            working_directory := get_panel_directory(editor, panel);
            if working_directory.count == 0 {
                close_mini_panel(editor, platform, input);
                editor_log(editor, "Failed to get directory for search");
                return;
            }

            args := tprint("rg %", search_text);

            log("nocheckin running '%' in '%'", args, working_directory);
            exit_code, output, error := platform.run_in_process(args, working_directory);
            log("nocheckin exit: %, OUTPUT: %, ERROR: %", exit_code, output, error);
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
    close_mini_panel(editor, platform, input);
    return false; // nocheckin
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_mini_panel(editor, platform, input);
}
