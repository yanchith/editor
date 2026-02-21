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
floor      :: Math.floor;
ceil       :: Math.ceil;
lerp       :: Math.lerp;
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
    buffer_viewport_scroll: Vector2;
    buffer_viewport_scroll_target: Vector2;

    dev_cull_viewport: bool;
}

init :: (editor: *Editor, platform: Platform, renderer: Renderer) {
    arena_procs := make_arena_procs(platform);
    editor.perm_arena = arena_allocate(arena_procs);

    font_arena   := arena_allocate(arena_procs);
    buffer_arena := arena_allocate(arena_procs);

    success, ttf_buffer := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, arena_allocator(font_arena));
    assert(success);

    editor.font   = make_font(font_arena, ttf_buffer, TEXTURE_ID_GLYPH_ATLAS);
    text_buffer_init(*editor.buffer, buffer_arena);
    editor.buffer_viewport_scroll = { 0, 0 };

    editor.dev_cull_viewport = true;

    text_buffer_insert(*editor.buffer, HELLO_TEXT);

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
                        case .PAGE_UP;      editor.buffer_viewport_scroll_target.y -= 10;
                        case .PAGE_DOWN;    editor.buffer_viewport_scroll_target.y += 10;

                        // TODO(jt): Move screen to the beginning and end of buffer.
                        case .HOME;
                        case .END;

                        case .F11;          editor.dev_cull_viewport = !editor.dev_cull_viewport;
                    }
                }

                case .CODEPOINT; {
                    if it.data.codepoint == {
                        case .BACKSPACE;  text_buffer_delete_backward(*editor.buffer); buffer_maybe_changed = true;
                        case .DELETE;     text_buffer_delete_forward(*editor.buffer);  buffer_maybe_changed = true;

                        // TODO(jt): Make indentation configurable.
                        // TODO(jt): Preserve tab-ness in tab-only documents.
                        case .TAB;        text_buffer_insert(*editor.buffer, "    ");  buffer_maybe_changed = true;
                        case .SPACEBAR;   text_buffer_insert(*editor.buffer, " ");     buffer_maybe_changed = true;

                        // TODO(jt): Preserve CRLF in CRLF-only documents.
                        case .ENTER;      text_buffer_insert(*editor.buffer, "\n");    buffer_maybe_changed = true;

                        case; {
                            // TODO(jt): @Speed Accumulate all codepoints into a UTF-8 temporary
                            // buffer before inserting. That includes spacebar, enter, linefeed, etc.
                            //
                            // TODO(jt): @Speed This is a little dumb, because buffer will be
                            // parsing this back to codepoints for its linedata tracking. Clean
                            // this up after we know what we are doing.
                            buf: [4] u8;
                            s: string;
                            s.data = buf.data;
                            Unicode.character_utf32_to_utf8(cast(u32, it.data.codepoint), *s);

                            text_buffer_insert(*editor.buffer, s);
                            buffer_maybe_changed = true;
                        }
                    }

                }
            }
        }
    }

    buffer_cell_w := editor.font.max_glyph_width_in_scaled_pixels;
    buffer_cell_h := editor.font.line_height_in_scaled_pixels;
    buffer_cursor0_position: Vector2;
    buffer_cursor1_position: Vector2;
    {
        c0_line_start, c0_line_end := text_buffer_get_cursors_for_line(editor.buffer, editor.buffer.cursor0.y);
        c0_line_view := text_buffer_view_between_cursors(editor.buffer, c0_line_start, c0_line_end);

        c1_line_start, c1_line_end := text_buffer_get_cursors_for_line(editor.buffer, editor.buffer.cursor1.y);
        c1_line_view := text_buffer_view_between_cursors(editor.buffer, c1_line_start, c1_line_end);

        buffer_cursor0_position.x = font_compute_position_on_line(editor.font, c0_line_view, editor.buffer.cursor0.x);
        buffer_cursor0_position.y = editor.buffer.cursor0.y * buffer_cell_h;

        buffer_cursor1_position.x = font_compute_position_on_line(editor.font, c1_line_view, editor.buffer.cursor1.x);
        buffer_cursor1_position.y = editor.buffer.cursor1.y * buffer_cell_h;
    }

    //
    // Scroll buffer to cursor, if something changed
    //
    if buffer_maybe_changed {
        window_w := cast(f32, input.window_size.x);
        window_h := cast(f32, input.window_size.y);

        SCROLL_PADDING_CELLS_X :: 0; // TODO(jt): #config Make this configurable. I don't like having this, so I turned it off.
        SCROLL_PADDING_CELLS_Y :: 0; // TODO(jt): #config Make this configurable. I don't like having this, so I turned it off.
        scroll_padding_x := min(window_w * 0.25, buffer_cell_w * SCROLL_PADDING_CELLS_X);
        scroll_padding_y := min(window_h * 0.25, buffer_cell_h * SCROLL_PADDING_CELLS_Y);

        cursor0 := editor.buffer.cursor0;

        viewport_rect := rect_from_point_and_size(editor.buffer_viewport_scroll_target.x, editor.buffer_viewport_scroll_target.y, window_w, window_h);
        cursor_rect := rect_from_point_and_size(buffer_cursor0_position.x, buffer_cursor0_position.y, buffer_cell_w, buffer_cell_h);

        if cursor_rect.x1 > viewport_rect.x1 {
            editor.buffer_viewport_scroll_target.x = cursor_rect.x0 - window_w + rect_width(cursor_rect) + scroll_padding_x;
        } else if cursor_rect.x0 < viewport_rect.x0 {
            editor.buffer_viewport_scroll_target.x = cursor_rect.x0 - scroll_padding_x;
        }

        if cursor_rect.y1 > viewport_rect.y1 {
            editor.buffer_viewport_scroll_target.y = cursor_rect.y0 - window_h + rect_height(cursor_rect) + scroll_padding_y;
        } else if cursor_rect.y0 < viewport_rect.y0 {
            editor.buffer_viewport_scroll_target.y = cursor_rect.y0 - scroll_padding_y;
        }

        editor.buffer_viewport_scroll_target.x = max(0.0, editor.buffer_viewport_scroll_target.x);
        editor.buffer_viewport_scroll_target.y = max(0.0, editor.buffer_viewport_scroll_target.y);
    }

    // TODO(jt): At least make this frame rate independent, but ideally also make it a closed-form
    // Hermite lerp, where we munge the previous animation.
    editor.buffer_viewport_scroll = lerp(editor.buffer_viewport_scroll, editor.buffer_viewport_scroll_target, 0.2);

    //
    // Draw cursor
    //
    {
        position := buffer_cursor0_position;

        cursor := array_add(*render_rects);
        cursor.rect = rect_from_point_and_size(position.x, position.y, buffer_cell_w, buffer_cell_h) - editor.buffer_viewport_scroll;
        cursor.texture_rect = { 0, 0, 0, 0 };
        cursor.texture_id = TEXTURE_ID_GLYPH_ATLAS;
        cursor.color = { 0.05, 0.5, 0.05, 1 };
    }

    //
    // Layout and draw text
    //
    if editor.dev_cull_viewport {
        // This does very simple vertical culling by doing layout and draw only on visible
        // lines. If the lines are long, we do a lot of layout and draw.
        //
        // TODO(jt): @Speed Horizontal culling?

        viewport_y0 := editor.buffer_viewport_scroll.y;
        viewport_y1 := editor.buffer_viewport_scroll.y + input.window_size.y;

        viewport_line_index_start := clamp(cast(s64, floor(viewport_y0 / buffer_cell_h)), 0, editor.buffer.lines.count - 1);
        viewport_line_index_end   := clamp(cast(s64, ceil(viewport_y1 / buffer_cell_h)), 0, editor.buffer.lines.count - 1);

        viewport_start := text_buffer_get_start_cursor_for_line(editor.buffer, viewport_line_index_start);
        viewport_end   := text_buffer_get_end_cursor_for_line(editor.buffer, viewport_line_index_end);
        viewport_view  := text_buffer_view_between_cursors(editor.buffer, viewport_start, viewport_end);

        // Because we start the layout just before the current viewport, the rendering scroll offset
        // is just the fractional part of the cell.
        scroll_offset: Vector2;
        scroll_offset.x = editor.buffer_viewport_scroll.x;
        scroll_offset.y = viewport_y0 - buffer_cell_h * viewport_line_index_start;

        font_layout_and_draw_text(*editor.font, cast(string, viewport_view), *render_rects, *update_regions, scroll_offset, is_new_frame = true);
    } else {
        text := gap_buffer_make_contiguous_view(editor.buffer.gb, 0, editor.buffer.gb.count);
        font_layout_and_draw_text(*editor.font, cast(string, text), *render_rects, *update_regions, editor.buffer_viewport_scroll, is_new_frame = true);
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
But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was
born and I will give you a complete account of the system, and expound the actual teachings of the
great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or
avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue
pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who
loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally
circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial
example, which of us ever undertakes laborious physical exercise, except to obtain some advantage
from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no
annoying consequences, or one who avoids a pain that produces no resultant pleasure?

On the other hand, we denounce with righteous indignation and dislike men who are so beguiled and
demoralized by the charms of pleasure of the moment, so blinded by desire, that they cannot foresee
the pain and trouble that are bound to ensue; and equal blame belongs to those who fail in their
duty through weakness of will, which is the same as saying through shrinking from toil and
pain. These cases are perfectly simple and easy to distinguish. In a free hour, when our power of
choice is untrammelled and when nothing prevents our being able to do what we like best, every
pleasure is to be welcomed and every pain avoided. But in certain circumstances and owing to the
claims of duty or the obligations of business it will frequently occur that pleasures have to be
repudiated and annoyances accepted. The wise man therefore always holds in these matters to this
principle of selection: he rejects pleasures to secure other greater pleasures, or else he endures
pains to avoid worse pains.

Hello, Sailor!
DONE
