#import "Compiler";
#import "File";

Profiler :: #import "Profiler"(IMPORT_MODE = .METAPROGRAM);

build :: () {
    do_optimized_build           := false;
    do_profiling_build           := false;

    for get_toplevel_command_line() {
        if it == "-release"    do_optimized_build = true;
        if it == "-optimized"  do_optimized_build = true;

    }

    for get_build_options().compile_time_command_line {
        // We could in theory detect the +Profiler flag from the top level command line, but that
        // would cause the Default_Metaprogram to inject stuff here, where we import the profiler as
        // a metaprogram plugin and not a runtime module. We could maybe do something about it so
        // that it would work anyway, but maybe it's best to not cause more confusion.
        if it == "-profile"    do_profiling_build = true;
    }

    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

    options := get_build_options(); // Inherited from what Default_Metaprogram set.
    options.output_executable_name = "editor";
    options.output_path            = "build";
    options.intermediate_path      = "build/.build";

    if !do_optimized_build {
        // This isn't enabled yet by default for debug builds.. and maybe they will only enable it
        // for very_debug builds, so...
        options.arithmetic_overflow_check = .FATAL;
    }

    set_build_options(options, w);

    if do_profiling_build {
        compiler_begin_intercept(w);
    }

    add_build_file("src/main.jai", w);

    if do_profiling_build {
        while true {
            message := compiler_wait_for_message();

            // No need to actually call Profiler.get_plugin. The plugin would just pipe the message
            // to the message procedure anyway.
            Profiler.handle_message(message);

            if message.kind == .COMPLETE {
                break;
            }
        }

        compiler_end_intercept(w);
    }

    // Do not output anything for this workspace.
    set_build_options_dc(.{ do_output = false });
}

#run build();
