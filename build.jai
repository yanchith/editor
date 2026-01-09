#import "Compiler";
#import "File";

build :: () {
    do_release_build := false;

    for get_toplevel_command_line() {
        if it == "-release"  do_release_build = true;
    }

    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

    options := get_build_options(); // Inherited from what Default_Metaprogram set.
    options.output_executable_name = "editor";
    options.output_path            = "build";
    options.intermediate_path      = "build/.build";

    if !do_release_build {
        // This isn't enabled yet by default for debug builds.. and maybe they will only enable it
        // for very_debug builds, so...
        options.arithmetic_overflow_check = .FATAL;
    }

    set_build_options(options, w);

    add_build_file("src/main.jai", w);

    // Do not output anything for this workspace.
    set_build_options_dc(.{ do_output = false });
}

#run build();
