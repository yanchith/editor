#import "Basic";

String :: #import "String";
Window :: #import "Window_Creation";
Input  :: #import "Input";
Simp   :: #import "Simp";
Editor :: #import,file "editor/editor.jai";

main :: () {
    time_program_start := current_time_monotonic();

    context_logger_data := Context_Logger_Data.{ time_program_start };

    editor_context := context;
    editor_context.logger      = context_logger;
    editor_context.logger_data = *context_logger_data;

    push_context editor_context {
        #if OS == .MACOS {
            // TODO(jt): Set working directory to executable path if we do not see our data.
        }

        time_last_frame_start := time_program_start;

        window_width:  s32 = 1600;
        window_height: s32 = 900;
        window := Window.create_window(window_width, window_height, "editor");

        Simp.set_render_target(window, .LEFT_HANDED);

        platform: Editor.Platform;
        // TODO(jt): Set up platform.

        editor: Editor.Editor;
        Editor.init(*editor, platform);

        should_run := true;
        while should_run {
            reset_temporary_storage();

            time_frame_start := current_time_monotonic();
            time_since_program_start := time_frame_start - time_program_start;

            dtime := time_frame_start - time_last_frame_start;
            time_last_frame_start = time_frame_start;

            input: Editor.Input;
            // TODO(jt): Fill in input.

            render_lists: Editor.Render_Lists;
            render_lists.buffer.allocator = temp;

            wants_quit := Editor.update_and_render(*editor, platform, input, *render_lists);
            if wants_quit {
                should_run = false;
            }

            Simp.update_window(window);
            Simp.clear_render_target(0, 0, 0, 1);
        }
    }
}

Context_Logger_Data :: struct {
    time_program_start: Apollo_Time;
}

context_logger :: (message: string, data: *void, info: Log_Info) {
    left_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        // TODO(jt): @Speed memset?
        for s.count..length - 1 {
            append(*builder, #char " ");
        }

        append(*builder, s);

        return builder_to_string(*builder,, temp);
    }

    right_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        append(*builder, s);

        // TODO(jt): @Speed memset?
        for s.count..length - 1 {
            append(*builder, #char " ");
        }

        return builder_to_string(*builder,, temp);
    }

    if !message {
        return;
    }

    context_logger_data := cast(*Context_Logger_Data, data);

    // Add time since launch. Pad to up to 4 leading digits and 6 decimal digits.
    time_start           := context_logger_data.time_program_start;
    time_now             := current_time_monotonic();
    time_since_start     := time_now - time_start;
    time_since_start_str := tprint("% ", formatFloat(to_float64_seconds(time_since_start), trailing_width = 6, zero_removal = .NO));
    time_prefix          := left_pad(time_since_start_str, 12);

    // Add log level.
    log_level_prefix := " INFO ";
    if info.common_flags & .WARNING  log_level_prefix = " WARN ";
    if info.common_flags & .ERROR    log_level_prefix = "ERROR ";

    // Add source file.
    source_prefix: string;
    {
        LENGTH :: 30;
        MODULES :: "modules/";

        path := info.location.fully_pathed_filename;
        index := String.find_index_from_left(path, MODULES);
        if index != -1 {
            source_prefix = advance(path, index + MODULES.count);
        } else {
            _, _, _, basename_with_extension := String.path_decomp(path);
            source_prefix = basename_with_extension;
        }

        source_prefix = right_pad(source_prefix, LENGTH + 1);
    }

    write_strings(time_prefix, log_level_prefix, source_prefix, message, "\n", to_standard_error = (info.common_flags & .ERROR) != 0);
}
