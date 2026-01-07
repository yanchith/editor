//
// This generate.jai is slightly cleaned up and modified, but is essentially the same template as
// the ones that ship with the compiler. I removed the AT_COMPILE_TIME flags (we always want to run
// this at compile time for now). I also removed platforms we don't care about.
//
// Usage:
//
// jai generate.jai [- [-x64] [-arm64] [-compile] [-debug]]
//
//
// The source of stb_truetype.h has very minor modifications, so that Bindings_Generator can pick up
// the functions defined there. Look for NOTE(jt) or #modification inside stb_truetype.h.
//

#import "Compiler";

#import "Basic";
#import "File";

BG        :: #import "Bindings_Generator";
Build_Cpp :: #import "BuildCpp";

SOURCE_PATH :: "source";
LIB_BASE_NAME :: "stb_truetype";

#run {
    options := get_build_options();
    if !generate_bindings(options.compile_time_command_line, options.minimum_os_version) {
        compiler_set_workspace_status(.FAILED);
    }

    set_build_options_dc({ do_output = false });
}

generate_bindings :: (args: [] string, minimum_os_version: type_of(Build_Options.minimum_os_version)) -> bool {
    target_x64    := array_find(args, "-x64");
    target_arm    := array_find(args, "-arm64");
    compile       := array_find(args, "-compile");
    compile_debug := array_find(args, "-debug");

    os_target  := OS;
    cpu_target := CPU;

    if target_x64  cpu_target = .X64;
    if target_arm  cpu_target = .ARM64;

    lib_directory: string;
    if os_target == {
        case .WINDOWS; lib_directory = "windows";
        case .LINUX;   lib_directory = "linux";
        case .MACOS;   lib_directory = "macos";
        case;          assert(false);
    }

    source_file := tprint("%/stb_truetype.c", SOURCE_PATH);

    if compile {
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);

        success := true;
        if os_target == .MACOS {
            success &&= Build_Cpp.build_universal_macos_binary(lib_path, source_file, type = .DYNAMIC_LIBRARY, debug = compile_debug);
            success &&= Build_Cpp.build_universal_macos_binary(lib_path, source_file, type = .STATIC_LIBRARY,  debug = compile_debug);
        } else {
            extra: [..] string;

            if os_target != .WINDOWS {
                array_add(*extra, "-fPIC"); // TODO(jt): Audit. What is this? I just copied it over from the beta.
            }

            success &&= Build_Cpp.build_cpp_dynamic_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
            success &&= Build_Cpp.build_cpp_static_lib(lib_path, source_file, target = os_target, debug = compile_debug, extra = extra);
        }

        if !success {
            return false;
        }
    }

    options: BG.Generate_Bindings_Options;
    options.os  = os_target;
    options.cpu = cpu_target;

    array_add(*options.library_search_paths, lib_directory);
    array_add(*options.libraries, { filename = LIB_BASE_NAME });
    array_add(*options.source_files, source_file);
    array_add(*options.typedef_prefixes_to_unwrap, "stbtt_");

    options.generate_library_declarations = false;
    options.footer = tprint(FOOTER_TEMPLATE, LIB_BASE_NAME);

    options.auto_detect_enum_prefixes = true;
    options.log_stripped_declarations = false;

    options.generate_compile_time_struct_checks = false;

    return BG.generate_bindings(options, "bindings.jai");
}

FOOTER_TEMPLATE :: #string END

#if OS == .WINDOWS {
    %1 :: #library "windows/%1";
} else #if OS == .LINUX {
    %1 :: #library "linux/%1";
} else #if OS == .MACOS {
    %1 :: #library "macos/%1";
} else {
    #assert false;
}

END
