//
// We define here the few things Bindings_Generator didn't:
//

// #define FT_LOAD_TARGET_( x )   ( FT_STATIC_CAST( FT_Int32, (x) & 15 ) << 16 )
//
// #define FT_LOAD_TARGET_NORMAL  FT_LOAD_TARGET_( FT_RENDER_MODE_NORMAL )
// #define FT_LOAD_TARGET_LIGHT   FT_LOAD_TARGET_( FT_RENDER_MODE_LIGHT  )
// #define FT_LOAD_TARGET_MONO    FT_LOAD_TARGET_( FT_RENDER_MODE_MONO   )
// #define FT_LOAD_TARGET_LCD     FT_LOAD_TARGET_( FT_RENDER_MODE_LCD    )
// #define FT_LOAD_TARGET_LCD_V   FT_LOAD_TARGET_( FT_RENDER_MODE_LCD_V  )

FT_LOAD_TARGET_ :: inline (render_mode: FT_Render_Mode) -> s32 {
    return (cast(s32, render_mode) & 15) << 16;
}

FT_Load_Target :: enum s32 {
    NORMAL :: #run FT_LOAD_TARGET_(.NORMAL);
    LIGHT  :: #run FT_LOAD_TARGET_(.LIGHT);
    MONO   :: #run FT_LOAD_TARGET_(.MONO);
    LCD    :: #run FT_LOAD_TARGET_(.LCD);
    LCD_V  :: #run FT_LOAD_TARGET_(.LCD_V);
}

ptrdiff_t :: s64;

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
