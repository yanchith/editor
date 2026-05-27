//
// This is our adapted version of the generate.jai modules/freetype in the Secret Beta. We removed
// platforms we don't build for and simplified what remained. We also added ftlcdfil.h to the build,
// so we can do subpixel rendering. You can run this at compile time (easier) or runtime (debugging).
//
// If you want to generate the bindings again, download freetype and extract it into
// source/freetype-x.y.z. Then modify devel/ftoption.h:
//
// - Comment out FT_CONFIG_OPTION_ENVIRONMENT_PROPERTIES (We don't need this)
// - Uncomment   FT_CONFIG_OPTION_SUBPIXEL_RENDERING     (We do need this)
//
// Usage:
//
// jai generate.jai [- [-x64] [-arm64] [-compile] [-debug]]
//
// This calls out to cmake on all platforms and lipo on macOS.
//

#import "Compiler";
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Process";

BG :: #import "Bindings_Generator";

AT_COMPILE_TIME :: true;

FREETYPE_PATH :: "source/freetype-2.14.3";

#if AT_COMPILE_TIME {
    #run {
        options := get_build_options();
        if !generate_bindings(options.compile_time_command_line) {
            compiler_set_workspace_status(.FAILED);
        }

        set_build_options_dc({ do_output = false });
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments()) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string) -> bool {
    target_x64    := array_find(args, "-x64");
    target_arm    := array_find(args, "-arm64");
    compile       := array_find(args, "-compile");
    compile_debug := array_find(args, "-debug");

    os_target  := OS;
    cpu_target := CPU;

    if os_target == .MACOS && (target_x64 || target_arm) {
        log("-x64 and -arm64 options are ignored on macOS. This command builds a universal binary.");
    }

    if target_x64  cpu_target = .X64;
    if target_arm  cpu_target = .ARM64;

    lib_directory: string;
    if os_target == {
        case .WINDOWS;  lib_directory = "windows";
        case .LINUX;    lib_directory = "linux";
        case .MACOS;    lib_directory = "macos";
        case;           assert(false);
    }

    if compile {
        if os_target == .MACOS {
            minimum_x64_version:   Build_Options.Os_Version = { 10, 13 };
            minimum_arm64_version: Build_Options.Os_Version = { 11,  0 };

            static_x64_path: string;
            dynamic_x64_path: string;
            {
                success:, static_x64_path, dynamic_x64_path = compile_freetype_variant(os_target, .X64, minimum_x64_version, lib_directory, compile_debug = compile_debug, suffix = "_x64");
                if !success {
                    return false;
                }
            }

            static_arm64_path: string;
            dynamic_arm64_path: string;
            {
                success:, static_arm64_path, dynamic_arm64_path = compile_freetype_variant(os_target, .ARM64, minimum_arm64_version, lib_directory, compile_debug = compile_debug, suffix = "_arm64");
                if !success {
                    return false;
                }
            }

            // Create universal binaries out of the two arch builds:
            run_or_exit(.["lipo", "-create", dynamic_x64_path, dynamic_arm64_path, "-output", tprint("%/freetype.dylib", lib_directory)], "");
            run_or_exit(.["lipo", "-create", static_x64_path,  static_arm64_path,  "-output", tprint("%/freetype.a",     lib_directory)], "");
        } else {
            minimum_os_version: Build_Options.Os_Version;
            success := compile_freetype_variant(os_target, cpu_target, minimum_os_version, lib_directory, compile_debug = compile_debug);
            if !success return false;
        }
    }

    freetype_include := tprint("%/include", FREETYPE_PATH);

    output_name: string;
    if os_target == {
        case .WINDOWS;  output_name = "windows.jai";
        case .LINUX;    #through;
        case .MACOS;    output_name = "unix.jai";
        case;           assert(false);
    }

    options: BG.Generate_Bindings_Options;
    options.os  = os_target;
    options.cpu = cpu_target;

    array_add(*options.library_search_paths, lib_directory);

    array_add(*options.libraries, { filename = "freetype" });
    array_add(*options.include_paths, freetype_include);

    sources := string.[
        "freetype/freetype.h",
        "freetype/tttables.h",
        "freetype/ftlcdfil.h",
    ];
    for sources {
        array_add(*options.source_files, tprint("%/%", freetype_include, it));
    }

    options.generate_library_declarations = false;

    options.auto_detect_enum_prefixes = true;
    options.log_stripped_declarations = false;
    options.generate_compile_time_struct_checks = false;

    array_add(*options.generate_enums_from_macros_with_prefixes, "FT_LOAD_TARGET");

    return BG.generate_bindings(options, output_name);
}


compile_freetype_variant :: (os_target: Operating_System_Tag, cpu_target: CPU_Tag, minimum_os_version: Build_Options.Os_Version, target_directory: string, compile_debug: bool, suffix := "") -> bool, static_lib_path: string, dynamic_lib_path: string {
    build_type := "Release";
    if compile_debug {
        build_type = "Debug";
    }

    absolute_build_dir := tprint("%/%_build%", get_absolute_path("."), target_directory, suffix);

    // TODO(jt): @Audit I don't know what some of these compiler arguments are, and should probably
    // double check them, but for now I trust that Raphael probably did a good job.

    static_library_extension: string;
    static_config_command: [..] string;
    array_add(
        *static_config_command,
        "cmake",
        tprint("-B%", absolute_build_dir),
        "-DFT_DISABLE_ZLIB=TRUE",
        "-DFT_DISABLE_BZIP2=TRUE",
        "-DFT_DISABLE_PNG=TRUE",
        "-DFT_DISABLE_HARFBUZZ=TRUE",
        "-DFT_DISABLE_BROTLI=TRUE",
        tprint("-DCMAKE_BUILD_TYPE=%", build_type),
    );

    dynamic_library_extension: string;
    dynamic_config_command: [..] string;
    array_add(
        *dynamic_config_command,
        "cmake",
        tprint("-B%", absolute_build_dir),
        "-DFT_DISABLE_ZLIB=TRUE",
        "-DFT_DISABLE_BZIP2=TRUE",
        "-DFT_DISABLE_PNG=TRUE",
        "-DFT_DISABLE_HARFBUZZ=TRUE",
        "-DFT_DISABLE_BROTLI=TRUE",
        "-DBUILD_SHARED_LIBS=true",
        tprint("-DCMAKE_BUILD_TYPE=%", build_type),
    );

    source_library_name: string;
    build_dir_suffix: string;
    if os_target == {
        case .WINDOWS; {
            static_library_extension = "lib";
            dynamic_library_extension = "dll";
            source_library_name = "freetype";
            build_dir_suffix = "Release/"; // XXX: And what about debug?

            array_add(*static_config_command,  tprint("-DCMAKE_CONFIGURATION_TYPES=%", build_type));
            array_add(*dynamic_config_command, tprint("-DCMAKE_CONFIGURATION_TYPES=%", build_type));
        }
        case .MACOS; {
            static_library_extension = "a";
            dynamic_library_extension = "dylib";
            source_library_name = ifx compile_debug then "libfreetyped" else "libfreetype";

            arch_name := ifx cpu_target == .X64 then "x86_64" else "arm64";
            arch_arg := tprint("-DCMAKE_OSX_ARCHITECTURES=%", arch_name);
            version_arg := tprint("-DCMAKE_OSX_DEPLOYMENT_TARGET=%.%", minimum_os_version.major, minimum_os_version.minor);
            array_add(*static_config_command,  arch_arg, version_arg);
            array_add(*dynamic_config_command, arch_arg, version_arg);
        }
        case .LINUX; {
            static_library_extension = "a";
            dynamic_library_extension = "so";
            source_library_name = ifx compile_debug then "libfreetyped" else "libfreetype";

            array_add(*static_config_command, "-DCMAKE_POSITION_INDEPENDENT_CODE=ON");
        }
        case; {
            assert(false);
        }
    }

    build_command: [..] string;
    array_add(*build_command, "cmake", "--build", absolute_build_dir);
    if OS == .WINDOWS {
        array_add(*build_command, tprint("--config=%", build_type));
    }

    success := make_directory_if_it_does_not_exist(target_directory, recursive = true);
    if !success {
        log_error("Failed to make directory \"%\"", target_directory);
        return false, "", "";
    }

    if file_exists(absolute_build_dir) {
        success := delete_directory(absolute_build_dir);
        if !success {
            log_error("Could not delete old build directory");
            return false, "", "";
        }
    }

    log("Configuring to build the static lib: %", static_config_command);
    run_or_exit(static_config_command, FREETYPE_PATH);

    log("Building the static lib");
    run_or_exit(build_command, FREETYPE_PATH);

    static_lib_source := tprint("%1/%2%3.%4", absolute_build_dir, build_dir_suffix, source_library_name, static_library_extension);
    static_lib_dest   := tprint("%/freetype%.%", target_directory, suffix, static_library_extension);
    if !copy_library(static_lib_source, static_lib_dest) {
        return false, "", "";
    }

    success = delete_directory(absolute_build_dir);
    if !success {
        log_error("Could not delete old build directory");
        return false, "", "";
    }

    log("Configuring to build the dynamic lib: %", dynamic_config_command);
    run_or_exit(dynamic_config_command, FREETYPE_PATH);

    log("Building the dynamic lib");
    run_or_exit(build_command, FREETYPE_PATH);

    dynamic_lib_source := tprint("%1/%2%3.%4", absolute_build_dir, build_dir_suffix, source_library_name, dynamic_library_extension);
    dynamic_lib_dest   := tprint("%/freetype%.%", target_directory, suffix, dynamic_library_extension);
    if !copy_library(dynamic_lib_source, dynamic_lib_dest) {
        return false, "", "";
    }

    delete_directory(absolute_build_dir);

    log("Built freetype successfully");
    return true, static_lib_dest, dynamic_lib_dest;
}

copy_library :: (src: string, dest: string) -> bool {
    if file_exists(dest) {
        success := file_delete(dest);
        if !success {
            log_error("Failed to delete old \"%\"", dest);
            return false;
        }
    }

    success := copy_file(src, dest);
    if !success {
        log_error("Failed to copy file \"%\" to \"%\"", src, dest);
        return false;
    }

    return true;
}


run_or_exit :: (command: [] string, working_directory: string) {
    // Uncomment this to see the commands being executed.
    // print("Executing command \"%\" in directory \"%\"\n", join(..command, separator = " "), working_directory);

    // Enable this for live output.
    LIVE_OUTPUT :: false;

    result, output_string, error_string := run_command(..command, working_directory = working_directory, capture_and_return_output = true, print_captured_output = LIVE_OUTPUT);
    defer {
        free(output_string);
        free(error_string);
    }

    if result.exit_code != 0 {
        log_error("Could not run command \"%\" in directory \"%\". Exit code: %\nError:\n%", get_quoted_command_string(command), working_directory, result.exit_code, error_string);
        exit(1);
    }
}
