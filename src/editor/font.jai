#import "freetype";

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
    line_height_multiplier: f32;

    //
    // Font info stuff. Does not change once we have loaded a font.
    //

    ft_library:              FT_Library;
    ft_face_for_regular:     FT_Face;
    ft_face_for_bold:        FT_Face;
    ft_face_for_italic:      FT_Face;
    ft_face_for_bold_italic: FT_Face;

    //
    // Scaled metrics for currently set pixel_height in the FreeType 26:6 fixed point format. (64-bit, because FT_Pos is 64-bit on Unix)
    //

    ascender: s64;
    descender: s64;
    line_height: s64; // line_height_multiplier not applied.

    //
    // Scaled metrics for currently set pixel_height in pixels.
    //

    line_height_in_pixels: f32; // line_height_multiplier applied.
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
    glyph_table: Table(u64, s32);

    glyph_cache_stamp: u32; // This can overflow, but we only ever compare it for equality to detect same-frame evictions.
    glyph_cache_hits: s64;
    glyph_cache_misses: s64;
    glyph_cache_overrun: bool;
}

Glyph_Entry :: struct {
    stamp: u32;
    prev: s32;
    next: s32;

    // The key, so that we can remove the from the hash table.
    glyph_index: u32;
    glyph_variant: Font_Variant;

    //
    // Metrics, metadata, anything that we know about the glyph.
    //
    // In the STBTT days, we didn't cache anything in here, but either I don't understand FreeType
    // very well, or it seems like even extracting at least some of these (except for advance) is a
    // heavyweight operation that involves actually rasterizing the glyph (or loading the bitmap
    // version, if present), so just in case, they are here.
    //

    // hole: u32
    glyph_advance: s64;        // In 26:6 pixels.
    glyph_offset_x: s32;       // In integer pixels.
    glyph_offset_y: s32;       // In integer pixels.
    glyph_bitmap_width: s32;   // In integer pixels.
    glyph_bitmap_height: s32;  // In integer pixels.
}

// The regular ttf buffer is mandatory, the rest can be an empty arrays. The caller should keep the
// ttf buffers alive. Easiest way is to put them in the passed in arena. If the arena already stores
// some allocations, they won't be popped, but you should not use it after passing it to the font.
//
// TOOD(jt): Also be able to load font variants from a font collection.
make_font :: (arena: *Arena, ttf_regular: [] u8, ttf_bold: [] u8, ttf_italic: [] u8, ttf_bold_italic: [] u8, texture_id: Texture_ID, pixel_height: s32, line_height_multiplier: f32) -> Font {
    font: Font;
    font.arena      = arena;
    font.arena_mark = arena_get_mark(arena); // So that we don't hose whatever else is stored in there when we reset.
    font.texture_id = texture_id;
    // pixel_height assigned in font_reset_for_options.

    error: FT_Error;

    // TODO(jt): @Memory In C, there is a FT_New_Library that supports custom allocators. Can we use that?
    error = FT_Init_FreeType(*font.ft_library);
    if error {
        log_error("FreeType error when initializing the Library");
        return font;
    }

    #if SUBPIXEL {
        FT_Library_SetLcdFilter(font.ft_library, .DEFAULT);
    }

    error = FT_New_Memory_Face(font.ft_library, ttf_regular.data, cast(s32, ttf_regular.count), 0, *font.ft_face_for_regular);
    if error {
        log_error("FreeType error when creating a new face from the regular ttf buffer");
        return font;
    }

    if ttf_bold.count {
        error = FT_New_Memory_Face(font.ft_library, ttf_bold.data, cast(s32, ttf_bold.count), 0, *font.ft_face_for_bold);
        if error {
            log_error("FreeType error when creating a new face from the bold ttf buffer. Will default to regular.");
        }
    }

    if ttf_italic.count {
        error = FT_New_Memory_Face(font.ft_library, ttf_italic.data, cast(s32, ttf_italic.count), 0, *font.ft_face_for_italic);
        if error {
            log_error("FreeType error when creating a new face from the italic ttf buffer. Will default to regular.");
        }
    }

    if ttf_bold_italic.count {
        error = FT_New_Memory_Face(font.ft_library, ttf_bold_italic.data, cast(s32, ttf_bold_italic.count), 0, *font.ft_face_for_bold_italic);
        if error {
            log_error("FreeType error when creating a new face from the bold_italic ttf buffer, Will default to regular.");
        }
    }

    font_reset_for_options(*font, pixel_height, line_height_multiplier);

    return font;
}

// Reset all font structures for new options. Implies font_new_frame, so don't do this in the middle of the frame.
font_reset_for_options :: (font: *Font, pixel_height: s32, line_height_multiplier: f32) {
    arena_pop_to_mark(font.arena, font.arena_mark);

    error: FT_Error;
    error = FT_Set_Pixel_Sizes(font.ft_face_for_regular, 0, cast(u32, pixel_height));
    if error {
        log_error("FreeType error when setting pixel size to the regular face");
        return;
    }

    if font.ft_face_for_bold != null {
        error = FT_Set_Pixel_Sizes(font.ft_face_for_bold, 0, cast(u32, pixel_height));
        if error {
            log_error("FreeType error when setting pixel size to the bold face");
            return;
        }
    }

    if font.ft_face_for_italic != null {
        error = FT_Set_Pixel_Sizes(font.ft_face_for_italic, 0, cast(u32, pixel_height));
        if error {
            log_error("FreeType error when setting pixel size to the italic face");
            return;
        }
    }


    if font.ft_face_for_bold_italic != null {
        error = FT_Set_Pixel_Sizes(font.ft_face_for_bold_italic, 0, cast(u32, pixel_height));
        if error {
            log_error("FreeType error when setting pixel size to the bold_italic face");
            return;
        }
    }

    font.pixel_height           = pixel_height;
    font.line_height_multiplier = line_height_multiplier;

    font.ascender    = font.ft_face_for_regular.size.metrics.ascender;
    font.descender   = font.ft_face_for_regular.size.metrics.descender;
    font.line_height = font.ft_face_for_regular.size.metrics.height;

    font.line_height_in_pixels = cast(f32, font.ft_face_for_regular.size.metrics.height) * R64 * line_height_multiplier;
    font.max_glyph_width_in_pixels  = cast(f32, font.ft_face_for_regular.size.metrics.max_advance) * R64;
    font.max_glyph_height_in_pixels = cast(f32, font.ft_face_for_regular.size.metrics.height) * R64;
    font.max_glyph_width_in_integer_pixels  = cast(s32, ceil(font.max_glyph_width_in_pixels));
    font.max_glyph_height_in_integer_pixels = cast(s32, ceil(font.max_glyph_height_in_pixels));

    // Because the atlas is bilinearly filtered, and we don't want to sample data from adjacent
    // cells. Also, asserts in copy_glyph_cell required us to increase the PADDING to 2, and asserts
    // in copy_glyph_cell_subpixel to 4.
    PADDING :: 4;

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

    glyph_table: Table(u64, s32);
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
    font.glyph_cache_overrun = false;
}

Font_Variant :: enum u32 {
    REGULAR :: 0;
    BOLD    :: 1;
    ITALIC  :: 2;
    BOLD_ITALIC :: 3;
}

Font_Style_Range :: struct {
    x0: s64;
    y0: s64;
    x1: s64; // Inclusive! The range would not exist, if it would be empty!
    y1: s64; // Inclusive! The range would not exist, if it would be empty!
    color: Vector4;
    variant: Font_Variant;
}

font_layout_and_draw_text :: (font: *Font, text: string, render_commands: *[..] Render_Command, atlas_update_regions: *[..] IRect, offset: DVector2, scissor_rect: Rect, default_color: Vector4, style_ranges: [] Font_Style_Range, binary: bool) {
    if binary {
        _font_layout_and_draw_text(font, text, render_commands, atlas_update_regions, offset, scissor_rect, default_color, style_ranges, true);
    } else {
        _font_layout_and_draw_text(font, text, render_commands, atlas_update_regions, offset, scissor_rect, default_color, style_ranges, false);
    }
}

_font_layout_and_draw_text :: (font: *Font, text: string, render_commands: *[..] Render_Command, atlas_update_regions: *[..] IRect, offset: DVector2, scissor_rect: Rect, default_color: Vector4, style_ranges: [] Font_Style_Range, $binary: bool) {
    ProfileZone("font_layout_and_draw_text");

    style_range_index: s64 = -1;
    if style_ranges.count {
        style_range_index = 0;
    }

    // Cursors are in 26:6 pixels (64-bit, because on Unix, FT_Pos is 64-bit even if they only use 32 bits).
    cursor_x: s64 = 0;
    cursor_y: s64 = font.ascender;

    current_line_index: s64 = 0;
    current_char_index: s64 = 0;

    ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
    for :ITERATOR text {
        if it == #char "\n" {
            cursor_x = 0;
            cursor_y += font.line_height;
            current_char_index = 0;
            current_line_index += 1;

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

        glyph_color   := default_color;
        glyph_variant := Font_Variant.REGULAR;
        if style_range_index != -1 {
            // Seek towards next token, if we are past the current one.
            past_vertically   := current_line_index > style_ranges[style_range_index].y1;
            past_horizontally := current_line_index == style_ranges[style_range_index].y1 && current_char_index > style_ranges[style_range_index].x1;
            while style_range_index != -1 && (past_vertically || past_horizontally) {
                style_range_index += 1;
                if style_range_index >= style_ranges.count {
                    style_range_index = -1;
                } else {
                    past_vertically   = current_line_index > style_ranges[style_range_index].y1;
                    past_horizontally = current_line_index == style_ranges[style_range_index].y1 && current_char_index > style_ranges[style_range_index].x1;
                }
            }

            if style_range_index != -1 {
                style_range := *style_ranges[style_range_index];
                if current_line_index > style_range.y0 && current_line_index < style_range.y1 {
                    glyph_color   = style_range.color;
                    glyph_variant = style_range.variant;
                } else if current_line_index == style_range.y0 && current_line_index == style_range.y1 {
                    if current_char_index >= style_range.x0 && current_char_index <= style_range.x1 {
                        glyph_color   = style_range.color;
                        glyph_variant = style_range.variant;
                    }
                } else if current_line_index == style_range.y0 {
                    if current_char_index >= style_range.x0 {
                        glyph_color   = style_range.color;
                        glyph_variant = style_range.variant;
                    }
                } else if current_line_index == style_range.y1 {
                    if current_char_index <= style_range.x1 {
                        glyph_color   = style_range.color;
                        glyph_variant = style_range.variant;
                    }
                }
            }
        }

        // @Hack In this routine, we extract metrics based on the weight/style of the character. In
        // the font_compute_xyz we always get metrics from the regular variant of the font. This is
        // probably okay, unless the font is inconsistent or badly authored, but I assume this would
        // be rare for popular fonts.
        ft_face: FT_Face;
        if #complete glyph_variant == {
            case .REGULAR;      ft_face = font.ft_face_for_regular;
            case .BOLD;         ft_face = ifx font.ft_face_for_bold        then font.ft_face_for_bold else font.ft_face_for_regular;
            case .ITALIC;       ft_face = ifx font.ft_face_for_italic      then font.ft_face_for_italic else font.ft_face_for_regular;
            case .BOLD_ITALIC;  ft_face = ifx font.ft_face_for_bold_italic then font.ft_face_for_bold_italic else font.ft_face_for_regular;
        }

        // FT_Get_Char_Index returns 0, if it can't find the character. 0 also automatically maps to
        // 'missing glyph' in FT_Load_Glyph.
        glyph_index := FT_Get_Char_Index(ft_face, it);

        // These get filled in one of the branches below. Either we compute them, or we get them from the cache.
        glyph_advance: s64;       // In 26:6 pixels.
        glyph_offset_x: s32;      // In integer pixels.
        glyph_offset_y: s32;      // In integer pixels.
        glyph_bitmap_width: s32;  // In integer pixels.
        glyph_bitmap_height: s32; // In integer pixels.

        glyph_cell_x: s32;
        glyph_cell_y: s32;

        entry_index_pointer := table_find_pointer(*font.glyph_table, compose_key(glyph_index, glyph_variant));
        if entry_index_pointer {
            font.glyph_cache_hits += 1;

            entry_index := entry_index_pointer.*;
            entry := *font.glyph_entries[entry_index];

            sanity_assert(entry.glyph_index == glyph_index);
            sanity_assert(entry.glyph_variant == glyph_variant);

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

            // We shouldn't overwrite an entry we wrote to this frame, as we would be evicting
            // something else we also wrote this frame that we need. For now, we just flag this, but
            // if we wanted to, we could flush the pipeline and continue from there, but maybe it's
            // just easier to have a larger cache.
            if entry.stamp == font.glyph_cache_stamp {
                font.glyph_cache_overrun = true;
            }

            table_remove(*font.glyph_table, compose_key(entry.glyph_index, entry.glyph_variant));

            entry.stamp = font.glyph_cache_stamp;
            entry.glyph_index   = glyph_index;
            entry.glyph_variant = glyph_variant;

            {
                ProfileZone("FT_Load_Glyph(FT_LOAD_RENDER)");
                error := FT_Load_Glyph(ft_face, glyph_index, FT_LOAD_RENDER | cast(s32, FT_LOAD_TARGET));

                if error {
                    // Perhaps we could set a per-frame error flag?
                    continue;
                }
            }

            glyph         := ft_face.glyph; // unlike metrics and bitmap, glyph is a pointer
            glyph_metrics := *ft_face.glyph.metrics;
            glyph_bitmap  := *ft_face.glyph.bitmap;

            // On Unix, FT_Pos is defined as s64, even if they only utilize only 32 bits. This is
            // probably some C long long thing.
            entry.glyph_advance       = glyph_metrics.horiAdvance;
            entry.glyph_offset_x      = glyph.bitmap_left;
            entry.glyph_offset_y      = -glyph.bitmap_top; // Vertical flip
            entry.glyph_bitmap_width  = cast(s32, glyph_bitmap.width);
            entry.glyph_bitmap_height = cast(s32, glyph_bitmap.rows);

            // :SubpixelDivideByThree
            //
            // Freetype automatically adjusts almost all relevant glyph metrics for subpixel
            // rendering, but it leaves the bitmap width as its actual thing. The bitmap is RGB (24
            // bits per pixel) coverages. To get the number of pixels, we divide by three. This is
            // important, because we derive all sorts of things from it (sizes of update regions,
            // texture coordinates, ...).
            #if SUBPIXEL {
                entry.glyph_bitmap_width /= 3;
            }

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

            #if SUBPIXEL {
                assert(glyph_bitmap.pixel_mode == cast(u8, FT_Pixel_Mode.LCD), "Pixel mode is: %", glyph_bitmap.pixel_mode);
                clear_glyph_cell_subpixel(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels);
                copy_glyph_cell_subpixel(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels,
                                         glyph_bitmap.buffer, cast(s32, glyph_bitmap.width), cast(s32, glyph_bitmap.rows), cast(s32, glyph_bitmap.pitch));
            } else {
                clear_glyph_cell(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels);
                copy_glyph_cell(dest, font.glyph_atlas_cell_width_in_pixels, font.glyph_atlas_cell_height_in_pixels, font.glyph_atlas_width_in_pixels,
                                glyph_bitmap.buffer, cast(s32, glyph_bitmap.width), cast(s32, glyph_bitmap.rows), cast(s32, glyph_bitmap.pitch));
            }

            table_add(*font.glyph_table, compose_key(glyph_index, glyph_variant), entry_index);
            array_add(
                atlas_update_regions,
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

        // Order of operations here is to make sure we are in f64 before converting to local coordinates.
        // We round after multiplying with line_height_multiplier, so we make sure we don't destroy whole-pixel snapping,
        // if the caller is aligned to pixels.
        rx := cast(f64, cursor_x) * R64 + offset.x + glyph_offset_x;
        ry := round(cast(f64, cursor_y) * R64 * font.line_height_multiplier) + offset.y + glyph_offset_y;

        r := rect_from_point_and_size(
            cast(f32, rx),
            cast(f32, ry),
            cast(f32, glyph_bitmap_width),
            cast(f32, glyph_bitmap_height),
        );

        // TODO(jt): @Speed We do horizontal culling here, but we could have saved more work, had we
        // done it sooner. We do need to load the glyph, but we definitely don't need to rasterize
        // it if ends up being discarded anyway.
        if rect_intersects_rect(scissor_rect, r) {
            command := array_add(render_commands);
            command.type = .DRAW_RECT;
            command.rect = r;
            command.texture_rect = rect_from_point_and_size(
                cast(f32, glyph_cell_x * font.glyph_atlas_cell_width_in_pixels) / font.glyph_atlas_width_in_pixels,
                cast(f32, glyph_cell_y * font.glyph_atlas_cell_height_in_pixels) / font.glyph_atlas_height_in_pixels,
                cast(f32, glyph_bitmap_width) / font.glyph_atlas_width_in_pixels,
                cast(f32, glyph_bitmap_height) / font.glyph_atlas_height_in_pixels,
            );
            command.texture_id = font.texture_id;
            command.color = glyph_color;
        }

        cursor_x += glyph_advance;
        current_char_index += 1;
    }
}

font_compute_line_length :: (font: Font, line_text: string, binary: bool) -> f64 {
    if binary {
        return _font_compute_line_length(font, line_text, true);
    } else {
        return _font_compute_line_length(font, line_text, false);
    }
}

_font_compute_line_length :: (font: Font, line_text: string, $binary: bool) -> f64 {
    ProfileZone("font_compute_line_length");
    advance: s64 = 0; // In FreeType's 26:6 fixed point pixels.

    ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
    for :ITERATOR line_text {
        #if binary {
            if it < 32 || it >= 127 {
                it = 0;
            }
        } else {
            // This is here for consistent selection rendering: we want to highlight the place occupied by the newline.
            if it == #char "\n" {
                it = #char " ";
            }
        }

        error := FT_Load_Char(font.ft_face_for_regular, it, FT_LOAD_DEFAULT | cast(s32, FT_LOAD_TARGET));
        if error {
            // Perhaps we could set a per-frame error flag?
            continue;
        }

        advance += font.ft_face_for_regular.glyph.metrics.horiAdvance;
    }

    scaled_advance: f64 = cast(f64, advance) * R64;

    return scaled_advance;
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
        } else {
            // This is here for consistent selection rendering: we want to highlight the place occupied by the newline.
            if it == #char "\n" {
                it = #char " ";
            }
        }

        error := FT_Load_Char(font.ft_face_for_regular, it, FT_LOAD_DEFAULT | cast(s32, FT_LOAD_TARGET));
        if error {
            // Perhaps we could set a per-frame error flag?
            continue;
        }

        advance += font.ft_face_for_regular.glyph.metrics.horiAdvance;
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
        } else {
            // This is here for consistent selection rendering: we want to highlight the place occupied by the newline.
            if it == #char "\n" {
                it = #char " ";
            }
        }

        error := FT_Load_Char(font.ft_face_for_regular, it, FT_LOAD_DEFAULT | cast(s32, FT_LOAD_TARGET));
        if error {
            // Perhaps we could set a per-frame error flag?
            continue;
        }

        advance += font.ft_face_for_regular.glyph.metrics.horiAdvance;
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

compose_key :: inline (glyph_index: u32, glyph_variant: Font_Variant) -> u64 {
    return (cast(u64, glyph_index) << 32) | cast(u64, glyph_variant);
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

    sanity_assert(dest_width >= source_width, "source_width (%) does not fit in dest_width (%)", source_width, dest_width);
    sanity_assert(dest_height >= source_height, "source_height (%) does not fit in dest_height (%)", source_height, dest_height);
    w := min(dest_width, source_width);
    h := min(dest_height, source_height);
    for y: 0..h - 1 {
        for x: 0..w - 1 {
            dest_p   := dest + y * dest_pitch + x;
            source_p := source + y * source_pitch + x;
            dest_p.* = source_p.*;
        }
    }
}

copy_glyph_cell_subpixel :: (dest: *u32, dest_width: s32, dest_height: s32, dest_pitch: s32, source: *u8, source_width: s32, source_height: s32, source_pitch: s32) {
    ProfileZone("copy_glyph_cell_subpixel");

    // See :SubpixelDivideByThree.
    sanity_assert(dest_width >= source_width / 3, "source_width/3 (%) does not fit in dest_width (%)", source_width / 3, dest_width);
    sanity_assert(dest_height >= source_height, "source_height (%) does not fit in dest_height (%)", source_height, dest_height);
    w := min(dest_width, source_width / 3);
    h := min(dest_height, source_height);
    for y: 0..h - 1 {
        for x: 0..w - 1 {
            dest_p   := dest + y * dest_pitch + x;
            source_p := source + y * source_pitch + x * 3;

            rgba: [4] u8;
            rgba[0] = (source_p + 0).*;
            rgba[1] = (source_p + 1).*;
            rgba[2] = (source_p + 2).*;
            rgba[3] = 255; // Not used for the subpixel stuff, but potentially useful for debug rendering.

            dest_p.* = cast(*u32, *rgba).*;
        }
    }
}

#if SUBPIXEL {
    FT_LOAD_TARGET :: FT_Load_Target.LCD;
    PIXEL_TYPE     :: u32;
} else {
    FT_LOAD_TARGET :: FT_Load_Target.NORMAL;
    PIXEL_TYPE     :: u8;
}

R64: f32 : 1.0 / 64.0;
