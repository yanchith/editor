/*

TODO(jt): Stuff to do:

- [X] Implement Arena, or use Flat_Pool.
- [X] Display text on screen
- [X] Nice font rendering.

- [X] Gap Buffer (or other text datastructure)

- [X] Basic file navigation
- [X] Basic file editing
- [ ] Load file/Save file
- [ ] Find in mini panel
- [X] Cut/Copy/Paste
- [X] Undo!

TODO(jt): Fancy stuff to do:

- [ ] Syntax Highlighting
- [ ] Themes
- [ ] Automatic indentation (C-i)
- [ ] Emacs-like undo?
- [ ] Emacs-like kill ring
- [ ] Lister panels
- [ ] Read only mode. Automatically on for files that had to undergo load fixups, as well as lister panels.
- [ ] if (0) and #if 0 behave like comments w.r.t. to highlighting.
- [ ] Font Kerning
- [ ] Very nice glyph rendering (Slug?)
- [ ] Git integration

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

#module_parameters()(SANITY := false);

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena";
#import "Hash_Table";
#import "Profiler"(IMPORT_MODE = .RUNTIME);

String  :: #import "String";
Math    :: #import "Math";
Unicode :: #import "Unicode";

Vector2        :: Math.Vector2;
Vector4        :: Math.Vector4;
floor          :: Math.floor;
ceil           :: Math.ceil;
sqrt           :: Math.sqrt;
lerp           :: Math.lerp;
length         :: Math.length;
length_squared :: Math.length_squared;
operator+      :: Math.operator+;
operator-      :: Math.operator-;
operator*      :: Math.operator*;
operator/      :: Math.operator/;
operator==     :: Math.operator==;

#load "assert.jai";
#load "bits.jai";
#load "string.jai";
#load "unicode.jai";
#load "math.jai";
#load "platform.jai";
#load "renderer.jai";
#load "input.jai";
#load "font.jai";
#load "gap_buffer.jai";
#load "text_buffer.jai";

// ID 0 is reserved for the texture-less pipeline. The backend must switch to a texture-less shader
// if the texture wasn't uploaded (we don't upload TEXTURE_ID_NONE). We could also reserve a few
// pixels in the font atlas for color shading, but maybe we don't want to do that?
TEXTURE_ID_NONE        : Texture_ID : 0;
TEXTURE_ID_GLYPH_ATLAS : Texture_ID : 1;

COLOR_CURSOR    : Vector4 : { 0.7, 0.8, 0.7, 1.0 };
COLOR_SELECTION : Vector4 : { 0.7, 0.8, 0.7, 0.3 };

SLOW_FRAME_THRESHOLD_MILLIS : f64 : 10;

MINI_PANEL_LINES :: 10; // TODO(jt): Make this configurable!

Editor :: struct {
    perm_arena: *Arena;

    font: Font;
    font_size: s32; // Scaled!

    input_state: Input_State;

    // TODO(jt): Layout!
    panels: [..] Panel;
    active_panel_index: s64;

    mini_panel: Mini_Panel;

    dev_show_atlas_texture: bool;
}

Panel :: struct {
    // Scroll vectors are in f64s, because buffers can be large and we actually ran into precision
    // issues. Doubles are fine for now (verified up to 1GB of prose), but maybe we should do our
    // own numeric type that's s64 + f32 offset.
    //
    // :FloatPrecision
    scroll_source: DVector2;
    scroll_target: DVector2;
    scroll_time_start: Apollo_Time;

    scroll: DVector2;

    // These clampers get set during event processing and unset after. We could store them somewhere
    // else, but we need them for every panel we have touched, so they might as well be here.
    //
    // TODO(jt): Turn these into flags!
    clamp_scroll_to_cursor: bool;
    clamp_scroll_to_start_of_line: bool;
    clamp_scroll_to_end_of_line: bool;

    // TODO(jt): Read-only flag.

    selecting: bool;
    buffer: Text_Buffer; // XXX: We need to reuse text buffers between various panels! (the panel content has to own the cursors)
}

Mini_Panel :: struct {
    open: bool;

    buffer: Text_Buffer;

    action: Action;

    things: [..] string;
    active_thing_index: s64;

    Action :: enum {
        SEARCH          :: 0;
        OPEN_FILE       :: 1;
        SWITCH_TO_PANEL :: 2;
        CLOSE_PANEL     :: 3;
    }
}

init :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) {
    profiler_init();
    profiler_start_frame("init");

    arena_procs := make_arena_procs(platform);
    editor.perm_arena = arena_allocate(arena_procs);

    font_arena   := arena_allocate(arena_procs);
    success, ttf_buffer := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, arena_allocator(font_arena));
    assert(success);

    editor.font_size = 16;
    log("Current font pixel height: %", editor.font_size);

    physical_pixel_height := cast(s32, ceil(editor.font_size * input.window_scale_factor));
    log("Initializing font for physical pixel height: %", physical_pixel_height);

    editor.font = make_font(font_arena, ttf_buffer, TEXTURE_ID_GLYPH_ATLAS, physical_pixel_height);

    input_state_update_on_frame_start(*editor.input_state, input);
    for input.events {
        input_state_update_with_event(*editor.input_state, it);
    }

    editor.panels.allocator = arena_allocator(editor.perm_arena);
    add_scratch_panel(editor, platform);

    mini_panel_arena := arena_allocate(arena_procs, reserve_size = 64 << 10);

    text_buffer_init(*editor.mini_panel.buffer, arena_allocate(arena_procs));
    editor.mini_panel.things.allocator = arena_allocator(editor.perm_arena);

    renderer.create_texture_r8unorm(
        TEXTURE_ID_GLYPH_ATLAS,
        editor.font.glyph_atlas_width_in_pixels,
        editor.font.glyph_atlas_height_in_pixels,
        editor.font.glyph_atlas,
    );

    time_scale := profiler_end_frame();
    print_profile_for_slow_frames(SLOW_FRAME_THRESHOLD_MILLIS, time_scale);
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> wants_quit: bool, wants_next_frame: bool {
    profiler_start_frame("update_and_render");

    // @Hack to constrain DT from sleeping frames. However, we should only be using DT in situations
    // where we are already animating.
    dt := min(to_float64_seconds(input.dtime), 0.33);

    wants_quit       := false;
    wants_next_frame := false;

    render_rects: [..] Render_Rect;
    render_rects.allocator = temp;
    update_regions: [..] IRect;
    update_regions.allocator = temp;

    input_state_update_on_frame_start(*editor.input_state, input);

    active_panel: *Panel = null;
    if editor.panels.count {
        index := clamp(editor.active_panel_index, 0, editor.panels.count - 1);
        active_panel = *editor.panels[index];
    }

    for input.events {
        handled := false;

        input_state_update_with_event(*editor.input_state, it);

        //
        // Global events handled at the editor level.
        //
        if it.flags & .KEY_PRESSED {
            if it.type == {
                case .KEY; {
                    if it.data.key == {
                        case .F1;  editor.dev_show_atlas_texture = !editor.dev_show_atlas_texture; handled = true;
                    }
                }

                case .CODEPOINT; {
                    if editor.input_state.keys[Key.CTRL] & .DOWN {
                        if it.data.codepoint == {
                            // TODO(jt): This works a little too well on Windows, we don't even need
                            // to press shift for the +. The problem is that Windows doesn't send us
                            // the TEXT_INPUT (WM_CHAR/WM_SYSCHAR) event at all if CTRL is down, so
                            // we are left with our shitty synthetic TEXT_INPUT in main.jai. We
                            // could try translating the message without the CTRL and then glueing
                            // the CTRL back in? I don't know.
                            case #char "+";  editor.font_size += 1; handled = true;
                            case #char "-";  editor.font_size = max(editor.font_size - 1, 4); handled = true;

                            case #char "g";  #through;
                            case #char "G"; {
                                if editor.mini_panel.open {
                                    editor.mini_panel.open = false;
                                    handled = true;
                                }
                            }

                            case #char "s";  #through;
                            case #char "S"; {
                                editor.mini_panel.open = true;
                                if editor.mini_panel.open {
                                    text_buffer_reset(*editor.mini_panel.buffer);
                                    array_reset_keeping_memory(*editor.mini_panel.things);

                                    editor.mini_panel.action = .SEARCH;

                                    array_add(*editor.mini_panel.things, "Gondar");
                                    array_add(*editor.mini_panel.things, "Nox");
                                    array_add(*editor.mini_panel.things, "Brennan");
                                    array_add(*editor.mini_panel.things, "Griffin");
                                    array_add(*editor.mini_panel.things, "Seth");
                                    editor.mini_panel.active_thing_index = 0;
                                }

                                handled = true;
                            }
                        }
                    }
                }
            }
        }

        //
        // Events that trickle down to the active panel.
        //
        if !handled {
            if editor.mini_panel.open {
                route_event_to_mini_panel(*editor.mini_panel, active_panel, it, platform, input, editor.input_state, editor.font.line_height_in_pixels);
            } else if active_panel {
                route_event_to_panel(active_panel, it, platform, input, editor.input_state, editor.font.line_height_in_pixels);
            }
        }
    }

    if editor.input_state.keys[Key.CTRL] & .DOWN {
        delta: s32;
        if input.mouse_wheel_delta > 0 then delta = 1;
        if input.mouse_wheel_delta < 0 then delta = -1;
        editor.font_size = max(editor.font_size + delta, 4);
    }

    {
        physical_pixel_height := cast(s32, ceil(editor.font_size * input.window_scale_factor));
        if editor.font.pixel_height != physical_pixel_height {
            log("Resetting font to new physical pixel height: %", physical_pixel_height);
            font_reset_for_pixel_height(*editor.font, physical_pixel_height);

            for * editor.panels {
                it.clamp_scroll_to_cursor = true;
            }
        }
    }

    // Upcast to f64 here, because we later multiply them with lines/columns, and we don't want to
    // accidentally do the multiply in f32, which is not precise enough in large buffers.
    cell_w := cast(f64, editor.font.max_glyph_width_in_pixels);
    cell_h := cast(f64, editor.font.line_height_in_pixels);

    if editor.mini_panel.open {
        // XXX: Handle mouse stuff in mini panel?
    } else {
        // XXX: Mouse stuff should activate the clicked panel!

        //
        // Mouse wheel scrolling
        //
        if active_panel && input.mouse_wheel_delta != 0 && !(editor.input_state.keys[Key.CTRL] & .DOWN) {
            // TODO(jt): This is choppy on macOS touchpad scrolling. Get underlying float scroll value?
            active_panel.scroll_target.y -= cast(f64, input.mouse_wheel_delta);
            active_panel.scroll_target.y = clamp(active_panel.scroll_target.y, 0, cell_h * (active_panel.buffer.lines.count - 1));
            finish_scroll_interpolation(active_panel);
        }

        //
        // Mouse Selection
        //
        // TODO(jt): Double click to select word.
        // TODO(jt): Triple click to select line.
        //
        if active_panel && editor.input_state.keys[Key.MB_LEFT] & .DOWN {
            mouse := input.mouse_position;

            //
            // Mouse selection scrolling
            //
            if editor.input_state.keys[Key.MB_LEFT] & .LAST_PRESS_WAS_WITH_MOUSE_INSIDE_WINDOW {
                SCROLL_APRON : f32 :  20.0;
                SCROLL_SPEED : f64 :  10.0;
                SCROLL_BOOST : f64 :   5.0;

                if mouse.x < SCROLL_APRON {
                    boost := (SCROLL_APRON - mouse.x) * SCROLL_BOOST;

                    active_panel.scroll_target.x -= SCROLL_SPEED * boost * dt;
                    active_panel.scroll_target.x = max(active_panel.scroll_target.x, 0);
                    finish_scroll_interpolation(active_panel);

                    wants_next_frame = true;
                } else if mouse.x > cast(f32, input.window_size.x) - SCROLL_APRON {
                    boost := (mouse.x - (cast(f32, input.window_size.x) - SCROLL_APRON)) * SCROLL_BOOST;

                    // Apron contains the newline (if present) and one additional horizontal cell.
                    apron := 2 * cell_w;

                    line_view := text_buffer_make_view_for_line(active_panel.buffer, active_panel.buffer.cursor0.y,, temp);
                    max_x := font_compute_position_on_line(editor.font, line_view, active_panel.buffer.cursor0.x) - input.window_size.x + apron;

                    active_panel.scroll_target.x += SCROLL_SPEED * boost * dt;
                    active_panel.scroll_target.x = min(active_panel.scroll_target.x, max_x);
                    finish_scroll_interpolation(active_panel);

                    wants_next_frame = true;
                }

                if mouse.y < SCROLL_APRON {
                    boost := (SCROLL_APRON - mouse.y) * SCROLL_BOOST;

                    active_panel.scroll_target.y -= SCROLL_SPEED * boost * dt;
                    active_panel.scroll_target.y = max(active_panel.scroll_target.y, 0);
                    finish_scroll_interpolation(active_panel);

                    wants_next_frame = true;
                } else if mouse.y > cast(f32, input.window_size.y) - SCROLL_APRON {
                    boost := (mouse.y - (cast(f32, input.window_size.y) - SCROLL_APRON)) * SCROLL_BOOST;

                    active_panel.scroll_target.y += SCROLL_SPEED * boost * dt;
                    active_panel.scroll_target.y = min(active_panel.scroll_target.y, cell_h * (active_panel.buffer.lines.count - 1));
                    finish_scroll_interpolation(active_panel);

                    wants_next_frame = true;
                }
            }

            row := cast(s64, floor((mouse.y + active_panel.scroll.y) / cell_h));
            col := 0;

            if row < 0 {
                row = 0;
                col = 0;
            } else if row > active_panel.buffer.lines.count - 1 {
                row = active_panel.buffer.lines.count - 1;

                // Include newline, so that the cursor can go there.
                line_view := text_buffer_make_view_for_line(active_panel.buffer, row, include_newline = true,, temp);
                col = font_compute_character_index_on_line(editor.font, line_view, mouse.x + active_panel.scroll.x);
            } else {
                // Include newline, so that the cursor can go there.
                line_view := text_buffer_make_view_for_line(active_panel.buffer, row, include_newline = true,, temp);
                col = font_compute_character_index_on_line(editor.font, line_view, mouse.x + active_panel.scroll.x);
            }

            text_buffer_move_cursor_to(*active_panel.buffer, col, row, !(editor.input_state.keys[Key.MB_LEFT] & .PRESSED));
        }
    }

    for * panel: editor.panels {
        //
        // Compute cursor position.
        //
        buffer_cursor0_position: DVector2;
        buffer_cursor0_line_end_x: f64;
        {
            c0_line_start, c0_line_end := text_buffer_get_cursors_for_line(panel.buffer, panel.buffer.cursor0.y);
            c0_line_view := text_buffer_make_view_between_cursors(panel.buffer, c0_line_start, c0_line_end,, temp);

            buffer_cursor0_position.x = font_compute_position_on_line(editor.font, c0_line_view, panel.buffer.cursor0.x);
            buffer_cursor0_position.y = panel.buffer.cursor0.y * cell_h;
            buffer_cursor0_line_end_x = font_compute_position_on_line(editor.font, c0_line_view, c0_line_end.x);
        }

        //
        // Scroll buffer to cursor, if buffer changed. Clamp cursor to buffer, if buffer scrolled.
        //
        if panel.clamp_scroll_to_cursor || panel.clamp_scroll_to_start_of_line || panel.clamp_scroll_to_end_of_line {
            ProfileZone(":ClampScroll");
            window_w := cast(f32, input.window_size.x);
            window_h := cast(f32, input.window_size.y);

            SCROLL_PADDING_CELLS_X :: 0; // TODO(jt): Make this configurable. I don't like having this, so I turned it off. :Config
            SCROLL_PADDING_CELLS_Y :: 0; // TODO(jt): Make this configurable. I don't like having this, so I turned it off. :Config
            scroll_padding_x := min(window_w * 0.25, cast(f32, cell_w) * SCROLL_PADDING_CELLS_X);
            scroll_padding_y := min(window_h * 0.25, cast(f32, cell_h) * SCROLL_PADDING_CELLS_Y);

            cursor0 := panel.buffer.cursor0;

            // XXX: This is not the correct viewport rect anymore! Compute for panel.
            viewport_rect := drect_from_point_and_size(panel.scroll_target.x, panel.scroll_target.y, window_w, window_h);
            scroll_to_rect: DRect;
            if panel.clamp_scroll_to_start_of_line {
                scroll_to_rect = drect_from_point_and_size(0, buffer_cursor0_position.y, cell_w, cell_h);
            } else if panel.clamp_scroll_to_end_of_line {
                scroll_to_rect = drect_from_point_and_size(buffer_cursor0_line_end_x, buffer_cursor0_position.y, cell_w, cell_h);
            } else {
                scroll_to_rect = drect_from_point_and_size(buffer_cursor0_position.x, buffer_cursor0_position.y, cell_w, cell_h);
            }

            if scroll_to_rect.x1 > viewport_rect.x1 {
                finish_scroll_interpolation(panel);
                panel.scroll_target.x = scroll_to_rect.x0 - window_w + drect_width(scroll_to_rect) + scroll_padding_x;
                setup_scroll_interpolation(panel, input.time);
            } else if scroll_to_rect.x0 < viewport_rect.x0 {
                finish_scroll_interpolation(panel);
                panel.scroll_target.x = scroll_to_rect.x0 - scroll_padding_x;
                setup_scroll_interpolation(panel, input.time);
            }

            if scroll_to_rect.y1 > viewport_rect.y1 {
                finish_scroll_interpolation(panel);
                panel.scroll_target.y = scroll_to_rect.y0 - window_h + drect_height(scroll_to_rect) + scroll_padding_y;
                setup_scroll_interpolation(panel, input.time);
            } else if scroll_to_rect.y0 < viewport_rect.y0 {
                finish_scroll_interpolation(panel);
                panel.scroll_target.y = scroll_to_rect.y0 - scroll_padding_y;
                setup_scroll_interpolation(panel, input.time);
            }
        }

        //
        // Scroll animation
        //
        {
            SCROLL_TIME : f64 : 0.12;

            // TODO(jt): Because we don't want to use DT, the animation starts with oine frame of
            // lag. We could make up some fake DT for the first frame. Maybe we could get the
            // monitor refresh rate?
            t := cast(f32, (to_float64_seconds(input.time) - to_float64_seconds(panel.scroll_time_start)) / SCROLL_TIME);
            t = clamp(t, 0.0, 1.0);
            t = smoothstep(0.0, 1.0, t);

            panel.scroll = lerp(panel.scroll_source, panel.scroll_target, t);

            if t < 1.0 {
                wants_next_frame = true;
            }
        }

        //
        // Layout and draw selection
        //
        if panel.buffer.cursor0 != panel.buffer.cursor1 {
            cursor_start := text_buffer_get_min_cursor(panel.buffer);
            cursor_end   := text_buffer_get_max_cursor(panel.buffer);

            if cursor_start.y == cursor_end.y {
                ProfileZone(":DrawSelectionHighlightSingleLine");

                line_start := text_buffer_get_start_cursor_for_line(panel.buffer, cursor_start.y);

                view_before_cursor   := text_buffer_make_view_between_cursors(panel.buffer, line_start, cursor_start,, temp);
                view_between_cursors := text_buffer_make_view_between_cursors(panel.buffer, cursor_start, cursor_end,, temp);

                selection_x0 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x);
                selection_x1 := font_compute_position_on_line(editor.font, view_between_cursors, cursor_end.x - cursor_start.x) + selection_x0;
                selection_y0 := cursor_start.y * cell_h;
                selection_y1 := selection_y0 + cell_h;
                selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), COLOR_SELECTION);
            } else {
                ProfileZone(":DrawSelectionHighlightMultiLine");

                // This does very simple vertical culling by doing layout and draw only on visible
                // lines. If the lines are long, we do a lot of layout and draw.
                //
                // TODO(jt): @Speed Horizontal culling?
                viewport_y0 := panel.scroll.y;
                viewport_y1 := panel.scroll.y + input.window_size.y; // XXX: Incorrect. Compute viewport for panel.

                viewport_line_index_start := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, panel.buffer.lines.count - 1);
                viewport_line_index_end   := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, panel.buffer.lines.count - 1);

                // Because we start the layout just before the current viewport, the rendering scroll Y offset
                // is just the fractional part of the cell.
                //
                // Because we expect scroll_offset to be small, we keep it in f32.
                scroll_offset: Vector2;
                scroll_offset.x = cast(f32, panel.scroll.x);
                scroll_offset.y = cast(f32, viewport_y0 - cell_h * viewport_line_index_start);

                // First line, if in viewport
                if cursor_start.y >= viewport_line_index_start && cursor_start.y <= viewport_line_index_end {
                    line_start, line_end := text_buffer_get_cursors_for_line(panel.buffer, cursor_start.y);

                    view_before_cursor := text_buffer_make_view_between_cursors(panel.buffer, line_start, cursor_start,, temp);
                    view_after_cursor  := text_buffer_make_view_between_cursors(panel.buffer, cursor_start, line_end,, temp);

                    selection_x0 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x);
                    selection_x1 := font_compute_position_on_line(editor.font, view_after_cursor, line_end.x - cursor_start.x) + selection_x0;
                    selection_y0 := cursor_start.y * cell_h;
                    selection_y1 := selection_y0 + cell_h;
                    selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                    draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), COLOR_SELECTION);
                }

                // Center lines, if in viewport
                for (cursor_start.y + 1)..(cursor_end.y - 1) {
                    // TODO(jt): @Speed Clamp center lines range instead.
                    if it < viewport_line_index_start || it > viewport_line_index_end {
                        continue;
                    }

                    line_end  := text_buffer_get_end_cursor_for_line(panel.buffer, it);
                    line_view := text_buffer_make_view_for_line(panel.buffer, it,, temp);
                    selection_x0 := 0.0;
                    selection_x1 := font_compute_position_on_line(editor.font, line_view, line_end.x);
                    selection_y0 := it * cell_h;
                    selection_y1 := selection_y0 + cell_h;
                    selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                    draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), COLOR_SELECTION);
                }

                if cursor_end.y >= viewport_line_index_start && cursor_end.y <= viewport_line_index_end {
                    line_start := text_buffer_get_start_cursor_for_line(panel.buffer, cursor_end.y);

                    view_before_cursor := text_buffer_make_view_between_cursors(panel.buffer, line_start, cursor_end,, temp);

                    selection_x0 := 0.0;
                    selection_x1 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_end.x);
                    selection_y0 := cursor_end.y * cell_h;
                    selection_y1 := selection_y0 + cell_h;
                    selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                    draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), COLOR_SELECTION);
                }
            }
        }

        //
        // Draw cursor
        //
        {
            position := buffer_cursor0_position;
            rect := drect_from_point_and_size(position.x, position.y, cell_w, cell_h) - panel.scroll;

            draw_rect(*render_rects, drect_to_rect(rect), COLOR_CURSOR);
        }

        //
        // Layout and draw text
        //
        {
            ProfileZone(":DrawText");

            // This does very simple vertical culling by doing layout and draw only on visible
            // lines. If the lines are long, we do a lot of layout and draw.
            //
            // TODO(jt): @Speed Horizontal culling?
            viewport_y0 := panel.scroll.y;
            viewport_y1 := panel.scroll.y + input.window_size.y; // XXX: Incorrect. Compute viewport for panel.

            viewport_line_index_start := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, panel.buffer.lines.count - 1);
            viewport_line_index_end   := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, panel.buffer.lines.count - 1);

            viewport_start := text_buffer_get_start_cursor_for_line(panel.buffer, viewport_line_index_start);
            viewport_end   := text_buffer_get_end_cursor_for_line(panel.buffer, viewport_line_index_end);
            viewport_view  := text_buffer_make_view_between_cursors(panel.buffer, viewport_start, viewport_end,, temp);

            // Because we start the layout just before the current viewport, the rendering scroll Y offset
            // is just the fractional part of the cell.
            //
            // While we expect vertical scroll_offset to be small, horizontal can in theory be pretty
            // big (although I'd wager we have serious performance problems before that starts to
            // matter), so we go f64 to be future proof.
            offset: DVector2;
            offset.x = -panel.scroll.x;
            offset.y = -viewport_y0 + cell_h * viewport_line_index_start;

            // TODO(jt): @Speed Cull render rects that are not on the screen. We still have to layout the text
            // to the left of the screen, but we don't have to emit render rects for it.
            font_layout_and_draw_text(*editor.font, cast(string, viewport_view), *render_rects, *update_regions, offset, is_new_frame = true);
        }

        panel.clamp_scroll_to_cursor        = false;
        panel.clamp_scroll_to_start_of_line = false;
        panel.clamp_scroll_to_end_of_line   = false;
    }

    // TODO(jt): Instead of just drawing over what the panels drew, let's also use this information for culling?
    if editor.mini_panel.open {
        cell_w32 := cast(f32, cell_w);
        cell_h32 := cast(f32, cell_h);

        background_h := cast(f32, (MINI_PANEL_LINES + 1)) * cell_h32;
        background_y := cast(f32, max(input.window_size.y - background_h, 0));

        window_w := cast(f32, input.window_size.x);
        window_h := cast(f32, input.window_size.y);

        draw_rect(*render_rects, 0, background_y, window_w, window_h, { 0.96, 0.96, 0.96, 1.0 });

        if editor.mini_panel.active_thing_index == -1 {
            draw_rect(*render_rects, 0, background_y, window_w, background_y + cell_h32, COLOR_SELECTION);
        }

        ACTION_TEXT_SEARCH :: "Search: ";
        action_text := ACTION_TEXT_SEARCH;

        line_view := text_buffer_make_view_for_line(editor.mini_panel.buffer, 0,, temp);
        cursor_x := cast(f32, font_compute_position_on_line(editor.font, action_text, action_text.count));
        cursor_x += cast(f32, font_compute_position_on_line(editor.font, line_view, editor.mini_panel.buffer.cursor0.x));

        draw_rect(*render_rects, cursor_x, background_y, cursor_x + cell_w32, background_y + cell_h32, COLOR_CURSOR);

        main_line := tprint("%%", action_text, line_view);

        font_layout_and_draw_text(*editor.font, main_line, *render_rects, *update_regions, { 0, background_y }, is_new_frame = false);

        for editor.mini_panel.things {
            if it_index == editor.mini_panel.active_thing_index {
                y0 := background_y + (it_index + 1) * cell_h32;
                y1 := background_y + (it_index + 2) * cell_h32;

                draw_rect(*render_rects, 0, y0, window_w, y1, COLOR_SELECTION);
            }

            offset_y: f64 = background_y + (it_index + 1) * cell_h;
            font_layout_and_draw_text(*editor.font, it, *render_rects, *update_regions, { 0, offset_y }, is_new_frame = false);
        }
    }

    if editor.dev_show_atlas_texture {
        array_reset_keeping_memory(*render_rects);

        w := cast(f32, editor.font.glyph_atlas_width_in_pixels);
        h := cast(f32, editor.font.glyph_atlas_height_in_pixels);
        draw_rect(*render_rects, 0, 0, w, h, { 0.89, 0.89, 0.95, 1 });
        draw_rect(*render_rects, 0, 0, w, h, { 0, 0, 0, 1 }, TEXTURE_ID_GLYPH_ATLAS);
    }

    // Moved above the rendering code below, because OpenGL blocks and waits for surface, and we
    // don't want to time that. When we switch to a better driver, we can move this to the bottom.
    time_scale := profiler_end_frame();
    print_profile_for_slow_frames(SLOW_FRAME_THRESHOLD_MILLIS, time_scale);

    {
        renderer.update_texture_regions_r8unorm(TEXTURE_ID_GLYPH_ATLAS, update_regions, editor.font.glyph_atlas);
        renderer.draw_rects(render_rects);
    }

    return wants_quit, wants_next_frame;
}

#scope_file

route_event_to_mini_panel :: (mini_panel: *Mini_Panel, active_panel: *Panel, event: Input_Event, platform: Platform, input: Input, input_state: Input_State, cell_h: f32) {
    // TODO(jt): Do selecting in mini panel
    // TODO(jt): Do horizontal scroll in mini panel.
    if event.flags & .KEY_PRESSED {
        if event.type == {
            case .KEY; {
                if event.data.key == {
                    case .ARROW_UP;     mini_panel.active_thing_index = clamp(mini_panel.active_thing_index - 1, -1, mini_panel.things.count - 1);
                    case .ARROW_DOWN;   mini_panel.active_thing_index = clamp(mini_panel.active_thing_index + 1, -1, mini_panel.things.count - 1);
                    case .ARROW_LEFT;   text_buffer_move_cursor_x(*mini_panel.buffer, -1, false);
                    case .ARROW_RIGHT;  text_buffer_move_cursor_x(*mini_panel.buffer,  1, false);
                }
            }

            case .CODEPOINT; {
                codepoint := event.data.codepoint;

                if input_state.keys[Key.CTRL] & .DOWN {
                    if codepoint == {
                        case #char "p";  #through;
                        case #char "P";  mini_panel.active_thing_index = clamp(mini_panel.active_thing_index - 1, -1, mini_panel.things.count - 1);
                        case #char "n";  #through;
                        case #char "N";  mini_panel.active_thing_index = clamp(mini_panel.active_thing_index + 1, -1, mini_panel.things.count - 1);
                        case #char "b";  #through;
                        case #char "B";  text_buffer_move_cursor_x(*mini_panel.buffer, -1, false);
                        case #char "f";  #through;
                        case #char "F";  text_buffer_move_cursor_x(*mini_panel.buffer,  1, false);
                        case #char "a";  #through;
                        case #char "A";  text_buffer_move_cursor_to_start_of_line(*mini_panel.buffer, false);
                        case #char "e";  #through;
                        case #char "E";  text_buffer_move_cursor_to_end_of_line(*mini_panel.buffer, false);
                        case #char "d";  #through;
                        case #char "D";  text_buffer_delete_forward(*mini_panel.buffer);
                    }
                } else {
                    if codepoint == {
                        case .BACKSPACE;  text_buffer_delete_backward(*mini_panel.buffer);
                        case .DELETE;     text_buffer_delete_forward(*mini_panel.buffer);

                        case .ENTER; {
                            // XXX: Confirm selection. Context specific.
                        }

                        // TODO(jt): Make indentation configurable.
                        case .TAB;  text_buffer_insert(*mini_panel.buffer, " ");
                        case; {
                            // TODO(jt): @Speed This is a little dumb, because buffer will be parsing
                            // this back to codepoints for its linedata tracking. Add
                            // text_buffer_insert_utf32?
                            buf: [4] u8;
                            s: string;
                            s.data = buf.data;
                            Unicode.character_utf32_to_utf8(cast(u32, codepoint), *s);

                            if !string_starts_with_newline(s) {
                                text_buffer_insert(*mini_panel.buffer, s);
                            }
                        }
                    }
                }
            }
        }
    }
}

route_event_to_panel :: (panel: *Panel, event: Input_Event, platform: Platform, input: Input, input_state: Input_State, cell_h: f32) {
    // TODO(jt): Switch on panel type here: e.g. route_event_to_text_buffer_panel vs route_event_to_lister_panel.

    if event.flags & .KEY_PRESSED {
        if event.type == {
            case .KEY; {
                // We can't go into global selecting mode if shift is down, because many
                // Emacs-like shortcuts require shift. Therefore we only enable it for arrow
                // keys. If we selected something using shift selecting, we also turn off global
                // buffer selecting.
                shift_selecting := input_state.keys[Key.SHIFT] & .DOWN;

                if event.data.key == {
                    case .ARROW_UP;     text_buffer_move_cursor_y(*panel.buffer, -1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;
                    case .ARROW_DOWN;   text_buffer_move_cursor_y(*panel.buffer,  1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;
                    case .ARROW_LEFT;   text_buffer_move_cursor_x(*panel.buffer, -1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;
                    case .ARROW_RIGHT;  text_buffer_move_cursor_x(*panel.buffer,  1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;

                    case .PAGE_UP;      scroll_panel_up_one_screen(panel, input, cell_h);
                    case .PAGE_DOWN;    scroll_panel_down_one_screen(panel, input, cell_h);

                    case .HOME;         text_buffer_move_cursor_to_start(*panel.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
                    case .END;          text_buffer_move_cursor_to_end(*panel.buffer, panel.selecting);   panel.clamp_scroll_to_cursor = true;
                }
            }

            case .CODEPOINT; {
                if input_state.keys[Key.CTRL] & .DOWN && input_state.keys[Key.ALT] & .DOWN {
                    if event.data.codepoint == {
                        case #char "p";  #through;
                        case #char "P";  // TODO(jt): Swap line with previous.
                        case #char "n";  #through;
                        case #char "N";  // TODO(jt): Swap line with next.
                    }
                } else if input_state.keys[Key.CTRL] & .DOWN {
                    if event.data.codepoint == {
                        case #char "p";  #through;
                        case #char "P";  text_buffer_move_cursor_y(*panel.buffer, -1, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "n";  #through;
                        case #char "N";  text_buffer_move_cursor_y(*panel.buffer,  1, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "b";  #through;
                        case #char "B";  text_buffer_move_cursor_x(*panel.buffer, -1, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "f";  #through;
                        case #char "F";  text_buffer_move_cursor_x(*panel.buffer,  1, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "a";  #through;
                        case #char "A";  text_buffer_move_cursor_to_start_of_line(*panel.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "e";  #through;
                        case #char "E";  text_buffer_move_cursor_to_end_of_line(*panel.buffer, panel.selecting);   panel.clamp_scroll_to_cursor = true;
                        case #char "l";  #through;
                        case #char "L";  recenter_panel(panel, input, cell_h);
                        case #char "v";  #through;
                        case #char "V";  scroll_panel_down_one_screen(panel, input, cell_h);

                        case .SPACEBAR;  panel.selecting = true;  text_buffer_join_cursors(*panel.buffer);
                        case #char "g";  #through;
                        case #char "G";  panel.selecting = false; text_buffer_join_cursors(*panel.buffer);

                        case #char "k";  #through;
                        case #char "K"; {
                            panel.selecting = false;
                            text := text_buffer_delete_line(*panel.buffer);
                            if text {
                                platform.clipboard_set_text(text);
                            }
                        }
                        case #char "d";  #through;
                        case #char "D";  panel.selecting = false; text_buffer_delete_forward(*panel.buffer);

                        case #char "m";  #through;
                        case #char "M"; {
                            // TODO(jt): Preserve CRLF in CRLF-only documents.
                            panel.selecting = false;
                            text_buffer_insert(*panel.buffer, "\n", undo_barrier = true);
                            panel.clamp_scroll_to_cursor = true;
                        }
                        case #char "o";  #through;
                        case #char "O"; {
                            // TODO(jt): Preserve CRLF in CRLF-only documents.
                            panel.selecting = false;
                            text_buffer_insert(*panel.buffer, "\n", undo_barrier = true);
                            text_buffer_move_cursor_y(*panel.buffer, -1, false);
                            text_buffer_move_cursor_to_end_of_line(*panel.buffer, false);
                        }

                        case #char "/";  text_buffer_undo_edit(*panel.buffer); panel.clamp_scroll_to_cursor = true;

                        case #char "w";  #through;
                        case #char "W"; {
                            panel.selecting = false;
                            deleted := text_buffer_delete_between_cursors(*panel.buffer);
                            if deleted {
                                platform.clipboard_set_text(deleted);
                            }

                        }
                        case #char "y";  #through;
                        case #char "Y"; {
                            panel.selecting = false;
                            text := platform.clipboard_get_text(,, temp);
                            if text {
                                text_buffer_insert(*panel.buffer, text, undo_barrier = true);
                                panel.clamp_scroll_to_cursor = true;
                            }
                        }
                    }
                } else if input_state.keys[Key.ALT] & .DOWN {
                    if event.data.codepoint == {
                        // TODO(jt): C-M
                        case #char "p";  #through;
                        case #char "P";  text_buffer_move_cursor_to_previous_blank_line(*panel.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "n";  #through;
                        case #char "N";  text_buffer_move_cursor_to_next_blank_line(*panel.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char "b";  #through;
                        case #char "B"; {
                            panel.clamp_scroll_to_end_of_line |= text_buffer_move_cursor_to_previous_word_boundary(*panel.buffer, panel.selecting);
                            panel.clamp_scroll_to_cursor = true;
                        }
                        case #char "f";  #through;
                        case #char "F"; {
                            panel.clamp_scroll_to_start_of_line |= text_buffer_move_cursor_to_next_word_boundary(*panel.buffer, panel.selecting);
                            panel.clamp_scroll_to_cursor = true;
                        }

                        case .BACKSPACE; // TODO(jt): text_buffer_delete_until_previous_word_boundary.
                        case #char "d";  #through;
                        case #char "D";  // TODO(jt): text_buffer_delete_until_next_word_boundary.

                        case #char "v";  #through;
                        case #char "V";  scroll_panel_up_one_screen(panel, input, cell_h);

                        case #char "<";  text_buffer_move_cursor_to_start(*panel.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
                        case #char ">";  text_buffer_move_cursor_to_end(*panel.buffer, panel.selecting);   panel.clamp_scroll_to_cursor = true;

                        case #char "/";  text_buffer_redo_edit(*panel.buffer); panel.clamp_scroll_to_cursor = true;

                        case #char "w";  #through;
                        case #char "W";  {
                            panel.selecting = false;
                            text := text_buffer_make_view_between_cursors(panel.buffer, panel.buffer.cursor0, panel.buffer.cursor1,, temp);
                            if text {
                                platform.clipboard_set_text(text);
                            }

                            text_buffer_join_cursors(*panel.buffer);
                        }
                    }
                } else if input_state.keys[Key.META] & .DOWN {
                    // Nothing for now.
                } else {
                    panel.selecting = false;

                    codepoint := event.data.codepoint;
                    if codepoint == {
                        case .BACKSPACE;  text_buffer_delete_backward(*panel.buffer); panel.clamp_scroll_to_cursor = true;
                        case .DELETE;     text_buffer_delete_forward(*panel.buffer);  panel.clamp_scroll_to_cursor = true;

                        // TODO(jt): Make indentation configurable.
                        // TODO(jt): Preserve tab-ness in tab-only documents.
                        case .TAB;        text_buffer_insert(*panel.buffer, "    ");  panel.clamp_scroll_to_cursor = true;
                        case .SPACEBAR;   text_buffer_insert(*panel.buffer, " ");     panel.clamp_scroll_to_cursor = true;

                        // TODO(jt): Preserve CRLF in CRLF-only documents.
                        case .ENTER;      text_buffer_insert(*panel.buffer, "\n", undo_barrier = true); panel.clamp_scroll_to_cursor = true;

                        case; {
                            // TODO(jt): @Speed This is a little dumb, because buffer will be parsing
                            // this back to codepoints for its linedata tracking. Add
                            // text_buffer_insert_utf32?
                            buf: [4] u8;
                            s: string;
                            s.data = buf.data;
                            Unicode.character_utf32_to_utf8(cast(u32, codepoint), *s);

                            text_buffer_insert(*panel.buffer, s);
                            panel.clamp_scroll_to_cursor = true;
                        }
                    }
                }
            }
        }
    }
}

add_scratch_panel :: (editor: *Editor, platform: Platform) {
    ProfileZone("add_scratch_panel");

    arena_procs := make_arena_procs(platform);

    buffer_arena            := arena_allocate(arena_procs, reserve_size = 16 << 30);
    buffer_patch_text_arena := arena_allocate(arena_procs, reserve_size = 16 << 30);

    buffer: Text_Buffer;
    text_buffer_init(*buffer, buffer_arena, buffer_patch_text_arena);

    panel_index := editor.panels.count;
    panel := array_add(*editor.panels);

    panel.scroll_source = { 0, 0 };
    panel.scroll_target = { 0, 0 };
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes for e.g. to_float64_seconds.
    panel.scroll = { 0, 0 };

    panel.clamp_scroll_to_cursor = true; // Because we are inserting pontentially large text.
    panel.clamp_scroll_to_start_of_line = false;
    panel.clamp_scroll_to_end_of_line = false;

    panel.selecting = false;
    panel.buffer = buffer;

    // For -x64/-llvm and -sanity, 64KB is smooth, but it chokes on larger stuff.
    // For -optimized and -no-sanity, 256MB is smooth, and can go up to 1GB without being too choppy.
    HELLO_SIZE : s64 : 64 << 10;

    hello_arena := arena_allocate(arena_procs, reserve_size = 16 << 30);
    hello_text := make_hello_text(hello_arena, HELLO_SIZE);
    text_buffer_insert(*panel.buffer, hello_text, undo_barrier = true);
    arena_release(hello_arena);

    editor.active_panel_index = panel_index;
}

// TODO(jt): Add:   add_file_visiting_panel :: (editor: *Editor) {}

recenter_panel :: (panel: *Panel, input: Input, cell_h: f32) {
    cursor_y := panel.buffer.cursor0.y * cell_h;

    center := cursor_y - 0.5 * input.window_size.y;
    top    := cursor_y;
    bottom := cursor_y - input.window_size.y + cell_h;

    finish_scroll_interpolation(panel);

    if panel.scroll_target.y == center {
        panel.scroll_target.y = top;
    } else if panel.scroll_target.y == top {
        panel.scroll_target.y = bottom;
    } else {
        panel.scroll_target.y = center;
    }

    setup_scroll_interpolation(panel, input.time);
}

scroll_panel_up_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    delta_max := cast(s64, floor(input.window_size.y / cell_h));
    delta     := min(panel.buffer.cursor0.y, delta_max);

    text_buffer_move_cursor_y(*panel.buffer, -delta, panel.selecting);

    finish_scroll_interpolation(panel);
    if delta == delta_max {
        panel.scroll_target.y -= delta * cell_h;
        setup_scroll_interpolation(panel, input.time);
    }
}

scroll_panel_down_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    delta_max := cast(s64, floor(input.window_size.y / cell_h));
    delta     := min(panel.buffer.lines.count - 1 - panel.buffer.cursor0.y, delta_max);

    text_buffer_move_cursor_y(*panel.buffer, delta, panel.selecting);

    finish_scroll_interpolation(panel);
    if delta == delta_max {
        panel.scroll_target.y += delta * cell_h;
        setup_scroll_interpolation(panel, input.time);
    }
}

finish_scroll_interpolation :: (panel: *Panel) {
    panel.scroll_source = panel.scroll_target;
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes for e.g. to_float64_seconds.
    panel.scroll = panel.scroll_target;
}

setup_scroll_interpolation :: (panel: *Panel, time: Apollo_Time) {
    panel.scroll_target.x = max(panel.scroll_target.x, 0.0);
    panel.scroll_target.y = max(panel.scroll_target.y, 0.0);

    panel.scroll_source = panel.scroll;
    panel.scroll_time_start = time;
}

draw_rect :: (render_rects: *[..] Render_Rect, x0: f32, y0: f32, x1: f32, y1: f32, color: Vector4 = { 1, 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    inline draw_rect(render_rects, { x0, y0, x1, y1 }, color, texture);
}

draw_rect :: (render_rects: *[..] Render_Rect, rect: Rect, color: Vector4 = { 1, 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    rr := array_add(render_rects);
    rr.rect = rect;
    rr.texture_rect = { 0, 0, 1, 1 };
    rr.texture_id = texture;
    rr.color = color;
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

print_profile_for_slow_frames :: (threshold_millis: f64, time_scale: f64) {
    zones, zone_labels := profiler_get_zones(.INCLUSIVE_TIME,, temp);
    if zones.count {
        frame_time := 1000.0 * time_scale * zones[0].elapsed_inclusive;
        if frame_time >= threshold_millis {
            print("\nFrame took more than % millis. Printing profiling info for % zones:\n\n", threshold_millis, zones.count);

            print("      zone                                                               hits    inclusive millis    exclusive millis\n");
            print("---------------------------------------------------------------------------------------------------------------------\n");
            for zones {
                print(
                    "% %      %     %     %\n",
                    temp_right_pad(tprint("[%]", it_index), 5),
                    temp_right_pad(zone_labels[it_index], 50),
                    formatInt(it.hits, minimum_digits = 15, padding = #char " "),
                    formatFloat(1000 * time_scale * it.elapsed_inclusive, width = 15, trailing_width = 3),
                    formatFloat(1000 * time_scale * it.elapsed_exclusive, width = 15, trailing_width = 3),
                );
            }
        }
    }
}

make_hello_text :: (arena: *Arena, approx_size_in_bytes: s64) -> string {
    // TODO(jt): @CompilerBug (or Temporary_Storage bug) When we were making hello text more naively
    // (String_Builder + temp), we got crashes on macOS (Windows wasn't tested). Since then we
    // started making it in its own virtual memory arena.
    //
    // 2GB hello text crashed with:
    //
    // Got signal 10. Stack trace:
    // 0   editor                              0x0000000104d2109c handle_signal_b000001d9 + 1592
    // 1   libsystem_platform.dylib            0x000000019cc416a4 _sigtramp + 56
    // 2   editor                              0x0000000104d2e14c __procedure_1100000296 + 356
    // 3   editor                              0x0000000104d30470 init_700000380 + 1644
    // 4   editor                              0x0000000104d34778 __program_main + 1140
    // 5   editor                              0x0000000104d1e2d4 main + 608
    // 6   dyld                                0x000000019c866b98 start + 6076
    //
    // 3GB crashed with this message after showing the window and running a few frames.
    //
    // editor(52377,0x20aba2240) malloc: Region cookie corrupted for region 0xb6c000000 (value is 0)[0xb6c0081fc]
    // editor(52377,0x20aba2240) malloc: *** set a breakpoint in malloc_error_break to debug

    result_bytes: s64 = 0;

    s := arena_push_string(arena, HELLO_TEXT);
    assert(s.count > 0);
    assert(s.data != null);

    result_bytes += s.count;

    while result_bytes < approx_size_in_bytes {
        _s: string;

        _s = arena_push_string(arena, HELLO_SEPARATOR);
        assert(_s.count > 0);
        assert(_s.data != null);
        result_bytes += HELLO_SEPARATOR.count;

        _s = arena_push_string(arena, HELLO_TEXT);
        assert(_s.count > 0);
        assert(_s.data != null);
        result_bytes += HELLO_TEXT.count;
    }

    result: string;
    result.count = result_bytes;
    result.data = s.data;

    return result;
}

HELLO_SEPARATOR :: "\n========================================================\n\n";

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
straightens a straight watchband. 62.5 percent of the room's faces are directed my way, pleasantly expectant. My chest bumps like a
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

'The issues my office faces with the application materials on file from you, Hal, involve some test scores.' He glances down at
a colorful sheet of standardized scores in the trench his arms have made. 'The Admissions staff is looking at standardized test
scores from you that are, as I'm sure you know and can explain, are, shall we say ... subnormal.' I'm to explain.
It's clear that this really pretty sincere yellow Dean at left is Admissions. And surely the little aviarian figure at right is
Athletics, then, because the facial creases of the shaggy middle Dean are now pursed in a kind of distanced affront, an I'm-eating-
something-that-makes-me-really-appreciate-the-presence-of-whatever-I'm-drinking-along-with-it look that spells professionally
Academic reservations. An uncomplicated loyalty to standards, then, at center. My uncle looks to Athletics as if puzzled. He shifts
slightly in his chair.
The incongruity between Admissions's hand- and face-color is almost wild. '—verbal scores that are just quite a bit closer to
zero than we're comfortable with, as against a secondary-school transcript from the institution where both your mother and her
brother are administrators —' reading directly out of the sheaf inside his arms' ellipse — 'that this past year, yes, has fallen off a
bit, but by the word I mean "fallen off" to outstanding from three previous years of frankly incredible.’
'Off the charts.’
'Most institutions do not even have grades of A with multiple pluses after it,' says the Director of Composition, his expression
impossible to interpret.
'This kind of ... how shall I put it... incongruity,' Admissions says, his expression frank and concerned, 'I've got to tell you
sends up a red flag of potential concern during the admissions process.’
'We thus invite you to explain the appearance of incongruity if not outright shenanigans.' Students has a tiny piping voice
that's absurd coming out of a face this big.
'Surely by incredible you meant very very very impressive, as opposed to literally quote "incredible," surely,' says C.T.,
seeming to watch the coach at the window massaging the back of his neck. The huge window gives out on nothing more than
dazzling sunlight and cracked earth with heat-shimmers over it.
'Then there is before us the matter of not the required two but nine separate application essays, some of which of nearly
monograph-length, each without exception being —' different sheet — 'the adjective various evalua-tors used was quote "stellar"
—’

Dir. of Comp.: 'I made in my assessment deliberate use of lapidary and effete.’
'— but in areas and with titles, I'm sure you recall quite well, Hal: "Neoclassical Assumptions in Contemporary Prescriptive
Grammar," "The Implications of Post-Fourier Transformations for a Holographically Mimetic Cinema," "The Emergence of
Heroic Stasis in Broadcast Entertainment" —’
' "Montague Grammar and the Semantics of Physical Modality"?’
' "A Man Who Began to Suspect He Was Made of Glass"?’
' "Tertiary Symbolism in Justinian Erotica"?’
Now showing broad expanses of recessed gum. 'Suffice to say that there's some frank and candid concern about the recipient
of these unfortunate test scores, though perhaps explainable test scores, being these essays' sole individual author.’
'I'm not sure Hal's sure just what's being implied here,' my uncle says. The Dean at center is fingering his lapels as he
interprets distasteful computed data.
'What the University is saying here is that from a strictly academic point of view there are admission problems that Hal needs
to try to help us iron out. A matriculant's first role at the University is and must be as a student. We couldn't admit a student we
have reason to suspect can't cut the mustard, no matter how much of an asset he might be on the field.’
'Dean Sawyer means the court, of course, Chuck,' Athletic Affairs says, head severely cocked so he's including the White
person behind him in the address somehow. 'Not to mention O.N.A.N.C.A.A. regulations and investigators always snuffling
around for some sort of whiff of the smell of impropriety.’
The varsity tennis coach looks at his own watch.
'Assuming these board scores are accurate reflectors of true capacity in this case,' Academic Affairs says, his high voice
serious and sotto, still looking at the file before him as if it were a plate of something bad, Til tell you right now my opinion is it
wouldn't be fair. It wouldn't be fair to the other applicants. Wouldn't be fair to the University community.' He looks at me. 'And
it'd be especially unfair to Hal himself. Admitting a boy we see as simply an athletic asset would amount to just using that boy.
We're under myriad scrutiny to make sure we're not using anybody. Your board results, son, indicate that we could be accused of
using you.’
Uncle Charles is asking Coach White to ask the Dean of Athletic Affairs whether the weather over scores would be as heavy
if I were, say, a revenue-raising football prodigy. The familiar panic at feeling misperceived is rising, and my chest bumps and
thuds. I expend energy on remaining utterly silent in my chair, empty, my eyes two great pale zeros. People have promised to get
me through this.
Uncle C.T., though, has the pinched look of the cornered. His voice takes on an odd timbre when he's cornered, as if he were
shouting as he receded. 'Hal's grades at E.T.A., which is I should stress an Academy, not simply a camp or factory, accredited by
both the Commonwealth of Massachusetts and the North American Sports Academy Association, it's focused on the total needs of
the player and student, founded by a towering intellectual figure whom I hardly need name, here, and based by him on the
rigorous Oxbridge Quadrivium-Trivium curricular model, a school fully staffed and equipped, by a fully certified staff, should
show that my nephew here can cut just about any Pac 10 mustard that needs cutting, and that —’
DeLint is moving toward the tennis coach, who is shaking his head.
'— would be able to see a distinct flavor of minor-sport prejudice about this whole thing,' C.T. says, crossing and recrossing
his legs as I listen, composed and staring.
The room's carbonated silence is now hostile. T think it's time to let the actual applicant himself speak out on his own behalf,'
Academic Affairs says very quietly. 'This seems somehow impossible with you here, sir.’
Athletics smiles tiredly under a hand that massages the bridge of his nose. 'Maybe you'd excuse us for a moment and wait
outside, Chuck.’

'Coach White could accompany Mr. Tavis and his associate out to reception,' the yellow Dean says, smiling into my
unfocused eyes.
'— led to believe this had all been ironed out in advance, from the —' C.T. is saying as he and deLint are shown to the door.
The tennis coach extends a hypertrophied arm. Athletics says 'We're all friends and colleagues here.’
This is not working out. It strikes me that exit signs would look to a native speaker of Latin like red-lit signs that say HE
leaves. I would yield to the urge to bolt for the door ahead of them if I could know that bolting for the door is what the men in this
room would see. DeLint is murmuring something to the tennis coach. Sounds of keyboards, phone consoles as the door is briefly
opened, then firmly shut. I am alone among administrative heads.
'— offense intended to anyone,' Athletic Affairs is saying, his sportcoat tan and his necktie insigniated in tiny print — 'beyond
just physical abilities out there in play, which believe me we respect, want, believe me.’
'— question about it we wouldn't be so anxious to chat with you directly, see?’
'— that we've known in processing several prior applications through Coach White's office that the Enfield School is
operated, however impressively, by close relations of first your brother, who I can still remember the way White's predecessor
Maury Klamkin wooed that kid, so that grades' objectivity can be all too easily called into question —’
'By whomsoever's calling — N.A.A.U.P., ill-willed Pac 10 programs, O.N.A.N.C.A.A. —’
The essays are old ones, yes, but they are mine; de moi. But they are, yes, old, not quite on the application's instructed subject
of Most Meaningful Educational Experience Ever. If I'd done you one from the last year, it would look to you like some sort of
infant's random stabs on a keyboard, and to you, who use whomsoever as a subject. And in this new smaller company, the
Director of Composition seems abruptly to have actuated, emerged as both the Alpha of the pack here and way more effeminate
than he'd seemed at first, standing hip-shot with a hand on his waist, walking with a roll to his shoulders, jingling change as he
pulls up his pants as he slides into the chair still warm from C.T.'s bottom, crossing his legs in a way that inclines him well into
my personal space, so that I can see multiple eyebrow-tics and capillary webs in the oysters below his eyes and smell fabric-
softener and the remains of a breath-mint turned sour.
'. . . a bright, solid, but very shy boy, we know about your being very shy, Kirk White's told us what your athletically built if
rather stand-offish younger instructor told him,' the Director says softly, cupping what I feel to be a hand over my sportcoat's
biceps (surely not), 'who simply needs to swallow hard and trust and tell his side of the story to these gentlemen who bear no
maliciousness none at all but are doing our jobs and trying to look out for everyone's interests at the same time.’
I can picture deLint and White sitting with their elbows on their knees in the defecatory posture of all athletes at rest, deLint
staring at his huge thumbs, while C.T. in the reception area paces in a tight ellipse, speaking into his portable phone. I have been
coached for this like a Don before a RICO hearing. A neutral and affectless silence. The sort of all-defensive game Schtitt used to
have me play: the best defense: let everything bounce off you; do nothing. I'd tell you all you want and more, if the sounds I made
could be what you hear.
Athletics with his head out from under his wing: '— to avoid admission procedures that could be seen as primarily athletics-
oriented. It could be a mess, son.’
'Bill means the appearance, not necessarily the real true facts of the matter, which you alone can fill in,' says the Director of
Composition.
'— the appearance of the high athletic ranking, the subnormal scores, the over-academic essays, the incredible grades
vortexing out of what could be seen as a nepotistic situation.’
The yellow Dean has leaned so far forward that his tie is going to have a horizontal dent from the table-edge, his face sallow
and kindly and no-shit-whatever:
'Look here, Mr. Incandenza, Hal, please just explain to me why we couldn't be accused of using you, son. Why nobody couldcome and say to us, why, look here, University of Arizona, here you are using a boy for just his body, a boy so shy and withdrawn
he won't speak up for himself, a jock with doctored marks and a store-bought application.’
The Brewster's-Angle light of the tabletop appears as a rose flush behind my closed lids. I cannot make myself understood. 'I
am not just a jock,' I say slowly. Distinctly. 'My transcript for the last year might have been dickied a bit, maybe, but that was to
get me over a rough spot. The grades prior to that are de moi.' My eyes are closed; the room is silent. 'I cannot make myself
understood, now.' I am speaking slowly and distinctly. 'Call it something I ate.’
It's funny what you don't recall. Our first home, in the suburb of Weston, which I barely remember — my eldest brother Orin
says he can remember being in the home's backyard with our mother in the early spring, helping the Moms till some sort of garden
out of the cold yard. March or early April. The garden's area was a rough rectangle laid out with Popsicle sticks and twine. Orin
was removing rocks and hard clods from the Moms's path as she worked the rented Rototiller, a wheelbarrow-shaped, gas-driven
thing that roared and snorted and bucked and he remembers seemed to propel the Moms rather than vice versa, the Moms very tall
and having to stoop painfully to hold on, her feet leaving drunken prints in the tilled earth. He remembers that in the middle of the
tilling I came tear-assing out the door and into the backyard wearing some sort of fuzzy red Pooh-wear, crying, holding out
something he said was really unpleasant-looking in my upturned palm. He says I was around five and crying and was vividly red
in the cold spring air. I was saying something over and over; he couldn't make it out until our mother saw me and shut down the
tiller, ears ringing, and came over to see what I was holding out. This turned out to have been a large patch of mold — Orin posits
from some dark corner of the Weston home's basement, which was warm from the furnace and flooded every spring. The patch
itself he describes as horrific: darkly green, glossy, vaguely hirsute, speckled with parasitic fungal points of yellow, orange, red.
Worse, they could see that the patch looked oddly incomplete, gnawed-on; and some of the nauseous stuff was smeared around
my open mouth. 'I ate this,' was what I was saying. I held the patch out to the Moms, who had her contacts out for the dirty work,
and at first, bending way down, saw only her crying child, hand out, proffering; and in that most maternal of reflexes she, who
feared and loathed more than anything spoilage and filth, reached to take whatever her baby held out — as in how many used
heavy Kleenex, spit-back candies, wads of chewed-out gum in how many theaters, airports, backseats, tournament lounges? O.
stood there, he says, hefting a cold clod, playing with the Velcro on his puffy coat, watching as the Moms, bent way down to me,
hand reaching, her lowering face with its presbyopic squint, suddenly stopped, froze, beginning to I.D. what it was I held out,
countenancing evidence of oral contact with same. He remembers her face as past describing. Her outstretched hand, still
Rototrembling, hung in the air before mine.

'I ate this,' I said.
'Pardon me?’
O. says he can only remember (sic) saying something caustic as he lim-boed a crick out of his back. He says he must have felt
a terrible impending anxiety. The Moms refused ever even to go into the damp basement. I had stopped crying, he remembers, and
simply stood there, the size and shape of a hydrant, in red PJ's with attached feet, holding out the mold, seriously, like the report of
some kind of audit.
O. says his memory diverges at this point, probably as a result of anxiety. In his first memory, the Moms's path around the
yard is a broad circle of hysteria:
'God!' she calls out.
'Help! My son ate this!' she yells in Orin's second and more fleshed-out recollection, yelling it over and over, holding the
speckled patch aloft in a pincer of fingers, running around and around the garden's rectangle while O. gaped at his first real sight
of adult hysteria. Suburban neighbors' heads appeared in windows and over the fences, looking. O. remembers me tripping over
the garden's laid-out twine, getting up dirty, crying, trying to follow.
'God! Help! My son ate this! Help!' she kept yelling, running a tight pattern just inside the square of string; and my brother
Orin remembers noting how even in hysterical trauma her flight-lines were plumb, her footprints Native-American-straight, her
turns, inside the ideogram of string, crisp and martial, crying 'My son ate this! Help!' and lapping me twice before the memory
recedes.
'My application's not bought,' I am telling them, calling into the darkness of the red cave that opens out before closed eyes. 'I
am not just a boy who plays tennis. I have an intricate history. Experiences and feelings. I'm complex.
'I read,' I say. 'I study and read. I bet I've read everything you've read. Don't think I haven't. I consume libraries. I wear out
spines and ROM-drives. I do things like get in a taxi and say, "The library, and step on it." My instincts concerning syntax and
mechanics are better than your own, I can tell, with due respect.
'But it transcends the mechanics. I'm not a machine. I feel and believe. I have opinions. Some of them are interesting. I could,
if you'd let me, talk and talk. Let's talk about anything. I believe the influence of Kierkegaard on Camus is underestimated. I
believe Dennis Gabor may very well have been the Antichrist. I believe Hobbes is just Rousseau in a dark mirror. I believe, with
Hegel, that transcendence is absorption. I could interface you guys right under the table,' I say. 'I'm not just a creãtus,
manufactured, conditioned, bred for a function.’
I open my eyes. 'Please don't think I don't care.’
I look out. Directed my way is horror. I rise from the chair. I see jowls sagging, eyebrows high on trembling foreheads,
cheeks bright-white. The chair recedes below me.
'Sweet mother of Christ,' the Director says.
T'm fine,' I tell them, standing. From the yellow Dean's expression, there's a brutal wind blowing from my direction.
Academics' face has gone instantly old. Eight eyes have become blank discs that stare at whatever they see.
'Good God,' whispers Athletics.
'Please don't worry,' I say. 'I can explain.' I soothe the air with a casual hand.
Both my arms are pinioned from behind by the Director of Comp., who wrestles me roughly down, on me with all his weight.
I taste floor.
'What's wrong?’
I say 'Nothing is wrong.’'It's all right! I'm here!' the Director is calling into my ear.
'Get help!' cries a Dean.
My forehead is pressed into parquet I never knew could be so cold. I am arrested. I try to be perceived as limp and pliable.
My face is mashed flat; Comp.'s weight makes it hard to breathe.
'Try to listen,' I say very slowly, muffled by the floor.
'What in God's name are those . . .,' one Dean cries shrilly, '. . . those sounds?’
There are clicks of a phone console's buttons, shoes' heels moving, pivoting, a sheaf of flimsy pages falling.
'God!’
'Help!’
The door's base opens at the left periphery: a wedge of halogen hall-light, white sneakers and a scuffed Nunn Bush. 'Let him
up!' That's deLint.
'There is nothing wrong,' I say slowly to the floor. Tm in here.’
I'm raised by the crutches of my underarms, shaken toward what he must see as calm by a purple-faced Director: 'Get a grip,
son!’
DeLint at the big man's arm: 'Stop it!’
'I am not what you see and hear.’
Distant sirens. A crude half nelson. Forms at the door. A young Hispanic woman holds her palm against her mouth, looking.
'I'm not,' I say.
You have to love old-fashioned men's rooms: the citrus scent of deodorant disks in the long porcelain trough; the stalls with
wooden doors in frames of cool marble; these thin sinks in rows, basins supported by rickety alphabets of exposed plumbing;
mirrors over metal shelves; behind all the voices the slight sound of a ceaseless trickle, inflated by echo against wet porcelain and
a cold tile floor whose mosaic pattern looks almost Islamic at this close range.
The disorder I've caused revolves all around. I've been half-dragged, still pinioned, through a loose mob of Administrative
people by the Comp. Director — who appears to have thought variously that I am having a seizure (prying open my mouth to
check for a throat clear of tongue), that I am somehow choking (a textbook Heimlich that left me whooping), that I am
psychotically out of control (various postures and grips designed to transfer that control to him) — while about us roil deLint,
trying to restrain the Director's restraint of me, the varsity tennis coach restraining deLint, my mother's half-brother speaking in
rapid combinations of polysyllables to the trio of Deans, who variously gasp, wring hands, loosen neckties, waggle digits in C.T.'s
face, and make pases with sheafs of now-pretty-clearly-superfluous application forms.
I am rolled over supine on the geometric tile. I am concentrating docilely on the question why U.S. restrooms always appear
to us as infirmaries for public distress, the place to regain control. My head is cradled in a knelt Director's lap, which is soft, my
face being swabbed with dusty-brown institutional paper towels he received from some hand out of the crowd overhead, staring
with all the blankness I can summon into his jowls' small pocks, worst at the blurred jaw-line, of scarring from long-ago acne.
Uncle Charles, a truly unparalleled slinger of shit, is laying down an enfilade of same, trying to mollify men who seem way more
in need of a good brow-mopping than I.
'He's fine,' he keeps saying. 'Look at him, calm as can be, lying there.’
'You didn't see what happened in there,' a hunched Dean responds through a face webbed with fingers.
'Excited, is all he gets, sometimes, an excitable kid, impressed with —’
'But the sounds he made.’
'Undescribable.’
'Like an animal.’
'Subanimalistic noises and sounds.’
'Nor let's not forget the gestures.’
'Have you ever gotten help for this boy Dr. Tavis?’
'Like some sort of animal with something in its mouth.’
'This boy is damaged.’
'Like a stick of butter being hit with a mallet.’
'A writhing animal with a knife in its eye.’
'What were you possibly about, trying to enroll this —’
'And his arms.’
'You didn't see it, Tavis. His arms were —’
'Flailing. This sort of awful reaching drumming wriggle. Waggling,' the group looking briefly at someone outside my sight
trying to demonstrate something.
'Like a time-lapse, a flutter of some sort of awful ... growth.’
'Sounded most of all like a drowning goat. A goat, drowning in something viscous.’
'This strangled series of bleats and —’
'Yes they waggled.’
'So suddenly a bit of excited waggling's a crime, now?’
'You, sir, are in trouble. You are in trouble.’
'His face. As if he was strangling. Burning. I believe I've seen a vision of hell.’
'He has some trouble communicating, he's communicatively challenged, no one's denying that.’
'The boy needs care.’
'Instead of caring for the boy you send him here to enroll, compete?’
'Hal?’
'You have not in your most dreadful fantasies dreamt of the amount of trouble you have bought yourself, Dr. so-called
Headmaster, educator.’'. . . were given to understand this was all just a formality. You took him aback, is all. Shy —’
'And you, White. You sought to recruit him!’
'— and terribly impressed and excited, in there, without us, his support system, whom you asked to leave, which if you'd —’
'I'd only seen him play. On court he's gorgeous. Possibly a genius. We had no idea. The brother's in the bloody NFL for God's
sake. Here's a top player, we thought, with Southwest roots. His stats were off the chart. We watched him through the whole
WhataBurger last fall. Not a waggle or a noise. We were watching ballet out there, a mate remarked, after.’
'Damn right you were watching ballet out there, White. This boy is a balletic athlete, a player.’
'Some kind of athletic savant then. Balletic compensation for deep problems which you sir choose to disguise by muzzling the
boy in there.' An expensive pair of Brazilian espadrilles goes by on the left and enters a stall, and the espadrilles come around and
face me. The urinal trickles behind the voices' small echoes.
'— haps we'll just be on our way,' C.T. is saying.
'The integrity of my sleep has been forever compromised, sir.’
'— think you could pass off a damaged applicant, fabricate credentials and shunt him through a kangaroo-interview and inject
him into all the rigors of college life?’
'Hal here functions, you ass. Given a supportive situation. He's fine when he's by himself. Yes he has some trouble with
excitability in conversation. Did you once hear him try to deny that?’
'We witnessed something only marginally mammalian in there, sir.’
'Like hell. Have a look. How's the excitable little guy doing down there, Aubrey, does it look to you?’
'You, sir, are quite possibly ill. This affair is not concluded.’
'What ambulance? Don't you guys listen? I'm telling you there's —’
'Hal? Hal?’
'Dope him up, seek to act as his mouthpiece, muzzling, and now he lies there catatonic, staring.’
The crackle of deLint's knees. 'Hal?’
'— inflate this publicly in any distorted way. The Academy has distinguished alumni, litigators at counsel. Hal here is
provably competent. Credentials out the bazoo, Bill. The boy reads like a vacuum. Digests things.’
I simply lie there, listening, smelling the paper towel, watching an es-padrille pivot.

'There's more to life than sitting there interfacing, it might be a newsflash to you.’
And who could not love that special and leonine roar of a public toilet?
Not for nothing did Orin say that people outdoors down here just scuttle in vectors from air conditioning to air conditioning.
The sun is a hammer. I can feel one side of my face start to cook. The blue sky is glossy and fat with heat, a few thin cirri sheared
to blown strands like hair at the rims. The traffic is nothing like Boston. The stretcher is the special type, with restraining straps at
the extremities. The same Aubrey deLint I'd dismissed for years as a 2-D martinet knelt gurneyside to squeeze my restrained hand
and say 'Just hang in there, Buckaroo,' before moving back into the administrative fray at the ambulance's doors. It is a special
ambulance, dispatched from I'd rather not dwell on where, with not only paramedics but some kind of psychiatric M.D. on board.
The medics lift gently and are handy with straps. The M.D., his back up against the ambulance's side, has both hands up in
dispassionate mediation between the Deans and C.T., who keeps stabbing skyward with his cellular's antenna as if it were a sabre,
outraged that I'm being needlessly ambulanced off to some Emergency Room against my will and interests. The issue whether the
damaged even have interested wills is shallowly hashed out as some sort of ultra-mach fighter too high overhead to hear slices the
sky from south to north. The M.D. has both hands up and is patting the air to signify dispassion. He has a big blue jaw. At the only
other emergency room I have ever been in, almost exactly one year back, the psychiatric stretcher was wheeled in and then parked
beside the waiting-room chairs. These chairs were molded orange plastic; three of them down the row were occupied by different
people all of whom were holding empty prescription bottles and perspiring freely. This would have been bad enough, but in the
end chair, right up next to the strap-secured head of my stretcher, was a T-shirted woman with barnwood skin and a trucker's cap
and a bad starboard list who began to tell me, lying there restrained and immobile, about how she had seemingly overnight
suffered a sudden and anomalous gigantism in her right breast, which she referred to as a titty; she had an almost parodic
Québecois accent and described the 'titty's' presenting history and possible diagnoses for almost twenty minutes before I was
rolled away. The jet's movement and trail seem incisionish, as if white meat behind the blue were exposed and widening in the
wake of the blade. I once saw the word KNIFE finger-written on the steamed mirror of a nonpublic bathroom. I have become an
infantophile. I am forced to roll my closed eyes either up or to the side to keep the red cave from bursting into flames from the
sunlight. The street's passing traffic is constant and seems to go 'Hush, hush, hush.' The sun, if your fluttering eye catches it even
slightly, gives you the blue and red floaters a flashbulb gives you. 'Why not? Why not? Why not not, then, if the best reasoning
you can contrive is why not?' C.T.'s voice, receding with outrage. Only the gallant stabs of his antenna are now visible, just inside
my sight's right frame. I will be conveyed to an Emergency Room of some kind, where I will be detained as long as I do not
respond to questions, and then, when I do respond to questions, I will be sedated; so it will be inversion of standard travel, the
ambulance and ER: I'll make the journey first, then depart. I think very briefly of the late Cosgrove Watt. I think of the
hypophalangial Grief-Therapist. I think of the Moms, alphabetizing cans of soup in the cabinet over the microwave. Of Himself's
umbrella hung by its handle from the edge of the mail table just inside the Headmaster's House's foyer. The bad ankle hasn't ached
once this whole year. I think of John N. R. Wayne, who would have won this year's WhataBurger, standing watch in a mask as
Donald Gately and I dig up my father's head. There's very little doubt that Wayne would have won. And Venus Williams owns a
ranch outside Green Valley; she may well attend the 18's Boys' and Girls' finals. I will be out in plenty of time for tomorrow's
semi; I trust Uncle Charles. Tonight's winner is almost sure to be Dymphna, sixteen but with a birthday two weeks under the 15
April deadline; and Dymphna will still be tired tomorrow at 0830, while I, sedated, will have slept like a graven image. I have
never before faced Dymphna in tournament play, nor played with the sonic balls the blind require, but I watched him barely
dispatch Petropolis Kahn in the Round of 16, and I know he is mine. It will start in the E.R., at the intake desk if C.T.'s late in
following the ambulance, or in the green-tiled room after the room with the invasive-digital machines; or, given this special M.D.-
supplied ambulance, maybe on the ride itself: some blue-jawed M.D. scrubbed to an antiseptic glow with his name sewn incursive on his white coat's breast pocket and a quality desk-set pen, wanting gurneyside Q&A, etiology and diagnosis by Socratic
method, ordered and point-by-point. There are, by the O.E.D. VI's count, nineteen nonarchaic synonyms for unresponsive, of
which nine are Latinate and four Saxonic. I will play either Stice or Polep in Sunday's final. Maybe in front of Venus Williams. It
will be someone blue-collar and unlicensed, though, inevitably — a nurse's aide with quick-bit nails, a hospital security guy, a
tired Cuban orderly who addresses me as jou — who will, looking down in the middle of some kind of bustled task, catch what he
sees as my eye and ask So yo then man what's your story?

DONE;
