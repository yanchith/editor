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

// ID 0 is reserved for the texture-less pipeline. The backend must switch to a texture-less shader
// if the texture wasn't uploaded (we don't upload TEXTURE_ID_NONE). We could also reserve a few
// pixels in the font atlas for color shading, but maybe we don't want to do that?
TEXTURE_ID_NONE        : Texture_ID : 0;
TEXTURE_ID_GLYPH_ATLAS : Texture_ID : 1;

COLOR_CURSOR    : Vector4 : { 0.7, 0.8, 0.7, 1.0 };
COLOR_SELECTION : Vector4 : { 0.7, 0.8, 0.7, 0.3 };

Editor :: struct {
    perm_arena: *Arena;
    font: Font;

    buffer: Text_Buffer;
    buffer_selecting: bool;
    buffer_viewport_scroll: Vector2;
    buffer_viewport_scroll_target: Vector2;

    key_ctrl_down: bool;
    key_alt_down: bool;
    key_shift_down: bool;
    key_meta_down: bool;
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

    editor.key_ctrl_down = false;
    editor.key_alt_down = false;
    editor.key_shift_down = false;
    editor.key_meta_down = false;

    text_buffer_insert(*editor.buffer, HELLO_TEXT);

    renderer.create_texture_r8unorm(
        TEXTURE_ID_GLYPH_ATLAS,
        editor.font.glyph_atlas_width,
        editor.font.glyph_atlas_height,
        editor.font.glyph_atlas,
    );
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> wants_quit: bool, wants_next_frame: bool {
    wants_quit       := false;
    wants_next_frame := false;

    render_rects: [..] Render_Rect;
    render_rects.allocator = temp;
    update_regions: [..] IRect;
    update_regions.allocator = temp;

    clamp_scroll_to_cursor := false;
    for input.events {
        if it.type == {
            case .KEY; if it.data.key == {
                case .CTRL;   editor.key_ctrl_down = cast(bool, it.flags & .KEY_PRESSED);
                case .ALT;    editor.key_alt_down = cast(bool, it.flags & .KEY_PRESSED);
                case .SHIFT; {
                    editor.key_shift_down = cast(bool, it.flags & .KEY_PRESSED);

                    if editor.key_shift_down {
                        // If we were already selecting (because of C-SPACE), flush that.
                        if editor.buffer_selecting {
                            text_buffer_join_cursors(*editor.buffer);
                        }
                        editor.buffer_selecting = true;
                    } else {
                        editor.buffer_selecting = false;
                    }

                }
                case .META;   editor.key_meta_down = cast(bool, it.flags & .KEY_PRESSED);
            }
        }

        if it.flags & .KEY_PRESSED {
            if it.type == {
                case .KEY; {
                    if it.data.key == {
                        case .ARROW_UP;     text_buffer_move_cursor_y(*editor.buffer, -1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                        case .ARROW_DOWN;   text_buffer_move_cursor_y(*editor.buffer,  1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                        case .ARROW_LEFT;   text_buffer_move_cursor_x(*editor.buffer, -1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                        case .ARROW_RIGHT;  text_buffer_move_cursor_x(*editor.buffer,  1, editor.buffer_selecting); clamp_scroll_to_cursor = true;

                        // TODO(jt): Move screen up or down.
                        case .PAGE_UP;      editor.buffer_viewport_scroll_target.y -= 10;
                        case .PAGE_DOWN;    editor.buffer_viewport_scroll_target.y += 10;

                        // TODO(jt): Move screen to the beginning and end of buffer.
                        case .HOME;
                        case .END;
                    }
                }

                case .CODEPOINT; {
                    if editor.key_ctrl_down {
                        if it.data.codepoint == {
                            case #char "P";  text_buffer_move_cursor_y(*editor.buffer, -1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "N";  text_buffer_move_cursor_y(*editor.buffer,  1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "B";  text_buffer_move_cursor_x(*editor.buffer, -1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "F";  text_buffer_move_cursor_x(*editor.buffer,  1, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "A";  text_buffer_move_cursor_to_start_of_line(*editor.buffer, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "E";  text_buffer_move_cursor_to_end_of_line(*editor.buffer, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "L";  recenter_viewport(editor, input);
                            case #char "V";  scroll_viewport_down(editor, input);
                            case .SPACEBAR;  editor.buffer_selecting = true;  text_buffer_join_cursors(*editor.buffer);
                            case #char "G";  editor.buffer_selecting = false; text_buffer_join_cursors(*editor.buffer);
                        }
                    } else if editor.key_alt_down {
                        if it.data.codepoint == {
                            case #char "P";  text_buffer_move_cursor_to_previous_blank_line(*editor.buffer, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "N";  text_buffer_move_cursor_to_next_blank_line(*editor.buffer, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "B";  text_buffer_move_cursor_to_previous_word_boundary(*editor.buffer, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "F";  text_buffer_move_cursor_to_next_word_boundary(*editor.buffer, editor.buffer_selecting); clamp_scroll_to_cursor = true;
                            case #char "V";  scroll_viewport_up(editor, input);
                        }
                    } else {
                        editor.buffer_selecting = false;

                        if it.data.codepoint == {
                            case .BACKSPACE;  text_buffer_delete_backward(*editor.buffer); clamp_scroll_to_cursor = true;
                            case .DELETE;     text_buffer_delete_forward(*editor.buffer);  clamp_scroll_to_cursor = true;

                            // TODO(jt): Make indentation configurable.
                            // TODO(jt): Preserve tab-ness in tab-only documents.
                            case .TAB;        text_buffer_insert(*editor.buffer, "    ");  clamp_scroll_to_cursor = true;
                            case .SPACEBAR;   text_buffer_insert(*editor.buffer, " ");     clamp_scroll_to_cursor = true;

                            // TODO(jt): Preserve CRLF in CRLF-only documents.
                            case .ENTER;      text_buffer_insert(*editor.buffer, "\n");    clamp_scroll_to_cursor = true;

                            case; {
                                // TODO(jt): @Speed Accumulate all codepoints into a UTF-8 temporary
                                // buffer before inserting. That includes spacebar, enter, linefeed, etc.
                                //
                                // TODO(jt): @Speed This is a little dumb, because buffer will be
                                // parsing this back to codepoints for its linedata tracking. Clean
                                // this up after we know what we are doing (on all levels, from the
                                // OS to our buffer!)
                                buf: [4] u8;
                                s: string;
                                s.data = buf.data;
                                Unicode.character_utf32_to_utf8(cast(u32, it.data.codepoint), *s);

                                text_buffer_insert(*editor.buffer, s);
                                clamp_scroll_to_cursor = true;
                            }
                        }
                    }
                }
            }
        }
    }

    buffer_cell_w := editor.font.max_glyph_width_in_scaled_pixels;
    buffer_cell_h := editor.font.line_height_in_scaled_pixels;
    buffer_cursor0_position: Vector2;
    {
        c0_line_start, c0_line_end := text_buffer_get_cursors_for_line(editor.buffer, editor.buffer.cursor0.y);
        c0_line_view := text_buffer_make_view_between_cursors(editor.buffer, c0_line_start, c0_line_end,, temp);

        buffer_cursor0_position.x = font_compute_position_on_line(editor.font, c0_line_view, editor.buffer.cursor0.x);
        buffer_cursor0_position.y = editor.buffer.cursor0.y * buffer_cell_h;
    }

    //
    // Scroll buffer to cursor, if buffer changed
    //
    if clamp_scroll_to_cursor {
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
    }


    //
    // Scroll animation
    //
    {
        editor.buffer_viewport_scroll_target.x = max(0.0, editor.buffer_viewport_scroll_target.x);
        editor.buffer_viewport_scroll_target.y = max(0.0, editor.buffer_viewport_scroll_target.y);

        // TODO(jt): At least make this frame rate independent, but ideally also make it a
        // closed-form Hermite lerp, where we munge the previous animation.
        editor.buffer_viewport_scroll = lerp(editor.buffer_viewport_scroll, editor.buffer_viewport_scroll_target, 0.2);
        if Math.length_squared(editor.buffer_viewport_scroll_target - editor.buffer_viewport_scroll) > 0.1 {
            wants_next_frame = true;
        }
    }

    //
    // Layout and draw selection
    //
    if editor.buffer.cursor0 != editor.buffer.cursor1 {
        cursor_start := text_buffer_get_min_cursor(editor.buffer);
        cursor_end   := text_buffer_get_max_cursor(editor.buffer);

        if cursor_start.y == cursor_end.y {
            line_start := text_buffer_get_start_cursor_for_line(editor.buffer, cursor_start.y);

            view_before_cursor   := text_buffer_make_view_between_cursors(editor.buffer, line_start, cursor_start,, temp);
            view_between_cursors := text_buffer_make_view_between_cursors(editor.buffer, cursor_start, cursor_end,, temp);

            selection_x0 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x);
            selection_x1 := font_compute_position_on_line(editor.font, view_between_cursors, cursor_end.x - cursor_start.x) + selection_x0;
            selection_y0 := cursor_start.y * buffer_cell_h;
            selection_y1 := selection_y0 + buffer_cell_h;

            selection := array_add(*render_rects);
            selection.rect = { selection_x0, selection_y0, selection_x1, selection_y1 } - editor.buffer_viewport_scroll;
            selection.texture_rect = { 0, 0, 0, 0 };
            selection.texture_id = TEXTURE_ID_NONE;
            selection.color = COLOR_SELECTION;
        } else {
            // This does very simple vertical culling by doing layout and draw only on visible
            // lines. If the lines are long, we do a lot of layout and draw.
            //
            // TODO(jt): @Speed Horizontal culling?
            viewport_y0 := editor.buffer_viewport_scroll.y;
            viewport_y1 := editor.buffer_viewport_scroll.y + input.window_size.y;

            viewport_line_index_start := clamp(cast(s64, floor(viewport_y0 / buffer_cell_h)), 0, editor.buffer.lines.count - 1);
            viewport_line_index_end   := clamp(cast(s64, ceil(viewport_y1 / buffer_cell_h)), 0, editor.buffer.lines.count - 1);

            // Because we start the layout just before the current viewport, the rendering scroll offset
            // is just the fractional part of the cell.
            scroll_offset: Vector2;
            scroll_offset.x = editor.buffer_viewport_scroll.x;
            scroll_offset.y = viewport_y0 - buffer_cell_h * viewport_line_index_start;

            // First line, if in viewport
            if cursor_start.y >= viewport_line_index_start && cursor_start.y <= viewport_line_index_end {
                line_start, line_end := text_buffer_get_cursors_for_line(editor.buffer, cursor_start.y);

                view_before_cursor := text_buffer_make_view_between_cursors(editor.buffer, line_start, cursor_start,, temp);
                view_after_cursor  := text_buffer_make_view_between_cursors(editor.buffer, cursor_start, line_end,, temp);

                selection_x0 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x);
                selection_x1 := font_compute_position_on_line(editor.font, view_after_cursor, line_end.x - cursor_start.x) + selection_x0;
                selection_y0 := cursor_start.y * buffer_cell_h;
                selection_y1 := selection_y0 + buffer_cell_h;

                selection := array_add(*render_rects);
                selection.rect = { selection_x0, selection_y0, selection_x1, selection_y1 } - editor.buffer_viewport_scroll;
                selection.texture_rect = { 0, 0, 0, 0 };
                selection.texture_id = TEXTURE_ID_NONE;
                selection.color = COLOR_SELECTION;
            }

            // Center lines, if in viewport
            for (cursor_start.y + 1)..(cursor_end.y - 1) {
                // TODO(jt): @Speed Clamp center lines range instead.
                if it < viewport_line_index_start || it > viewport_line_index_end {
                    continue;
                }

                line_start, line_end := text_buffer_get_cursors_for_line(editor.buffer, it);
                line_view            := text_buffer_make_view_between_cursors(editor.buffer, line_start, line_end,, temp);
                selection_x0 := 0.0;
                selection_x1 := font_compute_position_on_line(editor.font, line_view, line_end.x);
                selection_y0 := it * buffer_cell_h;
                selection_y1 := selection_y0 + buffer_cell_h;

                selection := array_add(*render_rects);
                selection.rect = { selection_x0, selection_y0, selection_x1, selection_y1 } - editor.buffer_viewport_scroll;
                selection.texture_rect = { 0, 0, 0, 0 };
                selection.texture_id = TEXTURE_ID_NONE;
                selection.color = COLOR_SELECTION;
            }

            if cursor_end.y >= viewport_line_index_start && cursor_end.y <= viewport_line_index_end {
                line_start := text_buffer_get_start_cursor_for_line(editor.buffer, cursor_end.y);

                view_before_cursor := text_buffer_make_view_between_cursors(editor.buffer, line_start, cursor_end,, temp);

                selection_x0 := 0.0;
                selection_x1 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_end.x);
                selection_y0 := cursor_end.y * buffer_cell_h;
                selection_y1 := selection_y0 + buffer_cell_h;

                selection := array_add(*render_rects);
                selection.rect = { selection_x0, selection_y0, selection_x1, selection_y1 } - editor.buffer_viewport_scroll;
                selection.texture_rect = { 0, 0, 0, 0 };
                selection.texture_id = TEXTURE_ID_NONE;
                selection.color = COLOR_SELECTION;
            }
        }
    }

    //
    // Draw cursor
    //
    {
        position := buffer_cursor0_position;

        cursor := array_add(*render_rects);
        cursor.rect = rect_from_point_and_size(position.x, position.y, buffer_cell_w, buffer_cell_h) - editor.buffer_viewport_scroll;
        cursor.texture_rect = { 0, 0, 0, 0 };
        cursor.texture_id = TEXTURE_ID_NONE;
        cursor.color = COLOR_CURSOR;
    }

    //
    // Layout and draw text
    //
    {
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
        viewport_view  := text_buffer_make_view_between_cursors(editor.buffer, viewport_start, viewport_end,, temp);

        // Because we start the layout just before the current viewport, the rendering scroll offset
        // is just the fractional part of the cell.
        scroll_offset: Vector2;
        scroll_offset.x = editor.buffer_viewport_scroll.x;
        scroll_offset.y = viewport_y0 - buffer_cell_h * viewport_line_index_start;

        font_layout_and_draw_text(*editor.font, cast(string, viewport_view), *render_rects, *update_regions, scroll_offset, is_new_frame = true);
    }

    renderer.update_texture_regions_r8unorm(TEXTURE_ID_GLYPH_ATLAS, update_regions, editor.font.glyph_atlas);
    renderer.draw_rects(render_rects);

    return wants_quit, wants_next_frame;
}

#scope_file

recenter_viewport :: (editor: *Editor, input: Input) {
    cursor_y := editor.buffer.cursor0.y * editor.font.line_height_in_scaled_pixels;

    center := cursor_y - 0.5 * input.window_size.y;
    top    := cursor_y;
    bottom := cursor_y - input.window_size.y + editor.font.line_height_in_scaled_pixels;

    if editor.buffer_viewport_scroll_target.y == center {
        editor.buffer_viewport_scroll_target.y = top;
    } else if editor.buffer_viewport_scroll_target.y == top {
        editor.buffer_viewport_scroll_target.y = bottom;
    } else {
        editor.buffer_viewport_scroll_target.y = center;
    }
}

scroll_viewport_up :: (editor: *Editor, input: Input) {
    cell_h := editor.font.line_height_in_scaled_pixels;

    delta_max := cast(s64, floor(input.window_size.y / cell_h));
    delta     := min(editor.buffer.cursor0.y, delta_max);

    text_buffer_move_cursor_y(*editor.buffer, -delta, editor.buffer_selecting);
    if delta == delta_max {
        editor.buffer_viewport_scroll_target.y -= delta * cell_h;
    }
}

scroll_viewport_down :: (editor: *Editor, input: Input) {
    cell_h := editor.font.line_height_in_scaled_pixels;

    delta_max := cast(s64, floor(input.window_size.y / cell_h));
    delta     := min(editor.buffer.lines.count - 1 - editor.buffer.cursor0.y, delta_max);

    text_buffer_move_cursor_y(*editor.buffer, delta, editor.buffer_selecting);
    if delta == delta_max {
        editor.buffer_viewport_scroll_target.y += delta * cell_h;
    }
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
YEAR OF GLAD
I am seated in an office, surrounded by heads and bodies. My posture is consciously congruent to the shape of my hard chair.
This is a cold room in University Administration, wood-walled, Remington-hung, double-windowed against the November heat,
insulated from Administrative sounds by the reception area outside, at which Uncle Charles, Mr. deLint and I were lately received.
I am in here.
Three faces have resolved into place above summer-weight sportcoats and half-Windsors across a polished pine conference
table shiny with the spidered light of an Arizona noon. These are three Deans — of Admissions, Academic Affairs, Athletic
Affairs. I do not know which face belongs to whom.
I believe I appear neutral, maybe even pleasant, though I've been coached to err on the side of neutrality and not attempt what
would feel to me like a pleasant expression or smile.
I have committed to crossing my legs I hope carefully, ankle on knee, hands together in the lap of my slacks. My fingers are
mated into a mirrored series of what manifests, to me, as the letter X. The interview room's other personnel include: the
University's Director of Composition, its varsity tennis coach, and Academy prorector Mr. A. deLint. C.T. is beside me; the others
sit, stand and stand, respectively, at the periphery of my focus. The tennis coach jingles pocket-change. There is something
vaguely digestive about the room's odor. The high-traction sole of my complimentary Nike sneaker runs parallel to the wobbling
loafer of my mother's half-brother, here in his capacity as Headmaster, sitting in the chair to what I hope is my immediate right,
also facing Deans.
The Dean at left, a lean yellowish man whose fixed smile nevertheless has the impermanent quality of something stamped
into uncooperative material, is a personality-type I've come lately to appreciate, the type who delays need of any response from
me by relating my side of the story for me, to me. Passed a packet of computer-sheets by the shaggy lion of a Dean at center, he is
speaking more or less to these pages, smiling down.
'You are Harold Incandenza, eighteen, date of secondary-school graduation approximately one month from now, attending the
Enfield Tennis Academy, Enfield, Massachusetts, a boarding school, where you reside.' His reading glasses are rectangular, court-
shaped, the sidelines at top and bottom. 'You are, according to Coach White and Dean [unintelligible], a regionally, nationally,
and continentally ranked junior tennis player, a potential O.N.A.N.C.A.A. athlete of substantial promise, recruited by Coach
White via correspondence with Dr. Tavis here commencing .. . February of this year.' The top page is removed and brought
around neatly to the bottom of the sheaf, at intervals. 'You have been in residence at the Enfield Tennis Academy since age
seven.’

I am debating whether to risk scratching the right side of my jaw, where there is a wen.
'Coach White informs our offices that he holds the Enfield Tennis Academy's program and achievements in high regard, that
the University of Arizona tennis squad has profited from the prior matriculation of several former E.T.A. alumni, one of whom
was one Mr. Aubrey F. deLint, who appears also to be with you here today. Coach White and his staff have given us —’
The yellow administrator's usage is on the whole undistinguished, though I have to admit he's made himself understood. The
Director of Composition seems to have more than the normal number of eyebrows. The Dean at right is looking at my face a bit
strangely.
Uncle Charles is saying that though he can anticipate that the Deans might be predisposed to weigh what he avers as coming
from his possible appearance as a kind of cheerleader for E.T.A., he can assure the assembled Deans that all this is true, and that
the Academy has presently in residence no fewer than a third of the continent's top thirty juniors, in age brackets all across the
board, and that I here, who go by 'Hal,' usually, am 'right up there among the very cream.' Right and center Deans smile
professionally; the heads of deLint and the coach incline as the Dean at left clears his throat:
'— belief that you could well make, even as a freshman, a real contribution to this University's varsity tennis program. We are
pleased,' he either says or reads, removing a page, 'that a competition of some major sort here has brought you down and given us
the chance to sit down and chat together about your application and potential recruitment and matriculation and scholarship.’
'I've been asked to add that Hal here is seeded third, Boys' 18-and-Under Singles, in the prestigious WhataBurger Southwest
Junior Invitational out at the Randolph Tennis Center —' says what I infer is Athletic Affairs, his cocked head showing a freckled
scalp.

'Out at Randolph Park, near the outstanding El Con Marriott,' C.T. inserts, 'a venue the whole contingent's been vocal about
finding absolutely top-hole thus far, which —’
'Just so, Chuck, and that according to Chuck here Hal has already justified his seed, he's reached the semifinals as of this
morning's apparently impressive win, and that he'll be playing out at the Center again tomorrow, against the winner of a
quarterfinal game tonight, and so will be playing tomorrow at I believe scheduled for 0830 —’
'Try to get under way before the godawful heat out there. Though of course a dry heat.’
'— and has apparently already qualified for this winter's Continental Indoors, up in Edmonton, Kirk tells me —' cocking
further to look up and left at the varsity coach, whose smile's teeth are radiant against a violent sunburn — 'Which is something
indeed.' He smiles, looking at me. 'Did we get all that right Hal.’
C.T. has crossed his arms casually; their triceps' flesh is webbed with mottle in the air-conditioned sunlight. 'You sure did.
Bill.' He smiles. The two halves of his mustache never quite match. 'And let me say if I may that Hal's excited, excited to be
invited for the third year running to the Invitational again, to be back here in a community he has real affection for, to visit with
your alumni and coaching staff, to have already justified his high seed in this week's not unstiff competition, to as they say still be
in it without the fat woman in the Viking hat having sung, so to speak, but of course most of all to have a chance to meet you
gentlemen and have a look at the facilities here. Everything here is absolutely top-slot, from what he's seen.’
There is a silence. DeLint shifts his back against the room's panelling and recenters his weight. My uncle beams and
straightens a straight watchband. 62.5% of the room's faces are directed my way, pleasantly expectant. My chest bumps like a
dryer with shoes in it. I compose what I project will be seen as a smile. I turn this way and that, slightly, sort of directing the
expression to everyone in the room.
There is a new silence. The yellow Dean's eyebrows go circumflex. The two other Deans look to the Director of Composition.
The tennis coach has moved to stand at the broad window, feeling at the back of his crewcut. Uncle Charles strokes the forearm
above his watch. Sharp curved palm-shadows move slightly over the pine table's shine, the one head's shadow a black moon.
'Is Hal all right, Chuck?' Athletic Affairs asks. 'Hal just seemed to ... well, grimace. Is he in pain? Are you in pain, son?’
'Hal's right as rain,' smiles my uncle, soothing the air with a casual hand. 'Just a bit of a let's call it maybe a facial tic, slightly,
at all the adrenaline of being here on your impressive campus, justifying his seed so far without dropping a set, receiving that
official written offer of not only waivers but a living allowance from Coach White here, on Pac 10 letterhead, being ready in all
probability to sign a National Letter of Intent right here and now this very day, he's indicated to me.' C.T. looks to me, his look
horribly mild. I do the safe thing, relaxing every muscle in my face, emptying out all expression. I stare carefully into the
Kekuléan knot of the middle Dean's necktie.
My silent response to the expectant silence begins to affect the air of the room, the bits of dust and sportcoat-lint stirred
around by the AC's vents dancing jaggedly in the slanted plane of windowlight, the air over the table like the sparkling space just
above a fresh-poured seltzer. The coach, in a slight accent neither British nor Australian, is telling C.T. that the whole application-
interface process, while usually just a pleasant formality, is probably best accentuated by letting the applicant speak up for
himself. Right and center Deans have inclined together in soft conference, forming a kind of tepee of skin and hair. I presume it's
probably facilitate that the tennis coach mistook for accentuate, though accelerate, while clunkier than facilitate, is from a phonetic
perspective more sensible, as a mistake. The Dean with the flat yellow face has leaned forward, his lips drawn back from his teeth
in what I see as concern. His hands come together on the conference table's surface. His own fingers look like they mate as my
own four-X series dissolves and I hold tight to the sides of my chair.
We need candidly to chat re potential problems with my application, they and I, he is beginning to say. He makes a reference
to candor and its value.
DONE
