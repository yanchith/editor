#import "Compiler";
#import "Basic";
#import "File";

// Metaprogram plugins
Check_Plugin    :: #import "Check";
Profiler_Plugin :: #import "Profiler"()(IMPORT_MODE = .METAPROGRAM);
Icon_Plugin     :: #import "Icon";

build :: () {
    is_optimized_build := false;

    do_check    := true;
    do_profile  := false;
    do_sanity   := true;
    do_subpixel := true;
    do_windows_console := true;

    for get_toplevel_command_line() {
        if it == {
            case "-o";                is_optimized_build = true;
            case "-optimized";        is_optimized_build = true;
            case "-od";               is_optimized_build = true;
            case "-optimized_debug";  is_optimized_build = true;
        }
    }

    for get_build_options().compile_time_command_line {
        if it == {
            case "-check";            do_check = true;
            case "-no-check";         do_check = false;
            case "-profile";          do_profile = true;
            case "-no-profile";       do_profile = false;
            case "-sanity";           do_sanity = true;
            case "-no-sanity";        do_sanity = false;
            case "-subpixel";         do_subpixel = true;
            case "-no-subpixel";      do_subpixel = false;
            case "-windows-console";  do_windows_console = true;
            case "-no-windows-console";  do_windows_console = false;
            case; {
                log_error("Unknown argument '%'.\nExiting.", it);
                exit(1);
            }
        }
    }

    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

    options := get_build_options(); // Inherited from what Default_Metaprogram set.
    options.output_executable_name = "editor";
    options.output_path            = "build";
    options.intermediate_path      = "build/.build";

    if !is_optimized_build {
        // The compiler doesn't enable this yet by default for debug builds. Let's try it out!
        //
        // UPDATE: There's code in jai modules (and sometimes in our own code) that can trigger
        // this. So far it was always a bug on my side, and I guess it's good that we have to
        // manually #no_aoc.
        options.arithmetic_overflow_check = .FATAL;
    }

    set_build_options(options, w);

    icon_plugin: Icon_Plugin.My_Plugin;
    icon_plugin.icon_filename = "./data/icon.ico";

    compiler_begin_intercept(w);

    if do_sanity {
        add_build_string("__SANITY :: true;\n", w);
    }

    if do_subpixel {
        add_build_string("__SUBPIXEL :: true;\n", w);
    }

    if do_windows_console {
        add_build_string("__WINDOWS_CONSOLE :: true;\n", w);
    }

    add_build_file("src/main.jai", w);

    while true {
        message := compiler_wait_for_message();

        if do_profile  Profiler_Plugin.message(null, message);
        if do_check    Check_Plugin.do_error_checking(null, message);

        Icon_Plugin.message(*icon_plugin, message);

        if message.kind == .COMPLETE {
            break;
        }
    }

    compiler_end_intercept(w);

    // Do not output anything for this workspace.
    set_build_options_dc({ do_output = false });
}

#run build();
