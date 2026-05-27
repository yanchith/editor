#import "freetype";

FONT_SUBPIXEL :: false;

FONT_ATLAS_WIDTH_IN_PIXELS  :: 1024;
FONT_ATLAS_HEIGHT_IN_PIXELS :: 1024;

// TODO(jt): All procedures in this file should eventually handle tabs (basically by pretending it
// is N spaces). Currently, the editor just inserts spaces everywhere, so it is kind of fine, but we
// won't be able to do that forever.

Font :: struct {
    //
    // "Inputs"
    //

    arena: *Arena;
    arena_mark: Arena_Mark;

    texture_id: Texture_ID;

    // These options can be reset with reset_for_options.
    pixel_height: s32;

    //
    // Font info stuff. Does not change once we have loaded a font.
    //

    ft_library:     FT_Library;
    ft_face:        FT_Face;

    //
    // Scaled metrics for currently set pixel_height in the FreeType 26:6 fixed point format. (64-bit, because FT_Pos is 64-bit on Unix)
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

    glyph_atlas: [] PIXEL_TYPE;
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
    // very well, or it seems like even extracting at least some of these (except for advance) is a
    // heavyweight operation that involves actually rasterizing the glyph (or loading the bitmap
    // version, if present), so just in case, they are here.
    //

    glyph_advance: s32;        // In 26:6 pixels.
    glyph_offset_x: s32;       // In integer pixels.
    glyph_offset_y: s32;       // In integer pixels.
    glyph_bitmap_width: s32;   // In integer pixels.
    glyph_bitmap_height: s32;  // In integer pixels.
}

// The caller should keep ttf_buffer alive. Easiest way is to put it in the passed in arena. If the
// arena already stores some allocations, they won't be popped, but you should not use it after
// passing it to the font.
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

    #if FONT_SUBPIXEL {
        FT_Library_SetLcdFilter(font.ft_library, .DEFAULT);
    }

    error = FT_New_Memory_Face(font.ft_library, ttf_buffer.data, cast(s32, ttf_buffer.count), 0, *font.ft_face);
    if error {
        log_error("FreeType error when creating a new Face");
        return font;
    }

    font_reset_for_options(*font, pixel_height);

    return font;
}

// Reset all font structures for new options. Implies font_new_frame, so don't do this in the middle of the frame.
font_reset_for_options :: (font: *Font, pixel_height: s32) {
    arena_pop_to_mark(font.arena, font.arena_mark);


    error: FT_Error;
    error = FT_Set_Pixel_Sizes(font.ft_face, 0, cast(u32, pixel_height));
    if error {
        log_error("FreeType error when setting pixel size");
        return;
    }
    font.pixel_height = pixel_height;

    font.ascender    = font.ft_face.size.metrics.ascender;
    font.descender   = font.ft_face.size.metrics.descender;
    font.line_height = font.ft_face.size.metrics.height;

    font.line_height_in_pixels = cast(f32, font.ft_face.size.metrics.height) * R64;
    font.max_glyph_width_in_pixels  = cast(f32, font.ft_face.size.metrics.max_advance) * R64;
    font.max_glyph_height_in_pixels = cast(f32, font.ft_face.size.metrics.height) * R64;
    font.max_glyph_width_in_integer_pixels  = cast(s32, ceil(font.max_glyph_width_in_pixels));
    font.max_glyph_height_in_integer_pixels = cast(s32, ceil(font.max_glyph_height_in_pixels));

    // Because the atlas is bilinearly filtered, and we don't want to sample data from adjacent cells.
    PADDING :: 1;

    atlas_cell_width_in_pixels  := font.max_glyph_width_in_integer_pixels + PADDING;
    atlas_cell_height_in_pixels := font.max_glyph_height_in_integer_pixels + PADDING;
    atlas_width_in_cells        := FONT_ATLAS_WIDTH_IN_PIXELS / atlas_cell_width_in_pixels;
    atlas_height_in_cells       := FONT_ATLAS_HEIGHT_IN_PIXELS / atlas_cell_height_in_pixels;
    table_size                  := atlas_width_in_cells * atlas_height_in_cells;

    assert(atlas_width_in_cells > 0);
    assert(atlas_height_in_cells > 0);
    assert(table_size > 0);

    log(
        "Glyph atlas size is %x% cells (% entries), %x% pixels. Glyph cell is %x% pixels.",
        atlas_width_in_cells, atlas_height_in_cells, table_size,
        FONT_ATLAS_WIDTH_IN_PIXELS, FONT_ATLAS_HEIGHT_IN_PIXELS,
        atlas_cell_width_in_pixels, atlas_cell_height_in_pixels,
    );

    font.glyph_atlas                       = arena_push_array(font.arena, PIXEL_TYPE, FONT_ATLAS_WIDTH_IN_PIXELS * FONT_ATLAS_HEIGHT_IN_PIXELS);
    font.glyph_atlas_cell_width_in_pixels  = atlas_cell_width_in_pixels;
    font.glyph_atlas_cell_height_in_pixels = atlas_cell_height_in_pixels;
    font.glyph_atlas_width_in_cells        = atlas_width_in_cells;
    font.glyph_atlas_height_in_cells       = atlas_height_in_cells;
    font.glyph_atlas_width_in_pixels       = FONT_ATLAS_WIDTH_IN_PIXELS;
    font.glyph_atlas_height_in_pixels      = FONT_ATLAS_HEIGHT_IN_PIXELS;
    font.glyph_entries                     = arena_push_array(font.arena, Glyph_Entry, table_size);
    font.glyph_entries_head                = 0;
    font.glyph_entries_tail                = 0;

    glyph_table: Table(s32, s32);
    glyph_table.allocator = arena_allocator(font.arena);
    font.glyph_table = glyph_table;

    table_ensure_space(*font.glyph_table, table_size);

    // Set stamp to 1, because link_and_initialize sets the stamps of the entries to zero, and our
    // own warning would fire when doing layout and render.
    font.glyph_cache_stamp = 1;

    font.glyph_cache_hits   = 0;
    font.glyph_cache_misses = 0;

    link_and_initialize_glyph_entries(font.glyph_entries, *font.glyph_entries_head, *font.glyph_entries_tail);
}

// Tell the glyph cache it can safely evict stuff from last frame. If you forget to call this, the
// logged error will still most likely be a false positive, depending on the font height and the
// size of the atlas texture.
font_new_frame :: (font: *Font) {
    #no_aoc {
        font.glyph_cache_stamp += 1;
    }

    font.glyph_cache_hits = 0;
    font.glyph_cache_misses = 0;
}

font_layout_and_draw_text :: (font: *Font, text: string, render_rects: *[..] Render_Rect, update_regions: *[..] IRect, offset: DVector2, color: Vector4, binary: bool) {
    if binary {
        _font_layout_and_draw_text(font, text, render_rects, update_regions, offset, color, true);
    } else {
        _font_layout_and_draw_text(font, text, render_rects, update_regions, offset, color, false);
    }
}

_font_layout_and_draw_text :: (font: *Font, text: string, render_rects: *[..] Render_Rect, update_regions: *[..] IRect, offset: DVector2, color: Vector4, $binary: bool) {
    ProfileZone("font_layout_and_draw_text");

    // Cursors are in 26:6 pixels (64-bit, because on Unix, FT_Pos is 64-bit even if they only use 32 bits).
    cursor_x: s64 = 0;
    cursor_y: s64 = font.ascender;

    ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
    for :ITERATOR text {
        if it == #char "\n" {
            cursor_x = 0;
            cursor_y += font.line_height;
            continue;
        }

        #if binary {
            if it < 32 || it >= 127 {
                it = 0;
            }
        }

        if it == #char "\r" {
            continue; // Not rendered.
        }

        // FT_Get_Char_Index returns 0, if it can't find the character. 0 also automatically maps to
        // 'missing glyph' in FT_Load_Glyph.
        glyph_index := FT_Get_Char_Index(font.ft_face, it);

        // These get filled in one of the branches below. Either we compute them, or we get them from the cache.
        glyph_advance: s32;       // In 26:6 pixels.
        glyph_offset_x: s32;      // In integer pixels.
        glyph_offset_y: s32;      // In integer pixels.
        glyph_bitmap_width: s32;  // In integer pixels.
        glyph_bitmap_height: s32; // In integer pixels.

        glyph_cell_x: s32;
        glyph_cell_y: s32;

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

            // We can't overwrite an entry we wrote to this frame, as we would be evicting something
            // else we also wrote this frame that we need. If we want to handle this case, we could
            // flush our rendering here and continue where we left of, but better to just have a
            // larger cache, especially now that we call this routine from multiple places.
            if entry.stamp == font.glyph_cache_stamp {
                log_error("Overwriting glyph cache slot % during same frame. Rendering will be incorrect.", entry_index);
            }

            table_remove(*font.glyph_table, entry.glyph_index);

            entry.stamp = font.glyph_cache_stamp;
            entry.glyph_index = cast(s32, glyph_index);

            {
                ProfileZone("FT_Load_Glyph(FT_LOAD_RENDER)");
                error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_RENDER | cast(s32, FT_LOAD_TARGET));

                if error {
                    // Not sure we can do anything here. Perhaps we could set a per-frame error flag?
                    continue;
                }
            }

            glyph         := font.ft_face.glyph; // unlike metrics and bitmap, glyph is a pointer
            glyph_metrics := *font.ft_face.glyph.metrics;
            glyph_bitmap  := *font.ft_face.glyph.bitmap;

            // On Unix, FT_Pos is defined as s64, even if they only utilize only 32 bits.
            entry.glyph_advance       = cast(s32, glyph_metrics.horiAdvance);
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

            #if FONT_SUBPIXEL {
                clear_glyph_cell_subpixel(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels);
                copy_glyph_cell_subpixel(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels,
                                         glyph_bitmap.buffer, cast(s32, glyph_bitmap.width), cast(s32, glyph_bitmap.rows), cast(s32, glyph_bitmap.pitch));
            } else {
                clear_glyph_cell(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels);
                copy_glyph_cell(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels,
                                glyph_bitmap.buffer, cast(s32, glyph_bitmap.width), cast(s32, glyph_bitmap.rows), cast(s32, glyph_bitmap.pitch));
            }

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

        // Order of operations here is somewhat important. Cursor and offset can be big, so
        // we subtract those first, so that the small glyph offset doesn't get destroyed.
        rx := cast(f64, cursor_x) * R64 + offset.x + glyph_offset_x;
        ry := cast(f64, cursor_y) * R64 + offset.y + glyph_offset_y;

        rr := array_add(render_rects);
        rr.rect = rect_from_point_and_size(
            cast(f32, rx),
            cast(f32, ry),
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
        rr.color = color;

        cursor_x += glyph_advance;
    }
}

font_compute_position_on_line :: (font: Font, line_text: string, character_index: s64, binary: bool) -> f64 {
    if binary {
        return _font_compute_position_on_line(font, line_text, character_index, true);
    } else {
        return _font_compute_position_on_line(font, line_text, character_index, false);
    }
}

// TODO(jt): @Speed For files with long lines (such as minified javascript), this very very
// slow. We'll probably need to avoid calling it (or do early out, if position exceeds some given
// value), or have make 100x faster.
_font_compute_position_on_line :: (font: Font, line_text: string, character_index: s64, $binary: bool) -> f64 {
    ProfileZone("font_compute_position_on_line");
    advance: s64 = 0; // In FreeType's 26:6 fixed point pixels.

    ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
    for :ITERATOR line_text {
        if it_index >= character_index {
            break;
        }

        #if binary {
            if it < 32 || it >= 127 {
                it = 0;
            }
        }

        error := FT_Load_Char(font.ft_face, it, FT_LOAD_DEFAULT | cast(s32, FT_LOAD_TARGET));
        if error {
            // Not sure we can do anything here. Perhaps we could set a per-frame error flag?
            continue;
        }

        advance += font.ft_face.glyph.metrics.horiAdvance;
    }

    scaled_advance: f64 = cast(f64, advance) * R64;

    return scaled_advance;
}

font_compute_character_index_on_line :: (font: Font, line_text: string, x: f64, binary: bool) -> s64 {
    if binary {
        return _font_compute_character_index_on_line(font, line_text, x, true);
    } else {
        return _font_compute_character_index_on_line(font, line_text, x, false);
    }
}

_font_compute_character_index_on_line :: (font: Font, line_text: string, x: f64, $binary: bool) -> s64 {
    ProfileZone("font_compute_character_index_on_line");
    character_index: s64 = 0;
    advance: s64 = 0; // In FreeType's 26:6 fixed point pixels.

    ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
    for :ITERATOR line_text {
        scaled_advance: f64 = cast(f64, advance) * R64;
        if scaled_advance >= x {
            break;
        }

        character_index = it_index;

        #if binary {
            if it < 32 || it >= 127 {
                it = 0;
            }
        }

        error := FT_Load_Char(font.ft_face, it, FT_LOAD_DEFAULT | cast(s32, FT_LOAD_TARGET));
        if error {
            // Not sure we can do anything here. Perhaps we could set a per-frame error flag?
            continue;
        }

        advance += font.ft_face.glyph.metrics.horiAdvance;
    };

    return character_index;
}

#scope_file

link_and_initialize_glyph_entries :: (entries: [] Glyph_Entry, head_index: *s32, tail_index: *s32) {
    for * entries {
        it.stamp = 0;

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
    ProfileZone("clear_glyph_cell");
    for y: 0..height - 1 {
        for x: 0..width - 1 {
            p := dest + y * pitch + x;
            p.* = 0;
        }
    }
}

clear_glyph_cell_subpixel :: (dest: *u32, width: s32, height: s32, pitch: s32) {
    ProfileZone("clear_glyph_cell_subpixel");
    for y: 0..height - 1 {
        for x: 0..width - 1 {
            p := dest + y * pitch + x;
            p.* = 0;
        }
    }
}

copy_glyph_cell :: (dest: *u8, dest_width: s32, dest_height: s32, dest_pitch: s32, source: *u8, source_width: s32, source_height: s32, source_pitch: s32) {
    ProfileZone("copy_glyph_cell");
    for y: 0..min(dest_height, source_height) - 1 {
        for x: 0..min(dest_width, source_width) - 1 {
            dest_p   := dest + y * dest_pitch + x;
            source_p := source + y * source_pitch + x;
            dest_p.* = source_p.*;
        }
    }
}

copy_glyph_cell_subpixel :: (dest: *u32, dest_width: s32, dest_height: s32, dest_pitch: s32, source: *u8, source_width: s32, source_height: s32, source_pitch: s32) {
    ProfileZone("copy_glyph_cell");
    for y: 0..min(dest_height, source_height) - 1 {
        for x: 0..min(dest_width, source_width) - 1 {
            dest_p   := dest + y * dest_pitch + x;
            source_p := source + y * source_pitch + x * 3;

            r: u8 = (source_p + 0).*;
            g: u8 = (source_p + 1).*;
            b: u8 = (source_p + 2).*;
            a: u8 = 255;

            c: u32 = (cast(u32, r) << 24) | (cast(u32, g) << 16) | (cast(u32, b) << 8) | a;

            dest_p.* = c;
        }
    }
}

#if FONT_SUBPIXEL {
    FT_LOAD_TARGET :: FT_Load_Target.LCD;
    PIXEL_TYPE     :: u32;
} else {
    FT_LOAD_TARGET :: FT_Load_Target.NORMAL;
    PIXEL_TYPE     :: u8;
}

R64: f32 : 1.0 / 64.0;
