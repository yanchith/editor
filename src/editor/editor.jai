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

*/

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena";
#import "Hash_Table";

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
#load "buffer.jai";

TEXTURE_ID_GLYPH_ATLAS: Texture_ID = 0;

Editor :: struct {
    perm_arena: *Arena;
    font: Font;
    buffer: Buffer;
}


init :: (editor: *Editor, platform: Platform, renderer: Renderer) {
    arena_procs := make_arena_procs(platform);
    editor.perm_arena = arena_allocate(arena_procs);

    font_arena   := arena_allocate(arena_procs);
    buffer_arena := arena_allocate(arena_procs);

    success, ttf_buffer := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, arena_allocator(font_arena));
    assert(success);

    editor.font   = make_font(font_arena, ttf_buffer, TEXTURE_ID_GLYPH_ATLAS);
    editor.buffer = make_buffer(buffer_arena);

    gap_buffer_insert(*editor.buffer.gb, HELLO_TEXT);

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

    for input.events {
        if it.flags & .KEY_PRESSED {
            if it.type == {
                case .KEY; {
                    if it.data.key == {
                        case .ARROW_UP;     maybe_move_buffer_cursor(*editor.buffer, 0, vertical_move = -1);
                        case .ARROW_DOWN;   maybe_move_buffer_cursor(*editor.buffer, 0, vertical_move = 1);
                        case .ARROW_LEFT;   maybe_move_buffer_cursor(*editor.buffer, -1);
                        case .ARROW_RIGHT;  maybe_move_buffer_cursor(*editor.buffer, 1);

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
                            delete_backward_from_buffer_at_cursor(*editor.buffer);
                        }
                        case .DELETE; {
                            delete_forward_from_buffer_at_cursor(*editor.buffer);
                        }

                        case .TAB; {
                            insert_to_buffer_at_cursor(*editor.buffer, "    ");
                        }
                        case .SPACEBAR; {
                            insert_to_buffer_at_cursor(*editor.buffer, " ");
                        }

                        case .ENTER; {
                            // TODO(jt): Preserve CRLF in CRLF-only documents.
                            insert_to_buffer_at_cursor(*editor.buffer, "\n");
                        }

                        case; {
                            // TODO(jt): Expand the visible ascii range to all valid unicode ranges... somehow.
                            if it.data.codepoint > 32 && it.data.codepoint < 127 {
                                // TODO(jt): @Speed Accumulate all codepoints into a UTF-8 temporary
                                // buffer, before inserting into the gap buffer. That includes
                                // spacebar, enter, linefeed, etc.
                                s := cast(string, NewArray(4, u8,, temp));
                                Unicode.character_utf32_to_utf8(cast(u32, it.data.codepoint), *s);

                                insert_to_buffer_at_cursor(*editor.buffer, s);
                            }
                        }
                    }

                }
            }
        }
    }

    text := gap_buffer_make_contiguous_view(editor.buffer.gb, 0, editor.buffer.gb.count);
    layout_and_draw_text_with_font(*editor.font, cast(string, text), *render_rects, *update_regions, is_new_frame = true);

    renderer.update_texture_regions_r8unorm(TEXTURE_ID_GLYPH_ATLAS, update_regions, editor.font.glyph_atlas);
    renderer.draw_rects(render_rects);

    return false;
}

#scope_file

cursor_to_buffer_index :: (buffer: Buffer) -> s64 {

}

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
