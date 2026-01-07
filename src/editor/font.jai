// XXX: HERE Do this next!
//
// For character rasterization and metrics extraction, try using stb_truetype. If it fails, try
// using freetype.
//
// If we do software rendering, we don't really care about having a pre-rasterized font atlas, and
// can just stamp our glyphs out of a font cache. This is appealing, but I am not sure if it will be
// fast enough.
//
// However, if we do GPU rendering, we definitely have to have either a texture array, or an atlas -
// either way something we must prepare, in which case we'll have to have a glyph cache to atlas
// packer.
//
// The glyph cache (and the atlas, if we do that) could just grow indefinitely as we keep requesting
// new characters at new sizes to draw. The grows of font atlases could be somewhat controlled
// byrasterizing the entire unicode range of that character.
//
// Also see what refterm and 4coder do...
//
// TODO(jt): Features:
//
// - [ ] glyphs
// - [ ] glyph metrics
// - [ ] mapping of codepoints to glyphs and metrics
// - [ ] basic layout
// - [ ] kerning
// - [ ] ligatures
//
// Nonfeatures:
//
// - hinting
// - shaping
// - right to left
// - vertical fonts
//

Font :: struct {
    info: stbtt_fontinfo;
    glyph_cache: Glyph_Cache;
}

Glyph_Info :: struct {
    advance: f32;
}

// TODO(jt): Make this into a LRU cache for rasterized glyphs of various sizes.
Glyph_Cache :: struct {
    arena: Arena;
}

make_font :: (arena: Arena, ttf_buffer: [] u8) -> Font {
    info: stbtt_fontinfo;
    stbtt_InitFont(*info, ttf_buffer.data, stbtt_GetFontOffsetForIndex(ttf_buffer.data, 0));

    glyph_cache: Glyph_Cache;
    glyph_cache.arena = arena;

    return { info, glyph_cache };
}

layout_text :: (font: *Font, font_size: f32, text: string) -> [..] Render_Rect {

}

#scope_file

#import "stb_truetype";
