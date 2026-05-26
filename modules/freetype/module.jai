ptrdiff_t :: s64; // TODO(jt): @Cleanup Shouldn't the Bindings_Generator have defined this?

#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS_IS_UNIX {
    #load "unix.jai";
} else {
    #assert false;
}

#if OS == .WINDOWS {
    freetype :: #library "windows/freetype";
} else #if OS == .LINUX {
    #assert false;
} else #if OS == .MACOS {
    freetype :: #library "macos/freetype";
} else {
    #assert false;
}
