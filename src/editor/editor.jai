/*

TODO(jt): Stuff to do:

- [X] Implement Arena, or use Flat_Pool.
- [X] Display text on screen
- [ ] Font Kerning

- [ ] Gap Buffer (or other text datastructure)

- [ ] Load file/Save file
- [ ] Basic file navigation
- [ ] Basic file editing

- [ ] Sytax Highlighting
- [ ] Indentation

- [ ] Customization and plugins


TODO(jt): Decide whether we want to be using context.allocator. The problem is that it is not always
clear without carefully reading a procedure's code, if that procedure *actively* expects the context
allocator to be overriden. The alternative is to use an explicit allocator parameter, which is
slighly more annoying. For now we are using context allocator and we'll see how it goes.

Related problems to the above are:

Q: Should we be using temp or not?
A: Use it (it is very convenient!), but not for return values, unless it is really clear that that's
   what's happening (one example being the tprint function).

Q: What if the procedure allocates stuff with multiple different (long-lived) lifetimes?
A: Pass an allocator for each lifetime. Fortunately, these situations are rare.

*/

DEBUG :: true; // Extra debugging features enabled for now.

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena";
#import "Hash_Table";

String  :: #import "String";
Math    :: #import "Math";
Unicode :: #import "Unicode";

Vector2    :: Math.Vector2;
Vector4    :: Math.Vector4;
ceil       :: Math.ceil;
operator+  :: Math.operator+;
operator-  :: Math.operator-;
operator*  :: Math.operator*;
operator/  :: Math.operator/;
operator== :: Math.operator==;

#load "math.jai";
#load "platform.jai";
#load "renderer.jai";
#load "input.jai";
#load "gap_buffer.jai";
#load "font.jai";
#load "text_buffer.jai";

TEXTURE_ID_GLYPH_ATLAS: Texture_ID = 0;

Editor :: struct {
    perm_arena: *Arena;
    font: Font;

    buffer: Text_Buffer;
    buffer_panel_scroll: Vector2;
}

init :: (editor: *Editor, platform: Platform, renderer: Renderer) {
    arena_procs := make_arena_procs(platform);
    editor.perm_arena = arena_allocate(arena_procs);

    font_arena   := arena_allocate(arena_procs);
    buffer_arena := arena_allocate(arena_procs);

    success, ttf_buffer := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, arena_allocator(font_arena));
    assert(success);

    editor.font   = make_font(font_arena, ttf_buffer, TEXTURE_ID_GLYPH_ATLAS);
    editor.buffer = make_text_buffer(buffer_arena);
    editor.buffer_panel_scroll = { 0, 0 };

    text_buffer_insert_at_cursor(*editor.buffer, HELLO_TEXT);

    renderer.create_texture_r8unorm(
        TEXTURE_ID_GLYPH_ATLAS,
        editor.font.glyph_atlas_width,
        editor.font.glyph_atlas_height,
        editor.font.glyph_atlas,
    );
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> bool {
    render_rects: [..] Render_Rect;
    render_rects.allocator = temp;
    update_regions: [..] IRect;
    update_regions.allocator = temp;

    buffer_maybe_changed := false;
    for input.events {
        if it.flags & .KEY_PRESSED {
            if it.type == {
                case .KEY; {
                    if it.data.key == {
                        case .ARROW_UP;     text_buffer_maybe_move_cursor_y(*editor.buffer, -1); buffer_maybe_changed = true;
                        case .ARROW_DOWN;   text_buffer_maybe_move_cursor_y(*editor.buffer, 1);  buffer_maybe_changed = true;
                        case .ARROW_LEFT;   text_buffer_maybe_move_cursor_x(*editor.buffer, -1); buffer_maybe_changed = true;
                        case .ARROW_RIGHT;  text_buffer_maybe_move_cursor_x(*editor.buffer, 1);  buffer_maybe_changed = true;

                        // TODO(jt): Move screen up or down.
                        case .PAGE_UP;      editor.buffer_panel_scroll.y -= 10;
                        case .PAGE_DOWN;    editor.buffer_panel_scroll.y += 10;

                        // TODO(jt): Move screen to the beginning and end of buffer.
                        case .HOME;
                        case .END;
                    }
                }

                case .CODEPOINT; {
                    if it.data.codepoint == {
                        case .BACKSPACE;  text_buffer_delete_backward_at_cursor(*editor.buffer); buffer_maybe_changed = true;
                        case .DELETE;     text_buffer_delete_forward_at_cursor(*editor.buffer);  buffer_maybe_changed = true;

                        // TODO(jt): Make indentation configurable.
                        // TODO(jt): Preserve tab-ness in tab-only documents.
                        case .TAB;        text_buffer_insert_at_cursor(*editor.buffer, "    ");  buffer_maybe_changed = true;
                        case .SPACEBAR;   text_buffer_insert_at_cursor(*editor.buffer, " ");     buffer_maybe_changed = true;

                        // TODO(jt): Preserve CRLF in CRLF-only documents.
                        case .ENTER;      text_buffer_insert_at_cursor(*editor.buffer, "\n");    buffer_maybe_changed = true;

                        case; {
                            // TODO(jt): Expand the visible ascii range to all valid unicode ranges... somehow.
                            if it.data.codepoint > 32 && it.data.codepoint < 127 {
                                // TODO(jt): @Speed Accumulate all codepoints into a UTF-8 temporary
                                // buffer before inserting. That includes spacebar, enter, linefeed, etc.
                                //
                                // TODO(jt): @Speed This is a little dumb, because buffer will be
                                // parsing this back to codepoints for its linedata tracking. Clean
                                // this up after we know what we are doing.
                                buf: [4] u8;
                                s := string.{ 4, cast(*u8, *buf) };
                                Unicode.character_utf32_to_utf8(cast(u32, it.data.codepoint), *s);

                                text_buffer_insert_at_cursor(*editor.buffer, s);
                                buffer_maybe_changed = true;
                            }
                        }
                    }

                }
            }
        }
    }

    buffer_cell_w := editor.font.max_glyph_width_in_scaled_pixels;
    buffer_cell_h := editor.font.line_height_in_scaled_pixels;
    buffer_cursor_position: Vector2;
    {
        line_start, line_end := text_buffer_get_cursors_for_line(editor.buffer, editor.buffer.cursor.y);
        line_view := text_buffer_view_between_cursors(editor.buffer, line_start, line_end);

        buffer_cursor_position.x = font_compute_position_on_line(editor.font, line_view, editor.buffer.cursor.x);
        buffer_cursor_position.y = editor.buffer.cursor.y * buffer_cell_h;
    }

    //
    // Scroll buffer to cursor, if something changed
    //
    if buffer_maybe_changed {
        window_w := cast(f32, input.window_size.x);
        window_h := cast(f32, input.window_size.y);

        scroll_padding_x := min(window_w * 0.25, buffer_cell_w * 4);
        scroll_padding_y := min(window_h * 0.25, buffer_cell_h * 4);

        cursor := editor.buffer.cursor;

        panel_rect := rect_from_point_and_size(editor.buffer_panel_scroll.x, editor.buffer_panel_scroll.y, window_w, window_h);
        cursor_rect := rect_from_point_and_size(buffer_cursor_position.x, buffer_cursor_position.y, buffer_cell_w, buffer_cell_h);

        if cursor_rect.y1 > panel_rect.y1 {
            editor.buffer_panel_scroll.y = cursor_rect.y0 - window_h + rect_height(cursor_rect) + scroll_padding_y;
        } else if cursor_rect.y0 < panel_rect.y0 {
            editor.buffer_panel_scroll.y = cursor_rect.y0 - scroll_padding_y;
        }

        editor.buffer_panel_scroll.x = max(0.0, editor.buffer_panel_scroll.x);
        editor.buffer_panel_scroll.y = max(0.0, editor.buffer_panel_scroll.y);
    }

    //
    // Draw cursor
    //
    {
        position := buffer_cursor_position;

        cursor := array_add(*render_rects);
        cursor.rect = rect_from_point_and_size(position.x, position.y, buffer_cell_w, buffer_cell_h) - editor.buffer_panel_scroll;
        cursor.texture_rect = { 0, 0, 0, 0 };
        cursor.texture_id = TEXTURE_ID_GLYPH_ATLAS;
        cursor.color = { 0.05, 0.5, 0.05, 1 };
    }

    //
    // Layout and draw text
    //
    {
        // XXX: Culling: Start on first visible line and end on last visible line. Don't layout the whole world.
        text := gap_buffer_make_contiguous_view(editor.buffer.gb, 0, editor.buffer.gb.occupied_count);
        font_layout_and_draw_text(*editor.font, cast(string, text), *render_rects, *update_regions, editor.buffer_panel_scroll, is_new_frame = true);
    }

    renderer.update_texture_regions_r8unorm(TEXTURE_ID_GLYPH_ATLAS, update_regions, editor.font.glyph_atlas);
    renderer.draw_rects(render_rects);

    return false;
}

#scope_file

make_arena_procs :: (platform: Platform) -> Arena_Procs {
    return {
        platform.page_size,
        platform.mem_reserve,
        platform.mem_release,
        platform.mem_commit,
        platform.mem_decommit,
    };
}

HELLO_TEXT :: #string DONE
But I must explain to you how all this mistaken idea of denouncing pleasure
and praising pain was born and I will give you a complete account of the system,
and expound the actual teachings of the great explorer of the truth,
the master-builder of human happiness.

Hello, Sailor!
DONE
