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
//
// TODO(jt): Features:
//
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

GLYPH_CACHE_SIZE :: 32;

// TODO(jt): Turn this into a LRU cache for rasterized glyphs and their metrics of various sizes.
// However, if we use proportional fonts, we can't easily compute the cell size for a rasterized
// glyph, so we'd have to support multiple size classes at once. Even if we stick to monospace
// fonts, the user can change the size, but in this case at least we could drop the cache and start
// over in our nicely regular monospace world.
Font :: struct {
    arena: Arena;
    font_vmetrics: Font_VMetrics;

    info: stbtt_fontinfo;
}

Font_VMetrics :: struct {
    ascent: s32;
    descent: s32;
    line_gap: s32;
}

Glyph_HMetrics :: struct {
    advance: s32;
    left_side_bearing: s32;
}

// The caller has to keep ttf_buffer alive. Easiest way is to put it in the arena.
make_font :: (arena: Arena, ttf_buffer: [] u8) -> Font {
    info: stbtt_fontinfo;
    stbtt_InitFont(*info, ttf_buffer.data, stbtt_GetFontOffsetForIndex(ttf_buffer.data, 0));

    result: Font;
    result.arena = arena;
    result.font_vmetrics = get_font_vmetrics(info);
    result.info = info;

    return result;
}

// XXX: About the font atlas....
//
// Q: So how and when do we generate the atlas? We could either generate the entire font, but isn't
// that too large? What happens when new characters enter the buffer that are not in the atlas?
// What does refterm do here?
//
// A: So refterm is monospace. Its glyph cache is a regular grid. It LRU-recycles cells of that grid
// as necessary, and the grid is large enough to fit the entire screen full of pixels, even if the
// entire screen is filled with entirely unique glyphs. (I assume the entire cache is flushed when
// font size changes.)
//
// The state of each grid cell is then tracked. It can be either unused, or
// rasterized-and-uploaded. The GPU uploads happen by subregions (or it just sends the bounding
// box).
//
// Now this is all quite elegant for monospace, but is there a way to adapt this for proportional
// fonts? I guess we'd have to start maintaining an atlas allocator or something. The good part is
// that we can still send incremental patches to the GPU, but we now waste more space, and
// allocation/deallocation is no longer just about LRU, but maybe we want to start thinking about
// freeing the most space, etc.
//
// So we start with monospace, and nuke the cache on font size change.
//
// UPDATE: After watching Casey's refterm cache video, I think we could adapt his farsi (ligature?
// ... we should verify if ligature widths have to be a multiple of the single-length character
// widths) code to support proportional fonts... by splitting the rasterized glyph into multiple
// slots in the atlas.
//
// UPDATE: To support ligatures, the input has to be the entire ligature... (multiple codepoints).

// This function does it all. Starts at the top of the screen (which we should fast means of
// finding), and keeps processing text until we leave the screen. Processing means doing layout
// based on metrics, but also ensuring the glyph is in the cache, and maintaining a list of patches
// to the texture on the GPU.
//
// XXX: Should we do it all in a single pass? What does refterm do here?
layout_and_draw_text :: (font: *Font, font_size: f32, text: string) -> [..] Render_Rect {
    result: [..] Render_Rect;

    // XXX: HERE Do the layout... In a single-pass way? Also we should probably take in some
    // starting state and return some end state, so that this can be called incrementally.

    for :Unicode.utf8_iter text {
        print("C: % % %\n", it, get_glyph_index(font.info, it), get_codepoint_hmetrics(font.info, it));
    }

    return result;
}

#scope_file

get_font_vmetrics :: (info: stbtt_fontinfo) -> Font_VMetrics {
    result: Font_VMetrics = ---;
    stbtt_GetFontVMetrics(*info, *result.ascent, *result.descent, *result.line_gap);
    return result;
}

get_glyph_index :: (info: stbtt_fontinfo, codepoint: u32) -> s32 {
    return stbtt_FindGlyphIndex(*info, cast,no_check(s32, codepoint));
}

get_codepoint_hmetrics :: (info: stbtt_fontinfo, codepoint: u32) -> Glyph_HMetrics {
    result: Glyph_HMetrics = ---;
    stbtt_GetCodepointHMetrics(*info, cast,no_check(s32, codepoint), *result.advance, *result.left_side_bearing);
    return result;
}

get_glyph_hmetrics :: (info: stbtt_fontinfo, glyph_index: s32) -> Glyph_HMetrics {
    result: Glyph_HMetrics = ---;
    stbtt_GetGlyphHMetrics(*info, glyph_index, *result.advance, *result.left_side_bearing);
    return result;
}

#import "stb_truetype";
