#import "Compiler";
#import "File";

Check    :: #import "Check";
Profiler :: #import "Profiler"(IMPORT_MODE = .METAPROGRAM);

build :: () {
    do_optimized_build := false;
    do_profiling_build := false;
    do_sanity_build    := true;
    do_check           := true;

    for get_toplevel_command_line() {
        if it == "-o"                do_optimized_build = true;
        if it == "-optimized"        do_optimized_build = true;
        if it == "-od"               do_optimized_build = true;
        if it == "-optimized_debug"  do_optimized_build = true;
        if it == "-llvm"             do_optimized_build = false;
        if it == "-x64"              do_optimized_build = false;
    }

    for get_build_options().compile_time_command_line {
        if it == "-profile"     do_profiling_build = true;
        if it == "-no-profile"  do_profiling_build = false;
        if it == "-sanity"      do_sanity_build = true;
        if it == "-no-sanity"   do_sanity_build = false;
        if it == "-check"       do_check = true;
        if it == "-no-check"    do_check = false;
    }

    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

    options := get_build_options(); // Inherited from what Default_Metaprogram set.
    options.output_executable_name = "editor";
    options.output_path            = "build";
    options.intermediate_path      = "build/.build";

    if !do_optimized_build {
        // The compiler doesn't enable this yet by default for debug builds. Let's try it out!
        //
        // UPDATE: There's code in jai modules (and sometimes in our own code) that can trigger
        // this. So far it was always a bug, but it was usually a benign one, and the resulting
        // crash was a little annoying to debug. Leaving it on for now, but man...
        options.arithmetic_overflow_check = .FATAL;
    }

    set_build_options(options, w);

    require_message_loop := do_profiling_build || do_check;

    if require_message_loop {
        compiler_begin_intercept(w);
    }

    if do_sanity_build {
        add_build_string("__SANITY :: true;\n", w);
    }

    add_build_file("src/main.jai", w);

    if require_message_loop {
        while true {
            message := compiler_wait_for_message();

            // The plugins we currently support (Profiler and Check) do not need any initialization,
            // and their message routines do not use the *Metaprogram_Plugin argument.

            if do_profiling_build  Profiler.message(null, message);
            if do_check            Check.do_error_checking(null, message);

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
