/*

TODO(jt): Stuff to do:

- [X] Implement Arena, or use Flat_Pool.
- [X] Display text on screen
- [X] Nice font rendering.

- [X] Gap Buffer (or other text datastructure)

- [X] Basic file navigation
- [X] Basic file editing
- [ ] Load file/Save file with file navigation in mini panel
- [ ] Find in mini panel
- [X] Cut/Copy/Paste
- [X] Undo!
- [ ] Panel splitting (we can move this to the fancy section)

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
#load "hello.jai";

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

// TODO(jt): @Cleanup Can we split this into its own file?
Mini_Panel :: struct {
    open: bool;

    buffer: Text_Buffer;

    action: Action;

    items_arena: *Arena;
    items: [..] string;
    item_index: s64;          // [0, items.count) to select a item, -1 to select the mini panel's buffer (if allowed by the action).
    items_need_update: bool;

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

    text_buffer_init(*editor.mini_panel.buffer, arena_allocate(arena_procs));

    editor.mini_panel.items_arena = arena_allocate(arena_procs);
    editor.mini_panel.items.allocator = arena_allocator(editor.mini_panel.items_arena);

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
                                    array_reset_keeping_memory(*editor.mini_panel.items);

                                    editor.mini_panel.action = .SEARCH;
                                    editor.mini_panel.items_need_update = true;
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

    if editor.mini_panel.open && editor.mini_panel.items_need_update {
        ProfileZone(":MiniPanelUpdate");

        array_reset(*editor.mini_panel.items);
        arena_reset(editor.mini_panel.items_arena);

        if editor.mini_panel.action == {
            case .SEARCH; {
                ProfileZone(":TextSearch");
                // TODO(jt): @Speed This is a very naive way to do this.
                // TODO(jt): auto_release_temp?

                if active_panel {
                    search_text := text_buffer_make_view_for_line(editor.mini_panel.buffer, 0,, temp);
                    for 0..active_panel.buffer.lines.count - 1 {
                        // TODO(jt): @Speed @Memory Instead of copying the string to temp and then maybe to the
                        // items arena, we can copy directly to items arena and pop/modify-last-push.
                        line_text := text_buffer_make_view_for_line(active_panel.buffer, it,, temp);
                        found := String.contains_nocase(line_text, search_text);
                        if found {
                            s := "";
                            if line_text.count {
                                s = arena_push_string(editor.mini_panel.items_arena, line_text);
                            }

                            array_add(*editor.mini_panel.items, s);
                        }
                    }
                }

                editor.mini_panel.items_need_update = false;
            }
        }
    }

    for * panel: editor.panels {
        ProfileZone(":PanelUpdateAndRender");

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
        ProfileZone(":MiniPanelRender");
        cell_w32 := cast(f32, cell_w);
        cell_h32 := cast(f32, cell_h);

        background_h := cast(f32, (MINI_PANEL_LINES + 1)) * cell_h32;
        background_y := cast(f32, max(input.window_size.y - background_h, 0));

        window_w := cast(f32, input.window_size.x);
        window_h := cast(f32, input.window_size.y);

        draw_rect(*render_rects, 0, background_y, window_w, window_h, { 0.96, 0.96, 0.96, 1.0 });

        if editor.mini_panel.item_index == -1 {
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

        index0 := max(editor.mini_panel.item_index - (MINI_PANEL_LINES / 2), 0);
        index1 := min(index0 + MINI_PANEL_LINES, editor.mini_panel.items.count - 1);

        it_index := 0;
        for index0..index1 {
            if it == editor.mini_panel.item_index {
                y0 := background_y + (it_index + 1) * cell_h32;
                y1 := background_y + (it_index + 2) * cell_h32;

                draw_rect(*render_rects, 0, y0, window_w, y1, COLOR_SELECTION);
            }

            offset_y: f64 = background_y + (it_index + 1) * cell_h;
            font_layout_and_draw_text(*editor.font, editor.mini_panel.items[it], *render_rects, *update_regions, { 0, offset_y }, is_new_frame = false);

            it_index += 1;
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
    min_item_index: s64;
    if mini_panel.action == {
        case .SEARCH;           min_item_index = 0;
        case .OPEN_FILE;        min_item_index = -1;
        case .SWITCH_TO_PANEL;  min_item_index = 0;
        case .CLOSE_PANEL;      min_item_index = 0;
    }

    // TODO(jt): Do selecting in mini panel
    // TODO(jt): Do animated horizontal scroll of buffer in mini panel.
    // TODO(jt): Do animated vertical scroll of item list in mini_panel.
    if event.flags & .KEY_PRESSED {
        if event.type == {
            case .KEY; {
                if event.data.key == {
                    case .ARROW_UP;     mini_panel.item_index = clamp(mini_panel.item_index - 1, min_item_index, mini_panel.items.count - 1);
                    case .ARROW_DOWN;   mini_panel.item_index = clamp(mini_panel.item_index + 1, min_item_index, mini_panel.items.count - 1);
                    case .ARROW_LEFT;   text_buffer_move_cursor_x(*mini_panel.buffer, -1, false);
                    case .ARROW_RIGHT;  text_buffer_move_cursor_x(*mini_panel.buffer,  1, false);
                }
            }

            case .CODEPOINT; {
                codepoint := event.data.codepoint;

                if input_state.keys[Key.CTRL] & .DOWN {
                    if codepoint == {
                        case #char "p";  #through;
                        case #char "P";  mini_panel.item_index = clamp(mini_panel.item_index - 1, min_item_index, mini_panel.items.count - 1);
                        case #char "n";  #through;
                        case #char "N";  mini_panel.item_index = clamp(mini_panel.item_index + 1, min_item_index, mini_panel.items.count - 1);
                        case #char "b";  #through;
                        case #char "B";  text_buffer_move_cursor_x(*mini_panel.buffer, -1, false);
                        case #char "f";  #through;
                        case #char "F";  text_buffer_move_cursor_x(*mini_panel.buffer,  1, false);
                        case #char "a";  #through;
                        case #char "A";  text_buffer_move_cursor_to_start_of_line(*mini_panel.buffer, false);
                        case #char "e";  #through;
                        case #char "E";  text_buffer_move_cursor_to_end_of_line(*mini_panel.buffer, false);
                        case #char "d";  #through;
                        case #char "D";  text_buffer_delete_forward(*mini_panel.buffer); mini_panel.items_need_update = true;

                        case #char "v";  #through;
                        case #char "V";  mini_panel.item_index = clamp(mini_panel.item_index + MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);
                    }
                } else if input_state.keys[Key.ALT] & .DOWN {
                    if codepoint == {
                        case #char "v";  #through;
                        case #char "V";  mini_panel.item_index = clamp(mini_panel.item_index - MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);

                        // TODO(jt): M-f, M-b.
                    }
                } else {
                    if codepoint == {
                        case .BACKSPACE;  text_buffer_delete_backward(*mini_panel.buffer); mini_panel.items_need_update = true;
                        case .DELETE;     text_buffer_delete_forward(*mini_panel.buffer);  mini_panel.items_need_update = true;

                        case .ENTER; {
                            // XXX: Confirm selection. Context specific. For search this means close
                            // mini panel and jump to match.
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
                                mini_panel.items_need_update = true;
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
