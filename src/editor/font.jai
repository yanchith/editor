ATLAS_WIDTH_IN_PIXELS  :: 2048;
ATLAS_HEIGHT_IN_PIXELS :: 2048;

R64 : f32 : 1.0 / 64.0;

Font :: struct {
    //
    // "Inputs"
    //

    arena: *Arena;
    arena_mark: Arena_Mark;

    texture_id: Texture_ID;

    pixel_height: s32;

    //
    // Font info stuff. Does not change once we have loaded a font.
    //

    ft_library: FT_Library;
    ft_face:    FT_Face;

    //
    // Scaled metrics for currently set pixel_height in the FreeType 26:6 fixed-point format.
    //

    ascender: s64;
    descender: s64;
    line_height: s64;

    //
    // Scaled metrics for currently set pixel_height in floating point pixels.
    //

    line_height_in_pixels: f32;
    max_glyph_width_in_pixels: f32;
    max_glyph_height_in_pixels: f32;
    max_glyph_width_in_integer_pixels: s32;
    max_glyph_height_in_integer_pixels: s32;

    //
    // Glyph cache stuff
    //

    glyph_atlas: [] u8;
    glyph_atlas_cell_width_in_pixels: s32;
    glyph_atlas_cell_height_in_pixels: s32;
    glyph_atlas_width_in_cells: s32;
    glyph_atlas_height_in_cells: s32;
    glyph_atlas_width_in_pixels: s32;
    glyph_atlas_height_in_pixels: s32;

    glyph_entries: [] Glyph_Entry;
    glyph_entries_head: s32;
    glyph_entries_tail: s32;

    // TODO(jt): @Speed @Memory Remove this hash table and do hashing over glyph_entries
    // directly. We'll have to make the size a power of two, etc.
    glyph_table: Table(s32, s32);

    glyph_cache_stamp: u32; // This can overflow, but we only ever compare it for equality to detect same-frame evictions.
    glyph_cache_hits: s64;
    glyph_cache_misses: s64;
}

Glyph_Entry :: struct {
    stamp: u32;
    prev: s32;
    next: s32;

    glyph_index: s32; // So that we can remove it from the hash table.

    //
    // Metrics, metadata, anything that we know about the glyph.
    //
    // In the STBTT days, we didn't cache anything in here, but either I don't understand FreeType
    // very well, or it seems like even extracing these is a heavyweight operation that involves
    // actually rasterizing the glyph (or loading the bitmap, if present).

    glyph_advance: f32;          // TODO(jt): Store this in 26:6 fixed-point to preserve precision?
    glyph_offset_x: s32;
    glyph_offset_y: s32;
    glyph_bitmap_width: s32;
    glyph_bitmap_height: s32;
}

// The caller should keep ttf_buffer alive. Easiest way is to put it in the passed in arena.
make_font :: (arena: *Arena, ttf_buffer: [] u8, texture_id: Texture_ID, pixel_height: s32) -> Font {
    font: Font;
    font.arena        = arena;
    font.arena_mark   = arena_get_mark(arena); // So that we don't hose whatever else is stored in there when we reset.
    font.texture_id   = texture_id;
    // pixel_height assigned in font_reset_for_pixel_height.

    error: FT_Error;

    // TODO(jt): @Memory In C, there is a FT_New_Library that supports custom allocators. Can we use that?
    error = FT_Init_FreeType(*font.ft_library);
    if error {
        log_error("FreeType error when initializing the Library");
        return font;
    }

    error = FT_New_Memory_Face(font.ft_library, ttf_buffer.data, cast(s32, ttf_buffer.count), 0, *font.ft_face);
    if error {
        log_error("FreeType error when creating a new Face");
        return font;
    }

    font_reset_for_pixel_height(*font, pixel_height);

    return font;
}

font_reset_for_pixel_height :: (font: *Font, pixel_height: s32) {
    arena_pop_to_mark(font.arena, font.arena_mark);

    font.pixel_height = pixel_height;

    error: FT_Error;
    error = FT_Set_Pixel_Sizes(font.ft_face, 0, cast(u32, pixel_height));
    if error {
        log_error("FreeType error when setting pixel size");
        return;
    }


    font.ascender    = font.ft_face.size.metrics.ascender;
    font.descender   = font.ft_face.size.metrics.descender;
    font.line_height = font.ft_face.size.metrics.height;

    font.line_height_in_pixels = cast(f32, font.ft_face.size.metrics.height) * R64;
    font.max_glyph_width_in_pixels  = cast(f32, font.ft_face.size.metrics.max_advance) * R64;
    font.max_glyph_height_in_pixels = cast(f32, font.ft_face.size.metrics.height) * R64;
    font.max_glyph_width_in_integer_pixels  = cast(s32, ceil(font.max_glyph_width_in_pixels));
    font.max_glyph_height_in_integer_pixels = cast(s32, ceil(font.max_glyph_height_in_pixels));

    PADDING :: 2; // Because the atlas is bilinearly filtered, and we don't want to sample data from adjacent cells.
    atlas_cell_width_in_pixels  := font.max_glyph_width_in_integer_pixels + PADDING;
    atlas_cell_height_in_pixels := font.max_glyph_height_in_integer_pixels + PADDING;
    atlas_width_in_cells        := ATLAS_WIDTH_IN_PIXELS / atlas_cell_width_in_pixels;
    atlas_height_in_cells       := ATLAS_HEIGHT_IN_PIXELS / atlas_cell_height_in_pixels;
    table_size                  := atlas_width_in_cells * atlas_height_in_cells;

    assert(atlas_width_in_cells > 0);
    assert(atlas_height_in_cells > 0);
    assert(table_size > 0);

    log("Glyph cell is %x% pixels. Glyph atlas size is %x% cells (% table entries)", atlas_cell_width_in_pixels, atlas_cell_height_in_pixels, atlas_width_in_cells, atlas_height_in_cells, table_size);

    font.glyph_atlas                       = arena_push_array(font.arena, u8, ATLAS_WIDTH_IN_PIXELS * ATLAS_HEIGHT_IN_PIXELS);
    font.glyph_atlas_cell_width_in_pixels  = atlas_cell_width_in_pixels;
    font.glyph_atlas_cell_height_in_pixels = atlas_cell_height_in_pixels;
    font.glyph_atlas_width_in_cells        = atlas_width_in_cells;
    font.glyph_atlas_height_in_cells       = atlas_height_in_cells;
    font.glyph_atlas_width_in_pixels       = ATLAS_WIDTH_IN_PIXELS;
    font.glyph_atlas_height_in_pixels      = ATLAS_HEIGHT_IN_PIXELS;
    font.glyph_entries                     = arena_push_array(font.arena, Glyph_Entry, table_size);
    font.glyph_entries_head                = 0;
    font.glyph_entries_tail                = 0;

    glyph_table: Table(s32, s32);
    glyph_table.allocator = arena_allocator(font.arena);
    font.glyph_table = glyph_table;

    table_ensure_space(*font.glyph_table, table_size);

    font.glyph_cache_stamp = 0;

    font.glyph_cache_hits   = 0;
    font.glyph_cache_misses = 0;

    link_initial_glyph_entries(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail);
}

font_layout_and_draw_text :: (font: *Font, text: string, render_rects: *[..] Render_Rect, update_regions: *[..] IRect, scroll: Vector2, is_new_frame := false) {
    ProfileZone("font_layout_and_draw_text");

    if is_new_frame {
        #no_aoc {
            font.glyph_cache_stamp += 1;
        }

        font.glyph_cache_hits = 0;
        font.glyph_cache_misses = 0;
    }

    // TODO(jt): @Cleanup Early exit to prevent utf8_iter accessing the first byte of a 0-length
    // string. Can remove after the fix is incorporated.
    if text.count == 0 {
        return;
    }

    // TODO(jt): Compute in font units and convert to floats at the end.
    cursor_x: f32 = 0;
    cursor_y: f32 = cast(f32, font.ascender) * R64;

    // XXX: We had a note here saying that utf8_iter doesn't support 'continue', but we for sure DO
    // 'continue' quite a bit in this file. Find out! This could also be related to that infinite
    // loop thing.

    for :Unicode.utf8_iter text {
        // TODO(jt): Support all kinds of newlines. XXX We already do this elsewhere, so might as well fix it here!
        if it == #char "\n" {
            cursor_x = 0;
            cursor_y += font.line_height_in_pixels;
        } else {
            glyph_index := FT_Get_Char_Index(font.ft_face, it);
            if glyph_index == 0 {
                // TODO(jt): Replacement character!
                continue;
            }

            // These are filled in in one of the two branches below
            glyph_advance: f32;
            glyph_offset_x: s32;
            glyph_offset_y: s32;
            glyph_bitmap_width: s32;
            glyph_bitmap_height: s32;

            glyph_cell_x: s32;
            glyph_cell_y: s32;

            // TODO(jt): Factor out cache manipulation and just return the all necessary metadata.
            entry_index_pointer := table_find_pointer(*font.glyph_table, cast(s32, glyph_index));
            if entry_index_pointer {
                font.glyph_cache_hits += 1;

                entry_index := entry_index_pointer.*;
                entry := *font.glyph_entries[entry_index];
                sanity_assert(entry.glyph_index == cast(s32, glyph_index));

                entry.stamp = font.glyph_cache_stamp;

                glyph_advance       = entry.glyph_advance;
                glyph_offset_x      = entry.glyph_offset_x;
                glyph_offset_y      = entry.glyph_offset_y;
                glyph_bitmap_width  = entry.glyph_bitmap_width;
                glyph_bitmap_height = entry.glyph_bitmap_height;

                // TODO(jt): @Speed Compute this with bit operations, since the dimensions are a power of two.
                glyph_cell_x = entry_index % font.glyph_atlas_width_in_cells;
                glyph_cell_y = entry_index / font.glyph_atlas_width_in_cells;

                move_back_glyph_entry(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail, entry_index);
                sanity_assert(font.glyph_entries_tail == entry_index);
            } else {
                font.glyph_cache_misses += 1;

                entry_index := font.glyph_entries_head;
                entry := *font.glyph_entries[entry_index];

                // We can't overwrite an entry we wrote to this frame, as we would be evicting
                // something else we also wrote this frame that we need. If we want to handle this
                // case, we could flush our rendering here and continue where we left of, but better
                // to just have a larger cache.
                if entry.stamp == font.glyph_cache_stamp {
                    log_error("Glyph cache overwriting slot % during same layout. Rendering is going to look funny.", entry_index);
                }

                table_remove(*font.glyph_table, entry.glyph_index);

                entry.stamp = font.glyph_cache_stamp;
                entry.glyph_index = cast(s32, glyph_index);

                {
                    ProfileZone("FT_Load_GLyph(FT_LOAD_RENDER)"); // XXX: @Bug Not instrumented!
                    error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_RENDER);
                    if error {
                        // TODO(jt): Replacement character!
                        continue;
                    }
                }

                glyph         := font.ft_face.glyph; // unlike metrics and bitmap, glyph is a pointer
                glyph_metrics := *font.ft_face.glyph.metrics;
                glyph_bitmap  := *font.ft_face.glyph.bitmap;

                entry.glyph_advance       = cast(f32, glyph_metrics.horiAdvance) * R64;
                entry.glyph_offset_x      = glyph.bitmap_left;
                entry.glyph_offset_y      = -glyph.bitmap_top; // Vertical flip
                entry.glyph_bitmap_width  = cast(s32, glyph_bitmap.width);
                entry.glyph_bitmap_height = cast(s32, glyph_bitmap.rows);

                glyph_advance       = entry.glyph_advance;
                glyph_offset_x      = entry.glyph_offset_x;
                glyph_offset_y      = entry.glyph_offset_y;
                glyph_bitmap_width  = entry.glyph_bitmap_width;
                glyph_bitmap_height = entry.glyph_bitmap_height;

                // TODO(jt): @Speed Compute this with bit operations, since the dimensions are a power of two.
                glyph_cell_x = entry_index % font.glyph_atlas_width_in_cells;
                glyph_cell_y = entry_index / font.glyph_atlas_width_in_cells;

                dest := font.glyph_atlas.data +
                        font.glyph_atlas_width_in_pixels * glyph_cell_y * font.glyph_atlas_cell_height_in_pixels +
                        glyph_cell_x * font.glyph_atlas_cell_width_in_pixels;

                clear_glyph_cell(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels);
                copy_glyph_cell(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels,
                                glyph_bitmap.buffer, cast(s32, glyph_bitmap.width), cast(s32, glyph_bitmap.rows), cast(s32, glyph_bitmap.pitch));

                table_add(*font.glyph_table, cast(s32, glyph_index), entry_index);
                array_add(
                    update_regions,
                    irect_from_point_and_size(
                        glyph_cell_x * font.glyph_atlas_cell_width_in_pixels,
                        glyph_cell_y * font.glyph_atlas_cell_height_in_pixels,
                        glyph_bitmap_width,
                        glyph_bitmap_height,
                    ),
                );

                move_back_glyph_entry(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail, entry_index);
                sanity_assert(font.glyph_entries_tail == entry_index);
            }

            rr := array_add(render_rects);
            rr.rect = rect_from_point_and_size(
                cursor_x + glyph_offset_x - scroll.x,
                cursor_y + glyph_offset_y - scroll.y,
                cast(f32, glyph_bitmap_width),
                cast(f32, glyph_bitmap_height),
            );
            rr.texture_rect = rect_from_point_and_size(
                cast(f32, glyph_cell_x * font.glyph_atlas_cell_width_in_pixels) / font.glyph_atlas_width_in_pixels,
                cast(f32, glyph_cell_y * font.glyph_atlas_cell_height_in_pixels) / font.glyph_atlas_height_in_pixels,
                cast(f32, glyph_bitmap_width) / font.glyph_atlas_width_in_pixels,
                cast(f32, glyph_bitmap_height) / font.glyph_atlas_height_in_pixels,
            );
            rr.texture_id = font.texture_id;

            cursor_x += glyph_advance;
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

    advance: s64 = 0; // In FreeType's 26:6 fixed-point pixels.
    for :Unicode.utf8_iter line_text {
        if it_index >= character_index {
            break;
        }

        glyph_index := FT_Get_Char_Index(font.ft_face, it);
        if glyph_index == 0 {
            // TODO(jt): Replacement character! (?)
            continue;
        }

        // TODO(jt): @Speed In the STBTT days, getting glyph metrics basically amounted to loading
        // some offsets in the TTF file. FreeType seems to do much more work, but maybe we can
        // disable most of it with the FT_LOAD_ flags? Otherwise we might need to cache this.
        error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_DEFAULT);
        if error {
            // TODO(jt): Replacement character! (?)
            continue;
        }

        advance += font.ft_face.glyph.metrics.horiAdvance;
    }

    scaled_advance: f64 = cast(f64, advance) * R64;

    return scaled_advance;
}

// XXX: This can infinite-loop now!
font_compute_character_index_on_line :: (font: Font, line_text: string, x: f64) -> s64 {
    ProfileZone("font_compute_character_index_on_line");

    // TODO(jt): @Cleanup Early exit to prevent utf8_iter accessing the first byte of a 0-length
    // string. Can remove after the fix is incorporated.
    if line_text.count == 0 {
        return 0;
    }

    character_index: s64 = 0;

    advance: s64 = 0; // In FreeType's 26:6 fixed-point pixels.
    for :Unicode.utf8_iter line_text {
        scaled_advance: f64 = cast(f64, advance) * R64;
        if scaled_advance >= x {
            break;
        }

        character_index = it_index;

        glyph_index := FT_Get_Char_Index(font.ft_face, it);
        if glyph_index == 0 {
            // TODO(jt): Replacement character! (?)
            continue;
        }

        // TODO(jt): @Speed In the STBTT days, getting glyph metrics basically amounted to loading
        // some offsets in the TTF file. FreeType seems to do much more work, but maybe we can
        // disable most of it with the FT_LOAD_ flags? Otherwise we might need to cache this.
        error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_DEFAULT);
        if error {
            // TODO(jt): Replacement character! (?)
            continue;
        }

        advance += font.ft_face.glyph.metrics.horiAdvance;
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

clear_glyph_cell :: (dest: *u8, width: s32, height: s32, pitch: s32) {
    for y: 0..height - 1 {
        for x: 0..width - 1 {
            // TODO(jt): @Speed memset each row span?
            p := dest + y * pitch + x;
            p.* = 0;
        }
    }
}

copy_glyph_cell :: (dest: *u8, dest_width: s32, dest_height: s32, dest_pitch: s32, source: *u8, source_width: s32, source_height: s32, source_pitch: s32) {
    for y: 0..min(dest_height, source_height) - 1 {
        for x: 0..min(dest_width, source_width) - 1 {
            // TODO(jt): @Speed memset each row span?
            dest_p   := dest + y * dest_pitch + x;
            source_p := source + y * source_pitch + x;
            dest_p.* = source_p.*;
        }
    }
}

#import "freetype"; // Move to scope exported scope, since the info field is visible anyway?
