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
// - [ ] ligatures?
//
// Nonfeatures:
//
// - hinting
// - shaping
// - right to left
// - vertical fonts
//

FONT_ATLAS_ALIGNMENT :: 16;

GLYPH_CACHE_SIZE :: 32;
FONT_PIXEL_HEIGHT: f32 = 12;

// TODO(jt): Turn this into a LRU cache for rasterized glyphs and their metrics of various sizes.
// However, if we use proportional fonts, we can't easily compute the cell size for a rasterized
// glyph, so we'd have to support multiple size classes at once. Even if we stick to monospace
// fonts, the user can change the size, but in this case at least we could drop the cache and start
// over in our nicely regular monospace world.
Font :: struct {
    arena: Arena;
    arena_mark: Arena_Mark;


    atlas: *u8;
    atlas_width: u16;
    atlas_height: u16;

    vmetrics: Font_VMetrics;
    scale: f32;

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

// The caller has to keep ttf_buffer alive. Easiest way is to put it in the passed in arena.
make_font :: (arena: Arena, ttf_buffer: [] u8) -> Font {
    INITIAL_WIDTH  :: 1024;
    INITIAL_HEIGHT :: 1024;

    arena_mark := arena_get_mark(arena); // So that we don't hose whatever else is stored in there when we reset.

    info: stbtt_fontinfo;
    stbtt_InitFont(*info, ttf_buffer.data, stbtt_GetFontOffsetForIndex(ttf_buffer.data, 0));

    result: Font;
    result.arena = arena;
    result.arena_mark = arena_mark;

    result.atlas = arena_push(*arena, INITIAL_WIDTH * INITIAL_HEIGHT, FONT_ATLAS_ALIGNMENT);
    result.atlas_width  = INITIAL_WIDTH;
    result.atlas_height = INITIAL_HEIGHT;

    result.vmetrics = get_font_vmetrics(info);
    result.scale = get_font_scale_for_pixel_height(info, FONT_PIXEL_HEIGHT);

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
// UPDATE: After watching Casey's refterm cache video
// (https://youtu.be/cGoQ3ceKX6g?si=aWlLDyDyHTFjrfMc), I think we could adapt his farsi (ligature?)
// code to support proportional fonts... by splitting the rasterized glyph into multiple slots in
// the atlas.
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
        gi := get_glyph_index(font.info, it);

        gbox := get_glyph_bitmap_box(font.info, gi, font.scale);
        gw   := gbox.x1 - gbox.x0;
        gh   := gbox.y1 - gbox.y0;

        print("%", gbox);

        rasterize_glyph(font.info, gi, font.atlas, gw, gh, font.atlas_width, font.scale);
        print("C: % % %\n", it, gi, get_glyph_hmetrics(font.info, gi));
    }

    return result;
}

#scope_file

get_font_vmetrics :: (info: stbtt_fontinfo) -> Font_VMetrics {
    result: Font_VMetrics = ---;
    stbtt_GetFontVMetrics(*info, *result.ascent, *result.descent, *result.line_gap);
    return result;
}

get_font_scale_for_pixel_height :: (info: stbtt_fontinfo, pixel_height: f32) -> f32 {
    return stbtt_ScaleForPixelHeight(*info, pixel_height);
}

get_glyph_index :: (info: stbtt_fontinfo, codepoint: u32) -> s32 {
    return stbtt_FindGlyphIndex(*info, cast,no_check(s32, codepoint));
}

get_glyph_hmetrics :: (info: stbtt_fontinfo, index: s32) -> Glyph_HMetrics {
    result: Glyph_HMetrics = ---;
    stbtt_GetGlyphHMetrics(*info, index, *result.advance, *result.left_side_bearing);
    return result;
}

get_glyph_bitmap_box :: (info: stbtt_fontinfo, index: s32, scale: f32) -> IRect {
    result: IRect = ---;
    stbtt_GetGlyphBitmapBox(*info, index, scale, scale, *result.x0, *result.y0, *result.x1, *result.y1);
    return result;
}

rasterize_glyph :: (info: stbtt_fontinfo, index: s32, out: *u8, out_width: s32, out_height: s32, out_stride: s32, scale: f32) {
    stbtt_MakeGlyphBitmap(*info, out, out_width, out_height, out_stride, scale, scale, index);
}

#import "stb_truetype";
