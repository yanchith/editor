// TODO(jt): Compute dynamically to fill screen.
ATLAS_WIDTH_IN_CELLS  :: 16;
ATLAS_HEIGHT_IN_CELLS :: 16;

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

    // These metrics are in font units.
    font_bounding_box: IRect;
    font_ascender:     s32;
    font_descender:    s32;
    font_line_height:  s32;

    //
    // Scaled metrics for currently set pixel_height
    //

    scale_from_font_units_to_pixels: f32;
    line_height_in_pixels: f32;
    max_glyph_width_in_pixels: f32;
    max_glyph_height_in_pixels: f32;
    max_glyph_width_in_integer_pixels: s32;
    max_glyph_height_in_integer_pixels: s32;

    //
    // Glyph cache stuff
    //

    glyph_atlas: [] u8;
    glyph_atlas_cell_width: s32;
    glyph_atlas_cell_height: s32;
    glyph_atlas_width: s32;
    glyph_atlas_height: s32;

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

    glyph_advance: f32;          // TODO(jt): Store this in font units to preserve precision?
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

    // NOTE(jt): bbox is s64 on macOS and s32 on Windows, so we just always cast.
    font.font_bounding_box.x0 = cast(s32, font.ft_face.bbox.xMin);
    font.font_bounding_box.y0 = cast(s32, font.ft_face.bbox.yMin);
    font.font_bounding_box.x1 = cast(s32, font.ft_face.bbox.xMax);
    font.font_bounding_box.y1 = cast(s32, font.ft_face.bbox.yMax);
    font.font_ascender    = font.ft_face.ascender;
    font.font_descender   = font.ft_face.descender;
    font.font_line_height = font.ft_face.height; // XXX: STB had line_gap here... is this gap or height?

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

    scale := cast(f32, pixel_height) / (font.font_ascender - font.font_descender);

    font.scale_from_font_units_to_pixels = scale;
    font.line_height_in_pixels = scale * (font.font_ascender - font.font_descender + font.font_line_height);
    font.max_glyph_width_in_pixels  = scale * cast(f32, font.font_bounding_box.x1 - font.font_bounding_box.x0);
    font.max_glyph_height_in_pixels = scale * cast(f32, font.font_bounding_box.y1 - font.font_bounding_box.y0);
    font.max_glyph_width_in_integer_pixels  = cast(s32, ceil(font.max_glyph_width_in_pixels));
    font.max_glyph_height_in_integer_pixels = cast(s32, ceil(font.max_glyph_height_in_pixels));

    atlas_cell_width  := font.max_glyph_width_in_integer_pixels;
    atlas_cell_height := font.max_glyph_height_in_integer_pixels;
    atlas_width       := ATLAS_WIDTH_IN_CELLS * atlas_cell_width;
    atlas_height      := ATLAS_HEIGHT_IN_CELLS * atlas_cell_height;
    table_size        := ATLAS_WIDTH_IN_CELLS * ATLAS_HEIGHT_IN_CELLS;

    font.glyph_atlas             = arena_push_array(font.arena, u8, atlas_width * atlas_height);
    font.glyph_atlas_cell_width  = atlas_cell_width;
    font.glyph_atlas_cell_height = atlas_cell_height;
    font.glyph_atlas_width       = atlas_width;
    font.glyph_atlas_height      = atlas_height;
    font.glyph_entries           = arena_push_array(font.arena, Glyph_Entry, table_size);
    font.glyph_entries_head      = 0;
    font.glyph_entries_tail      = 0;

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
    cursor_y: f32 = font.scale_from_font_units_to_pixels * font.font_ascender;

    // XXX: We had a note here saying that utf8_iter doesn't support 'continue', but we for sure DO
    // 'continue' quite a bit in this file. Find out!

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

                // TODO(jt): @Speed Compute this with shifts, since the dimensions are a power of two.
                glyph_cell_x = entry_index % ATLAS_WIDTH_IN_CELLS;
                glyph_cell_y = entry_index / ATLAS_HEIGHT_IN_CELLS;

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

                error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_RENDER);
                if error {
                    // TODO(jt): Replacement character!
                    continue;
                }

                glyph         := font.ft_face.glyph; // unlike metrics and bitmap, glyph is a pointer
                glyph_metrics := *font.ft_face.glyph.metrics;
                glyph_bitmap  := *font.ft_face.glyph.bitmap;

                entry.glyph_advance       = cast(f32, glyph_metrics.horiAdvance) / 64;
                // XXX: Simp gets sharper results. Is it pixel snapping?
                log("XXX advance % -> %", glyph_metrics.horiAdvance, entry.glyph_advance);
                log("XXX offsets % %", glyph.bitmap_left, glyph.bitmap_top);
                entry.glyph_offset_x      = glyph.bitmap_left;
                entry.glyph_offset_y      = glyph.bitmap_top;
                entry.glyph_bitmap_width  = cast(s32, glyph_bitmap.width);
                entry.glyph_bitmap_height = cast(s32, glyph_bitmap.rows);

                glyph_advance       = entry.glyph_advance;
                glyph_offset_x      = entry.glyph_offset_x;
                glyph_offset_y      = entry.glyph_offset_y;
                glyph_bitmap_width  = entry.glyph_bitmap_width;
                glyph_bitmap_height = entry.glyph_bitmap_height;

                // TODO(jt): @Speed Compute this with shifts, since the dimensions are a power of two.
                glyph_cell_x = entry_index % ATLAS_WIDTH_IN_CELLS;
                glyph_cell_y = entry_index / ATLAS_HEIGHT_IN_CELLS;

                dest := font.glyph_atlas.data +
                        font.glyph_atlas_width * glyph_cell_y * font.glyph_atlas_cell_height +
                        glyph_cell_x * font.glyph_atlas_cell_width;

                clear_glyph_cell(dest, font.glyph_atlas_cell_width, font.glyph_atlas_cell_height, font.glyph_atlas_width);
                copy_glyph_cell(dest, font.glyph_atlas_cell_width, font.glyph_atlas_cell_height, font.glyph_atlas_width,
                                glyph_bitmap.buffer, cast(s32, glyph_bitmap.width), cast(s32, glyph_bitmap.rows), cast(s32, glyph_bitmap.pitch));

                table_add(*font.glyph_table, cast(s32, glyph_index), entry_index);
                array_add(
                    update_regions,
                    irect_from_point_and_size(
                        glyph_cell_x * font.glyph_atlas_cell_width,
                        glyph_cell_y * font.glyph_atlas_cell_height,
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
                cast(f32, glyph_cell_x * font.glyph_atlas_cell_width) / font.glyph_atlas_width,
                cast(f32, glyph_cell_y * font.glyph_atlas_cell_height) / font.glyph_atlas_height,
                cast(f32, glyph_bitmap_width) / font.glyph_atlas_width,
                cast(f32, glyph_bitmap_height) / font.glyph_atlas_height,
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

    advance: s64 = 0; // In font integers. We scale at the end to avoid rounding errors. XXX Verify if it really is font integers
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
        //
        // NOTE(jt): FT_LOAD_NO_SCALE keeps the metrics in font units.
        error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_NO_SCALE);
        if error {
            // TODO(jt): Replacement character! (?)
            continue;
        }

        advance += font.ft_face.glyph.advance.x;;
    }

    // Return f64, because in theory lines could be pretty long. We use f64s for absulute pixel coordinates in the editor.
    scaled_advance := advance * cast(f64, font.scale_from_font_units_to_pixels);

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

    advance: s64 = 0; // In font integers. We scale at the end to avoid rounding errors.
    for :Unicode.utf8_iter line_text {
        // Return f64, because in theory lines could be pretty long. We use f64s for absulute pixel coordinates in the editor.
        scaled_advance := advance * cast(f64, font.scale_from_font_units_to_pixels);
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
        //
        // NOTE(jt): FT_LOAD_NO_SCALE keeps the metrics in font units.
        error := FT_Load_Glyph(font.ft_face, glyph_index, FT_LOAD_NO_SCALE);
        if error {
            // TODO(jt): Replacement character! (?)
            continue;
        }

        advance += font.ft_face.glyph.advance.x;
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


/* XXX:

Freetype functions from tutorial
FT_Init_Freetype(&library)
FT_New_Memory_Face
FT_Done_Face

Freetype structures from tutorial
FT_FaceRec
num_glyphs
face_flags
units_per_EM
num_fixed_sizes
available_sizes

FT_Size (face−>size)
FT_Set_Char_Size
error = FT_Set_Char_Size(
          face,    /* handle to face object         */
          0,       /* char_width in 1/64 of points  */
          16*64,   /* char_height in 1/64 of points */
          300,     /* horizontal device resolution  */
          300 );   /* vertical device resolution    */


error = FT_Set_Pixel_Sizes(
          face,   /* handle to face object */
          0,      /* pixel_width           */
          16 );   /* pixel_height          */

glyph_index = FT_Get_Char_Index( face, charcode );

error = FT_Load_Glyph(
          face,          /* handle to face object */
          glyph_index,   /* glyph index           */
          load_flags );  /* load flags, see below */

error = FT_Render_Glyph( face->glyph,   /* glyph slot  */
                         render_mode ); /* render mode */

glyph->bitmap
glyph->bitmap_left
glyph->bitmap_top

(For optimal rendering on a screen the bitmap should be used as an alpha channel in linear blending with gamma correction.)

Note that bitmap_left is the horizontal distance from the current pen position to the leftmost
border of the glyph bitmap, while bitmap_top is the vertical distance from the pen position (on the
baseline) to the topmost border of the glyph bitmap. It is positive to indicate an upwards distance.


Simple text rendering:

FT_GlyphSlot  slot = face->glyph;  /* a small shortcut */
int           pen_x, pen_y, n;


... initialize library ...
... create face object ...
... set character size ...

pen_x = 300;
pen_y = 200;

for ( n = 0; n < num_chars; n++ )
{
  FT_UInt  glyph_index;


  /* retrieve glyph index from character code */
  glyph_index = FT_Get_Char_Index( face, text[n] );

  /* load glyph image into the slot (erase previous one) */
  error = FT_Load_Glyph( face, glyph_index, FT_LOAD_DEFAULT );
  if ( error )
    continue;  /* ignore errors */

  /* convert to an anti-aliased bitmap */
  error = FT_Render_Glyph( face->glyph, FT_RENDER_MODE_NORMAL );
  if ( error )
    continue;

  /* now, draw to our target surface */
  my_draw_bitmap( &slot->bitmap,
                  pen_x + slot->bitmap_left,
                  pen_y - slot->bitmap_top );

  /* increment pen position */
  pen_x += slot->advance.x >> 6;
  pen_y += slot->advance.y >> 6; /* not useful for now */
  // NOTE(jt): shift by 6 is divide by 64, so... this is all in integers and we snap, and the font looks good because it is hinted? I don't understand.
  // NOTE(jt): If we do glyph caching, we *could* just draw the entire screen into a texture. Probably not what we want, because unlike an atlas we can't do partial updates, and also we'd have everything snapped to pixels, but interesting.
  // NOTE(jt): The advanced (c) example computes with font pixels (1/64), so it doesn't do the downshift, but also doesn't do floats.
}

// NOTE(jt): The advanced freetype example uses the transform API so that it rasterizes the bitmap
// already in the right place. This is probably the best for quality, but we can't stuff it into an
// atlas... Jon's Simp font rendering is nice enough. He does not use the transform API and lays out
// the text naively (as we do). Let's try that first, before we ponder rendering the whole screen with
// freetype. (XXX: HERE)

---------------------------------------------------
Freetype functions Jon uses

FT_Set_Pixel_Sizes
FT_Get_Char_Index
FT_Load_Glyph (with FT_LOAD_RENDER)


*/
