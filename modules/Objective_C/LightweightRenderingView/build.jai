DEBUG :: false;

LIB_PATH :: "libLightweightRenderingView";
SRC_FILE :: "LightweightRenderingView.m";
EXTRA :: string.["-framework", "AppKit", "-framework", "QuartzCore"];

#run {
    assert(OS == .MACOS);
    set_build_options_dc(.{do_output = false});
    success := true;
    success &&= build_universal_macos_binary(LIB_PATH, SRC_FILE, type = .DYNAMIC_LIBRARY, debug = DEBUG, extra = EXTRA);
    success &&= build_universal_macos_binary(LIB_PATH, SRC_FILE, type = .STATIC_LIBRARY,  debug = DEBUG, extra = EXTRA);
    if !success {
        compiler_set_workspace_status(.FAILED);
    }
}

#import "Basic";
#import "Compiler";
#import "BuildCpp";
