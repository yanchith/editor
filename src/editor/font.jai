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

FONT_PIXEL_HEIGHT: f32 = 12;

// TODO(jt): Turn this into a LRU cache for rasterized glyphs and their metrics of various sizes.
// However, if we use proportional fonts, we can't easily compute the cell size for a rasterized
// glyph, so we'd have to support multiple size classes at once. Even if we stick to monospace
// fonts, the user can change the size, but in this case at least we could drop the cache and start
// over in our nicely regular monospace world.
Font :: struct {
    arena: Arena;
    arena_mark: Arena_Mark;

    info: stbtt_fontinfo;

    font_vmetrics: Font_VMetrics;
    font_bounding_box: IRect;
    font_scale: f32;

    max_glyph_width: s32;
    max_glyph_height: s32;

    // Glyph cache stuff...
    glyph_atlas: *u8;
    glyph_atlas_width: s32;
    glyph_atlas_height: s32;
    glyph_entries: [] Glyph_Entry;
    glyph_entries_head: s32;
    glyph_entries_tail: s32;
    // TODO(jt): @Speed @Memory Remove this hash table and do hashing over glyph_entries directly. We'll have to make the size of power of two, etc.
    glyph_table: Table(s32, s32);
    glyph_cache_stamp: u32;       // This can overflow. We only ever compare it for equality to detect same-frame evictions.
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

Glyph_Entry :: struct {
    stamp: u32;
    prev: s32;
    next: s32;

    glyph_index: s32; // So that we can remove it from the hash table.
}

// The caller has to keep ttf_buffer alive. Easiest way is to put it in the passed in arena.
make_font :: (arena: Arena, ttf_buffer: [] u8) -> Font {
    ATLAS_WIDTH_IN_CELLS  :: 64;
    ATLAS_HEIGHT_IN_CELLS :: 64;

    arena_mark := arena_get_mark(arena); // So that we don't hose whatever else is stored in there when we reset.

    info: stbtt_fontinfo;
    stbtt_InitFont(*info, ttf_buffer.data, stbtt_GetFontOffsetForIndex(ttf_buffer.data, 0));

    font: Font;
    font.arena      = arena;
    font.arena_mark = arena_mark;

    font.info = info;

    font.font_vmetrics     = get_font_vmetrics(info);
    font.font_bounding_box = get_font_bounding_box(info);
    font.font_scale        = get_font_scale_for_pixel_height(info, FONT_PIXEL_HEIGHT);

    font.max_glyph_width  = font.font_bounding_box.x1 - font.font_bounding_box.x0;
    font.max_glyph_height = font.font_bounding_box.y1 - font.font_bounding_box.y0;

    atlas_width  := ATLAS_WIDTH_IN_CELLS * font.max_glyph_width;
    atlas_height := ATLAS_HEIGHT_IN_CELLS * font.max_glyph_height;
    table_size   := ATLAS_WIDTH_IN_CELLS * ATLAS_HEIGHT_IN_CELLS;

    font.glyph_atlas        = arena_push(*font.arena, atlas_width * atlas_height, FONT_ATLAS_ALIGNMENT);
    font.glyph_atlas_width  = atlas_width;
    font.glyph_atlas_height = atlas_height;
    font.glyph_entries      = NewArray(table_size, Glyph_Entry,, arena_allocator(*font.arena));
    font.glyph_table.allocator = arena_allocator(*font.arena);

    table_ensure_space(*font.glyph_table, table_size);

    link_initial_glyph_entries(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail);

    return font;
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

start_frame :: (font: *Font) {
    font.glyph_cache_stamp += 1;
}

layout_and_draw_text :: (font: *Font, font_size: f32, text: string) -> [..] Render_Rect, cache_hits: s64, cache_misses: s64 {
    result: [..] Render_Rect;
    cache_hits: s64;
    cache_misses: s64;

    for :Unicode.utf8_iter text {
        glyph_index := get_glyph_index(font.info, it);

        glyph_metrics := get_glyph_hmetrics(font.info, glyph_index);
        glyph_box     := get_glyph_bitmap_box(font.info, glyph_index, font.font_scale);

        glyph_width  := glyph_box.x1 - glyph_box.x0;
        glyph_height := glyph_box.y1 - glyph_box.y0;

        glyph_cell_x_in_atlas: s32;
        glyph_cell_y_in_atlas: s32;

        entry_index_pointer := table_find_pointer(*font.glyph_table, glyph_index);
        if entry_index_pointer {
            cache_hits += 1;

            entry_index := entry_index_pointer.*;
            entry := *font.glyph_entries[entry_index];
            assert(entry.glyph_index == glyph_index);

            // TODO(jt): Compute this with shifts, since the dimensions are a power of two.
            glyph_cell_x_in_atlas = entry_index % font.glyph_atlas_width;
            glyph_cell_y_in_atlas = entry_index / font.glyph_atlas_height;

            entry.stamp = font.glyph_cache_stamp;

            move_back_glyph_entry(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail, entry_index);
        } else {
            cache_misses += 1;

            entry_index := font.glyph_entries_head;
            entry := *font.glyph_entries[entry_index];

            // We can't overwrite an entry we wrote to this frame. We would be evicting something we
            // need this frame. If we really want to handle this case, we could flusb our rendering
            // here and continue where we left of, but better to just have a larger cache. Also, we
            // don't need to assert and can just log an error and overwrite.
            assert(entry.stamp != font.glyph_cache_stamp);

            table_remove(*font.glyph_table, entry.glyph_index);

            entry.stamp = font.glyph_cache_stamp;
            entry.glyph_index = glyph_index;

            // TODO(jt): Compute this with shifts, since the dimensions are a power of two.
            glyph_cell_x_in_atlas = entry_index % font.glyph_atlas_width;
            glyph_cell_y_in_atlas = entry_index / font.glyph_atlas_height;

            move_back_glyph_entry(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail, font.glyph_entries_head);

            out := font.glyph_atlas + font.glyph_atlas_width * glyph_cell_y_in_atlas * font.max_glyph_height + glyph_cell_x_in_atlas * font.max_glyph_width;
            // TODO(jt): This does not clear previous cell to zero, which we maybe should?
            rasterize_glyph(
                font.info,
                glyph_index,
                out,
                glyph_width,
                glyph_height,
                font.glyph_atlas_width,
                font.font_scale,
            );
        }
    }

    return result, cache_hits, cache_misses;
}

#scope_file

link_initial_glyph_entries :: (entries: [] Glyph_Entry, head_index: *s32, tail_index: *s32) {
    for * entries {
        it.prev = cast(s32, it_index - 1);
        it.next = cast(s32, it_index + 1);
    }
    entries[0].prev = -1;
    entries[entries.count - 1].next = -1;

    head_index.* = 0;
    tail_index.* = cast(s32, entries.count - 1);
}

move_back_glyph_entry :: (entries: [] Glyph_Entry, head_index: *s32, tail_index: *s32, index: s32) {
    entry := *entries[index];

    if head_index.* == index {
        head_index.* = entry.next;
    }

    if entry.prev >= 0 {
        entries[entry.prev].next = entry.next;
    }

    if entry.next >= 0 {
        entries[entry.next].prev = entry.prev;
    }

    entry.prev = tail_index.*;
    entry.next = -1;

    entries[tail_index.*].next = index;
}

get_font_vmetrics :: (info: stbtt_fontinfo) -> Font_VMetrics {
    result: Font_VMetrics = ---;
    stbtt_GetFontVMetrics(*info, *result.ascent, *result.descent, *result.line_gap);
    return result;
}

get_font_bounding_box :: (info: stbtt_fontinfo) -> IRect {
    result: IRect = ---;
    stbtt_GetFontBoundingBox(*info, *result.x0, *result.y0, *result.x1, *result.y1);
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

#import "stb_truetype"; // Move to scope exported scope, since the info field is visible anyway?
