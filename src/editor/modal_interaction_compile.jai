modal_interaction_compile_procs: Modal_Interaction_Procs = {
    get_action_text,
    init,
    handle_event,
    advance,
    cancel,
};

#scope_file

Mode :: enum u64 {
    PROJECT_OR_DIRECTORY;
    DIRECTORY;
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage or Static */ string {
    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return "";
    }

    mode := cast(Mode, mi.userdata);

    action_text: string;

    success, working_directory, working_directory_is_project := get_working_directory_for_active_view(editor, search_for_project = mode == .PROJECT_OR_DIRECTORY);
    if success {
        if working_directory_is_project {
            action_text = tprint("Compile project %: ", working_directory);
        } else {
            action_text = tprint("Compile directory %: ", working_directory);
        }
    } else {
        action_text = "Compile directory: ";
    }

    return action_text;
}

init :: (editor: *Editor, platform: Platform, input: Input, params: *void) {
    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return;
    }

    mi.userdata = params;
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

    mode := cast(Mode, mi.userdata);

    success, working_directory, working_directory_is_project := get_working_directory_for_active_view(editor, search_for_project = mode == .PROJECT_OR_DIRECTORY);
    if !success {
        editor_log(editor, "Failed to get working directory for *compilation*");
        close_modal_interaction(editor, platform, input);
        return;
    }

    args := text_buffer_make_view_for_line(mi.buffer, 0,, temp);

    // TODO(jt): @Incomplete Remember the last compile command and pre-fill it.

    compilation_document, compilation_panel := find_or_add_compilation_document(editor, platform, working_directory, args, show = true);
    assert(compilation_panel.view.kind == .DOCUMENT);
    compilation_view := *compilation_panel.view._document;

    // TODO(jt): @Cleanup We got the document only to forget it and now run_compilation has to get it again...
    run_compilation(editor, platform, compilation_panel);

    close_modal_interaction(editor, platform, input);
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_modal_interaction(editor, platform, input);
}
