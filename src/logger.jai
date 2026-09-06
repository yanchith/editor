Logger_Data :: struct {
    time_of_program_start: Apollo_Time;
    log_file: File.File; // Zero (invalid) handle by default.
}

logger :: (message: string, data: *void, info: Log_Info) {
    if !message {
        return;
    }

    logger_data := cast(*Logger_Data, data);

    time_start           := logger_data.time_of_program_start;
    time_now             := current_time_monotonic();
    time_since_start     := time_now - time_start;
    time_since_start_str := tprint("% ", formatFloat(to_float64_seconds(time_since_start), trailing_width = 6, zero_removal = .NO));
    time_prefix          := temp_left_pad(time_since_start_str, 12);

    log_level_prefix := " INFO ";
    if info.common_flags & .WARNING  log_level_prefix = " WARN ";
    if info.common_flags & .ERROR    log_level_prefix = "ERROR ";

    source_prefix: string;
    {
        PAD_LENGTH :: 30;
        MODULES :: "modules/";

        path := info.location.fully_pathed_filename;
        index := String.find_index_from_left(path, MODULES);
        if index != -1 {
            source_prefix = advance(path, index + MODULES.count);
        } else {
            filename := String.path_filename(path);
            source_prefix = filename;
        }

        source_prefix = temp_right_pad(source_prefix, PAD_LENGTH);
    }

    if File.is_valid(logger_data.log_file) {
        sb: String_Builder;
        sb.allocator = temp;

        append(*sb, time_prefix);
        append(*sb, log_level_prefix);
        append(*sb, source_prefix);
        append(*sb, " ");
        append(*sb, message);
        append(*sb, "\n");

        File.file_write(*logger_data.log_file, *sb);
        File.file_flush(logger_data.log_file);
    }

    write_strings(time_prefix, log_level_prefix, source_prefix, " ", message, "\n", to_standard_error = (info.common_flags & .ERROR) != 0);
}

assertion_failed :: (loc: Source_Code_Location, message: string) -> bool {
    runtime_support_assertion_failed(loc, message);

    logger_data := cast(*Logger_Data, context.logger_data);
    if logger_data && File.is_valid(logger_data.log_file) {
        sb: String_Builder;
        sb.allocator = temp;

        print(*sb, "%:%,%: Assertion failed", loc.fully_pathed_filename, loc.line_number, loc.character_number);
        if message {
            print(*sb, ":%\n", message);
        } else {
            print(*sb, "!\n");
        }

        if context.stack_trace {
            strings := get_stack_trace_strings(context.stack_trace);

            print(*sb, "\nStack trace:\n");
            for strings {
                print(*sb, "%\n", it);
            }
        }

        if Input.events_this_frame.count {
            print(*sb, "\nInput events this frame:\n");
            for Input.events_this_frame {
                print(*sb, "[%] %\n", it_index, it);
            }
        }

        print(*sb, "\nExiting.\n");

        File.file_write(*logger_data.log_file, *sb, do_reset = true);
        File.file_flush(logger_data.log_file);
    }

    return true;
}

#scope_file

// @Copypasta from src/string.jai, but it isn't worth it #load-ing all of that code just for these two.

temp_left_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    for s.count..length - 1 {
        append(*builder, " ");
    }

    append(*builder, s);

    return builder_to_string(*builder,, temp);
}

temp_right_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, s);

    for s.count..length - 1 {
        append(*builder, " ");
    }

    return builder_to_string(*builder,, temp);
}
