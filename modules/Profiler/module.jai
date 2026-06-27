#module_parameters()(IMPORT_MODE := Import_Mode.METAPROGRAM) {
    Import_Mode :: enum u8 {
        METAPROGRAM :: 0;
        RUNTIME     :: 1;
    }
}

// Metaprograms should import this module in METAPROGAM mode. It is the default, because current
// Default_Metaprogram can not provide module or program arguments to metaprogram plugins.
//
// Otherwise, at runtime, import in RUNTIME mode. You can import the profiler into multiple modules,
// and they will share global array for zone information. If you do, only provide the program
// argument from the main program.

#if IMPORT_MODE == .METAPROGRAM {
    #load "metaprogram.jai";
} else {
    #load "runtime.jai";
}
