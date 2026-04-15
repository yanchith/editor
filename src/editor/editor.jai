/*

TODO(jt): Stuff to do:

- [X] Implement Arena, or use Flat_Pool.
- [X] Display text on screen
- [X] Nice font rendering.

- [X] Gap Buffer (or other text datastructure)

- [X] Basic file navigation
- [X] Basic file editing
- [X] Load file/Save file with file navigation in mini panel
- [X] Switching panel documents
- [X] Closing documents
- [X] Find in mini panel
- [X] Cut/Copy/Paste
- [X] Undo!
- [X] Messages
- [X] Modeline
- [X] Keymap support
- [ ] Find/replace and modal/interactive commands.
- [ ] Open non-utf8 text buffers and binary files in read only mode. Detecting is going be pain. We
      can do a few heuristics in the beginning (look for well known magic numbers), scan the first
      4k for zeroes, etc, but if none of these trigger, we still need to attempt parsing the file as
      UTF8 and bailing if that fails.

TODO(jt): @Stream things:

- [X] Draw item count and item indices in mini panel (e.g. '(5) Search: my_search_text' and '7: line containing my_search_text and stuff')
- [X] OPEN_FILE starts in the directory of the currently open document
- [X] OPEN_FILE, switch to buffer and close buffer get tab completions.
- [ ] Deduplicate path prefixes in SWITCH_TO_DOCUMENT and CLOSE_DOCUMENT
- [ ] M-d, C-<backspace> (delete word forward/backward)
- [ ] M-u, M-l (upcase/downcase word and move cursor)
- [ ] M-x
- [ ] M-g g (go to line)
- [ ] C-M-p, C-M-n (move line up/down)
- [ ] C-u C-<space> and cursor undo.
- [ ] Sticky cursor (navigate to the end of long line, move up/down to a shorter line, move back to the long line and cursor goes to its original place)
- [ ] Flash cursor with typing (needs tuning)
- [ ] Trail behind cursor (needs tuning)

TODO(jt): Fancy stuff to do:

- [ ] Panel tiling
- [ ] Themes
- [ ] Syntax Highlighting
- [ ] Syntax aware indentation (C-i)
- [ ] Syntax aware parentheses
- [ ] Multiple Cursors
- [ ] *compilation* buffer
- [ ] Projects (project settings, project compilations, project text search with jumping, project-wide find/replace)
- [ ] Emacs-like undo? (If I find out I can't live without)
- [ ] Emacs-like kill ring (If I find out I can't live without)
- [ ] Lister panels (dired, etc)
- [ ] if (0) and #if 0 behave like comments w.r.t. to highlighting.
- [ ] Font Kerning
- [ ] Very nice text rendering (Slug?)
- [ ] Git integration (via plugin?)
- [ ] 4coder style floating annotations? (e.g. name of the function or if statement expresion after closing brace)
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
#import "Bucket_Array";
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
#load "key_map.jai";
#load "font.jai";
#load "gap_buffer.jai";
#load "text_buffer.jai";
#load "hello.jai";

// ID 0 is reserved for the texture-less pipeline. The backend must switch to a texture-less shader
// if the texture wasn't uploaded (we don't upload TEXTURE_ID_NONE). We could also reserve a few
// pixels in the font atlas for color shading, but maybe we don't want to do that?
TEXTURE_ID_NONE        : Texture_ID : 0;
TEXTURE_ID_GLYPH_ATLAS : Texture_ID : 1;

CURSOR_COLOR          : Vector4 : { 0.5, 0.8, 0.6, 1.0 };
CURSOR_COLOR_ACTIVE   : Vector4 : { 1.0, 0.6, 0.4, 1.0 };
SELECTION_COLOR       : Vector4 : { 0.7, 0.8, 0.7, 0.38 };
LINE_COLOR            : Vector4 : { 0.0, 0.0, 0.0, 0.0 };
MINI_PANEL_LINE_COLOR : Vector4 : { 0.7, 0.7, 0.9, 0.18 };
MODELINE_COLOR        : Vector4 : { 0.8, 0.8, 0.8, 1.0 };
BACKGROUND_COLOR      : Vector4 : { 1.0, 1.0, 1.0, 1.0 };

SLOW_FRAME_THRESHOLD_MILLIS : f64 : 10;

MINI_PANEL_LINES :: 10; // TODO(jt): Make this configurable! :Config

Editor :: struct {
    perm_arena: *Arena;

    font: Font;
    font_size: s32; // Scaled!

    input_state: Input_State;

    key_map: Key_Map;

    // Documents are referenced by panels. A document can be referenced by multiple panels. When we
    // close a panel, or switch a panel to a different document, the original document remains. When
    // we close/unload a document, we need to go through every panel and make sure it does not
    // reference that document.
    documents: Bucket_Array(Document, 16);

    // :MultiplePanels
    //
    // Currently we have just the one panel, but this array is the preparation for having multiple
    // panels open (by splitting a viewport horizontally or vertically). We can start doing this by
    // implementing just vertical side-by-side splitting, which does not require any additional data
    // structures.
    //
    // TODO(jt): Do panel splitting and fix all places in code that rely on the panel covering the
    // entire window.
    panels: [..] Panel;
    active_panel_index: s64;

    mini_panel: Mini_Panel;

    messages: [..] string;
    last_message_seen: bool;

    dev_show_atlas_texture: bool;
}

Document :: struct {
    locator: Bucket_Locator;

    time_of_last_interaction: Apollo_Time;

    kind: Kind;
    buffer: Text_Buffer;

    // TODO(jt): Read-only flag.

    // The arena is currently just for backing_file_path. The buffer has its own arenas. I don't
    // like this, but maybe it will become clear what to do later, once we have more stuff here.
    arena: *Arena;

    // Newly created documents (and scratch documents) do not have a backing file until saved, at
    // which point a backing file path is assigned and file created. A document with a
    // backing_file_path can also be created without the file already existing, in which case
    // backing_file_exists gets set only after the file is first written to.
    backing_file_path: string;
    backing_file_exists: bool;

    Kind :: enum {
        SCRATCH;
        FILE;
    }

    //
    // Visuals
    //

    // Preserved at the start of each frame to find out if we have kick off cursor animation.
    old_cursor: Cursor;
    old_cursor_position: DVector2;

    cursor_anim_source: DVector2;
    cursor_anim_target: DVector2;
    cursor_anim_time_start: Apollo_Time;
    cursor_anim: DVector2;

    cursor_flash_source: Vector4;
    cursor_flash_target: Vector4;
    cursor_flash_time_start: Apollo_Time;
    cursor_flash: Vector4;
}

Panel :: struct {
    // Scroll vectors are f64, because buffers can be large and we actually ran into precision
    // issues with f32 vectors. Doubles suffice for now (verified up to 4GB of prose), but maybe we
    // should do our own numeric type eventually (either 58:6 fixed point or maybe s64 + f32 offset)?
    //
    // :FloatPrecision
    scroll_source: DVector2;
    scroll_target: DVector2;
    scroll_time_start: Apollo_Time;

    scroll: DVector2;

    // These clampers get set during event processing and unset after update. We could store them
    // somewhere else, but we need them for every panel we have touched, so they might as well be here.
    //
    // TODO(jt): Turn these into flags!
    clamp_scroll_to_cursor: bool;
    clamp_scroll_to_start_of_line: bool;
    clamp_scroll_to_end_of_line: bool;

    selecting: bool;

    document: *Document; // Possibly null!
}

// TODO(jt): @Cleanup Can we split this into its own file?
Mini_Panel :: struct {
    open: bool;

    key_map: Key_Map;
    buffer: Text_Buffer;

    // For now, this is an enum of things we might want to do, but this is not extensible. Once we
    // want to do a plugin architecture, we should replace the current procs that switch on the
    // action and call out to plugin procs there.
    //
    // :MiniPanelAPI
    action: Action;

    items_arena: *Arena;
    items: [..] Item;
    item_index: s64;          // [0, items.count) to select a item, -1 to select the mini panel's buffer (if allowed by the action).

    Action :: enum {
        SEARCH             :: 0;
        OPEN_FILE          :: 1;
        SWITCH_TO_DOCUMENT :: 2;
        CLOSE_DOCUMENT     :: 3;
    }

    Item :: struct {
        text: string;
        highlight_x0: s64;
        highlight_x1: s64;

        // The proc that fills these in can put things in here for the render proc or confirm proc.
        // If this is allocated, it should be put in the items_arena. However, it does not
        // necessarily need to be an allocation - you can use the 64-bits of the pointer itself to
        // store stuff.
        //
        // :MiniPanelAPI
        userdata: *void;
    }
}

init :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) {
    profiler_init();
    profiler_start_frame("init");

    editor.perm_arena = make_arena(platform, .LARGE);

    font_arena := make_arena(platform, .LARGE);
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

    // Editor key map
    {
        key_map := *editor.key_map;
        key_map.allocator = arena_allocator(editor.perm_arena);
        key_map_init(key_map, 128);

        key_map_register(key_map, "C-p",     .MOVE_UP);
        key_map_register(key_map, "<up>",    .MOVE_UP);
        key_map_register(key_map, "C-n",     .MOVE_DOWN);
        key_map_register(key_map, "<down>",  .MOVE_DOWN);
        key_map_register(key_map, "C-b",     .MOVE_LEFT);
        key_map_register(key_map, "<left>",  .MOVE_LEFT);
        key_map_register(key_map, "C-f",     .MOVE_RIGHT);
        key_map_register(key_map, "<right>", .MOVE_RIGHT);

        key_map_register(key_map, "C-s",     .SEARCH);
        key_map_register(key_map, "C-x C-f", .OPEN_FILE);
        key_map_register(key_map, "C-x C-s", .SAVE_FILE);
        key_map_register(key_map, "C-x b",   .SWITCH_TO_DOCUMENT);
        key_map_register(key_map, "C-x k",   .CLOSE_DOCUMENT);

        key_map_register(key_map, "C-M-p",   .SWAP_LINE_UP);
        key_map_register(key_map, "C-M-n",   .SWAP_LINE_DOWN);

        key_map_register(key_map, "C-a",     .MOVE_TO_START_OF_LINE);
        key_map_register(key_map, "C-e",     .MOVE_TO_END_OF_LINE);

        key_map_register(key_map, "M-<",     .MOVE_TO_START_OF_DOCUMENT);
        key_map_register(key_map, "<home>",  .MOVE_TO_START_OF_DOCUMENT);
        key_map_register(key_map, "M->",     .MOVE_TO_END_OF_DOCUMENT);
        key_map_register(key_map, "<end>",   .MOVE_TO_END_OF_DOCUMENT);

        key_map_register(key_map, "M-p",     .MOVE_TO_PREVIOUS_BLANK_LINE);
        key_map_register(key_map, "M-n",     .MOVE_TO_NEXT_BLANK_LINE);

        key_map_register(key_map, "M-f",     .MOVE_FORWARD_WORD);
        key_map_register(key_map, "M-b",     .MOVE_BACKWARD_WORD);

        key_map_register(key_map, "C-l",     .RECENTER);
        key_map_register(key_map, "M-v",     .SCROLL_UP);
        key_map_register(key_map, "C-v",     .SCROLL_DOWN);
        key_map_register(key_map, "<pageup>", .SCROLL_UP);
        key_map_register(key_map, "<pagedown>", .SCROLL_DOWN);
        key_map_register(key_map, "<prior>", .SCROLL_UP);
        key_map_register(key_map, "<next>",  .SCROLL_DOWN);

        key_map_register(key_map, "C-<space>", .START_SELECTING);
        key_map_register(key_map, "C-g",     .STOP_SELECTING);

        key_map_register(key_map, "C-k",     .DELETE_LINE);
        key_map_register(key_map, "C-d",     .DELETE_FORWARD);
        key_map_register(key_map, "<backspace>", .DELETE_BACKWARD);
        key_map_register(key_map, "<delete>", .DELETE_FORWARD);

        key_map_register(key_map, "M-d",     .DELETE_FORWARD_WORD);
        key_map_register(key_map, "C-<backspace>", .DELETE_BACKWARD_WORD);
        key_map_register(key_map, "M-<backspace>", .DELETE_BACKWARD_WORD);

        key_map_register(key_map, "C-m",     .INSERT_LINE_BEFORE);
        key_map_register(key_map, "<enter>", .INSERT_LINE_BEFORE);
        key_map_register(key_map, "C-o",     .INSERT_LINE_AFTER);

        key_map_register(key_map, "<tab>",   .INSERT_TAB);

        key_map_register(key_map, "C-/",     .UNDO_EDIT);
        key_map_register(key_map, "M-/",     .REDO_EDIT);

        key_map_register(key_map, "M-w",     .COPY);
        key_map_register(key_map, "C-w",     .CUT);
        key_map_register(key_map, "C-y",     .PASTE);

        log("Document keymap:\n%", key_map_sprint(key_map,, temp));
    }


    editor.documents.allocator = arena_allocator(editor.perm_arena);
    editor.panels.allocator    = arena_allocator(editor.perm_arena);

    panel := array_add(*editor.panels);
    set_panel_document_to_newly_created_scratch(editor, panel, platform);

    //
    // Init mini panel
    //
    {
        mini_panel := *editor.mini_panel;
        key_map    := *mini_panel.key_map;

        key_map.allocator = arena_allocator(editor.perm_arena);
        key_map_init(key_map, 128);

        key_map_register(key_map, "C-p",         .MINI_PANEL_MOVE_UP);
        key_map_register(key_map, "C-n",         .MINI_PANEL_MOVE_DOWN);
        key_map_register(key_map, "C-b",         .MINI_PANEL_MOVE_LEFT);
        key_map_register(key_map, "C-f",         .MINI_PANEL_MOVE_RIGHT);
        key_map_register(key_map, "<up>",        .MINI_PANEL_MOVE_UP);
        key_map_register(key_map, "<down>",      .MINI_PANEL_MOVE_DOWN);
        key_map_register(key_map, "<left>",      .MINI_PANEL_MOVE_LEFT);
        key_map_register(key_map, "<right>",     .MINI_PANEL_MOVE_RIGHT);

        key_map_register(key_map, "M-f",         .MINI_PANEL_MOVE_FORWARD_WORD);
        key_map_register(key_map, "M-b",         .MINI_PANEL_MOVE_BACKWARD_WORD);

        key_map_register(key_map, "C-a",         .MINI_PANEL_MOVE_TO_START_OF_LINE);
        key_map_register(key_map, "C-e",         .MINI_PANEL_MOVE_TO_END_OF_LINE);

        key_map_register(key_map, "C-d",         .MINI_PANEL_DELETE_FORWARD);
        key_map_register(key_map, "<delete>",    .MINI_PANEL_DELETE_FORWARD);
        key_map_register(key_map, "<backspace>", .MINI_PANEL_DELETE_BACKWARD);

        key_map_register(key_map, "M-v",         .MINI_PANEL_SCROLL_UP);
        key_map_register(key_map, "C-v",         .MINI_PANEL_SCROLL_DOWN);

        key_map_register(key_map, "<tab>",       .MINI_PANEL_AUTOCOMPLETE);

        key_map_register(key_map, "<enter>",     .MINI_PANEL_CONFIRM);
        key_map_register(key_map, "C-m",         .MINI_PANEL_CONFIRM);

        key_map_register(key_map, "C-g",         .MINI_PANEL_CANCEL);

        log("Mini Panel keymap:\n%", key_map_sprint(key_map,, temp));

        // Mini text buffer gets its own arena, because it survives longer than the items.
        text_buffer_init(*mini_panel.buffer, make_arena(platform, .SMALL));

        mini_panel.items_arena = make_arena(platform, .LARGE);
        mini_panel.items.allocator = arena_allocator(mini_panel.items_arena);
    }

    editor.messages.allocator = arena_allocator(editor.perm_arena);


    renderer.create_texture_r8unorm(
        TEXTURE_ID_GLYPH_ATLAS,
        editor.font.glyph_atlas,
        editor.font.glyph_atlas_width_in_pixels,
        editor.font.glyph_atlas_height_in_pixels,
    );

    time_scale := profiler_end_frame();
    print_profile_for_slow_frames(SLOW_FRAME_THRESHOLD_MILLIS, time_scale);
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> wants_quit: bool, wants_next_frame: bool {
    profiler_start_frame("update_and_render");

    // @Hack to constrain DT from sleeping frames. However, we should only be using DT in situations
    // where we are already animating. Can we get rid of this, perhaps by framing the computations differently?
    dt := min(to_float64_seconds(input.dtime), 0.33);

    wants_quit       := false;
    wants_next_frame := false;

    render_rects: [..] Render_Rect;
    render_rects.allocator = temp;
    update_regions: [..] IRect;
    update_regions.allocator = temp;

    input_state_update_on_frame_start(*editor.input_state, input);

    // We do this for every panel instead of every document, so we don't unnecessarily compute the
    // positions for documents we do not see.
    for * editor.panels {
        if it.document.old_cursor != it.document.buffer.cursor0 {
            it.document.old_cursor = it.document.buffer.cursor0;
            it.document.old_cursor_position = get_cursor_position(it.document, editor.font);
        }

        if it.document.cursor_anim_time_start == Apollo_Time.{ 0, 0 } {
            setup_cursor_anim_interpolation(it.document, input.time, it.document.old_cursor_position, it.document.old_cursor_position);
        }
    }

    // Currently, there must always be at least one panel (and it must be active).
    active_panel: *Panel = get_active_panel(editor);
    assert(active_panel != null);

    for input.events {
        handled := false;

        input_state_update_with_event(*editor.input_state, it);

        //
        // Global events handled at the editor level.
        //
        if it.flags & .PRESSED {
            editor.last_message_seen = true;

            if it.type == {
                case .KEY; {
                    if it.data.key == {
                        case .F1;  editor.dev_show_atlas_texture = !editor.dev_show_atlas_texture; handled = true;
                    }
                }

                case .CODEPOINT; {
                    if editor.input_state.modifiers & .CTRL {
                        if it.data.codepoint == {
                            // TODO(jt): Move this to a global keymap.
                            //
                            // TODO(jt): This works a little too well on Windows, we don't even need
                            // to press shift for the +. The problem is that Windows doesn't send us
                            // the TEXT_INPUT (WM_CHAR/WM_SYSCHAR) event at all if CTRL is down, so
                            // we are left with our shitty synthetic TEXT_INPUT in main.jai. We
                            // could try translating the message without the CTRL and then glueing
                            // the CTRL back in? I don't know.
                            case #char "+";  editor.font_size += 1; handled = true;
                            case #char "-";  editor.font_size = max(editor.font_size - 1, 4); handled = true;
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
                route_event_to_mini_panel(editor, it, platform, input);
            } else {
                route_event_to_panel(editor, it, platform, input);
            }
        }
    }

    if editor.input_state.modifiers & .CTRL {
        delta: s32;
        if input.mouse_wheel_delta > 0 then delta = 1;
        if input.mouse_wheel_delta < 0 then delta = -1;
        editor.font_size = max(editor.font_size + delta, 4);
    }

    {
        physical_pixel_height := cast(s32, ceil(editor.font_size * input.window_scale_factor));
        if editor.font.pixel_height != physical_pixel_height {
            editor_log(editor, "Resetting font to new physical pixel height: %", physical_pixel_height);
            font_reset_for_pixel_height(*editor.font, physical_pixel_height);

            for * editor.panels {
                it.clamp_scroll_to_cursor = true;
            }
        }
    }

    // cell_w and cell_h are 32-bit and that's perfectly reasonable for them, but some text
    // documents are big. Beware multiplying cell_W and cell_h with integers (such as line count),
    // as that autocasts the integers to f32, but we want to manually cast them to f64. See :FloatPrecision
    //
    // TODO(jt): cell_w should be width of letter M or something, because width of widest glyph is
    // too much in variable-spaced fonts.
    cell_w := editor.font.max_glyph_width_in_pixels;
    cell_h := editor.font.line_height_in_pixels;
    window_w := cast(f32, input.window_size.x);
    window_h := cast(f32, input.window_size.y);

    if editor.mini_panel.open {
        // TODO(jt): Handle mouse in mini panel?
    } else {
        // TODO(jt): Mouse stuff should activate the clicked panel! See :MultiplePanels

        //
        // Mouse wheel scrolling
        //
        if input.mouse_wheel_delta != 0 && !(editor.input_state.modifiers & .CTRL) {
            // TODO(jt): This is choppy on macOS touchpad scrolling. Get underlying float scroll value?
            active_panel.scroll_target.y -= cast(f64, input.mouse_wheel_delta);
            active_panel.scroll_target.y = clamp(active_panel.scroll_target.y, 0, cell_h * cast(f64, active_panel.document.buffer.lines.count - 1));
            finish_scroll_interpolation(active_panel);
        }

        //
        // Mouse Selection
        //
        // TODO(jt): Double click to select word.
        // TODO(jt): Triple click to select line.
        //
        if editor.input_state.keys[Key.MB_LEFT] & .DOWN {
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
                } else if mouse.x > window_w - SCROLL_APRON {
                    boost := (mouse.x - (window_w - SCROLL_APRON)) * SCROLL_BOOST;

                    // Apron contains the newline (if present) and one additional horizontal cell.
                    apron := 2 * cell_w;

                    line_view := text_buffer_make_view_for_line(active_panel.document.buffer, active_panel.document.buffer.cursor0.y,, temp);

                    // Clamp to zero, so we don't end up scrolling the other way if the line is
                    // short. (Happens if you start scrolling on a long line, but then vertically
                    // scroll to a short line.)
                    max_x := max(font_compute_position_on_line(editor.font, line_view, active_panel.document.buffer.cursor0.x) - window_w + apron, 0);

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
                } else if mouse.y > window_h - SCROLL_APRON {
                    boost := (mouse.y - (window_h - SCROLL_APRON)) * SCROLL_BOOST;

                    active_panel.scroll_target.y += SCROLL_SPEED * boost * dt;
                    active_panel.scroll_target.y = min(active_panel.scroll_target.y, cell_h * cast(f64, active_panel.document.buffer.lines.count - 1));
                    finish_scroll_interpolation(active_panel);

                    wants_next_frame = true;
                }
            }

            row := cast(s64, floor((mouse.y + active_panel.scroll.y) / cell_h));
            col := 0;

            if row < 0 {
                row = 0;
                col = 0;
            } else if row > active_panel.document.buffer.lines.count - 1 {
                row = active_panel.document.buffer.lines.count - 1;

                // Include newline, so that the cursor can go there.
                line_view := text_buffer_make_view_for_line(active_panel.document.buffer, row, include_newline = true,, temp);
                col = font_compute_character_index_on_line(editor.font, line_view, mouse.x + active_panel.scroll.x);
            } else {
                // Include newline, so that the cursor can go there.
                line_view := text_buffer_make_view_for_line(active_panel.document.buffer, row, include_newline = true,, temp);
                col = font_compute_character_index_on_line(editor.font, line_view, mouse.x + active_panel.scroll.x);
            }

            text_buffer_move_cursor_to(*active_panel.document.buffer, col, row, !(editor.input_state.keys[Key.MB_LEFT] & .PRESSED));
        }
    }

    for * panel: editor.panels {
        ProfileZone(":PanelUpdateAndRender");

        document := panel.document;
        if !document {
            // TODO(jt): Draw something in empty panels?
            continue;
        }

        panel_w := window_w;
        panel_h := window_h - 2 * cell_h; // 2*cell_h is the mode line and message line.
        if editor.mini_panel.open {
            // Currently, this only affects the culling.
            //
            // TODO(jt): In Emacs, this would also modify the scroll offset, if the cursor would be
            // occluded by the newly visible mini panel. Should we do that?
            panel_h = window_h - (2 + MINI_PANEL_LINES) * cell_h;
        }

        //
        // Compute cursor position.
        //
        buffer_cursor0_position: DVector2;
        buffer_cursor0_line_end_x: f64;
        {
            c0_line_start, c0_line_end := text_buffer_get_cursors_for_line(document.buffer, document.buffer.cursor0.y);
            c0_line_view := text_buffer_make_view_between_cursors(document.buffer, c0_line_start, c0_line_end,, temp);

            buffer_cursor0_position.x = font_compute_position_on_line(editor.font, c0_line_view, document.buffer.cursor0.x);
            buffer_cursor0_position.y = cast(f64, document.buffer.cursor0.y) * cell_h;
            buffer_cursor0_line_end_x = font_compute_position_on_line(editor.font, c0_line_view, c0_line_end.x);
        }

        //
        // Scroll buffer to cursor, if buffer changed. Clamp cursor to buffer, if buffer scrolled.
        //
        if panel.clamp_scroll_to_cursor || panel.clamp_scroll_to_start_of_line || panel.clamp_scroll_to_end_of_line {
            ProfileZone(":ClampScroll");

            SCROLL_PADDING_CELLS_X :: 3; // TODO(jt): Make this configurable. I don't like having this, so I turned it off. :Config
            SCROLL_PADDING_CELLS_Y :: 3; // TODO(jt): Make this configurable. I don't like having this, so I turned it off. :Config
            scroll_padding_x := min(panel_w * 0.25, cell_w * SCROLL_PADDING_CELLS_X);
            scroll_padding_y := min(panel_h * 0.25, cell_h * SCROLL_PADDING_CELLS_Y);

            cursor0 := document.buffer.cursor0;

            // TODO(jt): Compute a viewport for panel instead that takes into account splitting. See :MultiplePanels
            viewport_rect := drect_from_point_and_size(panel.scroll_target.x, panel.scroll_target.y, panel_w, panel_h);
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
                panel.scroll_target.x = scroll_to_rect.x0 - panel_w + drect_width(scroll_to_rect) + scroll_padding_x;
                setup_scroll_interpolation(panel, input.time);
            } else if scroll_to_rect.x0 < viewport_rect.x0 {
                finish_scroll_interpolation(panel);
                panel.scroll_target.x = scroll_to_rect.x0 - scroll_padding_x;
                setup_scroll_interpolation(panel, input.time);
            }

            if scroll_to_rect.y1 > viewport_rect.y1 {
                finish_scroll_interpolation(panel);
                panel.scroll_target.y = scroll_to_rect.y0 - panel_h + drect_height(scroll_to_rect) + scroll_padding_y;
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
            SCROLL_TIME : f64 : 0.08;

            t := cast(f32, (to_float64_seconds(input.time) - to_float64_seconds(panel.scroll_time_start)) / SCROLL_TIME);
            t = clamp(t, 0.0, 1.0);
            t = smoothstep(0.0, 1.0, t);

            panel.scroll = lerp(panel.scroll_source, panel.scroll_target, t);

            if t < 1.0 {
                wants_next_frame = true;
            }
        }

        // Now that we have finished scrolling, we can define the range that the viewport sees.
        //
        // TODO(jt): Compute a viewport for panel instead that takes into account splitting. See :MultiplePanels
        viewport_y0 := panel.scroll.y;
        viewport_y1 := panel.scroll.y + panel_h;

        //
        // Layout and draw selection
        //
        if document.buffer.cursor0 != document.buffer.cursor1 {
            cursor_start := text_buffer_get_min_cursor(document.buffer);
            cursor_end   := text_buffer_get_max_cursor(document.buffer);

            if cursor_start.y == cursor_end.y {
                ProfileZone(":DrawSelectionSingleLine");

                line_start := text_buffer_get_start_cursor_for_line(document.buffer, cursor_start.y);

                view_before_cursor   := text_buffer_make_view_between_cursors(document.buffer, line_start, cursor_start,, temp);
                view_between_cursors := text_buffer_make_view_between_cursors(document.buffer, cursor_start, cursor_end,, temp);

                selection_x0 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x);
                selection_x1 := font_compute_position_on_line(editor.font, view_between_cursors, cursor_end.x - cursor_start.x) + selection_x0;
                selection_y0 := cast(f64, cursor_start.y) * cell_h;
                selection_y1 := selection_y0 + cell_h;
                selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), SELECTION_COLOR);
            } else {
                ProfileZone(":DrawSelectionMultiLine");

                // This does very simple vertical culling by doing layout and draw only on visible
                // lines. If the lines are long, we do a lot of layout and draw.
                //
                // TODO(jt): @Speed Horizontal culling?
                viewport_line_index_start := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, document.buffer.lines.count - 1);
                viewport_line_index_end   := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, document.buffer.lines.count - 1);

                // Because we start the layout just before the current viewport, the rendering scroll Y offset
                // is just the fractional part of the cell.
                //
                // Because we expect scroll_offset to be small, we keep it in f32.
                scroll_offset: Vector2;
                scroll_offset.x = cast(f32, panel.scroll.x);
                scroll_offset.y = cast(f32, viewport_y0 - cell_h * cast(f64, viewport_line_index_start));

                // First line, if in viewport
                if cursor_start.y >= viewport_line_index_start && cursor_start.y <= viewport_line_index_end {
                    line_start, line_end := text_buffer_get_cursors_for_line(document.buffer, cursor_start.y);

                    view_before_cursor := text_buffer_make_view_between_cursors(document.buffer, line_start, cursor_start,, temp);
                    view_after_cursor  := text_buffer_make_view_between_cursors(document.buffer, cursor_start, line_end,, temp);

                    selection_x0 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x);
                    selection_x1 := font_compute_position_on_line(editor.font, view_after_cursor, line_end.x - cursor_start.x) + selection_x0;
                    selection_y0 := cast(f64, cursor_start.y) * cell_h;
                    selection_y1 := selection_y0 + cell_h;
                    selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                    draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), SELECTION_COLOR);
                }

                // Center lines, if in viewport
                for (cursor_start.y + 1)..(cursor_end.y - 1) {
                    // TODO(jt): @Speed Clamp center lines range instead.
                    if it < viewport_line_index_start || it > viewport_line_index_end {
                        continue;
                    }

                    line_end  := text_buffer_get_end_cursor_for_line(document.buffer, it);
                    line_view := text_buffer_make_view_for_line(document.buffer, it,, temp);
                    selection_x0 := 0.0;
                    selection_x1 := font_compute_position_on_line(editor.font, line_view, line_end.x);
                    selection_y0 := cast(f64, it) * cell_h;
                    selection_y1 := selection_y0 + cell_h;
                    selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                    draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), SELECTION_COLOR);
                }

                // Last line, if in viewport
                if cursor_end.y >= viewport_line_index_start && cursor_end.y <= viewport_line_index_end {
                    line_start := text_buffer_get_start_cursor_for_line(document.buffer, cursor_end.y);

                    view_before_cursor := text_buffer_make_view_between_cursors(document.buffer, line_start, cursor_end,, temp);

                    selection_x0 := 0.0;
                    selection_x1 := font_compute_position_on_line(editor.font, view_before_cursor, cursor_end.x);
                    selection_y0 := cast(f64, cursor_end.y) * cell_h;
                    selection_y1 := selection_y0 + cell_h;
                    selection_rect: DRect = { selection_x0, selection_y0, selection_x1, selection_y1 };

                    draw_rect(*render_rects, drect_to_rect(selection_rect - panel.scroll), SELECTION_COLOR);
                }
            }
        }

        //
        // Draw cursor
        //
        {
            new_cursor_position := buffer_cursor0_position;

            // :CentralizedCursorInterpolationSetup
            //
            // Because the cursor position can be changed by both editing, mouse interaction,
            // scrolling, etc, we detect cursor changes every frame here (instead of in all the
            // places where the cursor can change).
            if panel.document.old_cursor != panel.document.buffer.cursor0 {
                setup_cursor_anim_interpolation(panel.document, input.time, panel.document.old_cursor_position, new_cursor_position);
            }

            FLASH_TIME : f64 : 0.50; // TODO(jt): Make flash time configurable. :Config
            ANIM_TIME  : f64 : 0.05; // TODO(jt): Make anim time configurable. :Config

            flash_t := cast(f32, (to_float64_seconds(input.time) - to_float64_seconds(document.cursor_flash_time_start)) / FLASH_TIME);
            flash_t = clamp(flash_t, 0.0, 1.0);
            flash_t = smoothstep(0.0, 1.0, flash_t);

            // TODO(jt): Doing cursor position interpolation introduces at least a frame of lag,
            // because anim_t starts out zero. We could artificially add delta time (or estimated
            // delta time, in case we didn't run on the previous frame), but maybe there's a better
            // integration method? (This is also true for all other interpolations, but for cursor,
            // this is most visible.)
            //
            // TODO(jt): For visuals, it would be nice, if the interpolated cursor left a trail
            // behind it as it moves, because currently, when it moves very fast, you can spot the
            // individual positions it occupies.

            anim_t := cast(f32, (to_float64_seconds(input.time) - to_float64_seconds(document.cursor_anim_time_start)) / ANIM_TIME);
            anim_t = clamp(anim_t, 0.0, 1.0);
            anim_t = smoothstep(0.0, 1.0, anim_t);

            if flash_t < 1.0 || anim_t < 1.0 {
                wants_next_frame = true;
            }

            document.cursor_flash = lerp(document.cursor_flash_source, document.cursor_flash_target, flash_t);
            document.cursor_anim = lerp(document.cursor_anim_source, document.cursor_anim_target, anim_t);

            cursor_rect: DRect;
            if ANIM_TIME == 0 {
                // Straight to the new position to avoid one frame of lag (and results of division by zero).
                cursor_rect = drect_from_point_and_size(new_cursor_position.x, new_cursor_position.y, cell_w, cell_h) - panel.scroll;
            } else {
                cursor_rect = drect_from_point_and_size(document.cursor_anim.x, document.cursor_anim.y, cell_w, cell_h) - panel.scroll;
            }

            line_rect: Rect = {
                0,
                cast(f32, new_cursor_position.y - panel.scroll.y),
                window_w,
                cast(f32, new_cursor_position.y + cell_h - panel.scroll.y),
            };

            draw_rect(*render_rects, line_rect, LINE_COLOR);
            draw_rect(*render_rects, drect_to_rect(cursor_rect), document.cursor_flash);
        }

        //
        // Layout and draw document text
        //
        {
            ProfileZone(":DrawDocumentText");

            // This does very simple vertical culling by doing layout and draw only on visible
            // lines. If the lines are long, we do a lot of layout and draw.
            //
            // TODO(jt): @Speed Horizontal culling?
            viewport_line_index_start := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, document.buffer.lines.count - 1);
            viewport_line_index_end   := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, document.buffer.lines.count - 1);

            viewport_start := text_buffer_get_start_cursor_for_line(document.buffer, viewport_line_index_start);
            viewport_end   := text_buffer_get_end_cursor_for_line(document.buffer, viewport_line_index_end);
            viewport_view  := text_buffer_make_view_between_cursors(document.buffer, viewport_start, viewport_end,, temp);

            // Because we start the layout just before the current viewport, the rendering scroll Y offset
            // is just the fractional part of the cell.
            //
            // While we expect vertical scroll_offset to be small, horizontal can in theory be pretty
            // big (although I'd wager we have serious performance problems before that starts to
            // matter), so we go f64 to be future proof.
            offset: DVector2;
            offset.x = -panel.scroll.x;
            offset.y = -viewport_y0 + cell_h * cast(f64, viewport_line_index_start);

            // TODO(jt): @Speed Cull render rects that are not on the screen. We still have to layout the text
            // to the left of the screen, but we don't have to emit render rects for it.
            font_layout_and_draw_text(*editor.font, cast(string, viewport_view), *render_rects, *update_regions, offset, is_new_frame = true);
        }

        panel.clamp_scroll_to_cursor        = false;
        panel.clamp_scroll_to_start_of_line = false;
        panel.clamp_scroll_to_end_of_line   = false;
    }

    {
        modeline_y := ifx editor.mini_panel.open then window_h - (MINI_PANEL_LINES + 2) * cell_h else window_h - 2 * cell_h;

        draw_rect(*render_rects, 0, modeline_y, window_w, modeline_y + cell_h, MODELINE_COLOR);

        cursor  := active_panel.document.buffer.cursor0;
        percent := cast(s64, 100.0 * cast(f32, cursor.y) / cast(f32, active_panel.document.buffer.lines.count));

        document_name: string;
        if #complete active_panel.document.kind == {
            case .SCRATCH; document_name = "*scratch*";
            case .FILE;    document_name = String.path_filename(active_panel.document.backing_file_path);
        }

        percent_string := temp_right_pad(tprint("%\%", percent), 5);

        s := tprint("  % % (%,%)", temp_right_pad(document_name, 20), percent_string, cursor.y + 1, cursor.x);
        font_layout_and_draw_text(*editor.font, s, *render_rects, *update_regions, { 0, modeline_y }, is_new_frame = false);
    }

    // TODO(jt): Instead of just drawing over what the panels drew, let's also use this information for culling?
    if editor.mini_panel.open {
        background_h := (MINI_PANEL_LINES + 1) * cell_h;
        background_y := max(window_h - background_h, 0);
        draw_rect(*render_rects, 0, background_y, window_w, window_h, { 0.96, 0.96, 0.96, 1.0 });

        if editor.mini_panel.item_index == -1 {
            draw_rect(*render_rects, 0, background_y, window_w, background_y + cell_h, SELECTION_COLOR);
        }

        // :MiniPanelAPI (mini_panel_render_proc)
        action_text: string;
        if editor.mini_panel.action == {
            case .SEARCH;              action_text = tprint("% Search: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
            case .OPEN_FILE;           action_text = tprint("% Open file: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
            case .SWITCH_TO_DOCUMENT;  action_text = tprint("% Switch to document: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
            case .CLOSE_DOCUMENT;      action_text = tprint("% Close document: ", temp_right_pad(tprint("(%)", editor.mini_panel.items.count), 9));
        }

        line_view := text_buffer_make_view_for_line(editor.mini_panel.buffer, 0,, temp);
        cursor_x := cast(f32, font_compute_position_on_line(editor.font, action_text, action_text.count));
        cursor_x += cast(f32, font_compute_position_on_line(editor.font, line_view, editor.mini_panel.buffer.cursor0.x));

        draw_rect(*render_rects, cursor_x, background_y, cursor_x + cell_w, background_y + cell_h, CURSOR_COLOR);

        main_line := tprint("%%", action_text, line_view);

        font_layout_and_draw_text(*editor.font, main_line, *render_rects, *update_regions, { 0, background_y }, is_new_frame = false);

        index0 := max(editor.mini_panel.item_index - (MINI_PANEL_LINES / 2), 0);
        index1 := min(index0 + MINI_PANEL_LINES, editor.mini_panel.items.count - 1);

        it_index := 0;
        for index0..index1 {
            item := *editor.mini_panel.items[it];

            if it == editor.mini_panel.item_index {
                y0 := background_y + (it_index + 1) * cell_h;
                y1 := background_y + (it_index + 2) * cell_h;
                draw_rect(*render_rects, 0, y0, window_w, y1, MINI_PANEL_LINE_COLOR);

                // TODO(jt): @Speed We need an incremental version of font_compute_position_on_line
                // that can resume where it left of last time. In can see multiple places in this
                // file where that would be useful. It will become more important for long lines.
                x0 := font_compute_position_on_line(editor.font, item.text, item.highlight_x0);
                x1 := font_compute_position_on_line(editor.font, item.text, item.highlight_x1);
                draw_rect(*render_rects, cast(f32, x0), y0, cast(f32, x1), y1, SELECTION_COLOR);
            }

            offset_y: f64 = background_y + (it_index + 1) * cell_h;
            font_layout_and_draw_text(*editor.font, item.text, *render_rects, *update_regions, { 0, offset_y }, is_new_frame = false);

            it_index += 1;
        }
    } else {
        message_line_y := window_h - cell_h;
        draw_rect(*render_rects, 0, message_line_y, window_w, window_h, BACKGROUND_COLOR);

        if editor.messages.count && !editor.last_message_seen {
            message := editor.messages[editor.messages.count - 1];
            font_layout_and_draw_text(*editor.font, message, *render_rects, *update_regions, { 0, message_line_y }, is_new_frame = false);
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
        r := irect_union_or_zero(update_regions);

        renderer.update_texture_r8unorm(TEXTURE_ID_GLYPH_ATLAS, editor.font.glyph_atlas, r);
        renderer.draw_rects(render_rects);
    }

    return wants_quit, wants_next_frame;
}

#scope_file

editor_log :: (editor: *Editor, format_string: string, args: ..Any, loc := #caller_location) {
    s := sprint(format_string, ..args,, arena_allocator(editor.perm_arena));
    array_add(*editor.messages, s);
    editor.last_message_seen = false;

    log(format_string, ..args, loc);
}

get_active_panel :: (editor: *Editor) -> *Panel {
    active_panel: *Panel = null;
    if editor.panels.count {
        index := clamp(editor.active_panel_index, 0, editor.panels.count - 1);
        active_panel = *editor.panels[index];
    }

    return active_panel;
}

route_event_to_mini_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    min_item_index := ifx mini_panel_can_select_text_line_proc(editor, platform, input) then -1 else 0;

    buffer_changed := false;
    old_item_index := mini_panel.item_index;

    key_map_buffered, key_map_action := key_map_input(*editor.mini_panel.key_map, event, editor.input_state.modifiers);
    if key_map_action == {
        case .MINI_PANEL_MOVE_UP;                mini_panel.item_index = clamp(mini_panel.item_index - 1, min_item_index, mini_panel.items.count - 1);
        case .MINI_PANEL_MOVE_DOWN;              mini_panel.item_index = clamp(mini_panel.item_index + 1, min_item_index, mini_panel.items.count - 1);
        case .MINI_PANEL_MOVE_LEFT;              text_buffer_move_cursor_x(*mini_panel.buffer, -1, false);
        case .MINI_PANEL_MOVE_RIGHT;             text_buffer_move_cursor_x(*mini_panel.buffer,  1, false);

        case .MINI_PANEL_MOVE_FORWARD_WORD;      text_buffer_move_cursor_to_next_word_boundary(*mini_panel.buffer, false);
        case .MINI_PANEL_MOVE_BACKWARD_WORD;     text_buffer_move_cursor_to_previous_word_boundary(*mini_panel.buffer, false);

        case .MINI_PANEL_MOVE_TO_START_OF_LINE;  text_buffer_move_cursor_to_start_of_line(*mini_panel.buffer, false);
        case .MINI_PANEL_MOVE_TO_END_OF_LINE;    text_buffer_move_cursor_to_end_of_line(*mini_panel.buffer, false);

        case .MINI_PANEL_DELETE_FORWARD;         text_buffer_delete_forward(*mini_panel.buffer); buffer_changed = true;
        case .MINI_PANEL_DELETE_BACKWARD; {
            // :MiniPanelAPI (mini_panel_text_update_proc ???)
            //
            // Some users of the mini panel might want to do fancier things when text is inserted or
            // deleted. For now, this is just deleting path segments for .OPEN_FILE, so we hardcode
            // that here, but eventually we want to pull this out into a proc that can be supplied
            // by a plugin.

            if mini_panel.action == .OPEN_FILE {
                gb := *mini_panel.buffer.gb;

                last_byte := ifx gb.count then gap_buffer_get_nongap_byte(gb, gb.count - 1) else 0;
                if last_byte == "/" {
                    buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
                    buffer_text.count -= 1; // The trailing '/', so that path_strip_filename can treat the last segment as a filename.

                    stripped_path := String.path_strip_filename(buffer_text);

                    text_buffer_reset(*mini_panel.buffer);
                    text_buffer_insert(*mini_panel.buffer, stripped_path);
                } else {
                    text_buffer_delete_backward(*mini_panel.buffer);
                }
            } else {
                text_buffer_delete_backward(*mini_panel.buffer);
            }

            buffer_changed = true;
        }

        case .MINI_PANEL_SCROLL_UP;              mini_panel.item_index = clamp(mini_panel.item_index - MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);
        case .MINI_PANEL_SCROLL_DOWN;            mini_panel.item_index = clamp(mini_panel.item_index + MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);

        case .MINI_PANEL_AUTOCOMPLETE;           buffer_changed |= mini_panel_autocomplete_proc(editor, platform, input);

        case .MINI_PANEL_CONFIRM;                mini_panel_confirm_proc(editor, platform, input);
        case .MINI_PANEL_CANCEL;                 close_mini_panel(*editor.mini_panel);
    }

    // TODO(jt): Do selecting in mini panel
    // TODO(jt): Do animated horizontal scroll of buffer in mini panel.
    // TODO(jt): Do animated vertical scroll of item list in mini_panel.
    if !key_map_buffered && key_map_action == .NONE && event.flags & .PRESSED {
        if event.type == {
            case .CODEPOINT; {
                codepoint := event.data.codepoint;

                if !(editor.input_state.modifiers & .CTRL) && !(editor.input_state.modifiers & .ALT) {
                    if codepoint == {
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
                                buffer_changed = true;
                            }
                        }
                    }
                }
            }
        }
    }

    if mini_panel.open {
        // TODO(jt): @Speed In case we'll be processing multiple events this frame, we want to delay
        // calling this until they have all been processed. Otherwise we'll be doing expensive stuff
        // multiple times per frame. Maybe we need to move this one level up and track the dirty
        // flags on the mini panel itself?
        mini_panel_update_proc(editor, platform, input, buffer_changed, mini_panel.item_index != old_item_index);
    }
}

route_event_to_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    panel := get_active_panel(editor);
    if !panel {
        return;
    }

    document := panel.document;
    if !document {
        return;
    }

    shift_selecting := editor.input_state.modifiers & .SHIFT;

    key_map_buffered, key_map_action := key_map_input(*editor.key_map, event, editor.input_state.modifiers);

    if key_map_action == {
        case .MOVE_UP;     text_buffer_move_cursor_y(*document.buffer, -1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;
        case .MOVE_DOWN;   text_buffer_move_cursor_y(*document.buffer,  1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;
        case .MOVE_LEFT;   text_buffer_move_cursor_x(*document.buffer, -1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;
        case .MOVE_RIGHT;  text_buffer_move_cursor_x(*document.buffer,  1, shift_selecting || panel.selecting); panel.clamp_scroll_to_cursor = true; if shift_selecting then panel.selecting = false;

        case .SEARCH; {
            was_closed := open_mini_panel(*editor.mini_panel, .SEARCH);
            mini_panel_update_proc(editor, platform, input, true, true);
        }

        case .OPEN_FILE; {
            path := "./";

            // TODO(jt): In the future, we could set the path to the project directory.
            if panel.document.kind == .FILE && panel.document.backing_file_path.count {
                path = String.path_strip_filename(panel.document.backing_file_path);
            }

            open_mini_panel(*editor.mini_panel, .OPEN_FILE, path);
            mini_panel_update_proc(editor, platform, input, true, true);
        }
        case .SAVE_FILE; {
            if document.backing_file_path.count {
                buffer := *document.buffer;

                gap_buffer_move_gap_to(*buffer.gb, 0);
                contents := gap_buffer_make_view(buffer.gb, 0, buffer.gb.count, assert_that_we_do_not_allocate = true);
                success := platform.write_file(document.backing_file_path, contents);
                if success {
                    document.backing_file_exists = true; // It might have existed before, too!
                    editor_log(editor, "Wrote file %", document.backing_file_path);
                } else {
                    editor_log(editor, "Failed to write file %", document.backing_file_path);
                }
            }
        }
        case .SWITCH_TO_DOCUMENT; {
            open_mini_panel(*editor.mini_panel, .SWITCH_TO_DOCUMENT);
            mini_panel_update_proc(editor, platform, input, true, true);
        }
        case .CLOSE_DOCUMENT; {
            open_mini_panel(*editor.mini_panel, .CLOSE_DOCUMENT);
            mini_panel_update_proc(editor, platform, input, true, true);
        }

        case .SWAP_LINE_UP; // TODO(jt)
        case .SWAP_LINE_DOWN; // TODO(jt)

        case .MOVE_TO_START_OF_LINE;        text_buffer_move_cursor_to_start_of_line(*document.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
        case .MOVE_TO_END_OF_LINE;          text_buffer_move_cursor_to_end_of_line(*document.buffer, panel.selecting);   panel.clamp_scroll_to_cursor = true;

        case .MOVE_TO_START_OF_DOCUMENT;    text_buffer_move_cursor_to_start(*document.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
        case .MOVE_TO_END_OF_DOCUMENT;      text_buffer_move_cursor_to_end(*document.buffer, panel.selecting);   panel.clamp_scroll_to_cursor = true;

        case .MOVE_TO_PREVIOUS_BLANK_LINE;  text_buffer_move_cursor_to_previous_blank_line(*document.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;
        case .MOVE_TO_NEXT_BLANK_LINE;      text_buffer_move_cursor_to_next_blank_line(*document.buffer, panel.selecting); panel.clamp_scroll_to_cursor = true;

        case .MOVE_FORWARD_WORD; {
            panel.clamp_scroll_to_start_of_line |= text_buffer_move_cursor_to_next_word_boundary(*document.buffer, panel.selecting);
            panel.clamp_scroll_to_cursor = true;
        }
        case .MOVE_BACKWARD_WORD; {
            panel.clamp_scroll_to_end_of_line |= text_buffer_move_cursor_to_previous_word_boundary(*document.buffer, panel.selecting);
            panel.clamp_scroll_to_cursor = true;
        }

        case .RECENTER;                     recenter_active_panel(editor, input);
        case .SCROLL_UP;                    scroll_panel_up_one_screen(panel, input, editor.font.line_height_in_pixels);
        case .SCROLL_DOWN;                  scroll_panel_down_one_screen(panel, input, editor.font.line_height_in_pixels);

        case .START_SELECTING;              panel.selecting = true;  text_buffer_join_cursors(*document.buffer);
        case .STOP_SELECTING;               panel.selecting = false; text_buffer_join_cursors(*document.buffer);

        case .DELETE_LINE; {
            panel.selecting = false;
            text := text_buffer_delete_line(*document.buffer);
            if text {
                platform.clipboard_set_text(text);
            }
        }
        case .DELETE_FORWARD;               panel.selecting = false; text_buffer_delete_forward(*document.buffer);  panel.clamp_scroll_to_cursor = true;
        case .DELETE_BACKWARD;              panel.selecting = false; text_buffer_delete_backward(*document.buffer); panel.clamp_scroll_to_cursor = true;

        case .DELETE_FORWARD_WORD;          // TODO(jt): text_buffer_delete_until_next_word_boundary.
        case .DELETE_BACKWARD_WORD;         // TODO(jt): text_buffer_delete_until_previous_word_boundary.

        case .INSERT_LINE_BEFORE; {
            // TODO(jt): Preserve CRLF in CRLF-only documents.
            panel.selecting = false;
            text_buffer_insert(*document.buffer, "\n", undo_barrier = true);
            panel.clamp_scroll_to_cursor = true;
        }
        case .INSERT_LINE_AFTER; {
            // TODO(jt): Preserve CRLF in CRLF-only documents.
            panel.selecting = false;
            text_buffer_insert(*document.buffer, "\n", undo_barrier = true);
            text_buffer_move_cursor_y(*document.buffer, -1, false);
            text_buffer_move_cursor_to_end_of_line(*document.buffer, false);
        }

        // TODO(jt): Make indentation configurable.
        // TODO(jt): Preserve tab-ness in tab-only documents.
        case .INSERT_TAB;                   text_buffer_insert(*document.buffer, "    ");  panel.clamp_scroll_to_cursor = true;

        case .UNDO_EDIT;                    text_buffer_undo_edit(*document.buffer); panel.clamp_scroll_to_cursor = true;
        case .REDO_EDIT;                    text_buffer_redo_edit(*document.buffer); panel.clamp_scroll_to_cursor = true;

        case .COPY; {
            panel.selecting = false;
            text := text_buffer_make_view_between_cursors(document.buffer, document.buffer.cursor0, document.buffer.cursor1,, temp);
            if text {
                platform.clipboard_set_text(text);
            }

            text_buffer_join_cursors(*document.buffer);
        }
        case .CUT; {
            panel.selecting = false;
            deleted := text_buffer_delete_between_cursors(*document.buffer);
            if deleted {
                platform.clipboard_set_text(deleted);
            }
        }
        case .PASTE; {
            panel.selecting = false;
            text := platform.clipboard_get_text(,, temp);
            if text {
                text_buffer_insert(*document.buffer, text, undo_barrier = true);
                panel.clamp_scroll_to_cursor = true;
            }
        }
    }

    inserted := false;
    if !key_map_buffered && key_map_action == .NONE && event.flags & .PRESSED {
        if event.type == {
            case .CODEPOINT; {
                panel.selecting = false;

                codepoint := event.data.codepoint;

                // TODO(jt): @Speed This is a little dumb, because buffer will be parsing
                // this back to codepoints for its linedata tracking. Add
                // text_buffer_insert_utf32?
                buf: [4] u8;
                s: string;
                s.data = buf.data;
                Unicode.character_utf32_to_utf8(cast(u32, codepoint), *s);

                text_buffer_insert(*document.buffer, s);
                panel.clamp_scroll_to_cursor = true;

                inserted = true;
            }
        }
    }

    action_kind := action_classify(key_map_action);
    if action_kind >= .MOVE || inserted {
        // The cursor position interpolation gets setup in a centralized place instead of here, because the
        // cursor can be moved from other places than this one (e.g. mouse, SEARCH mini
        // panel...).
        //
        // :CentralizedCursorInterpolationSetup
        document.time_of_last_interaction = input.time;
    }
    if action_kind >= .EDIT || inserted {
        setup_cursor_flash_interpolation(document, input.time, CURSOR_COLOR_ACTIVE, CURSOR_COLOR);
        document.time_of_last_interaction = input.time;
    }
}

open_mini_panel :: (mini_panel: *Mini_Panel, action: Mini_Panel.Action, initial_text := "") -> was_closed: bool {
    key_map_flush(*mini_panel.key_map);

    text_buffer_reset(*mini_panel.buffer);
    text_buffer_insert(*mini_panel.buffer, initial_text);

    array_reset(*mini_panel.items);
    arena_reset(mini_panel.items_arena);
    mini_panel.item_index = 0;

    mini_panel.action = action;

    was_closed := !mini_panel.open;
    mini_panel.open = true;

    return was_closed;
}

close_mini_panel :: (mini_panel: *Mini_Panel) -> was_open: bool {
    text_buffer_reset(*mini_panel.buffer);

    array_reset(*mini_panel.items);
    arena_reset(mini_panel.items_arena);

    was_open := mini_panel.open;
    mini_panel.open = false;

    return was_open;
}

// :MiniPanelAPI
//
// These mini_panel_* procs currently switch on the action enum of the mini panel and do hardcoded
// stuff, but are later expected to be the entry points for mini panel plugins. This is why some of
// them get more parameters than they actually need.

Open_File_Userdata :: struct {
    full_file_path: string;
}

mini_panel_can_select_text_line_proc :: (editor: Editor, platform: Platform, input: Input) -> bool {
    if editor.mini_panel.action == .OPEN_FILE {
        return true;
    }

    return false;
}

// buffer_changed can imply selected_line_changed.
mini_panel_update_proc :: (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool) {
    ProfileZone("mini_panel_update");

    mini_panel := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    if buffer_changed {
        array_reset(*mini_panel.items);
        arena_reset(mini_panel.items_arena);

        if mini_panel.action == {
            case .SEARCH; {
                ProfileZone(":MiniPanelSearchUpdate");

                if active_panel && active_panel.document {
                    document := active_panel.document;

                    old_cursor_y   := document.buffer.cursor0.y;
                    new_item_index := -1;

                    search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
                    search_text_char_count := mini_panel.buffer.lines[0].char_count;

                    gb_index := 0;
                    for 0..document.buffer.lines.count - 1 {
                        gb_count := document.buffer.lines[it].byte_count;

                        // We go straight to the gap buffer and count its indices manually, so that
                        // we avoid the quadratic behavior of calling get_gb_index_for_line each
                        // time through the loop.
                        //
                        // Note that even though we pass in temp, making of the view will only
                        // allocate for one of the lines - the one that crosses the gap.
                        line_bytes := gap_buffer_make_view(document.buffer.gb, gb_index, gb_count,, temp);
                        line_text := cast(string, line_bytes);

                        // TODO(jt): We need a fuzzy searcher here! Additionally
                        // String.index_of_string_nocase is kind of deprecated, we don't really want
                        // to use it.
                        //
                        // TODO(jt): @Speed index_of_string_nocase is kind of slooooow.
                        found_index: s64;
                        found: bool;
                        {
                            ProfileZone("String.index_of_string_nocase");
                            found_index, found = String.index_of_string_nocase(line_text, search_text);
                        }
                        if found {
                            s := "";
                            if line_text.count {
                                s = sprint("%%", temp_right_pad(tprint("[%]", it + 1), 10), line_text,, arena_allocator(mini_panel.items_arena));
                            }

                            x0 := count_utf8_characters(String.slice(line_text, 0, found_index));

                            item_index := mini_panel.items.count;
                            item := array_add(*mini_panel.items);
                            item.text = s;
                            item.highlight_x0 = x0;
                            item.highlight_x1 = x0 + search_text_char_count;
                            item.userdata = cast(*void, it);

                            if new_item_index == -1 && it >= old_cursor_y {
                                new_item_index = item_index;
                            }
                        }

                        gb_index += gb_count;
                    }

                    if new_item_index == -1 {
                        new_item_index = mini_panel.items.count - 1;
                    }

                    if new_item_index != -1 {
                        mini_panel.item_index = new_item_index;
                        selected_item_changed = true;
                    }
                }
            }

            case .OPEN_FILE; {
                ProfileZone(":MiniPanelOpenFileUpdate");

                path_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
                path_text_char_count := mini_panel.buffer.lines[0].char_count;

                path_prefix, _, _, file_name_with_extension := String.path_decomp(path_text);
                path_prefix = String.trim_right(path_prefix, "/");

                file_name_with_extension_char_count := count_utf8_characters(file_name_with_extension);

                // TODO(jt): @Speed Consider not listing these again unless the prefix changed?
                file_list := platform.list_files(path_prefix,, temp);
                for file_list {
                    visited_file_path := it.name;
                    visited_filename := String.path_filename(it.name);

                    found_index, found := String.index_of_string_nocase(visited_filename, file_name_with_extension);
                    if found {
                        s := "";
                        if it.name.count {
                            s = arena_push_string(mini_panel.items_arena, visited_filename);
                        }

                        x0 := count_utf8_characters(String.slice(visited_filename, 0, found_index));

                        item := array_add(*mini_panel.items);
                        item.text = s;
                        item.highlight_x0 = x0;
                        item.highlight_x1 = x0 + file_name_with_extension_char_count;
                        item.userdata = null;

                        if it.name.count {
                            full_file_path := arena_push_string(mini_panel.items_arena, it.name);

                            userdata := New(Open_File_Userdata,, arena_allocator(mini_panel.items_arena));
                            userdata.full_file_path = full_file_path;

                            item.userdata = userdata;
                        }
                    }
                }

                mini_panel.item_index = min(mini_panel.item_index, mini_panel.items.count - 1);
            }

            case .SWITCH_TO_DOCUMENT; #through;
            case .CLOSE_DOCUMENT; {
                // XXX: @Bug This does not find scratch for switching when we type in some text.

                ProfileZone(":MiniPanelSwitchToDocumentOrCloseDocumentUpdate");

                search_text := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);
                search_text_char_count := mini_panel.buffer.lines[0].char_count;

                for * editor.documents {
                    if mini_panel.action == .CLOSE_DOCUMENT && it.kind == .SCRATCH {
                        continue;
                    }

                    document_name: string;
                    if it.kind == {
                        case .SCRATCH;  document_name = "*scratch*";
                        case .FILE;     document_name = it.backing_file_path; // TODO(jt): Strip path prefix common for all items.
                    }

                    found_index, found := String.index_of_string_nocase(it.backing_file_path, search_text);
                    if found {
                        s := "";
                        if document_name.count {
                            s = arena_push_string(mini_panel.items_arena, document_name);
                        }

                        x0 := count_utf8_characters(String.slice(document_name, 0, found_index));

                        item := array_add(*mini_panel.items);
                        item.text = s;
                        item.highlight_x0 = x0;
                        item.highlight_x1 = x0 + search_text_char_count;
                        item.userdata = it;
                    }
                }
            }
        }

        mini_panel.item_index = min(mini_panel.items.count - 1, 0);
    }

    if selected_item_changed {
        if mini_panel.action == .SEARCH {
            // TODO(jt): @Cleanup This is the copypaste of the confirm action, except it does not close the mini panel.

            // Changing the mini panel buffer OR the selected item can put the index to -1 (in case
            // of search, -1 can only be achieved by changing the buffer), so in general we don't
            // want to assert the index points to the array.
            if mini_panel.item_index >= 0 {
                item := *mini_panel.items[mini_panel.item_index];

                x := item.highlight_x0;
                y := cast(s64, item.userdata);

                document := active_panel.document;

                old_cursor_y := document.buffer.cursor0.y;
                text_buffer_move_cursor_to(*document.buffer, x, y, false);

                if document.buffer.cursor0.y != old_cursor_y {
                    recenter_active_panel(editor, input, true);
                }
            }
        }
    }
}

mini_panel_autocomplete_proc :: (editor: *Editor, platform: Platform, input: Input) -> changed: bool {
    mini_panel := *editor.mini_panel;

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return false;
    }

    if mini_panel.action == {
        case .OPEN_FILE; {
            userdata: *Open_File_Userdata;
            if mini_panel.items.count == 1 {
                userdata = mini_panel.items[0].userdata;
            } else if mini_panel.items.count > 1 {
                userdata = mini_panel.items[mini_panel.item_index].userdata;
            }

            if userdata && userdata.full_file_path.count {
                completion_text := String.path_filename(mini_panel.items[0].text);
                buffer_text := text_buffer_make_view_for_line(mini_panel.buffer, 0, force_allocate = true,, temp);
                buffer_path, _, _, buffer_filename := String.path_decomp(buffer_text);

                completion_filename := String.path_filename(completion_text);

                recomposed_path := tprint("%%", buffer_path, completion_filename);

                text_buffer_reset(*mini_panel.buffer);
                text_buffer_insert(*mini_panel.buffer, recomposed_path);

                if platform.file_is_directory(recomposed_path) {
                    text_buffer_insert(*mini_panel.buffer, "/");
                }

                return true;
            }
        }

        case .SWITCH_TO_DOCUMENT; #through;
        case .CLOSE_DOCUMENT; {
            if mini_panel.items.count == 1 {
                // TODO(jt): The reset also nukes the edit history of the mini panel buffer... maybe
                // we don't want that?
                text_buffer_reset(*mini_panel.buffer);
                text_buffer_insert(*mini_panel.buffer, mini_panel.items[0].text);

                return true;
            } else if mini_panel.items.count > 1 {
                // TODO(jt): The reset also nukes the edit history of the mini panel buffer... maybe
                // we don't want that?
                text_buffer_reset(*mini_panel.buffer);
                text_buffer_insert(*mini_panel.buffer, mini_panel.items[mini_panel.item_index].text);

                return true;
            }
        }
    }

    return false;
}

mini_panel_confirm_proc :: (editor: *Editor, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;
    active_panel := get_active_panel(editor);

    sanity_assert(mini_panel.open);
    if !mini_panel.open {
        return;
    }

    if mini_panel.action == {
        case .SEARCH; {
            // TODO(jt): Because we route events before we do the search,
            // the confirm action here can see the unupdated items. We could
            // force the update here.
            if mini_panel.items.count {
                assert(mini_panel.item_index >= 0);
                item := *mini_panel.items[mini_panel.item_index];

                x := item.highlight_x0;
                y := cast(s64, item.userdata);

                sanity_assert(cast(bool, active_panel));
                if active_panel && active_panel.document {
                    text_buffer_move_cursor_to(*active_panel.document.buffer, x, y, false);
                    recenter_active_panel(editor, input, true);
                }
            }

            close_mini_panel(mini_panel);
        }

        case .OPEN_FILE; {
            // XXX: @Bug If the file does not exist, get_absolute_path will fail on macOS. We need
            // to do something about it.

            file_path: string;
            file_exists: bool;
            if mini_panel.item_index == -1 {
                file_path = text_buffer_make_view_for_line(editor.mini_panel.buffer, 0,, temp);
                file_exists = platform.file_exists(file_path);
            } else if mini_panel.items.count {
                userdata: *Open_File_Userdata = mini_panel.items[mini_panel.item_index].userdata;
                if userdata {
                    file_path = userdata.full_file_path;
                    file_exists = true; // Unless deleted since we last looked.
                }
            }

            success, file_absolute_path := platform.get_absolute_path(file_path,, temp);
            if success {
                String.path_overwrite_separators(file_absolute_path, "/");

                document, document_newly_created := find_or_add_document(editor, platform, .FILE, file_absolute_path);
                document.backing_file_exists = file_exists;

                if document_newly_created {
                    if file_exists {
                        editor_log(editor, "Opening file: %", file_absolute_path);

                        // TODO(jt): Detect/Watch file changes on disk!
                        success, file_contents := platform.read_file(file_absolute_path,, temp);
                        if success {
                            text_buffer_insert(*document.buffer, file_contents);
                            text_buffer_move_cursor_to(*document.buffer, 0, 0, false);

                            if active_panel {
                                set_panel_document(active_panel, document);
                                recenter_active_panel(editor, input, true);
                            }
                        }
                    } else {
                        editor_log(editor, "Opening new file with path: %", file_absolute_path);
                        if active_panel {
                            set_panel_document(active_panel, document);
                        }
                    }
                } else {
                    if active_panel {
                        set_panel_document(active_panel, document);
                    }
                }
            } else {
                log_error("Failed to get absolute path for %", file_path);
            }

            close_mini_panel(mini_panel);
        }

        case .SWITCH_TO_DOCUMENT; {
            if mini_panel.items.count {
                assert(mini_panel.item_index >= 0);
                item := *mini_panel.items[mini_panel.item_index];

                document := cast(*Document, item.userdata);

                if active_panel {
                    set_panel_document(active_panel, document);

                    // TODO(jt): Emacs actually remembers the previous scroll of the panel in
                    // document. Do we want to do the same?
                    recenter_active_panel(editor, input, true);
                    finish_scroll_interpolation(active_panel);
                }
            }

            close_mini_panel(mini_panel);
        }

        case .CLOSE_DOCUMENT; {
            if mini_panel.items.count {
                assert(mini_panel.item_index >= 0);
                item := *mini_panel.items[mini_panel.item_index];

                document := cast(*Document, item.userdata);
                close_document(editor, document);
            }

            close_mini_panel(mini_panel);
        }
    }
}

find_or_add_document :: (editor: *Editor, platform: Platform, kind: Document.Kind, backing_file_path: string) -> *Document, newly_created: bool {
    for * editor.documents {
        if it.kind != kind                            continue;
        if it.backing_file_path != backing_file_path  continue;

        return it, false;
    }

    document_arena         := make_arena(platform, .SMALL);
    buffer_arena           := make_arena(platform, .LARGE);
    buffer_edit_text_arena := make_arena(platform, .LARGE);

    document: Document;
    document.kind = kind;
    text_buffer_init(*document.buffer, buffer_arena, buffer_edit_text_arena);

    document.arena = document_arena;
    if backing_file_path.count {
        document.backing_file_path = copy_string(backing_file_path,, arena_allocator(document_arena));
    }

    document.cursor_flash_source = CURSOR_COLOR;
    document.cursor_flash_target = CURSOR_COLOR;
    document.cursor_flash_time_start = {};
    document.cursor_flash = CURSOR_COLOR;

    locator, document_pointer := bucket_array_add(*editor.documents, document);
    document_pointer.locator = locator;

    return document_pointer, true;
}

close_document :: (editor: *Editor, document: *Document) {
    editor_log(editor, "Closing document % %", document.kind, document.backing_file_path);

    document_to_show: *Document;
    document_to_show_time: Apollo_Time;
    for * editor.documents {
        if it != document {
            if it.time_of_last_interaction > document_to_show_time {
                document_to_show = it;
                document_to_show_time = it.time_of_last_interaction;
            }
        }
    }

    // Make sure nobody references the document anymore.
    for * editor.panels {
        if it.document == document {
            it.document = document_to_show;
        }
    }

    // Release arenas. Can't touch anything dynamically allocated on the document after.
    arena_release(document.arena);
    arena_release(document.buffer.arena);
    arena_release(document.buffer.edit_text_arena);

    locator := document.locator;

    // Remove document itself.
    bucket_array_remove(*editor.documents, locator);
}

set_panel_document :: (panel: *Panel, document: *Document) {
    panel.scroll_source = { 0, 0 };
    panel.scroll_target = { 0, 0 };
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes for e.g. to_float64_seconds.
    panel.scroll = { 0, 0 };

    panel.clamp_scroll_to_cursor = false;
    panel.clamp_scroll_to_start_of_line = false;
    panel.clamp_scroll_to_end_of_line = false;

    panel.selecting = false;
    panel.document = document;
}

set_panel_document_to_newly_created_scratch :: (editor: *Editor, panel: *Panel, platform: Platform) {
    ProfileZone("set_panel_document_to_scratch");

    document := find_or_add_document(editor, platform, .SCRATCH, "");

    panel.scroll_source = { 0, 0 };
    panel.scroll_target = { 0, 0 };
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes for e.g. to_float64_seconds.
    panel.scroll = { 0, 0 };

    panel.clamp_scroll_to_cursor = true; // Because we are inserting pontentially large text.
    panel.clamp_scroll_to_start_of_line = false;
    panel.clamp_scroll_to_end_of_line = false;

    panel.selecting = false;
    panel.document = document;

    // For -x64/-llvm and -sanity, 64KB is smooth, but it chokes on larger stuff.
    // For -optimized and -no-sanity, 256MB is smooth, and can go up to 1GB without being too choppy.
    HELLO_SIZE : s64 : 64 << 10;

    hello_arena := make_arena(platform, .LARGE);
    hello_text := make_hello_text(hello_arena, HELLO_SIZE);
    text_buffer_insert(*document.buffer, hello_text, undo_barrier = true);

    // For when you want to materialize The Year of Glad.
    //
    // {
    //     #import "File";
    //     write_entire_file("hello.txt", hello_text);
    // }

    arena_release(hello_arena);
}

// TODO(jt): Add:   add_file_visiting_panel :: (editor: *Editor) {}

recenter_active_panel :: (editor: *Editor, input: Input, force_center := false) {
    panel := get_active_panel(editor);
    if !panel {
        return;
    }

    document := panel.document;
    if !document {
        return;
    }

    cursor_y := document.buffer.cursor0.y * editor.font.line_height_in_pixels;

    top    := cursor_y;
    center := cursor_y - 0.5 * input.window_size.y;
    bottom := cursor_y - input.window_size.y + 3 * editor.font.line_height_in_pixels;

    if editor.mini_panel.open {
        center += 0.5 * MINI_PANEL_LINES * editor.font.line_height_in_pixels;
        bottom += MINI_PANEL_LINES * editor.font.line_height_in_pixels;
    }

    finish_scroll_interpolation(panel);

    if force_center {
        panel.scroll_target.y = center;
    } else if panel.scroll_target.y == center {
        panel.scroll_target.y = top;
    } else if panel.scroll_target.y == top {
        panel.scroll_target.y = bottom;
    } else {
        panel.scroll_target.y = center;
    }

    setup_scroll_interpolation(panel, input.time);
}

scroll_panel_up_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    document := panel.document;
    if !document {
        return;
    }

    delta_max := cast(s64, floor(input.window_size.y / cell_h));
    delta     := min(document.buffer.cursor0.y, delta_max);

    text_buffer_move_cursor_y(*document.buffer, -delta, panel.selecting);

    finish_scroll_interpolation(panel);
    if delta == delta_max {
        panel.scroll_target.y -= delta * cell_h;
        setup_scroll_interpolation(panel, input.time);
    }
}

scroll_panel_down_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    document := panel.document;
    if !document {
        return;
    }

    delta_max := cast(s64, floor(input.window_size.y / cell_h));
    delta     := min(document.buffer.lines.count - 1 - document.buffer.cursor0.y, delta_max);

    text_buffer_move_cursor_y(*document.buffer, delta, panel.selecting);

    finish_scroll_interpolation(panel);
    if delta == delta_max {
        panel.scroll_target.y += delta * cell_h;
        setup_scroll_interpolation(panel, input.time);
    }
}

get_cursor_position :: (document: Document, font: Font) -> DVector2 {
    x := document.buffer.cursor0.x;
    y := document.buffer.cursor0.y;

    line_view := text_buffer_make_view_for_line(document.buffer, y,, temp);

    position: DVector2;
    position.x = font_compute_position_on_line(font, line_view, x);
    position.y = cast(f64, y) * font.line_height_in_pixels;

    return position;
}

setup_scroll_interpolation :: (panel: *Panel, time: Apollo_Time) {
    panel.scroll_target.x = max(panel.scroll_target.x, 0.0);
    panel.scroll_target.y = max(panel.scroll_target.y, 0.0);

    panel.scroll_source = panel.scroll;
    panel.scroll_time_start = time;
}

finish_scroll_interpolation :: (panel: *Panel) {
    panel.scroll_source = panel.scroll_target;
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes Int128 stuff in to_float64_seconds.
    panel.scroll = panel.scroll_target;
}

setup_cursor_anim_interpolation :: (document: *Document, time: Apollo_Time, source: DVector2, target: DVector2) {
    document.cursor_anim_source = source;
    document.cursor_anim_target = target;
    document.cursor_anim_time_start = time;
    document.cursor_anim = source;
}

setup_cursor_flash_interpolation :: (document: *Document, time: Apollo_Time, source: Vector4, target: Vector4) {
    document.cursor_flash_source = source;
    document.cursor_flash_target = target;
    document.cursor_flash_time_start = time;
    document.cursor_flash = source;
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

Arena_Size :: enum s64 {
    SMALL  :: 64 << 10;
    LARGE  :: 16 << 30;
}

make_arena :: (platform: Platform, size: Arena_Size) -> *Arena {
    procs: Arena_Procs;
    procs.page_size    = platform.page_size;
    procs.mem_reserve  = platform.mem_reserve;
    procs.mem_release  = platform.mem_release;
    procs.mem_commit   = platform.mem_commit;
    procs.mem_decommit = platform.mem_decommit;

    reserve_size := cast(s64, size);

    arena := arena_allocate(procs, reserve_size = reserve_size);

    return arena;
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
