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

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena";
#import "Hash_Table";

String  :: #import "String";
Math    :: #import "Math";
Unicode :: #import "Unicode";

Vector2 :: Math.Vector2;
Vector4 :: Math.Vector4;
ceil    :: Math.ceil;

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
    // render_rects.allocator = temp; // XXX
    update_regions: [..] IRect;
    // update_regions.allocator = temp; // XXX

    for input.events {
        if it.flags & .KEY_PRESSED {
            if it.type == {
                case .KEY; {
                    if it.data.key == {
                        case .ARROW_UP;     text_buffer_maybe_move_cursor_y(*editor.buffer, -1);
                        case .ARROW_DOWN;   text_buffer_maybe_move_cursor_y(*editor.buffer, 1);
                        case .ARROW_LEFT;   text_buffer_maybe_move_cursor_x(*editor.buffer, -1);
                        case .ARROW_RIGHT;  text_buffer_maybe_move_cursor_x(*editor.buffer, 1);

                        // TODO(jt): Move screen up or down.
                        case .PAGE_UP;
                        case .PAGE_DOWN;

                        // TODO(jt): Move screen to the beginning and end of buffer.
                        case .HOME;
                        case .END;
                    }
                }

                case .CODEPOINT; {
                    if it.data.codepoint == {
                        case .BACKSPACE; {
                            text_buffer_delete_backward_at_cursor(*editor.buffer);
                        }
                        case .DELETE; {
                            text_buffer_delete_forward_at_cursor(*editor.buffer);
                        }

                        case .TAB; {
                            // TODO(jt): Make indentation configurable.
                            // TODO(jt): Preserve tab-ness in tab-only documents.
                            text_buffer_insert_at_cursor(*editor.buffer, "    ");
                        }
                        case .SPACEBAR; {
                            text_buffer_insert_at_cursor(*editor.buffer, " ");
                        }

                        case .ENTER; {
                            // TODO(jt): Preserve CRLF in CRLF-only documents.
                            text_buffer_insert_at_cursor(*editor.buffer, "\n");
                        }

                        case; {
                            // TODO(jt): Expand the visible ascii range to all valid unicode ranges... somehow.
                            if it.data.codepoint > 32 && it.data.codepoint < 127 {
                                // TODO(jt): @Speed Accumulate all codepoints into a UTF-8 temporary
                                // buffer, before inserting into the gap buffer. That includes
                                // spacebar, enter, linefeed, etc.
                                //
                                // TODO(jt): @Speed This is also a little dumb, because buffer will
                                // be parsing this back to codepoints for its linedata
                                // tracking. Clean this up after we know what we are doing.
                                buf: [4] u8;
                                s := string.{ 4, cast(*u8, *buf) };
                                Unicode.character_utf32_to_utf8(cast(u32, it.data.codepoint), *s);

                                text_buffer_insert_at_cursor(*editor.buffer, s);
                            }
                        }
                    }

                }
            }
        }
    }

    //
    // Draw cursor
    //
    {
        // XXX: @CompilerBug ??? Sooo, line_end is uninitialized with -x64 after I insert a space
        // at the beginnning. Do I stamp on the stack somehow?

        // line_start, line_end := text_buffer_get_cursors_for_line(editor.buffer, editor.buffer.cursor.y);
        line_start := text_buffer_get_start_cursor_for_line(editor.buffer, editor.buffer.cursor.y);
        line_end   := text_buffer_get_end_cursor_for_line(editor.buffer, editor.buffer.cursor.y);

        line_view := text_buffer_view_between_cursors(editor.buffer, line_start, line_end); // XXX temp

        position := font_compute_position_on_line(editor.font, line_view, editor.buffer.cursor.x);

        w: f32 = cast(f32, editor.font.max_glyph_width_in_integer_pixels);
        h: f32 = editor.font.font_scale * (editor.font.font_vmetrics.ascent - editor.font.font_vmetrics.descent + editor.font.font_vmetrics.line_gap);
        x: f32 = position;
        y: f32 = editor.buffer.cursor.y * h;

        cursor := array_add(*render_rects);
        cursor.rect = rect_from_point_and_size(x, y, w, h);
        cursor.texture_rect = { 0, 0, 0, 0 };
        cursor.texture_id = TEXTURE_ID_GLYPH_ATLAS;
        cursor.color = { 0.8, 0, 0.7, 1 };
    }

    //
    // Layout and draw text
    //
    {
        text := gap_buffer_make_contiguous_view(editor.buffer.gb, 0, editor.buffer.gb.occupied_count); // XXX temp
        font_layout_and_draw_text(*editor.font, cast(string, text), *render_rects, *update_regions, is_new_frame = true);
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
