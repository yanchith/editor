modal_interaction_compile_project_procs: Modal_Interaction_Procs = {
    get_action_text,
    init,
    handle_event,
    advance,
    cancel,
};

#scope_file

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage or Static */ string {
    action_text: string;
    if editor.project_directory.count {
        action_text = tprint("Compile project %: ", String.path_filename(editor.project_directory));
    } else {
        panel := get_panel_for_active_view(editor);
        sanity_assert(panel != null);
        if panel {
            if #complete panel.view.kind == {
                case .DOCUMENT;  action_text = tprint("Compile directory %: ", panel.view._document.document.backing_directory_path);
                case .LISTING;   action_text = tprint("Compile directory %: ", panel.view._listing.listing.backing_directory_path);
            }
        } else {
            action_text = "Compile directory:";
        }
    }

    return action_text;
}

init :: (editor: *Editor, platform: Platform, input: Input) {

}

handle_event :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) -> handled: bool {
    return false;
}

advance :: (editor: *Editor, platform: Platform, input: Input) {
    modal_interaction := *editor.modal_interaction;
    sanity_assert(modal_interaction.open);
    if !modal_interaction.open {
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
        editor_log(editor, "Failed to get working directory for *compilation*");
        close_modal_interaction(editor, platform, input);
        return;
    }

    args := text_buffer_make_view_for_line(modal_interaction.buffer, 0,, temp);

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
