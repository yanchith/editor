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
}

build :: () {
    build_version_major := 0;
    build_version_minor := 0;
    build_version_patch := 1;
    build_timestamp := to_calendar(current_time_consensus());

    optimization_level := Optimization_Level.DEBUG;

    profiler_plugin: Profiler_Plugin.Profiler_Plugin;
    profiler_plugin.verbose = false;

    icon_plugin: Icon_Plugin.My_Plugin;
    icon_plugin.icon_filename = "./data/icon.ico";

    do_print_help      := false;
    do_profile         := true;
    do_sanity          := true;
    do_windows_console := true;

    // Match on commandline received by the default metaprogram so that we can tweak its decisions.
    // We try to respect it as much as possible, but we also provide the same switches.
    //
    // I tried modifying Default_Metaprogram to do what we need by merging it with this one, but
    // it isn't so easy. It involves hacking import_path, and makes it impossible(?) to pass program arguments
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
            case "-profile";             do_profile = true;
            case "-no-profile";          do_profile = false;
            case "-profile-verbose";     profiler_plugin.verbose = true;
            case "-no-profile-verbose";  profiler_plugin.verbose = false;
            case "-sanity";              do_sanity = true;
            case "-no-sanity";           do_sanity = false;
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
            set_optimization(*options, .DEBUG, preserve_debug_info = true);
            options.stack_trace = true;
            options.arithmetic_overflow_check = .FATAL;
        }
        case .OPTIMIZED; {
            set_optimization(*options, .VERY_OPTIMIZED, preserve_debug_info = true);
            options.stack_trace = false;
            options.arithmetic_overflow_check = .OFF;
        }
        case .OPTIMIZED_DEBUG; {
            set_optimization(*options, .OPTIMIZED, preserve_debug_info = true);
            options.stack_trace = true;
            options.arithmetic_overflow_check = .FATAL;
        }
    }

    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

    set_build_options(options, w);

    compiler_begin_intercept(w);

    build_info_declaration := tprint(BUILD_INFO_DECLARATION_TEMPLATE, build_version_major, build_version_minor, build_version_patch,
                                     build_timestamp.day_of_month_starting_at_0 + 1,
                                     month_text(build_timestamp.month_starting_at_0),
                                     build_timestamp.year);

    add_build_string(build_info_declaration, w);

    if do_sanity           add_build_string("__SANITY :: true;\n", w);
    if do_windows_console  add_build_string("__WINDOWS_CONSOLE :: true;\n", w);

    add_build_file("src/main.jai", w);

    while true {
        message := compiler_wait_for_message();

        Check_Plugin.do_error_checking(null, message);

        if do_profile {
            Profiler_Plugin.message(*profiler_plugin, message);
        }
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

BUILD_INFO_DECLARATION_TEMPLATE :: #string DONE
__VERSION_MAJOR    :: %;
__VERSION_MINOR    :: %;
__VERSION_PATCH    :: %;
__BUILD_TIMESTAMP  :: "% % %";
DONE;

HELP :: #string DONE

Usage: jai [DEFAULT_METAPROGRAM_OPTIONS] build.jai - [OPTIONS]

OPTIONS:

  -help                   Prints this message

  -debug                  Make a debug build
  -optimized              Make an optimized build
  -optimized_debug        Make a slightly less optimized build with debug info

  -x64                    Compile with the x64 backend
  -llvm                   Compile with the LLVM backend

  -profile                Instrument with profiling code
  -no-profile             Don't instrument with profiling code
  -profile-verbose        Print more messages about instrumented profiler zones
  -no-profile-verbose     Do not print more messages about instrumented profiler zones
  -sanity                 Turns on slow paranoid asserts
  -no-sanity              Turns off slow paranoid asserts
  -windows-console        Shows console on Windows when launched from gui
  -no-windows-console     Hides console on Windows when launched from gui and disables all console logging

For DEFAULT_METAPROGRAM_OPTIONS, type 'jai -help'.

DONE;

month_text :: (month_starting_at_0: s8) -> string {
    if month_starting_at_0 == {
        case 0;   return "January";
        case 1;   return "February";
        case 2;   return "March";
        case 3;   return "April";
        case 4;   return "May";
        case 5;   return "June";
        case 6;   return "July";
        case 7;   return "August";
        case 8;   return "September";
        case 9;   return "October";
        case 10;  return "November";
        case 11;  return "December";
        case;     return "Unknown";
    }
}