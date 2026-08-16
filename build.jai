#import "Compiler";
#import "Basic";
#import "File";

Check_Plugin    :: #import "Check";
Profiler_Plugin :: #import "Profiler"()(IMPORT_MODE = .METAPROGRAM);
Icon_Plugin     :: #import "Icon";

Optimization_Level :: enum {
    DEBUG;
    OPTIMIZED;
    OPTIMIZED_DEBUG;
    // We can be elaborate more later on:
    // OPTIMIZED_FOR_SPEED;
    // OPTIMIZED_FOR_SPEED_DEBUG:
    // OPTIMIZED_FOR_SIZE;
    // OPTIMIZED_FOR_SIZE_DEBUG;
}

build :: () {
    optimization_level := Optimization_Level.DEBUG;

    do_print_help      := false;
    do_check           := true;
    do_profile         := false;
    do_sanity          := true;
    do_subpixel        := true;
    do_windows_console := true;

    // Match on commandline received by the default metaprogram so that we can tweak its decisions.
    // We try to respect it as much as possible, but we also provide the same switches.
    //
    // I tried modifying Default_Metaprogram to do what we need by merging it with this one, but
    // it isn't so easy. It involves hacking import_path, and makes it impossible to pass program arguments
    // metaprogram plugins. We can try again later, but maybe it's not worth it.  -jt, 14 August 2026
    for get_toplevel_command_line() {
        if it == {
            case "-o";                optimization_level = .OPTIMIZED;
            case "-optimized";        optimization_level = .OPTIMIZED;
            case "-od";               optimization_level = .OPTIMIZED_DEBUG;
            case "-optimized_debug";  optimization_level = .OPTIMIZED_DEBUG;
        }
    }

    options := get_build_options(); // Inherited from Default_Metaprogram.

    for options.compile_time_command_line {
        if it == {
            case "-help";                do_print_help = true;
            case "-debug";               optimization_level = .DEBUG;
            case "-optimized";           optimization_level = .OPTIMIZED;
            case "-optimized_debug";     optimization_level = .OPTIMIZED_DEBUG;
            case "-x64";                 options.backend = .X64;
            case "-llvm";                options.backend = .LLVM;
            case "-check";               do_check = true;
            case "-no-check";            do_check = false;
            case "-profile";             do_profile = true;
            case "-no-profile";          do_profile = false;
            case "-sanity";              do_sanity = true;
            case "-no-sanity";           do_sanity = false;
            case "-subpixel";            do_subpixel = true;
            case "-no-subpixel";         do_subpixel = false;
            case "-windows-console";     do_windows_console = true;
            case "-no-windows-console";  do_windows_console = false;
            case; {
                log_error("Unknown argument '%'. Pass -help to print allowed options.\nExiting.", it);
                exit(1);
            }
        }
    }

    if do_print_help {
        // This goes to standard error, because otherwise both Emacs and this editor don't see this output. Regular console sees it. Weird.
        log_error(HELP);
        exit(1);
    }

    options.output_executable_name = "editor";
    options.output_path            = "build";
    options.intermediate_path      = "build/.build";

    if #complete optimization_level == {
        case .DEBUG; {
            set_optimization(*options, .DEBUG);
            options.stack_trace = true;
            options.arithmetic_overflow_check = .FATAL;
        }
        case .OPTIMIZED; {
            set_optimization(*options, .OPTIMIZED_VERY_SMALL);
            options.stack_trace = false;
            options.arithmetic_overflow_check = .OFF;
        }
        case .OPTIMIZED_DEBUG; {
            set_optimization(*options, .OPTIMIZED_SMALL);
            options.stack_trace = false;
            options.arithmetic_overflow_check = .FATAL;
        }
    }

    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

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

HELP :: #string DONE

Usage: jai [DEFAULT_METAPROGRAM_OPTIONS] FILE... - [OPTIONS]

OPTIONS:

  -help                   Prints this message.

  -debug                  Make a debug build.
  -optimized              Make an optimized build.
  -optimized_debug        Make a slightly less optimized build with debug info.

  -x64                    Compile with the x64 backend.
  -llvm                   Compile with the LLVM backend.

  -check                  Enables additional compile time checking.
  -no-check               Disables additional compile time checking.
  -profile                Enables the builtin runtime profiler.
  -no-profile             Disables the builtin runtime profiler.
  -sanity                 Turns on slow paranoid asserts.
  -no-sanity              Turns off slow paranoid asserts.
  -subpixel               Uses subpixel text rendering (FT_LOAD_TARGET.LCD).
  -no-subpixel            Uses regular text rendering (FT_LOAD_TARGET.NORMAL).
  -windows-console        Shows console on Windows when launched from gui.
  -no-windows-console     Hides console on Windows when launched from gui and disables all console logging.

For DEFAULT_METAPROGRAM_OPTIONS, type 'jai -help'.

DONE;
