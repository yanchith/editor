#import "Compiler";
#import "File";

build :: () {
    make_directory_if_it_does_not_exist("build");

    w := compiler_create_workspace("Editor");

    options := get_build_options(); // Inherited from what Default_Metaprogram set.
    options.output_executable_name = "editor";
    options.output_path            = "build";
    options.intermediate_path      = "build/.build";

    set_build_options(options, w);

    add_build_file("src/main.jai", w);

    // Do not output anything for this workspace.
    set_build_options_dc(.{ do_output = false });
}

#run build();
