modal_interaction_build_procs: Modal_Interaction_Procs = {
    get_action_text,
    init,
    handle_event,
    advance,
    cancel,
};

#scope_file

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* static */ string {
    return "Compile command: ";
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

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return;
    }

    // TODO(jt): @Incomplete Remember the last compile command and pre-fill it.
    // TODO(jt): @Incomplete Actually spawn a *compilation* buffer with its own key_map, highlighting, etc.

    wd: string;

    if #complete panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            document := view.document;

            if document.backing_file_path.count {
                wd = String.path_strip_filename(document.backing_file_path);
            }
        }

        case .LISTING; {
            view := *panel.view._listing;
            listing := view.listing;

            if listing.backing_directory_path.count {
                wd = listing.backing_directory_path;
            }
        }
    }

    if wd.count == 0 {
        // TODO(jt): Default to project directory, once we have something like projects.
        success:, wd = platform.get_absolute_path(".",, temp);
        if !success {
            wd = "";
        }
    }

    if wd.count == 0 {
        close_modal_interaction(editor, platform, input);
        editor_log(editor, "Failed to get working directory for *compilation*");
        return;
    }

    args := text_buffer_make_view_for_line(modal_interaction.buffer, 0,, temp);

    exit_code, output, error := platform.run_in_process(args, wd);

    scratch_document, scratch_panel := get_scratch(editor);
    cursors := ifx scratch_panel then *scratch_panel.view._document.cursors else *scratch_document.cursors_cold;

    text_buffer_delete_all(*scratch_document.buffer, cursors);

    // TODO(jt): We should probably try to interleave stdout and stderr, because we don't know what
    // the particular compiler does.
    if exit_code == 0 {
        text_buffer_insert(*scratch_document.buffer, cursors, output);
    } else {
        text_buffer_insert(*scratch_document.buffer, cursors, error);
    }

    text_buffer_insert(*scratch_document.buffer, cursors, tprint("\nCompilation exited with code: %\n\n", exit_code));

    close_modal_interaction(editor, platform, input);
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_modal_interaction(editor, platform, input);
}
