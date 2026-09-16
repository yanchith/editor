/*

Making a local build:

jai [-x64] build.jai
jai -optimized_debug build.jai

Making a release:

0) Set version number in this file

(Windows)

1) jai -optimized_debug build.jai - -no-windows-console -bundle
2) Zip build/editor

(macOS)

1) jai -optimized_debug build.jai - -bundle

(Linux coming soonish)

*/

VERSION_MAJOR :: 0;
VERSION_MINOR :: 0;
VERSION_PATCH :: 2;

#import "Compiler";
#import "Basic";
#import "File";
#import "File_Utilities";

Check_Plugin    :: #import "Check";
Profiler_Plugin :: #import "Profiler"()(IMPORT_MODE = .METAPROGRAM);

#if OS == .WINDOWS {
    Icon_Plugin :: #import "Icon";
}

Optimization_Level :: enum {
    DEBUG;
    OPTIMIZED;
    OPTIMIZED_DEBUG;
}

build :: () {
    build_timestamp := to_calendar(current_time_consensus());

    optimization_level := Optimization_Level.DEBUG;

    profiler_plugin: Profiler_Plugin.Profiler_Plugin;
    profiler_plugin.verbose = false;

    #if OS == .WINDOWS {
        icon_plugin: Icon_Plugin.My_Plugin;
        icon_plugin.icon_filename = "./data/icon.ico";
    }

    do_print_help      := false;
    do_profile         := true;
    do_sanity          := true;
    do_windows_console := true;
    do_bundle          := false;

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
            case "-bundle";              do_bundle = true;
            case "-no-bundle";           do_bundle = false;
            case; {
                log_error("Unknown argument '%'. Pass -help to print allowed options.\nExiting.", it);
                exit(1);
            }
        }
    }

    if do_print_help {
        // This goes to standard error, because otherwise both Emacs and this editor don't see this output.
        // Regular console sees it. Weird.
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

    build_info := tprint(BUILD_INFO_TEMPLATE, VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH,
                         build_timestamp.day_of_month_starting_at_0 + 1,
                         month_text(build_timestamp.month_starting_at_0),
                         build_timestamp.year);

    add_build_string(build_info, w);

    if do_sanity           add_build_string("__SANITY :: true;\n", w);
    if do_windows_console  add_build_string("__WINDOWS_CONSOLE :: true;\n", w);

    add_build_file("src/main.jai", w);

    compilation_failed := false;
    while true {
        m := compiler_wait_for_message();

        Check_Plugin.do_error_checking(null, m);

        if do_profile       Profiler_Plugin.message(*profiler_plugin, m);
        #if OS == .WINDOWS  Icon_Plugin.message(*icon_plugin, m);

        if m.kind == .COMPLETE {
            mc := cast(*Message_Complete, m);
            if mc.error_code == .COMPILATION_FAILED {
                compilation_failed = true;
            }

            break;
        }
    }

    compiler_end_intercept(w);

    if !compilation_failed && do_bundle {
        // TODO(jt): Make all bundles copy to a dist directory. macOS currently goes to root,
        // and Windows to build (which interferes with regular dev process).
        #if OS == .WINDOWS {
            make_windows_bundle(options);
        } else #if OS == .MACOS {
            make_macos_bundle(options);
        } else {
            log_error("Bundles for % are not supported", OS);
        }
    }

    // Do not output anything for this workspace.
    set_build_options_dc({ do_output = false });
}

#run build();

BUILD_INFO_TEMPLATE :: #string DONE
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
  -bundle                 Create a bundle after compilation succeeds
  -no-bundle              Don't create a bundle after compilation succeeds

For DEFAULT_METAPROGRAM_OPTIONS, type 'jai -help'.

DONE;

#if OS == .WINDOWS {
    make_windows_bundle :: (options: Build_Options) {
        Copy :: struct {
            kind: enum { file; dir; };
            source: string;
            dest: string;
        }

        log("\nMaking windows bundle");

        bundle_path := tprint("%/editor", options.output_path);

        exe_name := tprint("%.exe", options.output_executable_name);
        exe_path := tprint("%/%.exe", options.output_path, options.output_executable_name);

        make_directory_if_it_does_not_exist(bundle_path);

        ok := true;
        for Copy.[
            { .file, exe_path,                tprint("%/%", bundle_path, exe_name) },
            { .dir,  "data",                  tprint("%/data", bundle_path) },
        ] {
            log("Copying % % -> %", it.kind, it.source, it.dest);

            success: bool;
            if it.kind == {
                case .file;  success = copy_file(it.source, it.dest);
                case .dir;   success = copy_directory(it.source, it.dest);
            }

            if !success {
                ok = false;
                log_error("Failed to copy % %", it.kind, it.source);
            }
        }

        if ok {
            log("\nBundle done");
        } else {
            log("\nBundle error");
        }
    }
}

#if OS == .MACOS {
    #import "MacOS_Bundler";

    make_macos_bundle :: (options: Build_Options) {
        log("\nMaking macOS bundle");

        exe_path := tprint("%/%", options.output_path, options.output_executable_name, );

        create_app_bundle("Editor", exe_path, "data/icon.ico", "data", only_copy_subdirectories_and_files = true, write_plist = true);
        log("\nBundle done");
    }
}

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