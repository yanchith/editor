// TODO(jt): Features:
//
// - [~] Basic text layout (in progress, might change)
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

FONT_PIXEL_HEIGHT : f32 : 30;

ATLAS_WIDTH_IN_CELLS  :: 32;
ATLAS_HEIGHT_IN_CELLS :: 32;

Font :: struct {
    arena: *Arena;
    arena_mark: Arena_Mark;

    texture_id: Texture_ID;

    // Font info stuff

    info: stbtt_fontinfo;

    font_vmetrics: Font_VMetrics;
    font_bounding_box: IRect;
    font_scale: f32;

    line_height_in_scaled_pixels: f32;
    max_glyph_width_in_scaled_pixels: f32;
    max_glyph_height_in_scaled_pixels: f32;
    max_glyph_width_in_scaled_integer_pixels: s32;
    max_glyph_height_in_scaled_integer_pixels: s32;

    // Glyph cache stuff

    glyph_atlas: [] u8;
    glyph_atlas_width: s32;
    glyph_atlas_height: s32;
    glyph_entries: [] Glyph_Entry;
    glyph_entries_head: s32;
    glyph_entries_tail: s32;
    // TODO(jt): @Speed @Memory Remove this hash table and do hashing over glyph_entries directly. We'll have to make the size of power of two, etc.
    glyph_table: Table(s32, s32);
    // This can overflow after about 200 days (if we rendered 60 frames every second), but we only
    // ever compare it for equality to detect same-frame evictions.
    glyph_cache_stamp: u32;

    frame_cache_hits: s64;
    frame_cache_misses: s64;
}

Font_VMetrics :: struct {
    // TODO(jt): In internal font units. If we are going to keep scaling this, maybe we should do it
    // only once and cache?
    ascent: s32;
    descent: s32;
    line_gap: s32;
}

Glyph_HMetrics :: struct {
    // TODO(jt): In internal font units. If we are going to keep scaling this, maybe we should do it
    // only once and cache?
    advance: s32;
    left_side_bearing: s32;
}

Glyph_Entry :: struct {
    stamp: u32;
    prev: s32;
    next: s32;

    glyph_index: s32; // So that we can remove it from the hash table.
}

// The caller should keep ttf_buffer alive. Easiest way is to put it in the passed in arena.
make_font :: (arena: *Arena, ttf_buffer: [] u8, texture_id: Texture_ID) -> Font {
    arena_mark := arena_get_mark(arena); // So that we don't hose whatever else is stored in there when we reset.

    info: stbtt_fontinfo;
    stbtt_InitFont(*info, ttf_buffer.data, stbtt_GetFontOffsetForIndex(ttf_buffer.data, 0));

    font: Font;
    font.arena      = arena;
    font.arena_mark = arena_mark;

    font.texture_id = texture_id;

    font.info = info;

    font.font_vmetrics     = get_font_vmetrics(info);
    font.font_bounding_box = get_font_bounding_box(info);
    font.font_scale        = get_font_scale_for_pixel_height(info, FONT_PIXEL_HEIGHT);

    font.line_height_in_scaled_pixels = font.font_scale * (font.font_vmetrics.ascent - font.font_vmetrics.descent + font.font_vmetrics.line_gap);
    font.max_glyph_width_in_scaled_pixels  = font.font_scale * cast(f32, font.font_bounding_box.x1 - font.font_bounding_box.x0);
    font.max_glyph_height_in_scaled_pixels = font.font_scale * cast(f32, font.font_bounding_box.y1 - font.font_bounding_box.y0);
    font.max_glyph_width_in_scaled_integer_pixels  = cast(s32, ceil(font.max_glyph_width_in_scaled_pixels));
    font.max_glyph_height_in_scaled_integer_pixels = cast(s32, ceil(font.max_glyph_height_in_scaled_pixels));

    atlas_width  := ATLAS_WIDTH_IN_CELLS * font.max_glyph_width_in_scaled_integer_pixels;
    atlas_height := ATLAS_HEIGHT_IN_CELLS * font.max_glyph_height_in_scaled_integer_pixels;
    table_size   := ATLAS_WIDTH_IN_CELLS * ATLAS_HEIGHT_IN_CELLS;

    font.glyph_atlas        = NewArray(atlas_width * atlas_height, u8,, arena_allocator(font.arena));
    font.glyph_atlas_width  = atlas_width;
    font.glyph_atlas_height = atlas_height;
    font.glyph_entries      = NewArray(table_size, Glyph_Entry,, arena_allocator(font.arena));
    font.glyph_table.allocator = arena_allocator(font.arena);

    table_ensure_space(*font.glyph_table, table_size);

    link_initial_glyph_entries(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail);

    return font;
}

font_layout_and_draw_text :: (font: *Font, text: string, render_rects: *[..] Render_Rect, update_regions: *[..] IRect, scroll: Vector2, is_new_frame := false) {
    ProfileZone("font_layout_and_draw_text");

    // TODO(jt): @Cleanup Consider having the user update the stamp manually?
    if is_new_frame {
        font.glyph_cache_stamp += 1;

        font.frame_cache_hits = 0;
        font.frame_cache_misses = 0;
    }

    // TODO(jt): @Cleanup Early exit to prevent utf8_iter accessing the first byte of a 0-length
    // string. Can remove after the fix is incorporated.
    if text.count == 0 {
        return;
    }

    cursor_x: f32 = 0;
    cursor_y: f32 = font.font_scale * font.font_vmetrics.ascent;

    for :Unicode.utf8_iter text {
        // TODO(jt): @Cleanup Factored this way, because utf8_iter does not support 'continue' (or I
        // used it incorrectly, or something).
        //
        // TODO(jt): Support all kinds of newlines.
        if it == #char "\n" {
            cursor_x = 0;
            cursor_y += font.font_scale * (font.font_vmetrics.line_gap + font.font_vmetrics.ascent - font.font_vmetrics.descent);
        } else {
            glyph_index   := get_glyph_index(font.info, it);
            glyph_metrics := get_glyph_hmetrics(font.info, glyph_index);

            // Already scaled from internal font units to pixels.
            glyph_bitmap_box    := get_glyph_bitmap_box(font.info, glyph_index, font.font_scale);
            glyph_bitmap_width  := glyph_bitmap_box.x1 - glyph_bitmap_box.x0;
            glyph_bitmap_height := glyph_bitmap_box.y1 - glyph_bitmap_box.y0;

            glyph_cell_x_in_atlas: s32;
            glyph_cell_y_in_atlas: s32;

            // TODO(jt): Factor out cache manipulation and just return the cell coordinates.
            entry_index_pointer := table_find_pointer(*font.glyph_table, glyph_index);
            if entry_index_pointer {
                font.frame_cache_hits += 1;

                entry_index := entry_index_pointer.*;
                entry := *font.glyph_entries[entry_index];
                assert(entry.glyph_index == glyph_index);

                // TODO(jt): Compute this with shifts, since the dimensions are a power of two.
                glyph_cell_x_in_atlas = entry_index % ATLAS_WIDTH_IN_CELLS;
                glyph_cell_y_in_atlas = entry_index / ATLAS_HEIGHT_IN_CELLS;

                entry.stamp = font.glyph_cache_stamp;

                move_back_glyph_entry(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail, entry_index);
            } else {
                font.frame_cache_misses += 1;

                entry_index := font.glyph_entries_head;
                entry := *font.glyph_entries[entry_index];

                // We can't overwrite an entry we wrote to this frame. We would be evicting something we
                // need this frame. If we really want to handle this case, we could flush our rendering
                // here and continue where we left of, but better to just have a larger cache.
                if entry.stamp == font.glyph_cache_stamp {
                    log_error("Glyph cache overwriting slot % during same layout. Rendering is going to look funny.", entry_index);
                }

                table_remove(*font.glyph_table, entry.glyph_index);

                entry.stamp = font.glyph_cache_stamp;
                entry.glyph_index = glyph_index;

                // TODO(jt): Compute this with shifts, since the dimensions are a power of two.
                glyph_cell_x_in_atlas = entry_index % ATLAS_WIDTH_IN_CELLS;
                glyph_cell_y_in_atlas = entry_index / ATLAS_HEIGHT_IN_CELLS;

                move_back_glyph_entry(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail, entry_index);
                assert(font.glyph_entries_tail == entry_index);

                dest := font.glyph_atlas.data +
                        font.glyph_atlas_width * glyph_cell_y_in_atlas * font.max_glyph_height_in_scaled_integer_pixels +
                        glyph_cell_x_in_atlas * font.max_glyph_width_in_scaled_integer_pixels;

                clear_glyph_cell(dest, font.max_glyph_width_in_scaled_integer_pixels, font.max_glyph_height_in_scaled_integer_pixels, font.glyph_atlas_width);

                // :SDF
                // sdf := get_glyph_sdf_bitmap(font.info, glyph_index, font.font_scale);
                // // XXX
                // // assert(sdf.width <= font.max_glyph_width_in_scaled_integer_pixels, "W % <= %", sdf.width, font.max_glyph_width_in_scaled_integer_pixels);
                // // assert(sdf.height <= font.max_glyph_height_in_scaled_integer_pixels, "H % <= %", sdf.height, font.max_glyph_height_in_scaled_integer_pixels);
                // if (sdf.data) {
                //     copy_glyph_cell(dest, font.max_glyph_width_in_scaled_integer_pixels, font.max_glyph_height_in_scaled_integer_pixels, font.glyph_atlas_width,
                //                     sdf.data, sdf.width, sdf.height);
                //     free_sdf_bitmap(*sdf);
                // }

                // XXX
                // :Rasterize
                rasterize_glyph(font.info, glyph_index,
                                dest, glyph_bitmap_width, glyph_bitmap_height,
                                font.glyph_atlas_width,
                                font.font_scale);
                table_add(*font.glyph_table, glyph_index, entry_index);

                array_add(
                    update_regions,
                    irect_from_point_and_size(
                        glyph_cell_x_in_atlas * font.max_glyph_width_in_scaled_integer_pixels,
                        glyph_cell_y_in_atlas * font.max_glyph_height_in_scaled_integer_pixels,
                        glyph_bitmap_width,
                        glyph_bitmap_height,
                    ),
                );
            }

            rr := array_add(render_rects);
            rr.rect = rect_from_point_and_size(
                cursor_x + glyph_bitmap_box.x0 - scroll.x,
                cursor_y + glyph_bitmap_box.y0 - scroll.y,
                cast(f32, glyph_bitmap_width),
                cast(f32, glyph_bitmap_height),
            );
            rr.texture_rect = rect_from_point_and_size(
                cast(f32, glyph_cell_x_in_atlas * font.max_glyph_width_in_scaled_integer_pixels) / font.glyph_atlas_width,
                cast(f32, glyph_cell_y_in_atlas * font.max_glyph_height_in_scaled_integer_pixels) / font.glyph_atlas_height,
                cast(f32, glyph_bitmap_width) / font.glyph_atlas_width,
                cast(f32, glyph_bitmap_height) / font.glyph_atlas_height,
            );
            rr.texture_id = font.texture_id;

            cursor_x += font.font_scale * glyph_metrics.advance;
        }
    }
}

font_compute_position_on_line :: (font: Font, line_text: string, character_index: s64) -> f64 {
    ProfileZone("font_compute_position_on_line");

    // TODO(jt): @Cleanup Early exit to prevent utf8_iter accessing the first byte of a 0-length
    // string. Can remove after the fix is incorporated.
    if line_text.count == 0 {
        return 0;
    }

    advance: s64 = 0; // In font integers. We scale at the end to avoid rounding errors.
    for :Unicode.utf8_iter line_text {
        if it_index >= character_index {
            break;
        }

        glyph_index   := get_glyph_index(font.info, it);
        glyph_metrics := get_glyph_hmetrics(font.info, glyph_index);

        advance += glyph_metrics.advance;
    }

    // Return f64, because in theory lines could be pretty long. We use f64s for absulute pixel coordinates in the editor.
    scaled_advance := advance * cast(f64, font.font_scale);

    return scaled_advance;
}

font_compute_character_index_on_line :: (font: Font, line_text: string, x: f64) -> s64 {
    ProfileZone("font_compute_character_index_on_line");

    // TODO(jt): @Cleanup Early exit to prevent utf8_iter accessing the first byte of a 0-length
    // string. Can remove after the fix is incorporated.
    if line_text.count == 0 {
        return 0;
    }

    character_index: s64 = 0;

    advance: s64 = 0; // In font integers. We scale at the end to avoid rounding errors.
    for :Unicode.utf8_iter line_text {
        // Return f64, because in theory lines could be pretty long. We use f64s for absulute pixel coordinates in the editor.
        scaled_advance := advance * cast(f64, font.font_scale);
        if scaled_advance >= x {
            break;
        }

        character_index = it_index;

        glyph_index   := get_glyph_index(font.info, it);
        glyph_metrics := get_glyph_hmetrics(font.info, glyph_index);

        advance += glyph_metrics.advance;
    }

    return character_index;
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
    if tail_index.* == index {
        // The entry already is at the tail.
        return;
    }

    entry := *entries[index];

    if head_index.* == index {
        head_index.* = entry.next;
    }

    if entry.prev >= 0  entries[entry.prev].next = entry.next;
    if entry.next >= 0  entries[entry.next].prev = entry.prev;

    entry.prev = tail_index.*;
    entry.next = -1;

    entries[tail_index.*].next = index;
    tail_index.* = index;
}

clear_glyph_cell :: (dest: *u8, width: s32, height: s32, stride: s32) {
    for y: 0..height - 1 {
        for x: 0..width - 1 {
            // TODO(jt): @Speed memset each row span?
            p := dest + y * stride + x;
            p.* = 0;
        }
    }
}

copy_glyph_cell :: (dest: *u8, dest_width: s32, dest_height: s32, dest_stride: s32, source: *u8, source_width: s32, source_height: s32) {
    for y: 0..min(dest_height, source_height) - 1 {
        for x: 0..min(dest_width, source_width) - 1 {
            // TODO(jt): @Speed memset each row span?
            dest_p   := dest + y * dest_stride + x;
            source_p := source + y * source_width + x;
            dest_p.* = source_p.*;
        }
    }
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

rasterize_glyph :: (info: stbtt_fontinfo, index: s32, dest: *u8, dest_width: s32, dest_height: s32, dest_stride: s32, scale: f32) {
    // TODO(jt): @Memory stbtt_MakeGlyphBitmap actually hits STBTT_malloc multiple times (in
    // stbtt_Rasterize, but also in stbtt_GetGlyphbitmapBox), so we should probably have a way to
    // set the allocator to temp?
    stbtt_MakeGlyphBitmap(*info, dest, dest_width, dest_height, dest_stride, scale, scale, index);
}

// stbtt does not give us a function where we make the memory, so instead we have to free this.
// TODO(jt): @Memory Fix this! We should be able to create this directly in target memory!
SDF_Bitmap :: struct {
    width: s32;
    height: s32;
    data: *u8;
    x_offset: s32;
    y_offset: s32;
}

SDF_ON_EDGE_VALUE    : u8  : 128;
SDF_PIXEL_DIST_SCALE : f32 : cast(f32, SDF_ON_EDGE_VALUE) / 2.0;

get_glyph_sdf_bitmap :: (info: stbtt_fontinfo, index: s32, scale: f32) -> SDF_Bitmap {
    result: SDF_Bitmap;
    result.data = stbtt_GetGlyphSDF(*info, scale, index, 0, SDF_ON_EDGE_VALUE, SDF_PIXEL_DIST_SCALE, *result.width, *result.height, *result.x_offset, *result.y_offset);

    log("XXX %", result);

    return result;
}

free_sdf_bitmap :: (b: *SDF_Bitmap) {
    stbtt_FreeSDF(b.data, null);
    b.data = null;
    b.width = 0;
    b.height = 0;
    b.x_offset = 0;
    b.y_offset = 0;
}

#import "stb_truetype"; // Move to scope exported scope, since the info field is visible anyway?
