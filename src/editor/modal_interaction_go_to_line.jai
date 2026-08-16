modal_interaction_go_to_line_procs: Modal_Interaction_Procs = {
    get_action_text,
    init,
    handle_event,
    advance,
    cancel,
};

#scope_file

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* static */ string {
    return "Go to line: ";
}

init :: (editor: *Editor, platform: Platform, input: Input) {

}

handle_event :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) -> handled: bool {
    return false;
}

advance :: (editor: *Editor, platform: Platform, input: Input) {
    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return;
    }

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    if panel.view.kind != .DOCUMENT {
        return;
    }

    input_text := text_buffer_make_view_for_line(mi.buffer, 0,, temp);
    line_number, success := string_to_int(input_text, T = s64);

    if !success {
        editor_log(editor, "Can't parse line number.");
        close_modal_interaction(editor, platform, input);
        return;
    }

    line_index := max(line_number - 1, 0);

    view := *panel.view._document;
    document := view.document;

    text_buffer_move_cursor_to(document.buffer, *view.cursors, 0, line_index, view.selecting);
    view.flags |= .CLAMP_SCROLL_TO_CURSOR;
    view.flags |= .CLAMP_SCROLL_TO_START_OF_LINE;

    close_modal_interaction(editor, platform, input);
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_modal_interaction(editor, platform, input);
}