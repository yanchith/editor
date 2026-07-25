/*

TODO(jt): Known serious bugs:

(none currently)

TODO(jt): Roadmap:

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
- [X] Find/replace and modal/interactive commands.
- [X] Open non-utf8 text buffers and binary files.

- [X] Syntax Highlighting
- [X] Mode defined parentheses (surround, autoclose)
- [X] Matching parentheses highlight
- [~] Syntax aware indentation (C-i)
- [~] Watch opened files for changes on disk
- [~] Panel tiling
- [ ] Directory Lister panel
- [ ] Create file in new directories (mkdirp)
- [ ] Delete file
- [ ] *compilation* buffer
- [ ] Mode defined comments
- [ ] Themes
- [ ] 4coder-like poor man's hex mode - substitute binary for escaped hex codes (e.g. 255 -> /ff) during layout and position calculation.
- [ ] Hex mode Panel
- [ ] Multiple Cursors
- [ ] Projects (project root, settings, compilations, text search with jumping, find/replace)
- [ ] Emacs-like undo? (If I find out I can't live without)
- [ ] Emacs-like kill ring (If I find out I can't live without)
- [ ] if (0) and #if 0 behave like comments w.r.t. to highlighting.
- [ ] FreeType subpixel rendering
- [ ] Font Kerning
- [ ] Very nice text rendering (kb_text_shape + Slug)
- [ ] Git integration (via plugin?)
- [ ] 4coder style floating annotations? (e.g. name of the function or if statement expresion after closing brace)
- [ ] Customization and plugins

TODO(jt): @Stream Small things to do:

- [X] Map-like zoom
- [X] Draw item count and item indices in mini panel (e.g. '(5) Search: my_search_text' and '7: line containing my_search_text and stuff')
- [X] OPEN_FILE starts in the directory of the currently open document
- [X] OPEN_FILE, switch to buffer and close buffer get tab completions.
- [X] OPEN_FILE completion also completes, if we are on the text line but there is only one item in the list.
- [X] Selection in mini panel text buffer.
- [ ] Selection in modal interaction text buffer.
- [ ] SEARCH should allow words separated by spaces
- [ ] SEARCH items render with syntax highlighting
- [ ] Keep displaying (and updating) panel selection while SEARCH is active.
- [ ] Deduplicate path prefixes in SWITCH_TO_DOCUMENT and CLOSE_DOCUMENT
- [ ] C-j join-next-line
- [ ] M-d, C-<backspace> (delete forward/backward word)
- [ ] M-u, M-l (upcase/downcase word and move cursor)
- [ ] M-x
- [ ] M-g g (go to line)
- [ ] C-M-p, C-M-n (move line up/down) SWAP_LINE_UP/SWAP_LINE_DOWN
- [ ] C-u C-<space> and cursor undo.
- [ ] M-q (reflow)
- [ ] Sticky cursor (navigate to the end of long line, move up/down to a shorter line, move back to the long line and cursor goes to its original place)
- [X] Flash cursor with typing (needs tuning)
- [X] When switching-to/closing documents, sort by recency.
- [ ] Read-only mode for documents.
- [ ] Dark text color under bright rectangles (cursor, selection, line)
- [ ] Animate current line highlight the same way we animate cursor.

*/

#module_parameters()(SANITY := false);

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena"(ENABLE_SANITY_ASSERTS = SANITY, DEFAULT_OVERWRITE_MEMORY = SANITY);
#import "Bucket_Array";
#import "Hash_Table";
#import "Profiler";

String  :: #import "String";
Math    :: #import "Math";
Unicode :: #import "Unicode";

Vector2        :: Math.Vector2;
Vector3        :: Math.Vector3;
Vector4        :: Math.Vector4;
floor          :: Math.floor;
ceil           :: Math.ceil;
fmod_cycling   :: Math.fmod_cycling;
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
#load "hash.jai";
#load "string.jai";
#load "math.jai";
#load "platform.jai";
#load "renderer.jai";
#load "input.jai";
#load "key_map.jai";
#load "font.jai";
#load "gap_buffer.jai";
#load "text_buffer.jai";
#load "parentheses.jai";
#load "color.jai";
#load "mini_panel_search.jai";
#load "mini_panel_open_file.jai";
#load "mini_panel_switch_to_document.jai";
#load "mini_panel_close_document.jai";
#load "modal_interaction_search_and_replace.jai";
#load "lang_jai.jai";
#load "hello.jai";

// ID 0 is reserved for the texture-less pipeline. The backend must switch to a texture-less shader
// if the texture wasn't uploaded (we don't upload TEXTURE_ID_NONE). We could also reserve a few
// pixels in the font atlas for color shading, but maybe we don't want to do that?
TEXTURE_ID_NONE:        Texture_ID : 0;
TEXTURE_ID_GLYPH_ATLAS: Texture_ID : 1;

// TODO(jt): Get the monitor refresh rate from platform instead!
USUAL_DELTA_TIME: f64 : 1.0 / 60.0;

FILE_WATCH_POLL_PERIOD:  Apollo_Time : #run milliseconds_to_apollo(5000); // The maximum amount of time after which the polling fallback for file detection happens.
FILE_WATCH_BLIND_WINDOW: Apollo_Time : #run milliseconds_to_apollo(250);  // The amount of time we for which we disregard reported changes for a directory after a write.

// TODO(jt): Make the colors themeable. :Config
CURSOR_COLOR               :: #run unpack_srgba(0x50ffa0ff);
ACTIVE_CURSOR_COLOR        :: #run unpack_srgba(0xffffffff);
READONLY_CURSOR_COLOR      :: #run unpack_srgba(0xff0000ff);
SELECTION_COLOR            :: #run -> Vector4 { c := adjust_saturation_and_value(CURSOR_COLOR, 0.5, 1.2); c.w = 0.2; return c; };
HIGHLIGHT_COLOR            :: #run -> Vector4 { c := adjust_saturation_and_value(CURSOR_COLOR, 0.5, 1.2); c.w = 0.4; return c; };
ACTIVE_HIGHLIGHT_COLOR     :: #run unpack_srgba(0xd08080ff);
MATCHING_PARENTHESIS_COLOR :: #run unpack_srgba(0x70a0f0ff);
LINE_COLOR                 :: Vector4.{ 0, 0, 0, 0 };
MODELINE_COLOR             :: #run unpack_srgba(0x090909ff);
GUTTER_COLOR               :: BACKGROUND_COLOR;
SEPARATOR_COLOR            :: MODELINE_COLOR;
BACKGROUND_COLOR           :: #run unpack_srgba(0x191919ff);

TEXT_COLOR                   :: #run unpack_srgba(0xcdaa7dff);
KEYWORD_COLOR                :: #run unpack_srgba(0xe95410ff);
ATTRIBUTE_COLOR              :: KEYWORD_COLOR;
PREPROCESSOR_DIRECTIVE_COLOR :: KEYWORD_COLOR;
STRING_LITERAL_COLOR         :: #run unpack_srgba(0x98c379ff);
NUMBER_LITERAL_COLOR         :: #run unpack_srgba(0x759fbfff);
COMMENT_COLOR                :: #run unpack_srgba(0xa0a0a0ff);

MINI_PANEL_LINE_COLOR      :: #run -> Vector4 { c := adjust_saturation_and_value(CURSOR_COLOR, 0.5, 1.2); c.w = 0.1; return c; };
MINI_PANEL_ITEM_TEXT_COLOR :: TEXT_COLOR;
MINI_PANEL_ITEM_WARNING_TEXT_COLOR :: #run unpack_srgba(0xe95410ff);

PANEL_GUTTER_PIXELS          :: 10.0; // TODO(jt): Make this configurable. :Config
PANEL_SCROLL_PADDING_CELLS_X :: 3;    // TODO(jt): Make this configurable. :Config
PANEL_SCROLL_PADDING_CELLS_Y :: 3;    // TODO(jt): Make this configurable. :Config

MINI_PANEL_LINES :: 10;   // TODO(jt): Make this configurable. :Config

Editor :: struct {
    perm_arena: *Arena;

    font: Font;
    font_size: s32; // Scaled!

    input_state: Input_State;
    key_map: Key_Map(Editor_Action);
    watched_files: [..] string;

    //
    // Documents are referenced by panels (one document, many panels). When we close a panel or
    // switch a panel to a different document, the original document remains. When we close/unload a
    // document, we need to go through every panel and make sure it does not reference that.
    //
    documents: Bucket_Array(Document, 16);
    panels:    [..] Panel;

    // This is a simple hardcoded version of the view tree. We can replace it with fully K-d tree
    // layout out in an array, once we do arbitrary panel splitting.
    active_view: enum u8 {
        FULL;   // The screen is not split into multiple views.
        LEFT;   // The screen is split horizontally, and the left view is active.
        RIGHT;  // The screen is split horizontally, and the right view is active.
    };
    full_view_panel_index: s64;
    left_view_panel_index: s64;
    right_view_panel_index: s64;

    mini_panel: Mini_Panel;
    modal_interaction: Modal_Interaction;

    messages: [..] string;
    last_message_seen: bool;

    is_first_frame: bool;

    dev_view: Dev_View;

    Dev_View :: enum u8 {
        NONE;
        ATLAS_TEXTURE;
        PALETTE;
    };
}

Document :: struct {
    locator: Bucket_Locator;

    kind: Kind;
    mode: Mode;
    flags: Flags;
    time_of_last_interaction: Apollo_Time;

    cursors: Text_Cursors; // Used to restore cursors in the panel, if the document was in the background. Otherwise, the panel's cursors take precedence.
    buffer: Text_Buffer;

    arena: *Arena; // For backing_file_path and syntax_highlight_tokens.

    // Newly created documents (and scratch documents) do not have a backing file until saved, at
    // which point a backing file path is assigned and file created. A document with a
    // backing_file_path can also be created without the file already existing.
    backing_file_path: string;
    backing_file_exists: bool;
    backing_file_time_of_last_save: Apollo_Time; // Used to filter out modifications from the filesystem done by us.
    backing_file_time_of_last_sync: Apollo_Time;
    // The modification time and size are used to detect changes on filesystem since we last read
    // from or wrote to the file.
    //
    // TODO(jt): modtime and size are not sufficient to detect all file changes, and we may need to
    // resort to actually reading that and comparing the contents hash to a previously stored hash,
    backing_file_last_synced_modification_time: Apollo_Time;
    backing_file_last_synced_size: s64;
    backing_file_last_synced_hash: u64;

    parenthesized_scopes:    [..] Parenthesized_Scope;
    syntax_highlight_tokens: [..] Syntax_Highlight_Token;

    Kind :: enum u32 {
        SCRATCH;
        // COMPILATION;
        FILE;
    }

    Mode :: enum u32 {
        PLAIN_TEXT;
        JAI;
    }

    Flags :: enum_flags u32 {
        NONE :: 0;

        MODIFIED_THIS_FRAME :: 0x01;
        MODIFIED            :: 0x02; // Also see backing_file_exists

        // INCONSISTENT_INDENTATION  0x04;
        // INCONSISTENT_NEWLINES     0x08;

        READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT :: 0x10;
        READONLY_BECAUSE_OF_MANUAL_LOCK         :: 0x20;

        READONLY :: READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT | READONLY_BECAUSE_OF_MANUAL_LOCK;

        // :TransientDocumentFlags
        //
        // These get set during event processing and unset after update for this document's panel is done.
        TRANSIENT :: MODIFIED_THIS_FRAME;
    }

    Parenthesized_Scope :: struct {
        loc0: Text_Location;
        loc1: Text_Location;

        open_paren_char:  u32;
        close_paren_char: u32;

        indentation_flags: Flags;
        indentation_level: s64;

        parent_index:       s64 = -1;
        first_child_index:  s64 = -1;
        next_sibling_index: s64 = -1;

        Flags :: enum_flags u32 {
            NONE :: 0;

            HANGING  :: 0x01; // Casey-style scope, e.g. 'hwnd = CreateWindowExW(0,' (continues on the next line).
            PREFIXED :: 0x02; // The scope opening paren has text before it, e.g. 'for {'. Not actually read, but maybe it will be useful later?
        }
    }

    Syntax_Highlight_Token :: struct {
        loc0: Text_Location;
        loc1: Text_Location;
        type: Type;

        Type :: enum u32 {
            UNINITIALIZED :: 0;

            KEYWORD;
            NUMBER_LITERAL;
            STRING_LITERAL;

            OPERATOR;
            PARENTHESIS;

            // TYPE;
            // IDENTIFIER; (variable, parameter, global...)

            PREPROCESSOR_DIRECTIVE;
            ATTRIBUTE; // [[attribute]] or __attribute__() in C. @Note in JAI, #[attribute] in Rust, [Attribute] in C#;

            COMMENT;
        }
    }
}

Panel :: struct {
    flags: Flags;

    highlights_arena: *Arena;
    highlights: [..] Highlight;
    highlight_index: s64 = -1;

    document: *Document; // Possibly null!

    cursors: Text_Cursors;
    selecting: bool;

    // :FloatPrecision
    //
    // Scroll vectors are f64, because buffers can be large and we actually ran into precision
    // issues with f32 vectors. Doubles suffice for now (verified up to 4GB of prose), but maybe we
    // should do our own numeric type eventually (either 58:6 fixed point or maybe s64 + f32 offset)?
    scroll_source: DVector2;
    // TODO(jt): Snap scroll_target to integers, so we don't blur the font. (At least LiberationMono
    // actually takes care to advance in integer amount of pixels when laying out the line.)
    scroll_target: DVector2;
    scroll_time_start: Apollo_Time;
    // TODO(jt): Consider rethinking the coordinate system here. Currently scroll is screen-centric,
    // but maybe we want to represent it as translation in world space (which would basically mean
    // negating it).
    scroll: DVector2;

    // Preserved at the start of each frame to find out if we want to kick off cursor animation, if
    // the cursor changed position due to input.
    old_cursor: Text_Location;
    old_cursor_position: DVector2;

    cursor_anim_source: DVector2;
    cursor_anim_target: DVector2;
    cursor_anim_time_start: Apollo_Time;
    cursor_anim: DVector2;

    cursor_flash_source: Vector4;
    cursor_flash_target: Vector4;
    cursor_flash_time_start: Apollo_Time;
    cursor_flash: Vector4;

    Flags :: enum_flags u32 {
        NONE :: 0;

        CLAMP_CURSOR_TO_SCROLL        :: 0x01;
        CLAMP_SCROLL_TO_CURSOR        :: 0x02;
        CLAMP_SCROLL_TO_START_OF_LINE :: 0x04; // Implies CLAMP_SCROLL_TO_CURSOR;
        CLAMP_SCROLL_TO_END_OF_LINE   :: 0x08; // Implies CLAMP_SCROLL_TO_CURSOR;
        RECEIVED_KEYBOARD_INTERACTION :: 0x10;
        RECEIVED_MOUSE_INTERACTION    :: 0x20;

        // These get set and unset in setup_cursor_anim_interpolation.
        CURSOR_ANIM_TRIGGERED_BY_MOUSE    :: 0x0100;
        CURSOR_ANIM_TRIGGERED_BY_KEYBOARD :: 0x0200;

        // :TransientPanelFlags
        //
        // These get set during event processing and unset after update for this panel is done.
        TRANSIENT :: CLAMP_CURSOR_TO_SCROLL |
                     CLAMP_SCROLL_TO_CURSOR | CLAMP_SCROLL_TO_START_OF_LINE | CLAMP_SCROLL_TO_END_OF_LINE |
                     RECEIVED_KEYBOARD_INTERACTION | RECEIVED_MOUSE_INTERACTION;
    }

    Highlight :: struct {
        x0: s64;
        x1: s64;
        y:  s64;
    }
}

// TODO(jt): @Design @Cleanup Try moving Mini_Panel, Modal_Interaction, and their APIs to their own
// files, so that we slowly start formalizing how people would do more of this stuff.

Mini_Panel :: struct {
    open: bool;
    procs: Mini_Panel_Procs;

    cursors: Text_Cursors;
    selecting: bool;

    buffer: Text_Buffer;

    key_map: Key_Map(Mini_Panel_Action); // Not reset, because all mini panel things basically interact the same.

    items_arena: *Arena;
    items: [..] Item;
    item_index: s64; // [0, items.count) to select a item, -1 to select the mini panel's buffer (if allowed by the action).

    userdata_arena: *Arena;
    userdata: *void; // Set this by passing it to open_mini_panel. You can allocate it with userdata_arena.

    Item :: struct {
        text: string;
        text_color: Vector4;
        flags: Flags;
        highlight_x0: s64;
        highlight_x1: s64;

        // The proc that fills these in can put things in here for the other procs. It can use the
        // items_arena to allocate.
        userdata: *void;

        Flags :: enum_flags u64 {
            NONE :: 0;

            BINARY :: 0x01;
        }
    }
}

Mini_Panel_Procs :: struct {
    get_action_text:      Mini_Panel_Get_Action_Text_Proc;
    can_select_text_line: Mini_Panel_Can_Select_Text_Line_Proc;
    init:                 Mini_Panel_Init_Proc;
    update:               Mini_Panel_Update_Proc;
    delete_backward:      Mini_Panel_Delete_Backward_Proc;
    autocomplete:         Mini_Panel_Autocomplete_Proc;
    confirm:              Mini_Panel_Confirm_Proc;
    cancel:               Mini_Panel_Cancel_Proc;
}

Mini_Panel_Get_Action_Text_Proc      :: #type (editor: *Editor, platform: Platform, input: Input) -> /* Possibly short lifetime */ string;
Mini_Panel_Can_Select_Text_Line_Proc :: #type (editor: *Editor, platform: Platform, input: Input) -> bool;
Mini_Panel_Init_Proc                 :: #type (editor: *Editor, platform: Platform, input: Input);
Mini_Panel_Update_Proc               :: #type (editor: *Editor, platform: Platform, input: Input, buffer_changed: bool, selected_item_changed: bool);
Mini_Panel_Delete_Backward_Proc      :: #type (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool;
Mini_Panel_Autocomplete_Proc         :: #type (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool;
Mini_Panel_Confirm_Proc              :: #type (editor: *Editor, platform: Platform, input: Input) -> buffer_changed: bool;
Mini_Panel_Cancel_Proc               :: #type (editor: *Editor, platform: Platform, input: Input);

Modal_Interaction :: struct {
    open: bool;
    procs: Modal_Interaction_Procs;

    key_map: Key_Map(Modal_Interaction_Action); // In the permanent arena. Unlike mini panel, this key_map gets reset (keeping memory) and re-initialized each time we open.

    cursors: Text_Cursors;
    buffer: Text_Buffer;                        // Has its own arena, because buffers are special snowflakes (for now).

    userdata_arena: *Arena;
    userdata: *void;
}

Modal_Interaction_Procs :: struct {
    get_action_text: Modal_Interaction_Get_Action_Text_Proc;
    init:            Modal_Interaction_Init_Proc;
    handle_event:    Modal_Interaction_Handle_Event_Proc;
    advance:         Modal_Interaction_Advance_Proc;
    cancel:          Modal_Interaction_Cancel_Proc;
}

Modal_Interaction_Get_Action_Text_Proc :: #type (editor: *Editor, platform: Platform, input: Input) -> /* Possibly short lifetime */ string;
Modal_Interaction_Init_Proc            :: #type (editor: *Editor, platform: Platform, input: Input);
Modal_Interaction_Handle_Event_Proc    :: #type (editor: *Editor, event: Input_Event, platform: Platform, input: Input) -> handled: bool;
Modal_Interaction_Advance_Proc         :: #type (editor: *Editor, platform: Platform, input: Input);
Modal_Interaction_Cancel_Proc          :: #type (editor: *Editor, platform: Platform, input: Input);

init :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) {
    ProfileZone("Editor.init");

    editor.perm_arena = make_arena(platform, .LARGE);

    {
        ProfileZone(":InitFont");
        font_arena := make_arena(platform, .LARGE);

        success := true;
        success=, ttf_regular     := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, arena_allocator(font_arena));
        assert(success);
        success=, ttf_bold        := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Bold.ttf",, arena_allocator(font_arena));
        assert(success);
        success=, ttf_italic      := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Italic.ttf",, arena_allocator(font_arena));
        assert(success);
        success=, ttf_bold_italic := platform.read_file("./data/fonts/LiberationMono/LiberationMono-BoldItalic.ttf",, arena_allocator(font_arena));
        assert(success);

        // TODO(jt): None of the text editors seem to agree on what font size actually is, at least
        // Emacs, VS Code and this editor have completely different ideas. Figure this out and match
        // a standard, if that's even possible.
        FONT_SIZE :: 18; // 16 for use, 18 for streaming

        want_pixel_height := cast(s32, ceil(FONT_SIZE * input.window_scale_factor));

        editor.font_size = FONT_SIZE;
        editor.font = make_font(font_arena, ttf_regular, ttf_bold, ttf_italic, ttf_bold_italic, TEXTURE_ID_GLYPH_ATLAS, want_pixel_height);
    }

    input_state_update_on_frame_start(*editor.input_state, input);
    for input.events {
        input_state_update_with_event(*editor.input_state, it);
    }

    // Editor key map
    {
        key_map := *editor.key_map;
        key_map.allocator = arena_allocator(editor.perm_arena);

        key_map_reserve(key_map, 128);

        key_map_add(key_map, "C-p",     .MOVE_UP);
        key_map_add(key_map, "<up>",    .MOVE_UP);
        key_map_add(key_map, "C-n",     .MOVE_DOWN);
        key_map_add(key_map, "<down>",  .MOVE_DOWN);
        key_map_add(key_map, "C-b",     .MOVE_LEFT);
        key_map_add(key_map, "<left>",  .MOVE_LEFT);
        key_map_add(key_map, "C-f",     .MOVE_RIGHT);
        key_map_add(key_map, "<right>", .MOVE_RIGHT);

        key_map_add(key_map, "C-s",     .SEARCH);
        // TODO(jt): @Cleanup In Emacs, SEARCH_AND_REPLACE is C-M-%, but our platform layer sucks, so we just bound it to something else for now.
        key_map_add(key_map, "C-r",     .SEARCH_AND_REPLACE);

        key_map_add(key_map, "C-x C-f", .OPEN_FILE);
        key_map_add(key_map, "C-x C-s", .SAVE_DOCUMENT);
        key_map_add(key_map, "C-x C-r", .RELOAD_DOCUMENT);

        key_map_add(key_map, "C-x b",   .SWITCH_TO_DOCUMENT);
        key_map_add(key_map, "C-x k",   .CLOSE_DOCUMENT);

        key_map_add(key_map, "C-M-p",   .SWAP_LINE_UP);
        key_map_add(key_map, "C-M-n",   .SWAP_LINE_DOWN);

        key_map_add(key_map, "C-a",     .MOVE_TO_START_OF_LINE);
        key_map_add(key_map, "C-e",     .MOVE_TO_END_OF_LINE);

        key_map_add(key_map, "M-<",     .MOVE_TO_START_OF_DOCUMENT);
        key_map_add(key_map, "<home>",  .MOVE_TO_START_OF_DOCUMENT);
        key_map_add(key_map, "M->",     .MOVE_TO_END_OF_DOCUMENT);
        key_map_add(key_map, "<end>",   .MOVE_TO_END_OF_DOCUMENT);

        key_map_add(key_map, "M-p",     .MOVE_TO_PREVIOUS_BLANK_LINE);
        key_map_add(key_map, "M-n",     .MOVE_TO_NEXT_BLANK_LINE);

        key_map_add(key_map, "M-f",     .MOVE_FORWARD_WORD);
        key_map_add(key_map, "M-b",     .MOVE_BACKWARD_WORD);

        key_map_add(key_map, "C-l",     .RECENTER);
        key_map_add(key_map, "M-v",     .SCROLL_UP);
        key_map_add(key_map, "C-v",     .SCROLL_DOWN);
        key_map_add(key_map, "<pageup>", .SCROLL_UP);
        key_map_add(key_map, "<pagedown>", .SCROLL_DOWN);
        key_map_add(key_map, "<prior>", .SCROLL_UP);
        key_map_add(key_map, "<next>",  .SCROLL_DOWN);

        key_map_add(key_map, "C-<space>", .START_SELECTING);
        key_map_add(key_map, "C-g",     .STOP_SELECTING);

        key_map_add(key_map, "C-k",     .DELETE_LINE);
        key_map_add(key_map, "C-d",     .DELETE_FORWARD);
        key_map_add(key_map, "<backspace>", .DELETE_BACKWARD);
        key_map_add(key_map, "<delete>", .DELETE_FORWARD);

        key_map_add(key_map, "M-d",     .DELETE_FORWARD_WORD);
        key_map_add(key_map, "C-<backspace>", .DELETE_BACKWARD_WORD);
        key_map_add(key_map, "M-<backspace>", .DELETE_BACKWARD_WORD);

        key_map_add(key_map, "C-m",     .INSERT_LINE_BEFORE);
        key_map_add(key_map, "<enter>", .INSERT_LINE_BEFORE);
        key_map_add(key_map, "C-o",     .INSERT_LINE_AFTER);

        key_map_add(key_map, "<tab>",   .INDENT_OR_AUTOCOMPLETE);
        key_map_add(key_map, "C-i",     .INDENT_OR_AUTOCOMPLETE);

        key_map_add(key_map, "C-/",     .UNDO_EDIT);
        key_map_add(key_map, "M-/",     .REDO_EDIT);

        key_map_add(key_map, "M-w",     .COPY);
        key_map_add(key_map, "C-w",     .CUT);
        key_map_add(key_map, "C-y",     .PASTE);

        key_map_add(key_map, "C-x 3",   .SPLIT_VIEW_HORIZONTALLY);
        key_map_add(key_map, "C-x 0",   .CLOSE_CURRENT_VIEW);
        key_map_add(key_map, "C-x 1",   .CLOSE_OTHER_VIEWS);
        key_map_add(key_map, "C-x o",   .GO_TO_NEXT_VIEW);

        log("Document keymap:\n%", key_map_sprint(key_map,, temp));
    }

    editor.watched_files.allocator = arena_allocator(editor.perm_arena);
    editor.documents.allocator     = arena_allocator(editor.perm_arena);
    editor.panels.allocator        = arena_allocator(editor.perm_arena);

    // Create *scratch* document
    scratch_document := find_or_add_document(editor, platform, .SCRATCH, "");
    {
        // For -x64/-llvm and -sanity, 64KB is smooth, but it chokes on larger stuff.
        // For -optimized and -no-sanity, 256MB is smooth, and can go up to 1GB without being too choppy.
        HELLO_SIZE: s64 : 128 << 10;

        hello_arena := make_arena(platform, .LARGE);
        hello_text := make_hello_text(hello_arena, HELLO_SIZE);

        text_buffer_insert(*scratch_document.buffer, *scratch_document.cursors, hello_text, .OMIT);
        scratch_document.cursors.c0 = { 0, 0 };
        scratch_document.cursors.c1 = { 0, 0 };

        // For when you want to materialize The Year of Glad.
        //
        // {
        //     #import "File";
        //     write_entire_file("hello.txt", hello_text);
        // }

        arena_release(hello_arena);
    }

    panel := array_add(*editor.panels);
    panel_init(panel, editor, platform, scratch_document);

    //
    // Init mini panel
    //
    {
        mini_panel := *editor.mini_panel;

        key_map := *mini_panel.key_map;
        key_map.allocator = arena_allocator(editor.perm_arena);

        key_map_reserve(key_map, 128);

        key_map_add(key_map, "C-p",         .MOVE_UP);
        key_map_add(key_map, "C-n",         .MOVE_DOWN);
        key_map_add(key_map, "C-b",         .MOVE_LEFT);
        key_map_add(key_map, "C-f",         .MOVE_RIGHT);
        key_map_add(key_map, "<up>",        .MOVE_UP);
        key_map_add(key_map, "<down>",      .MOVE_DOWN);
        key_map_add(key_map, "<left>",      .MOVE_LEFT);
        key_map_add(key_map, "<right>",     .MOVE_RIGHT);

        key_map_add(key_map, "C-a",         .MOVE_TO_START_OF_LINE);
        key_map_add(key_map, "C-e",         .MOVE_TO_END_OF_LINE);

        key_map_add(key_map, "M-f",         .MOVE_FORWARD_WORD);
        key_map_add(key_map, "M-b",         .MOVE_BACKWARD_WORD);

        key_map_add(key_map, "C-d",         .DELETE_FORWARD);
        key_map_add(key_map, "<delete>",    .DELETE_FORWARD);
        key_map_add(key_map, "<backspace>", .DELETE_BACKWARD);

        key_map_add(key_map, "M-v",         .SCROLL_UP);
        key_map_add(key_map, "C-v",         .SCROLL_DOWN);

        key_map_add(key_map, "C-<space>",   .START_SELECTING);

        key_map_add(key_map, "<tab>",       .INDENT_OR_AUTOCOMPLETE);
        key_map_add(key_map, "C-i",         .INDENT_OR_AUTOCOMPLETE);

        key_map_add(key_map, "<enter>",     .CONFIRM);
        key_map_add(key_map, "C-m",         .CONFIRM);
        key_map_add(key_map, "C-g",         .CANCEL_OR_STOP_SELECTING);

        log("Mini Panel keymap:\n%", key_map_sprint(key_map,, temp));

        // Mini text buffer gets its own arena, because it survives longer than the items.
        text_buffer_init(*mini_panel.buffer, make_arena(platform, .SMALL));

        mini_panel.items_arena = make_arena(platform, .LARGE);
        mini_panel.items.allocator = arena_allocator(mini_panel.items_arena);

        mini_panel.userdata_arena = make_arena(platform, .SMALL);
    }

    //
    // Init modal interaction
    //
    {
        modal_interaction := *editor.modal_interaction;

        key_map := *modal_interaction.key_map;
        key_map.allocator = arena_allocator(editor.perm_arena);
        key_map_reserve(key_map, 128);

        text_buffer_init(*modal_interaction.buffer, make_arena(platform, .SMALL));

        modal_interaction.userdata_arena = make_arena(platform, .SMALL);
    }

    editor.messages.allocator = arena_allocator(editor.perm_arena);

    #if FONT_SUBPIXEL {
        atlas: [] u8;
        atlas.count = editor.font.glyph_atlas.count * 4;
        atlas.data  = cast(*u8, editor.font.glyph_atlas.data);

        renderer.create_texture_rgba8unorm(
            TEXTURE_ID_GLYPH_ATLAS,
            atlas,
            editor.font.glyph_atlas_width_in_pixels,
            editor.font.glyph_atlas_height_in_pixels,
        );
    } else {
        renderer.create_texture_r8unorm(
            TEXTURE_ID_GLYPH_ATLAS,
            editor.font.glyph_atlas,
            editor.font.glyph_atlas_width_in_pixels,
            editor.font.glyph_atlas_height_in_pixels,
        );
    }

    editor.is_first_frame = true;
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> wants_next_frame: bool {
    ProfileZone("Editor.update_and_render");

    dt: f64;
    if input.frame_requested_by_editor {
        dt = to_float64_seconds(input.dtime);
    } else {
        // No way to tell delta if we were sleeping, so we just put something in there.
        dt = USUAL_DELTA_TIME;
    }

    // With wants_this_frame we control whether early out to save battery/fans. Currently, we early
    // out just before submitting stuff to the GPU, but we could take this further and early out
    // during the panel processing loop, etc.
    //
    // :BatterySaver
    //
    // Note that this is volatile and sensitive to changes in other parts of the code. For instance,
    // we we add a new type of input, we also have to check here to see if it should cause us to
    // always render the frame.
    //
    // TODO(jt): Windows still reports a very high power usage if we just move the mouse around. Can
    // we do something better?
    wants_this_frame :=
        editor.is_first_frame ||
        input.window_size != editor.input_state.window_size ||
        // TODO(jt): input.window_scale_factor != editor.input_state.window_scale_factor ||
        input.frame_requested_by_editor ||
        input.mouse_wheel_delta != 0 ||
        input.watched_directory_changes.count > 0 ||
        input.events.count > 0;
    wants_next_frame := false;

    render_commands: [..] Render_Command;
    render_commands.allocator = temp;
    update_regions: [..] IRect;
    update_regions.allocator = temp;

    input_state_update_on_frame_start(*editor.input_state, input);

    for * editor.panels {
        if it.old_cursor != it.cursors.c0 {
            it.old_cursor = it.cursors.c0;
            it.old_cursor_position = get_cursor_position(it, editor.font);
        }
    }

    for change: input.watched_directory_changes {
        if change.flags & .MODIFIED {
            // Make sure to supress changes for documents we recently changed ourselves. We need to
            // know the coalescing period of the file watcher to reliably do this.
            path, _, _, filename := String.path_decomp(change.path);
            do_full_scan := cast(bool, change.flags & .NEED_FULL_CHILDREN_SCAN); // This should imply the directory is MODIFIED.

            for * editor.documents {
                // Possibly the file was modified by us. Ignore. If this indeed is a valid
                // modification done by someone else, we'll discover it int the fallback.
                if input.time - it.backing_file_time_of_last_save < FILE_WATCH_BLIND_WINDOW {
                    continue;
                }

                if it.backing_file_path == change.path {
                    sync_document_with_filesystem(editor, platform, input, it);
                    continue;
                }

                if do_full_scan && String.begins_with(String.path_strip_filename(it.backing_file_path), change.path) {
                    sync_document_with_filesystem(editor, platform, input, it);
                    continue;
                }
            }
        }
    }

    for * editor.documents {
        // Only check after FILE_WATCH_POLL_PERIOD has passed.
        if input.time - it.backing_file_time_of_last_sync > FILE_WATCH_POLL_PERIOD {
            sync_document_with_filesystem(editor, platform, input, it);
        }
    }

    font_new_frame(*editor.font);

    for input.events {
        handled := false;

        input_state_update_with_event(*editor.input_state, it);

        //
        // Global events handled at the editor level.
        //
        if it.flags & .PRESSED {
            if !(it.flags & .REPEAT) {
                editor.last_message_seen = true;
            }

            if it.type == {
                case .KEY; {
                    if it.key == {
                        case .F1;   toggle_dev_view(*editor.dev_view, .ATLAS_TEXTURE); handled = true;
                        case .F2;   toggle_dev_view(*editor.dev_view, .PALETTE); handled = true;
                    }
                }

                case .CODEPOINT; {
                    if editor.input_state.modifiers & .CTRL {
                        if it.codepoint == {
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
            } else if editor.modal_interaction.open {
                route_event_to_modal_interaction(editor, it, platform, input);
            } else {
                route_event_to_panel(editor, it, platform, input);
            }
        }
    }

    //
    // Switch active view by clicking
    //
    // Remember the click before we do the mouse interaction stuff later. Because the mouse stuff
    // happens after we have processed the keyboard events, this code might cause some weird
    // behavior, where the keyboard interaction determines what view is active, and then we change
    // it here. Shouldn't be a problem in practice, right?
    //
    if editor.input_state.keys[Key.MB_LEFT] & .PRESSED {
        for * panel: editor.panels {
            panel_rect := get_panel_rect(editor, it_index);
            if rect_contains_point(panel_rect, input.mouse_position) {
                if #complete editor.active_view == {
                    case .FULL; // No-op
                    case .LEFT;   if it_index == editor.right_view_panel_index  editor.active_view = .RIGHT;
                    case .RIGHT;  if it_index == editor.left_view_panel_index   editor.active_view = .LEFT;
                }
            }
        }
    }

    {
        //
        // Chaging font size (zoom)
        //

        if editor.input_state.modifiers & .CTRL {
            delta: s32;
            if input.mouse_wheel_delta > 0 then delta = 1;
            if input.mouse_wheel_delta < 0 then delta = -1;
            editor.font_size = max(editor.font_size + delta, 1);
        }

        pixel_height := cast(s32, ceil(editor.font_size * input.window_scale_factor));
        if editor.font.pixel_height != pixel_height {
            editor_log(editor, "Font size: %, physical pixel height: %, subpixel: %", editor.font_size, pixel_height, FONT_SUBPIXEL);

            cell_h_before_zoom := editor.font.line_height_in_pixels;
            font_reset_for_options(*editor.font, pixel_height);
            cell_h_after_zoom  := editor.font.line_height_in_pixels;

            for * editor.panels {
                cursor_y := it.cursors.c0.y;
                mouse_y  := (input.mouse_position.y + it.scroll_target.y) / cell_h_before_zoom;

                y: f64 = ifx input.mouse_wheel_delta == 0 then cast(f64, cursor_y) else mouse_y;

                y_position_before_zoom := y * cell_h_before_zoom;
                y_position_after_zoom  := y * cell_h_after_zoom;

                delta := y_position_after_zoom - y_position_before_zoom;

                {
                    target := it.scroll_target;
                    target.y += delta;
                    target.y = max(target.y, 0);
                    setup_instant_scroll_interpolation(it, target);
                }

                // If we change zoom, we need to invalidate old cursor positions in every panel. We
                // also want to fast-forward every every cursor animation, because the interpolants
                // are about to get stale.
                cursor_position := get_cursor_position(it, editor.font);

                it.old_cursor_position = cursor_position;
                setup_instant_cursor_anim_interpolation(it, cursor_position);
            }
        }
    }

    // :FloatPrecision
    //
    // cell_w and cell_h are 32-bit and that's perfectly reasonable for them, but some text
    // documents are big. Beware multiplying cell_W and cell_h with integers (such as line count),
    // as that autocasts the integers to f32, but we want to manually cast them to f64.
    //
    //
    // TODO(jt): cell_w is incorrect in variable-spaced fonts. It should be the width of the current
    // character (of width of a space, if we are pointing past line content).
    cell_w := editor.font.max_glyph_width_in_pixels;
    cell_h := editor.font.line_height_in_pixels;
    window_w := cast(f32, input.window_size.x);
    window_h := cast(f32, input.window_size.y);

    // Currently, there must always be at least one panel. We can relax this in the future.
    hovered_panel, hovered_panel_index := get_panel_for_mouse_cursor(editor, input);
    assert(hovered_panel != null);

    if editor.mini_panel.open {
        // TODO(jt): Handle mouse in mini panel.
    } else if editor.modal_interaction.open {
        // TODO(jt): Handle mouse in modal interaction.
    } else {
        //
        // Mouse wheel scrolling
        //
        // We scroll the hovered panel regardless of which view is hovered or active.
        //
        if input.mouse_wheel_delta != 0 && !(editor.input_state.modifiers & .CTRL) {
            target := hovered_panel.scroll_target;
            target.y -= cast(f64, input.mouse_wheel_delta);
            target.y = clamp(target.y, 0, cell_h * cast(f64, hovered_panel.document.buffer.line_bytes.count - 1));
            setup_instant_scroll_interpolation(hovered_panel, target);

            hovered_panel.flags |= .CLAMP_CURSOR_TO_SCROLL;
            hovered_panel.flags |= .RECEIVED_MOUSE_INTERACTION;
        }

        //
        // Mouse Selection
        //
        // Unlike scrolling, mouse selection is sticky to the panel where it started.
        //
        // TODO(jt): Double click to select word.
        // TODO(jt): Triple click to select line.
        //
        if editor.input_state.keys[Key.MB_LEFT] & .DOWN {
            mouse := input.mouse_position;

            panel_index: s64;
            if #complete editor.active_view == {
                case .FULL;   panel_index = editor.full_view_panel_index;
                case .LEFT;   panel_index = editor.left_view_panel_index;
                case .RIGHT;  panel_index = editor.right_view_panel_index;
            }

            panel      := *editor.panels[panel_index];
            panel_rect := get_panel_rect(editor, panel_index);
            panel_w    := rect_width(panel_rect);

            //
            // Mouse selection scrolling
            //
            {
                SCROLL_ZONE:  f32 :  20.0;
                SCROLL_SPEED: f64 :  10.0;
                SCROLL_BOOST: f64 :   5.0;

                left_edge   := panel_rect.x0 + SCROLL_ZONE;
                right_edge  := panel_rect.x1 - SCROLL_ZONE;
                top_edge    := panel_rect.y0 + SCROLL_ZONE;
                bottom_edge := panel_rect.y1 - SCROLL_ZONE;

                if mouse.x < left_edge {
                    boost := (left_edge - mouse.x) * SCROLL_BOOST;

                    target := panel.scroll_target;
                    target.x -= SCROLL_SPEED * boost * dt;
                    target.x = max(target.x, 0);
                    setup_instant_scroll_interpolation(panel, target);

                    wants_this_frame = true;
                    wants_next_frame = true;
                } else if mouse.x > right_edge {
                    boost := (mouse.x - right_edge) * SCROLL_BOOST;

                    // Apron contains at least the horizontal space to place the cursor after
                    // scroll, and optionally the configurable horizontal padding, so that it
                    // behaves the same as if we scrolled there by moving the cursor with the
                    // keyboard.
                    apron := (1 + PANEL_SCROLL_PADDING_CELLS_X) * cell_w + PANEL_GUTTER_PIXELS;

                    line_view := text_buffer_make_view_for_line(panel.document.buffer, panel.cursors.c0.y,, temp);

                    // Clamp to zero, so we don't end up scrolling the other way if the line is
                    // short. (Happens if you start scrolling on a long line, but then vertically
                    // scroll to a short line.)
                    max_x := max(font_compute_line_length(editor.font, line_view, binary = panel.document.buffer.binary_mode) - panel_w + apron, 0);

                    target := panel.scroll_target;
                    target.x += SCROLL_SPEED * boost * dt;
                    target.x = min(target.x, max_x);
                    setup_instant_scroll_interpolation(panel, target);

                    wants_this_frame = true;
                    wants_next_frame = true;
                }

                if mouse.y < top_edge {
                    boost := (top_edge - mouse.y) * SCROLL_BOOST;

                    target := panel.scroll_target;
                    target.y -= SCROLL_SPEED * boost * dt;
                    target.y = max(target.y, 0);
                    setup_instant_scroll_interpolation(panel, target);

                    wants_this_frame = true;
                    wants_next_frame = true;
                } else if mouse.y > bottom_edge {
                    boost := (mouse.y - bottom_edge) * SCROLL_BOOST;

                    target := panel.scroll_target;
                    target.y += SCROLL_SPEED * boost * dt;
                    target.y = min(target.y, cell_h * cast(f64, panel.document.buffer.line_bytes.count - 1));
                    setup_instant_scroll_interpolation(panel, target);

                    wants_this_frame = true;
                    wants_next_frame = true;
                }
            }

            row := cast(s64, floor((mouse.y + panel.scroll.y) / cell_h));
            col := 0;

            if row < 0 {
                row = 0;
                col = 0;
            } else if row > panel.document.buffer.line_bytes.count - 1 {
                row = panel.document.buffer.line_bytes.count - 1;

                // Include newline, so that the cursor can go there.
                line_view := text_buffer_make_view_for_line(panel.document.buffer, row, include_newline = true,, temp);
                col = font_compute_character_index_on_line(editor.font, line_view, mouse.x - panel_rect.x0 + panel.scroll.x, binary = panel.document.buffer.binary_mode);
            } else {
                // Include newline, so that the cursor can go there.
                line_view := text_buffer_make_view_for_line(panel.document.buffer, row, include_newline = true,, temp);
                col = font_compute_character_index_on_line(editor.font, line_view, mouse.x - panel_rect.x0 + panel.scroll.x, binary = panel.document.buffer.binary_mode);
            }

            text_buffer_move_cursor_to(panel.document.buffer, *panel.cursors, col, row, !(editor.input_state.keys[Key.MB_LEFT] & .PRESSED));

            panel.flags |= .RECEIVED_MOUSE_INTERACTION;
        }
    }

    for * panel, panel_index: editor.panels {
        ProfileZone(":PanelUpdateAndRender");

        //
        // :PanelUpdate
        //
        // This is maybe a misnomer, because some updates already happened when the panel received
        // keyboard events (route_event_to_panel) and mouse input (zoom, scrolling, selection). In
        // general, those earlier pieces of code tried to do as little work as possible, deferring
        // serious updates to this loop (e.g. update_syntax_highlights) by setting various flags on
        // the panel.
        //
        // The bottom half of this loop is animation and rendering.
        //

        document := panel.document;
        if !document {
            // TODO(jt): Draw something in empty panels?
            continue;
        }

        defer {
            // Clearing is deferred, because we are thinking of doing early return in this loop.
            // See :BatterySaver.
            clear_transient_document_flags(*document.flags);
            clear_transient_panel_flags(*panel.flags);
        }

        // Because other panels could have edited the same document before this code runs (either or
        // this frame, if they run before us in the loop, or in the previous frame, if they run
        // after), we need to make sure the cursors are still valid. We could also be clamping for
        // each operation, but I am not sure I like that.  -jt, 24 July 2026.
        text_buffer_clamp_cursors(document.buffer, *panel.cursors);

        panel_rect, panel_content_rect := get_panel_rect(editor, panel_index);
        panel_x := panel_rect.x0;
        panel_y := panel_rect.y0;
        panel_w := rect_width(panel_rect);
        panel_h := rect_height(panel_rect);
        panel_content_x := panel_content_rect.x0;
        panel_content_w := rect_width(panel_content_rect);

        panel_is_active := panel == get_panel_for_active_view(editor);

        //
        // Compute cursor position.
        //
        panel_cursor0_position, panel_cursor0_line_end_x := get_cursor_position(panel, editor.font);

        //
        // Move cursor to buffer
        //
        if panel.flags & .CLAMP_CURSOR_TO_SCROLL {
            ProfileZone(":ClampCursor");

            viewport_rect := drect_from_point_and_size(panel.scroll_target.x, panel.scroll_target.y, panel_w, panel_h);
            cursor_rect   := drect_from_point_and_size(panel_cursor0_position.x, panel_cursor0_position.y, cell_w, cell_h);

            SCROLL_PADDING :: 7; // TODO(jt): Make this configurable. :Config

            cursor_position_dirty := false;
            if viewport_rect.y0 > cursor_rect.y1 {
                // Move cursor down
                delta := cast(s64, ceil((viewport_rect.y0 - cursor_rect.y1) / cell_h)) + SCROLL_PADDING;
                text_buffer_move_cursor_y(document.buffer, *panel.cursors, delta, panel.selecting);

                cursor_position_dirty = true;
            } else if viewport_rect.y1 < cursor_rect.y0 {
                // Move cursor up
                delta := cast(s64, ceil((cursor_rect.y0 - viewport_rect.y1) / cell_h)) + SCROLL_PADDING;
                text_buffer_move_cursor_y(document.buffer, *panel.cursors, -delta, panel.selecting);

                cursor_position_dirty = true;
            }

            if cursor_position_dirty {
                panel_cursor0_position, panel_cursor0_line_end_x = get_cursor_position(panel, editor.font);
            }
        }

        //
        // Scroll buffer to cursor
        //
        if panel.flags & .CLAMP_SCROLL_TO_CURSOR || panel.flags & .CLAMP_SCROLL_TO_START_OF_LINE || panel.flags & .CLAMP_SCROLL_TO_END_OF_LINE {
            ProfileZone(":ClampScroll");

            scroll_padding_x := min(panel_w * 0.25, cell_w * PANEL_SCROLL_PADDING_CELLS_X);
            scroll_padding_y := min(panel_h * 0.25, cell_h * PANEL_SCROLL_PADDING_CELLS_Y);

            viewport_rect := drect_from_point_and_size(panel.scroll_target.x + PANEL_GUTTER_PIXELS, panel.scroll_target.y, panel_content_w, panel_h);
            scroll_to_rect: DRect;
            if panel.flags & .CLAMP_SCROLL_TO_START_OF_LINE {
                scroll_to_rect = drect_from_point_and_size(0, panel_cursor0_position.y, cell_w, cell_h);
            } else if panel.flags & .CLAMP_SCROLL_TO_END_OF_LINE {
                scroll_to_rect = drect_from_point_and_size(panel_cursor0_line_end_x, panel_cursor0_position.y, cell_w, cell_h);
            } else {
                scroll_to_rect = drect_from_point_and_size(panel_cursor0_position.x, panel_cursor0_position.y, cell_w, cell_h);
            }

            if scroll_to_rect.x1 > viewport_rect.x1 {
                target := panel.scroll_target;
                target.x = scroll_to_rect.x0 - panel_w + drect_width(scroll_to_rect) + scroll_padding_x;
                setup_scroll_interpolation(panel, input.time, panel.scroll, target);
            } else if scroll_to_rect.x0 < viewport_rect.x0 {
                target := panel.scroll_target;
                target.x = scroll_to_rect.x0 - scroll_padding_x;
                setup_scroll_interpolation(panel, input.time, panel.scroll, target);
            }

            if scroll_to_rect.y1 > viewport_rect.y1 {
                target := panel.scroll_target;
                target.y = scroll_to_rect.y0 - panel_h + drect_height(scroll_to_rect) + scroll_padding_y;
                setup_scroll_interpolation(panel, input.time, panel.scroll, target);
            } else if scroll_to_rect.y0 < viewport_rect.y0 {
                target := panel.scroll_target;
                target.y = scroll_to_rect.y0 - scroll_padding_y;
                setup_scroll_interpolation(panel, input.time, panel.scroll, target);
            }
        }

        if document.flags & .MODIFIED_THIS_FRAME {
            update_syntax_highlights(editor, document, platform, input);
        }

        //
        // :PanelAnimateAndRender
        //

        //
        // Scroll animation
        //
        {
            SCROLL_TIME: f64 : 0.15; // TODO(jt): Make this configurable. :Config

            t := cast(f32, (to_float64_seconds(input.time) + USUAL_DELTA_TIME - to_float64_seconds(panel.scroll_time_start)) / SCROLL_TIME);
            t = clamp(t, 0.0, 1.0);
            t = smoothstep(0.0, 1.0, t);

            if SCROLL_TIME == 0 {
                panel.scroll = panel.scroll_target;
            } else {
                panel.scroll = lerp(panel.scroll_source, panel.scroll_target, t);
            }

            if t < 1.0 {
                wants_this_frame = true;
                wants_next_frame = true;
            }
        }

        // Now that we have finished scrolling, we can define the range that the viewport sees.
        viewport_y0 := panel.scroll.y;
        viewport_y1 := panel.scroll.y + panel_h;

        viewport_line0 := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, document.buffer.line_bytes.count - 1);
        viewport_line1 := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, document.buffer.line_bytes.count - 1);

        // We'll be drawing from here on until the end of the loop, so better set that scissor.
        set_scissor(*render_commands, panel_rect);

        //
        // Draw Highlights
        //
        for panel.highlights {
            if it.y < viewport_line0  continue; // TODO(jt): @Speed Binary search or skip ahead for the start instead?
            if it.y > viewport_line1  break;

            // TODO(jt): @Speed Compute gap buffer indices incrementally as we go through the loop.
            line_view := text_buffer_make_view_for_line(document.buffer, it.y,, temp);

            x0 := font_compute_position_on_line(editor.font, line_view, it.x0, binary = document.buffer.binary_mode);
            x1 := font_compute_position_on_line(editor.font, line_view, it.x1, binary = document.buffer.binary_mode);
            y0 := cast(f64, it.y) * cell_h;
            y1 := y0 + cell_h;

            highlight_rect_world: DRect = { x0, y0, x1, y1 };
            highlight_rect_screen := panel_content_rect.p0 + drect_to_rect(highlight_rect_world - panel.scroll);
            highlight_rect_screen = rect_clamp(highlight_rect_screen, panel_content_rect);

            if it_index == panel.highlight_index {
                draw_rect(*render_commands, highlight_rect_screen, ACTIVE_HIGHLIGHT_COLOR);
            } else {
                draw_rect(*render_commands, highlight_rect_screen, HIGHLIGHT_COLOR);
            }
        }

        //
        // Layout and draw selection
        //
        if panel_is_active && panel.cursors.c0 != panel.cursors.c1 {
            cursor_start := text_location_min(panel.cursors.c0, panel.cursors.c1);
            cursor_end   := text_location_max(panel.cursors.c0, panel.cursors.c1);

            if cursor_start.y == cursor_end.y {
                ProfileZone(":DrawSelectionSingleLine");

                line_start := text_buffer_get_start_of_line(document.buffer, cursor_start.y);

                view_before_cursor   := text_buffer_make_view_for_interval(document.buffer, line_start, cursor_start,, temp);
                view_between_cursors := text_buffer_make_view_for_interval(document.buffer, cursor_start, cursor_end,, temp);

                selection_x0_world := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x, binary = document.buffer.binary_mode);
                selection_x1_world := font_compute_position_on_line(editor.font, view_between_cursors, cursor_end.x - cursor_start.x, binary = document.buffer.binary_mode) + selection_x0_world;
                selection_y0_world := cast(f64, cursor_start.y) * cell_h;
                selection_y1_world := selection_y0_world + cell_h;
                selection_rect_world: DRect = {
                    selection_x0_world,
                    selection_y0_world,
                    selection_x1_world,
                    selection_y1_world,
                };

                selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll);
                selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                draw_rect(*render_commands, selection_rect_screen, SELECTION_COLOR);
            } else {
                ProfileZone(":DrawSelectionMultiLine");

                // TODO(jt): @Speed Horizontal culling?

                // Because we start the layout just before the current viewport, the rendering scroll Y offset
                // is just the fractional part of the cell.
                //
                // Because we expect scroll_offset to be small, we keep it in f32.
                scroll_offset: Vector2;
                scroll_offset.x = cast(f32, panel.scroll.x);
                scroll_offset.y = cast(f32, viewport_y0 - cell_h * cast(f64, viewport_line0));

                // First line, if in viewport
                if cursor_start.y >= viewport_line0 && cursor_start.y <= viewport_line1 {
                    line_start := text_buffer_get_start_of_line(document.buffer, cursor_start.y);
                    line_end   := text_buffer_get_end_of_line(document.buffer, cursor_start.y);

                    view_before_cursor := text_buffer_make_view_for_interval(document.buffer, line_start, cursor_start,, temp);
                    view_after_cursor  := text_buffer_make_view_for_interval(document.buffer, cursor_start, line_end,, temp);

                    selection_x0_world := font_compute_position_on_line(editor.font, view_before_cursor, cursor_start.x, binary = document.buffer.binary_mode);
                    selection_x1_world := font_compute_position_on_line(editor.font, view_after_cursor, line_end.x - cursor_start.x, binary = document.buffer.binary_mode) + selection_x0_world;
                    selection_y0_world := cast(f64, cursor_start.y) * cell_h;
                    selection_y1_world := selection_y0_world + cell_h;
                    selection_rect_world: DRect = {
                        selection_x0_world,
                        selection_y0_world,
                        selection_x1_world,
                        selection_y1_world,
                    };

                    selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll);
                    selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                    draw_rect(*render_commands, selection_rect_screen, SELECTION_COLOR);
                }

                // Center lines, if in viewport
                for (cursor_start.y + 1)..(cursor_end.y - 1) {
                    // TODO(jt): @Speed Clamp center lines range instead.
                    if it < viewport_line0 || it > viewport_line1 {
                        continue;
                    }

                    line_end  := text_buffer_get_end_of_line(document.buffer, it);
                    line_view := text_buffer_make_view_for_line(document.buffer, it,, temp);
                    selection_x0_world := 0.0;
                    selection_x1_world := font_compute_position_on_line(editor.font, line_view, line_end.x, binary = document.buffer.binary_mode);
                    selection_y0_world := cast(f64, it) * cell_h;
                    selection_y1_world := selection_y0_world + cell_h;
                    selection_rect_world: DRect = {
                        selection_x0_world,
                        selection_y0_world,
                        selection_x1_world,
                        selection_y1_world,
                    };

                    selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll);
                    selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                    draw_rect(*render_commands, selection_rect_screen, SELECTION_COLOR);
                }

                // Last line, if in viewport
                if cursor_end.y >= viewport_line0 && cursor_end.y <= viewport_line1 {
                    line_start := text_buffer_get_start_of_line(document.buffer, cursor_end.y);

                    view_before_cursor := text_buffer_make_view_for_interval(document.buffer, line_start, cursor_end,, temp);

                    selection_x0_world := 0.0;
                    selection_x1_world := font_compute_position_on_line(editor.font, view_before_cursor, cursor_end.x, binary = document.buffer.binary_mode);
                    selection_y0_world := cast(f64, cursor_end.y) * cell_h;
                    selection_y1_world := selection_y0_world + cell_h;
                    selection_rect_world: DRect = {
                        selection_x0_world,
                        selection_y0_world,
                        selection_x1_world,
                        selection_y1_world,
                    };

                    selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll);
                    selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                    draw_rect(*render_commands, selection_rect_screen, SELECTION_COLOR);
                }
            }
        }

        {
            ProfileZone(":DrawMatchingParenthesisHighlight");

            found := false;
            highlight_loc: Text_Location;

            scope := find_parenthesized_scope_for_location(document, panel.cursors.c0);
            if scope && scope.parent_index != -1 {
                if scope.loc0 == panel.cursors.c0 {
                    found = true;
                    highlight_loc = scope.loc1;
                }

                if scope.loc1 == panel.cursors.c0 {
                    found = true;
                    highlight_loc = scope.loc0;
                }
            }

            if found {
                highlight_position := get_position_of_location(document, editor.font, highlight_loc) - panel.scroll;
                highlight_rect := rect_from_point_and_size(panel_content_x + cast(f32, highlight_position.x), cast(f32, highlight_position.y), cell_w, cell_h);

                draw_rect(*render_commands, highlight_rect, MATCHING_PARENTHESIS_COLOR);
            }
        }

        //
        // Draw cursor
        //
        {
            new_cursor_position := panel_cursor0_position;

            // :CentralizedCursorInterpolationSetup
            //
            // Because the cursor position can be changed by both editing, mouse interaction,
            // scrolling, etc, we detect cursor changes every frame here (instead of in all the
            // places where the cursor can change).
            //
            // UPDATE: Now we do the same for cursor flash animation.
            if panel.old_cursor != panel.cursors.c0 {
                triggered_by_mouse    := cast(bool, panel.flags & .RECEIVED_MOUSE_INTERACTION);
                triggered_by_keyboard := cast(bool, panel.flags & .RECEIVED_KEYBOARD_INTERACTION);

                setup_cursor_anim_interpolation(panel, input.time, panel.old_cursor_position, new_cursor_position, triggered_by_mouse, triggered_by_keyboard);
            }

            if document.flags & .MODIFIED_THIS_FRAME {
                setup_cursor_flash_interpolation(panel, input.time, ACTIVE_CURSOR_COLOR, CURSOR_COLOR);
            }

            FLASH_TIME:         f64 : 0.20; // TODO(jt): Make flash time configurable. :Config
            ANIM_TIME_MOUSE:    f64 : 0.15; // TODO(jt): Make mouse anim time configurable. :Config
            ANIM_TIME_KEYBOARD: f64 : 0.00; // TODO(jt): Make keyboard anim time configurable. :Config

            anim_time: f64 = 0.0;
            if panel.flags & .CURSOR_ANIM_TRIGGERED_BY_MOUSE     anim_time = max(anim_time, ANIM_TIME_MOUSE);
            if panel.flags & .CURSOR_ANIM_TRIGGERED_BY_KEYBOARD  anim_time = max(anim_time, ANIM_TIME_KEYBOARD);

            // TODO(jt): Division by zero. (We work around it for scroll and cursor animation.)
            flash_t := cast(f32, (to_float64_seconds(input.time) - to_float64_seconds(panel.cursor_flash_time_start)) / FLASH_TIME);
            flash_t = clamp(flash_t, 0.0, 1.0);
            flash_t = smoothstep(0.0, 1.0, flash_t);

            // TODO(jt): For visuals, it would be nice, if the interpolated cursor left a trail
            // behind it as it moves, because currently, when it moves very fast, you can spot the
            // individual positions it occupies. Fred does this with a CRT persistence effect. Let's
            // also do that!
            //
            // UPDATE: I accidentatlly had something like this with a rect_clamp bug, and it really
            // does look cool. Let's do this!

            anim_t := cast(f32, (to_float64_seconds(input.time) + USUAL_DELTA_TIME - to_float64_seconds(panel.cursor_anim_time_start)) / anim_time);
            anim_t = clamp(anim_t, 0.0, 1.0);
            anim_t = smoothstep(0.0, 1.0, anim_t);

            if flash_t < 1.0 || anim_t < 1.0 {
                wants_this_frame = true;
                wants_next_frame = true;
            }

            panel.cursor_flash = lerp(panel.cursor_flash_source, panel.cursor_flash_target, flash_t);
            panel.cursor_anim = lerp(panel.cursor_anim_source, panel.cursor_anim_target, anim_t);

            if panel_is_active {
                line_rect := rect_from_point_and_size(
                    panel_content_x,
                    cast(f32, new_cursor_position.y - panel.scroll.y),
                    panel_w,
                    cell_h,
                );

                draw_rect(*render_commands, line_rect, LINE_COLOR);

                cursor_rect: Rect;
                if anim_time == 0 {
                    // Straight to the new position to avoid one frame of lag (and results of division by zero).
                    r :=  drect_from_point_and_size(panel_content_x + new_cursor_position.x, new_cursor_position.y, cell_w, cell_h) - panel.scroll;
                    cursor_rect = drect_to_rect(r);
                } else {
                    r := drect_from_point_and_size(panel_content_x + panel.cursor_anim.x, panel.cursor_anim.y, cell_w, cell_h) - panel.scroll;
                    cursor_rect = drect_to_rect(r);
                }

                cursor_rect = rect_clamp(cursor_rect, panel_content_rect);

                draw_rect(*render_commands, cursor_rect, ifx document.flags & .READONLY then READONLY_CURSOR_COLOR else panel.cursor_flash);
            }
        }

        // TODO(jt): @Speed This is an opportune spot to skip work, if we are not going to be
        // presenting this frame. However, we can't easily prove that the next iteration won't set
        // wants_this_frame to true, leading to bad rendering. (Currently, it doesn't happen only by
        // happy accident.) Maybe we could split this loop into two?
        //
        // When this code is enabled, both the Windows (TM) Task Manager and my ears report that the
        // computer is doing less work. We should think about a robust way of doing this. See :BatterySaver.
        //
        // if !wants_this_frame {
        //     continue;
        // }

        //
        // Layout and draw document text
        //
        {
            ProfileZone(":DrawDocumentText");

            // TODO(jt): @Speed Horizontal culling?

            viewport_start := text_buffer_get_start_of_line(document.buffer, viewport_line0);
            viewport_end   := text_buffer_get_end_of_line(document.buffer, viewport_line1);
            viewport_view  := text_buffer_make_view_for_interval(document.buffer, viewport_start, viewport_end,, temp);

            // Because we start the layout just before the current viewport, the rendering scroll Y offset
            // is just the fractional part of the cell.
            //
            // While we expect vertical scroll_offset to be small, horizontal can in theory be pretty
            // big (although I'd wager we have serious performance problems before that starts to
            // matter), so we go f64 to be future proof.
            offset: DVector2;
            offset.x = panel_content_x + -panel.scroll.x;
            offset.y = -viewport_y0 + cell_h * cast(f64, viewport_line0);

            style_ranges: [..] Font_Style_Range;
            style_ranges.allocator = temp;

            //
            // Find syntax highlights for current screen
            //
            {
                ProfileZone(":FindSyntaxHighlights");

                for document.syntax_highlight_tokens {
                    if it.loc1.y < viewport_line0  continue; // TODO(jt): @Speed Binary search or skip ahead for the start instead?
                    if it.loc0.y > viewport_line1  break;

                    r: Font_Style_Range;
                    r.x0 = it.loc0.x;
                    r.y0 = it.loc0.y - viewport_line0;
                    r.x1 = it.loc1.x;
                    r.y1 = it.loc1.y - viewport_line0;

                    if it.type == {
                        // TODO(jt): @Cleanup While we sort of define color constants for things, we
                        // also can modify bold/italic, for which we have no way of customization
                        // yet. :Config
                        case .KEYWORD;                 r.color = KEYWORD_COLOR;
                        case .ATTRIBUTE;               r.color = ATTRIBUTE_COLOR; r.variant = .BOLD;
                        case .PREPROCESSOR_DIRECTIVE;  r.color = PREPROCESSOR_DIRECTIVE_COLOR; r.variant = .BOLD;
                        case .STRING_LITERAL;          r.color = STRING_LITERAL_COLOR;
                        case .NUMBER_LITERAL;          r.color = NUMBER_LITERAL_COLOR;
                        case .COMMENT;                 r.color = COMMENT_COLOR;

                        case; continue;
                    }

                    array_add(*style_ranges, r);
                }
            }

            scissor_rect := rect_from_point_and_size(panel_content_x, 0.0, panel_content_w, panel_h);
            font_layout_and_draw_text(*editor.font, cast(string, viewport_view), *render_commands, *update_regions, offset, scissor_rect, TEXT_COLOR, style_ranges, binary = document.buffer.binary_mode);
        }

        //
        // Draw gutters
        //
        draw_rect(*render_commands, rect_from_point_and_size(panel_x, panel_y, PANEL_GUTTER_PIXELS, panel_h), GUTTER_COLOR);
        draw_rect(*render_commands, rect_from_point_and_size(panel_x + PANEL_GUTTER_PIXELS + panel_content_w, panel_y, PANEL_GUTTER_PIXELS, panel_h), GUTTER_COLOR);

        {
            // TODO(jt): @Cleanup Reformulate the modeline rect as cutting into the current panel instead of using absolute coordinates.
            modeline_y      := ifx editor.mini_panel.open then window_h - (MINI_PANEL_LINES + 2) * cell_h else window_h - 2 * cell_h;
            modeline_rect   := rect_from_point_and_size(panel_x, modeline_y, panel_w, cell_h);
            modeline_offset := DVector2.{ panel_x, modeline_y };

            set_scissor(*render_commands, modeline_rect);
            draw_rect(*render_commands, modeline_rect, MODELINE_COLOR);

            cursor  := panel.cursors.c0;
            percent := cast(s64, 100.0 * cast(f32, cursor.y) / cast(f32, panel.document.buffer.line_bytes.count));

            document_name: string;
            if #complete panel.document.kind == {
                case .SCRATCH; document_name = "*scratch*";
                case .FILE;    document_name = String.path_filename(panel.document.backing_file_path);
            }

            percent_string := temp_right_pad(tprint("%\%", percent), 4);

            s := tprint(" % % (%,%)", temp_right_pad(document_name, 15), percent_string, cursor.y + 1, cursor.x);
            _font_layout_and_draw_text(*editor.font, s, *render_commands, *update_regions, modeline_offset, modeline_rect, TEXT_COLOR, .[], binary = false);
        }
    }

    // Reset scissor for the rest of the drawing.
    set_scissor(*render_commands, { 0, 0, window_w, window_h });

    // Draw view separator
    if editor.active_view != .FULL {
        draw_rect(*render_commands, rect_from_point_and_size(window_w * 0.5 - 1.0, 0.0, 2.0, window_h), SEPARATOR_COLOR);
    }

    // TODO(jt): Instead of just drawing over what the panels drew, let's also use this information for culling?
    if editor.mini_panel.open {
        mini_panel := *editor.mini_panel;

        background_h := (MINI_PANEL_LINES + 1) * cell_h;
        background_y := max(window_h - background_h, 0);
        draw_rect(*render_commands, 0, background_y, window_w, window_h, BACKGROUND_COLOR);

        if mini_panel.item_index == -1 {
            draw_rect(*render_commands, 0, background_y, window_w, background_y + cell_h, MINI_PANEL_LINE_COLOR);
        }

        action_text := mini_panel.procs.get_action_text(editor, platform, input);

        line_view := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);

        line_x    := cast(f32, _font_compute_position_on_line(editor.font, action_text, action_text.count, binary = false));
        cursor0_x := line_x + cast(f32, _font_compute_position_on_line(editor.font, line_view, mini_panel.cursors.c0.x, binary = false));
        cursor1_x := line_x + cast(f32, _font_compute_position_on_line(editor.font, line_view, mini_panel.cursors.c1.x, binary = false));

        draw_rect(*render_commands, cursor0_x, background_y, cursor1_x, background_y + cell_h, SELECTION_COLOR);
        draw_rect(*render_commands, cursor0_x, background_y, cursor0_x + cell_w, background_y + cell_h, CURSOR_COLOR);

        main_line := tprint("%%", action_text, line_view);

        _font_layout_and_draw_text(*editor.font, main_line, *render_commands, *update_regions, { 0, background_y }, { 0, 0, window_w, window_h }, TEXT_COLOR, .[], binary = false);

        index0 := max(mini_panel.item_index - (MINI_PANEL_LINES / 2), 0);
        index1 := min(index0 + MINI_PANEL_LINES, mini_panel.items.count - 1);

        it_index := 0;
        for index0..index1 {
            item := *mini_panel.items[it];

            if it == mini_panel.item_index {
                y0 := background_y + (it_index + 1) * cell_h;
                y1 := background_y + (it_index + 2) * cell_h;
                draw_rect(*render_commands, 0, y0, window_w, y1, MINI_PANEL_LINE_COLOR);

                // TODO(jt): @Speed We need an incremental version of font_compute_position_on_line
                // that can resume where it left of last time. In can see multiple places in this
                // file where that would be useful. It will become more important for long lines.
                x0 := font_compute_position_on_line(editor.font, item.text, item.highlight_x0, binary = cast(bool, item.flags & .BINARY));
                x1 := font_compute_position_on_line(editor.font, item.text, item.highlight_x1, binary = cast(bool, item.flags & .BINARY));

                draw_rect(*render_commands, cast(f32, x0), y0, cast(f32, x1), y1, HIGHLIGHT_COLOR);
            }

            offset_y: f64 = background_y + (it_index + 1) * cell_h;
            font_layout_and_draw_text(*editor.font, item.text, *render_commands, *update_regions, { 0, offset_y }, { 0, 0, window_w, window_h }, item.text_color, .[], binary = cast(bool, item.flags & .BINARY));

            it_index += 1;
        }
    } else if editor.modal_interaction.open {
        modal_interaction := *editor.modal_interaction;

        modal_interaction_line_y := window_h - cell_h;
        draw_rect(*render_commands, 0, modal_interaction_line_y, window_w, window_h, BACKGROUND_COLOR);

        action_text := modal_interaction.procs.get_action_text(editor, platform, input);

        line_view := text_buffer_make_view_for_line(modal_interaction.buffer, 0,, temp);

        line_x   := cast(f32, _font_compute_position_on_line(editor.font, action_text, action_text.count, binary = false));
        cursor_x := line_x + _font_compute_position_on_line(editor.font, line_view, editor.modal_interaction.cursors.c0.x, binary = false);

        draw_rect(*render_commands, rect_from_point_and_size(cast(f32, cursor_x), modal_interaction_line_y, cell_w, cell_h), CURSOR_COLOR);

        main_line := tprint("%%", action_text, line_view);

        _font_layout_and_draw_text(*editor.font, main_line, *render_commands, *update_regions, { 0, modal_interaction_line_y }, { 0, 0, window_w, window_h }, TEXT_COLOR, .[], binary = false);
    } else {
        message_line_y := window_h - cell_h;
        draw_rect(*render_commands, 0, message_line_y, window_w, window_h, BACKGROUND_COLOR);

        if editor.messages.count && !editor.last_message_seen {
            message := editor.messages[editor.messages.count - 1];
            _font_layout_and_draw_text(*editor.font, message, *render_commands, *update_regions, { 0, message_line_y }, { 0, 0, window_w, window_h }, TEXT_COLOR, .[], binary = false);
        }
    }

    if editor.dev_view == {
        case .NONE; // Nothing
        case .ATLAS_TEXTURE; {
            array_reset_keeping_memory(*render_commands);

            w := cast(f32, editor.font.glyph_atlas_width_in_pixels);
            h := cast(f32, editor.font.glyph_atlas_height_in_pixels);
            draw_rect(*render_commands, 0, 0, w, h, { 0.89, 0.89, 0.95, 1 });
            draw_rect(*render_commands, 0, 0, w, h, { 0, 0, 0, 1 }, TEXTURE_ID_GLYPH_ATLAS);
        }
        case .PALETTE; {
            array_reset_keeping_memory(*render_commands);

            for 0..255 {
                WIDTH  :: 100.0;
                HEIGHT :: 4.0;

                y := HEIGHT * it;
                color: Vector4 = { cast(f32, it) / 255.0, 0.0, 0.0, 1.0 };

                {
                    r := rect_from_point_and_size(0, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_value(color, 1.0 / 1.50));
                }

                {
                    r := rect_from_point_and_size(100, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_value(color, 1.0 / 1.25));
                }

                {
                    r := rect_from_point_and_size(200, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, color);
                }

                {
                    r := rect_from_point_and_size(300, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_value(color, 1.25));
                }

                {
                    r := rect_from_point_and_size(400, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_value(color, 1.50));
                }

                {
                    r := rect_from_point_and_size(700, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_saturation(color, 1.0 / 1.50));
                }

                {
                    r := rect_from_point_and_size(800, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_saturation(color, 1.0 / 1.25));
                }

                {
                    r := rect_from_point_and_size(900, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, color);
                }

                {
                    r := rect_from_point_and_size(1000, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_saturation(color, 1.25));
                }

                {
                    r := rect_from_point_and_size(1100, y, WIDTH, HEIGHT);
                    draw_rect(*render_commands, r, adjust_saturation(color, 1.50));
                }
            }
        }
    }

    if editor.font.glyph_cache_overrun {
        log_error("Glyph cache was overrun this frame. Rendering is going to be incorrect. Increase the size of the glyph cache, if this happens.");
    }

    if wants_this_frame {
        update_region := irect_union_or_zero(update_regions);

        // TODO(jt): @Speed OpenGL is doing some kind of synchronization here. Depending on whether
        // update_texture does early return (because the update region is empty), either it or
        // draw_rects blocks for about 10-15ms, but at least one of them does. We should probably just
        // switch to our own rendering backend (raw Vulkan/Metal, WGPU or SGPU) and tune it for latency.
        #if FONT_SUBPIXEL {
            atlas: [] u8;
            atlas.count = editor.font.glyph_atlas.count * 4;
            atlas.data  = cast(*u8, editor.font.glyph_atlas.data);

            renderer.update_texture_rgba8unorm(TEXTURE_ID_GLYPH_ATLAS, atlas, update_region);
        } else {
            renderer.update_texture_r8unorm(TEXTURE_ID_GLYPH_ATLAS, editor.font.glyph_atlas, update_region);
        }

        renderer.begin_frame(BACKGROUND_COLOR);
        renderer.draw(render_commands);
        renderer.submit_frame();
    }

    editor.is_first_frame = false;

    return wants_next_frame;
}

editor_log :: (editor: *Editor, format_string: string, args: ..Any, loc := #caller_location) {
    s := sprint(format_string, ..args,, arena_allocator(editor.perm_arena));
    array_add(*editor.messages, s);
    editor.last_message_seen = false;

    log(format_string, ..args, loc);
}

get_panel_for_active_view :: (editor: Editor) -> *Panel, panel_index: s64 {
    index: s64;
    if #complete editor.active_view == {
        case .FULL;   index = editor.full_view_panel_index;
        case .LEFT;   index = editor.left_view_panel_index;
        case .RIGHT;  index = editor.right_view_panel_index;
    }

    panel: *Panel = null;
    if editor.panels.count {
        panel = *editor.panels[index];
    }

    return panel, index;
}

get_panel_for_mouse_cursor :: (editor: Editor, input: Input) -> *Panel, panel_index: s64 {
    index: s64;
    if editor.active_view == .FULL {
        index = editor.full_view_panel_index;
    } else {
        if input.mouse_position.x < 0.5 * input.window_size.x {
            index = editor.left_view_panel_index;
        } else {
            index = editor.right_view_panel_index;
        }
    }

    panel: *Panel = null;
    if editor.panels.count {
        panel = *editor.panels[index];
    }

    return panel, index;
}

get_panel_rect :: (editor: Editor, panel_index: s64) -> Rect, content_rect: Rect {
    window_w := cast(f32, editor.input_state.window_size.x);
    window_h := cast(f32, editor.input_state.window_size.y);
    cell_h := editor.font.line_height_in_pixels;

    panel_x: f32 = 0.0;
    panel_content_x: f32 = PANEL_GUTTER_PIXELS;
    if editor.active_view != .FULL && editor.right_view_panel_index == panel_index {
        panel_x = window_w * 0.5;
        panel_content_x = window_w * 0.5 + PANEL_GUTTER_PIXELS;
    }

    panel_y: f32 = 0.0;

    panel_w         := ifx editor.active_view == .FULL then window_w else window_w * 0.5;
    panel_content_w := ifx editor.active_view == .FULL then window_w - 2 * PANEL_GUTTER_PIXELS else window_w * 0.5 - 2 * PANEL_GUTTER_PIXELS;

    panel_h := window_h - 2 * cell_h; // 2*cell_h is the mode line and message line.
    if editor.mini_panel.open {
        // Currently, this only affects culling.
        //
        // TODO(jt): In Emacs, this would also modify the scroll offset, if the cursor would be
        // occluded by the newly visible mini panel. Should we do that?
        panel_h = window_h - (2 + MINI_PANEL_LINES) * cell_h;
    }

    // TODO(jt): @Speed This is slightly wasteful, that we convert xywh into a point rect, only for
    // the callers to convert it back into xywh. Maybe rethink this once we do this too often?
    panel_rect         := rect_from_point_and_size(panel_x, panel_y, panel_w, panel_h);
    panel_content_rect := rect_from_point_and_size(panel_content_x, panel_y, panel_content_w, panel_h);

    return panel_rect, panel_content_rect;
}

// For ease of use, the editor talks about watching individual files, but it merely means it is
// interested in those files. The OS APIs can only watch for changes in a directory, so we do simple
// refcounting here before calling out to the platform layer. Additionally, the OS APIs can miss
// events, so we rescan the files we are interested in periodically anyway.

watch_file :: (editor: *Editor, platform: Platform, input: Input, file_path: string) {
    watched_directories: Table(string, void);
    watched_directories.allocator = temp;

    for editor.watched_files {
        table_add(*watched_directories, String.path_strip_filename(it), null.*);
    }

    directory_path := String.path_strip_filename(file_path);
    if !table_contains(*watched_directories, directory_path) {
        // Start watching directory, if this is the first file in that directory.
        platform.watch_directory(directory_path);
    }

    // TODO(jt): if_unique, so that people can call watch_document multiple times on the same
    // file. Maybe we don't need the slop we should sanity_assert instead.
    array_add_if_unique(*editor.watched_files, file_path);
}

unwatch_file :: (editor: *Editor, platform: Platform, input: Input, file_path: string) {
    // TODO(jt): remove_by_value removes all occurences by default. We do this, so that people can
    // call unwatch_document multiple times on the same file. Maybe we don't need the slop and
    // should sanity_assert instead.
    array_unordered_remove_by_value(*editor.watched_files, file_path);

    watched_directories: Table(string, void);
    watched_directories.allocator = temp;

    for editor.watched_files {
        table_add(*watched_directories, String.path_strip_filename(it), null.*);
    }

    directory_path := String.path_strip_filename(file_path);
    if !table_contains(*watched_directories, directory_path) {
        // Stop watching directory, if this was the last file in that directory.
        platform.unwatch_directory(directory_path);
    }
}

sync_document_with_filesystem :: (editor: *Editor, platform: Platform, input: Input, document: *Document) {
    if document.backing_file_exists {
        exists, modification_time, size := platform.file_modification_time_and_size(document.backing_file_path);

        // We are okay with the file not existing anymore, because this means we don't have
        // to sync with anyone. Let's just reset the things.
        if !exists {
            document.backing_file_exists = false;
            document.backing_file_time_of_last_sync = {};
            document.backing_file_time_of_last_save = {};

            document.backing_file_last_synced_modification_time = {};
            document.backing_file_last_synced_size = 0;
            document.backing_file_last_synced_hash = 0;

            return;
        }

        metadata_changed := false;
        if modification_time > document.backing_file_last_synced_modification_time  metadata_changed = true;
        if size != document.backing_file_last_synced_size                           metadata_changed = true;

        document.backing_file_time_of_last_sync = input.time;

        document.backing_file_last_synced_modification_time = modification_time;
        document.backing_file_last_synced_size = size;

        if metadata_changed {
            // TODO(jt): @Memory To keep memory usage down, load the file in chunks and hash
            // it chunk by chunk, re-using the same memory.
            success, contents := platform.read_file(document.backing_file_path,, temp);
            if success {
                hash := hash_file_contents(contents);
                if hash != document.backing_file_last_synced_hash {
                    document.backing_file_last_synced_hash = hash;

                    if document.flags & .MODIFIED {
                        document.flags |= .READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT;

                        save_shortcut := shortcut_sprint(key_map_find_shortcut(editor.key_map, .SAVE_DOCUMENT),, temp);
                        reload_shortcut := shortcut_sprint(key_map_find_shortcut(editor.key_map, .RELOAD_DOCUMENT),, temp);
                        editor_log(editor, "% modified, but file changed on filesystem. % or % to exit read only mode", String.path_filename(document.backing_file_path), save_shortcut, reload_shortcut);
                    } else {
                        // TODO(jt): @Speed @Memory Figure out a diff instead of changing the whole file?

                        cursor_before_reload := document.cursors.c0;

                        text_buffer_delete_all(*document.buffer, *document.cursors);
                        text_buffer_insert(*document.buffer, *document.cursors, contents, .FUSE);
                        text_buffer_move_cursor_to(document.buffer, *document.cursors, cursor_before_reload, false);

                        update_parenthesized_scopes(document);
                        update_syntax_highlights(editor, document, platform, input);

                        editor_log(editor, "Updated % from filesystem", String.path_filename(document.backing_file_path));
                    }
                }
            } else {
                // This can only happen as a race condition. We reset everything as though
                // this file only ever existed in our memory.
                document.backing_file_exists = false;
                document.backing_file_time_of_last_sync = {};
                document.backing_file_time_of_last_save = {};

                document.backing_file_last_synced_modification_time = {};
                document.backing_file_last_synced_size = 0;
                document.backing_file_last_synced_hash = 0;
            }
        }
    }
}

#scope_file

Mini_Panel_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    DELETE_FORWARD;
    DELETE_BACKWARD;

    SCROLL_UP;
    SCROLL_DOWN;

    START_SELECTING;

    INDENT_OR_AUTOCOMPLETE;

    CONFIRM;
    CANCEL_OR_STOP_SELECTING;
}

route_event_to_mini_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;
    active_panel := get_panel_for_active_view(editor);

    min_item_index := ifx mini_panel.procs.can_select_text_line(editor, platform, input) then -1 else 0;

    buffer_changed := false;
    old_item_index := mini_panel.item_index;

    buffered, action := key_map_input(*editor.mini_panel.key_map, event, editor.input_state.modifiers);
    if action == {
        case .MOVE_UP;                 mini_panel.item_index = clamp(mini_panel.item_index - 1, min_item_index, mini_panel.items.count - 1);
        case .MOVE_DOWN;               mini_panel.item_index = clamp(mini_panel.item_index + 1, min_item_index, mini_panel.items.count - 1);
        case .MOVE_LEFT;               text_buffer_move_cursor_x(mini_panel.buffer, *mini_panel.cursors, -1, mini_panel.selecting);
        case .MOVE_RIGHT;              text_buffer_move_cursor_x(mini_panel.buffer, *mini_panel.cursors,  1, mini_panel.selecting);

        case .MOVE_TO_START_OF_LINE;   text_buffer_move_cursor_to_start_of_line(mini_panel.buffer, *mini_panel.cursors, mini_panel.selecting);
        case .MOVE_TO_END_OF_LINE;     text_buffer_move_cursor_to_end_of_line(mini_panel.buffer, *mini_panel.cursors, mini_panel.selecting);

        case .MOVE_FORWARD_WORD;       text_buffer_move_cursor_to_next_word_boundary(mini_panel.buffer, *mini_panel.cursors, mini_panel.selecting);
        case .MOVE_BACKWARD_WORD;      text_buffer_move_cursor_to_previous_word_boundary(mini_panel.buffer, *mini_panel.cursors, mini_panel.selecting);

        case .DELETE_FORWARD;          text_buffer_delete_forward(*mini_panel.buffer, *mini_panel.cursors); buffer_changed = true;
        case .DELETE_BACKWARD;         buffer_changed |= mini_panel.procs.delete_backward(editor, platform, input);

        case .SCROLL_UP;               mini_panel.item_index = clamp(mini_panel.item_index - MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);
        case .SCROLL_DOWN;             mini_panel.item_index = clamp(mini_panel.item_index + MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);

        case .START_SELECTING;         mini_panel.selecting = true; text_cursors_join(*mini_panel.cursors);

        case .INDENT_OR_AUTOCOMPLETE;  buffer_changed |= mini_panel.procs.autocomplete(editor, platform, input);

        case .CONFIRM;                 buffer_changed |= mini_panel.procs.confirm(editor, platform, input);

        case .CANCEL_OR_STOP_SELECTING; {
            if mini_panel.selecting {
                text_cursors_join(*mini_panel.cursors);
                mini_panel.selecting = false;
            } else {
                mini_panel.procs.cancel(editor, platform, input);
            }
        }
    }

    // TODO(jt): Animated cursor in mini panel
    // TODO(jt): Do animated horizontal scroll of buffer in mini panel.
    // TODO(jt): Do animated vertical scroll of item list in mini panel.
    if !buffered && action == .NONE && event.flags & .PRESSED {
        if event.type == .CODEPOINT {
            if !(editor.input_state.modifiers & .CTRL) && !(editor.input_state.modifiers & .ALT) {
                char := cast(u32, event.codepoint);
                buffer_changed |= text_buffer_insert_char(*mini_panel.buffer, *mini_panel.cursors, char);
            }
        }
    }

    if mini_panel.open {
        // TODO(jt): @Speed In case we'll be processing multiple events this frame, we want to delay
        // calling this until they have all been processed. Otherwise we'll be doing expensive stuff
        // multiple times per frame. Maybe we need to move this one level up and track the dirty
        // flags on the mini panel itself?
        mini_panel.procs.update(editor, platform, input, buffer_changed, mini_panel.item_index != old_item_index);
    }
}

Modal_Interaction_Action :: enum {
    NONE;

    MOVE_LEFT;
    MOVE_RIGHT;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    DELETE_FORWARD;
    DELETE_BACKWARD;

    INDENT_OR_AUTOCOMPLETE;

    CONFIRM;
    CANCEL_OR_STOP_SELECTING;
}

route_event_to_modal_interaction :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    modal_interaction := *editor.modal_interaction;
    active_panel := get_panel_for_active_view(editor);

    if modal_interaction.procs.handle_event(editor, event, platform, input) {
        return;
    }

    buffer_changed := false;

    buffered, action := key_map_input(*modal_interaction.key_map, event, editor.input_state.modifiers);
    if action == {
        case .MOVE_LEFT;                 text_buffer_move_cursor_x(modal_interaction.buffer, *modal_interaction.cursors, -1, false);
        case .MOVE_RIGHT;                text_buffer_move_cursor_x(modal_interaction.buffer, *modal_interaction.cursors,  1, false);

        case .MOVE_TO_START_OF_LINE;     text_buffer_move_cursor_to_start_of_line(modal_interaction.buffer, *modal_interaction.cursors, false);
        case .MOVE_TO_END_OF_LINE;       text_buffer_move_cursor_to_end_of_line(modal_interaction.buffer, *modal_interaction.cursors, false);

        case .MOVE_FORWARD_WORD;         text_buffer_move_cursor_to_next_word_boundary(modal_interaction.buffer, *modal_interaction.cursors, false);
        case .MOVE_BACKWARD_WORD;        text_buffer_move_cursor_to_previous_word_boundary(modal_interaction.buffer, *modal_interaction.cursors, false);

        case .DELETE_FORWARD;            text_buffer_delete_forward(*modal_interaction.buffer, *modal_interaction.cursors); buffer_changed = true;
        case .DELETE_BACKWARD;           text_buffer_delete_backward(*modal_interaction.buffer, *modal_interaction.cursors); buffer_changed = true;

        case .INDENT_OR_AUTOCOMPLETE;    // No-op, we just want to prevent inserting a tab for now.

        case .CONFIRM;                   modal_interaction.procs.advance(editor, platform, input);
        case .CANCEL_OR_STOP_SELECTING;  modal_interaction.procs.cancel(editor, platform, input);
    }

    // TODO(jt): Do selecting in modal interaction
    // TODO(jt): Animated cursor in modal interaction
    if !buffered && action == .NONE && event.flags & .PRESSED {
        if event.type == .CODEPOINT {
            if !(editor.input_state.modifiers & .CTRL) && !(editor.input_state.modifiers & .ALT) {
                char := cast(u32, event.codepoint);
                buffer_changed |= text_buffer_insert_char(*modal_interaction.buffer, *modal_interaction.cursors, char);
            }
        }
    }
}

Editor_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;

    SEARCH;
    SEARCH_AND_REPLACE;

    OPEN_FILE;
    SAVE_DOCUMENT;
    RELOAD_DOCUMENT;

    SWITCH_TO_DOCUMENT;
    CLOSE_DOCUMENT;

    SWAP_LINE_UP;
    SWAP_LINE_DOWN;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_TO_START_OF_DOCUMENT;
    MOVE_TO_END_OF_DOCUMENT;

    MOVE_TO_PREVIOUS_BLANK_LINE;
    MOVE_TO_NEXT_BLANK_LINE;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    RECENTER;
    SCROLL_UP;
    SCROLL_DOWN;

    START_SELECTING;
    STOP_SELECTING;

    DELETE_LINE;
    DELETE_FORWARD;
    DELETE_BACKWARD;

    DELETE_FORWARD_WORD;
    DELETE_BACKWARD_WORD;

    INSERT_LINE_BEFORE;
    INSERT_LINE_AFTER;

    INDENT_OR_AUTOCOMPLETE;

    UNDO_EDIT;
    REDO_EDIT;

    COPY;
    CUT;
    PASTE;

    SPLIT_VIEW_HORIZONTALLY;
    CLOSE_CURRENT_VIEW;
    CLOSE_OTHER_VIEWS;
    GO_TO_NEXT_VIEW;
}

route_event_to_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    panel := get_panel_for_active_view(editor);
    if !panel {
        return;
    }

    document := panel.document;
    if !document {
        return;
    }

    buffer_changed := false; // Implies cursor_moved
    cursor_moved   := false;

    shift_selecting := editor.input_state.modifiers & .SHIFT;

    buffered, action := key_map_input(*editor.key_map, event, editor.input_state.modifiers);
    if action == {
        case .MOVE_UP;             cursor_moved |= text_buffer_move_cursor_y(document.buffer, *panel.cursors, -1, shift_selecting || panel.selecting); panel.flags |= .CLAMP_SCROLL_TO_CURSOR; if shift_selecting then panel.selecting = false;
        case .MOVE_DOWN;           cursor_moved |= text_buffer_move_cursor_y(document.buffer, *panel.cursors,  1, shift_selecting || panel.selecting); panel.flags |= .CLAMP_SCROLL_TO_CURSOR; if shift_selecting then panel.selecting = false;
        case .MOVE_LEFT;           cursor_moved |= text_buffer_move_cursor_x(document.buffer, *panel.cursors, -1, shift_selecting || panel.selecting); panel.flags |= .CLAMP_SCROLL_TO_CURSOR; if shift_selecting then panel.selecting = false;
        case .MOVE_RIGHT;          cursor_moved |= text_buffer_move_cursor_x(document.buffer, *panel.cursors,  1, shift_selecting || panel.selecting); panel.flags |= .CLAMP_SCROLL_TO_CURSOR; if shift_selecting then panel.selecting = false;

        case .SEARCH;              open_mini_panel(editor, platform, input, mini_panel_search_procs);
        case .SEARCH_AND_REPLACE;  open_modal_interaction(editor, platform, input, modal_interaction_search_and_replace_procs);

        case .OPEN_FILE; {
            path := "./";

            if panel.document.kind == .FILE && panel.document.backing_file_path.count {
                path = String.path_strip_filename(panel.document.backing_file_path);
            }

            open_mini_panel(editor, platform, input, mini_panel_open_file_procs, path);
        }
        case .SAVE_DOCUMENT; {
            if document.backing_file_path.count {
                if document.flags & .MODIFIED {
                    buffer := *document.buffer;

                    gap_buffer_move_gap_to(*buffer.gb, 0);
                    contents := gap_buffer_make_view(buffer.gb, 0, buffer.gb.count, assert_no_allocations = true);
                    success := platform.write_file(document.backing_file_path, contents);
                    if success {
                        editor_log(editor, "Wrote file %", document.backing_file_path);

                        document.flags &= ~.MODIFIED;
                        document.flags &= ~.READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT;

                        if !document.backing_file_exists {
                            watch_file(editor, platform, input, document.backing_file_path);
                        }

                        document.backing_file_exists = true;
                        document.backing_file_time_of_last_save = input.time;
                        document.backing_file_time_of_last_sync = input.time;

                        // We sync the modification time and size here, but the filesystem may give us
                        // stale data and our write is not yet visible. If this happens, it will cause
                        // the polling fallback of the file watcher to reload the and rehash the file.
                        _, modification_time, size := platform.file_modification_time_and_size(document.backing_file_path);
                        document.backing_file_last_synced_modification_time = modification_time;
                        document.backing_file_last_synced_size = size;
                        document.backing_file_last_synced_hash = hash_text_buffer_contents(document.buffer);
                    } else {
                        editor_log(editor, "Failed to write file %", document.backing_file_path);
                    }

                } else {
                    editor_log(editor, "No need to save unmodified file %", document.backing_file_path);
                }
            }
        }
        case .RELOAD_DOCUMENT; {
            if document.backing_file_path {
                success, file_contents := platform.read_file(document.backing_file_path,, temp);
                if success {
                    document.backing_file_exists = true;
                    document.backing_file_time_of_last_save = input.time;
                    document.backing_file_time_of_last_sync = input.time;

                    _, modification_time, size := platform.file_modification_time_and_size(document.backing_file_path);
                    document.backing_file_last_synced_modification_time = modification_time;
                    document.backing_file_last_synced_size = size;
                    document.backing_file_last_synced_hash = hash_file_contents(file_contents);

                    text_buffer_delete_all(*document.buffer, *panel.cursors);
                    text_buffer_insert(*document.buffer, *panel.cursors, file_contents, .OMIT);
                    text_buffer_move_cursor_to(document.buffer, *panel.cursors, 0, 0, false);

                    update_parenthesized_scopes(document);
                    update_syntax_highlights(editor, document, platform, input);

                    editor_log(editor, "Reloaded file: %", document.backing_file_path);
                }
            }
        }

        case .SWITCH_TO_DOCUMENT;           open_mini_panel(editor, platform, input, mini_panel_switch_to_document_procs);
        case .CLOSE_DOCUMENT;               open_mini_panel(editor, platform, input, mini_panel_close_document_procs);

        case .SWAP_LINE_UP;                 // TODO(jt): text_buffer_swap_line_up
        case .SWAP_LINE_DOWN;               // TODO(jt): text_buffer_swap_line_down

        case .MOVE_TO_START_OF_LINE;        cursor_moved |= text_buffer_move_cursor_to_start_of_line(document.buffer, *panel.cursors, panel.selecting);
        case .MOVE_TO_END_OF_LINE;          cursor_moved |= text_buffer_move_cursor_to_end_of_line(document.buffer, *panel.cursors, panel.selecting);

        case .MOVE_TO_START_OF_DOCUMENT;    cursor_moved |= text_buffer_move_cursor_to_start(document.buffer, *panel.cursors, panel.selecting);
        case .MOVE_TO_END_OF_DOCUMENT;      cursor_moved |= text_buffer_move_cursor_to_end(document.buffer, *panel.cursors, panel.selecting);

        case .MOVE_TO_PREVIOUS_BLANK_LINE;  cursor_moved |= text_buffer_move_cursor_to_previous_blank_line(document.buffer, *panel.cursors, panel.selecting);
        case .MOVE_TO_NEXT_BLANK_LINE;      cursor_moved |= text_buffer_move_cursor_to_next_blank_line(document.buffer, *panel.cursors, panel.selecting);

        case .MOVE_FORWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_cursor_to_next_word_boundary(document.buffer, *panel.cursors, panel.selecting);
            if cursor_y_moved {
                panel.flags |= .CLAMP_SCROLL_TO_START_OF_LINE;
            }
        }
        case .MOVE_BACKWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_cursor_to_previous_word_boundary(document.buffer, *panel.cursors, panel.selecting);
            if cursor_y_moved {
                panel.flags |= .CLAMP_SCROLL_TO_END_OF_LINE;
            }
        }

        case .RECENTER;                     recenter_active_panel(editor, input);
        case .SCROLL_UP;                    scroll_panel_up_one_screen(panel, input, editor.font.line_height_in_pixels);
        case .SCROLL_DOWN;                  scroll_panel_down_one_screen(panel, input, editor.font.line_height_in_pixels);

        case .START_SELECTING;              panel.selecting = true;  text_cursors_join(*panel.cursors);
        case .STOP_SELECTING;               panel.selecting = false; text_cursors_join(*panel.cursors);

        case .DELETE_LINE; {
            panel.selecting = false;
            text := text_buffer_delete_line(*document.buffer, *panel.cursors);
            if text {
                buffer_changed = true;
                platform.set_clipboard_text(text);
            }
        }
        case .DELETE_FORWARD;               panel.selecting = false; buffer_changed |= text_buffer_delete_forward(*document.buffer, *panel.cursors);
        case .DELETE_BACKWARD;              panel.selecting = false; buffer_changed |= text_buffer_delete_backward(*document.buffer, *panel.cursors);

        case .DELETE_FORWARD_WORD;          // TODO(jt): text_buffer_delete_until_next_word_boundary
        case .DELETE_BACKWARD_WORD;         // TODO(jt): text_buffer_delete_until_previous_word_boundary

        case .INSERT_LINE_BEFORE; {
            should_make_space_for_block := false;
            if panel.cursors.c0.x > 0 {
                curr_loc := panel.cursors.c0;
                prev_loc := curr_loc;
                prev_loc.x -= 1;

                if text_buffer_can_read_at_location(document.buffer, curr_loc) {
                    prev_byte := text_buffer_get_byte_at_location(document.buffer, prev_loc);
                    curr_byte := text_buffer_get_byte_at_location(document.buffer, curr_loc);

                    opens, _, paired_char := is_part_of_surround_pair(document, prev_byte);
                    if opens && paired_char == curr_byte {
                        should_make_space_for_block = true;
                    }
                }
            }

            // TODO(jt): Preserve CRLF in CRLF-only documents.
            panel.selecting = false;
            buffer_changed |= text_buffer_insert(*document.buffer, *panel.cursors, "\n", .BARRIER);

            if should_make_space_for_block {
                buffer_changed |= text_buffer_insert(*document.buffer, *panel.cursors, "\n", .FUSE);

                cursor_moved |= text_buffer_move_cursor_y(document.buffer, *panel.cursors, -1, false);
                if document.parenthesized_scopes.count {
                    update_parenthesized_scopes(document);

                    level := find_indentation_level(document, panel.cursors.c0);
                    buffer_changed |= text_buffer_indent_line(*document.buffer, *panel.cursors, level, .FUSE);
                }
                cursor_moved |= text_buffer_move_cursor_y(document.buffer, *panel.cursors, 1, false);
            }

            if document.parenthesized_scopes.count {
                update_parenthesized_scopes(document);

                level := find_indentation_level(document, panel.cursors.c0);
                buffer_changed |= text_buffer_indent_line(*document.buffer, *panel.cursors, level, .FUSE);
            }

            if should_make_space_for_block {
                cursor_moved |= text_buffer_move_cursor_y(document.buffer, *panel.cursors, -1, false);
                cursor_moved |= text_buffer_move_cursor_to_end_of_line(document.buffer, *panel.cursors, false);
            }
        }
        case .INSERT_LINE_AFTER; {
            // TODO(jt): Preserve CRLF in CRLF-only documents.
            panel.selecting = false;
            buffer_changed |= text_buffer_insert(*document.buffer, *panel.cursors, "\n", .BARRIER);
            cursor_moved   |= text_buffer_move_cursor_y(document.buffer, *panel.cursors, -1, false);
            cursor_moved   |= text_buffer_move_cursor_to_end_of_line(document.buffer, *panel.cursors, false);
        }

        // TODO(jt): Preserve tabness in tab-only documents.
        case .INDENT_OR_AUTOCOMPLETE; {
            if document.parenthesized_scopes.count {
                panel.selecting = false;

                // TODO(jt): @Bug Our parentheses parser does not skip comments. Should it?

                original_y0 := panel.cursors.c0.y;
                original_y1 := panel.cursors.c1.y;
                y0 := min(panel.cursors.c0.y, panel.cursors.c1.y);
                y1 := max(panel.cursors.c0.y, panel.cursors.c1.y);

                first := true;
                for y0..y1 {
                    indentation_level := find_indentation_level(document, { 0, it });
                    text_buffer_move_cursor_to(document.buffer, *panel.cursors, { 0, it }, false);
                    changed := text_buffer_indent_line(*document.buffer, *panel.cursors, indentation_level, ifx first then .NONE else .FUSE);

                    if changed {
                        update_parenthesized_scopes(document);
                        first = false;
                    }

                    buffer_changed |= changed;
                }

                // Restore cursor's vertical position if the selection is backwards.
                if original_y0 < original_y1 {
                    text_buffer_move_cursor_to(document.buffer, *panel.cursors, panel.cursors.c0.x, original_y0, false);
                }
            } else {
                if panel.cursors.c0 == panel.cursors.c1 {
                    buffer_changed |= text_buffer_insert(*document.buffer, *panel.cursors, "    ");
                }
            }
        }

        case .UNDO_EDIT;  buffer_changed |= text_buffer_undo_edit(*document.buffer, *panel.cursors);
        case .REDO_EDIT;  buffer_changed |= text_buffer_redo_edit(*document.buffer, *panel.cursors);

        case .COPY; {
            panel.selecting = false;
            text := text_buffer_make_view_for_interval(document.buffer, panel.cursors.c0, panel.cursors.c1,, temp);
            if text {
                platform.set_clipboard_text(text);
            }

            text_cursors_join(*panel.cursors);
        }
        case .CUT; {
            panel.selecting = false;
            deleted := text_buffer_delete_selection(*document.buffer, *panel.cursors);
            if deleted {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }
        case .PASTE; {
            panel.selecting = false;
            text := platform.get_clipboard_text(,, temp);
            if text {
                buffer_changed |= text_buffer_insert(*document.buffer, *panel.cursors, text, .BARRIER);
            }
        }

        case .SPLIT_VIEW_HORIZONTALLY; {
            if editor.active_view == .FULL {
                assert(editor.panels.count == 1);

                right_panel := array_add(*editor.panels);
                panel_init(right_panel, editor, platform, editor.panels[0].document);

                editor.left_view_panel_index  = 0;
                editor.right_view_panel_index = 1;

                editor.active_view = .LEFT;
            }
        }
        case .CLOSE_CURRENT_VIEW; {
            if #complete editor.active_view == {
                case .FULL; // No-op
                case .LEFT; {
                    assert(editor.panels.count == 2);

                    panel_deinit(*editor.panels[editor.left_view_panel_index]);
                    array_unordered_remove_by_index(*editor.panels, editor.left_view_panel_index);

                    editor.full_view_panel_index = 0;
                    editor.active_view = .FULL;
                }
                case .RIGHT; {
                    assert(editor.panels.count == 2);

                    panel_deinit(*editor.panels[editor.right_view_panel_index]);
                    array_unordered_remove_by_index(*editor.panels, editor.right_view_panel_index);

                    editor.full_view_panel_index = 0;
                    editor.active_view = .FULL;
                }
            }
        }
        case .CLOSE_OTHER_VIEWS; {
            if #complete editor.active_view == {
                case .FULL; // No-op
                case .LEFT; {
                    assert(editor.panels.count == 2);

                    panel_deinit(*editor.panels[editor.right_view_panel_index]);
                    array_unordered_remove_by_index(*editor.panels, editor.right_view_panel_index);

                    editor.full_view_panel_index = 0;
                    editor.active_view = .FULL;
                }
                case .RIGHT; {
                    assert(editor.panels.count == 2);

                    panel_deinit(*editor.panels[editor.left_view_panel_index]);
                    array_unordered_remove_by_index(*editor.panels, editor.left_view_panel_index);

                    editor.full_view_panel_index = 0;
                    editor.active_view = .FULL;
                }
            }
        }
        case .GO_TO_NEXT_VIEW; {
            if #complete editor.active_view == {
                case .FULL; // No-op
                case .LEFT;   editor.active_view = .RIGHT;
                case .RIGHT;  editor.active_view = .LEFT;
            }
        }
    }

    if !buffered && action == .NONE && event.flags & .PRESSED {
        if event.type == {
            case .CODEPOINT; {
                panel.selecting = false;

                char := cast(u32, event.codepoint);

                handled := false;
                opens, closes, paired_char := is_part_of_surround_pair(document, char);

                if closes {
                    if panel.cursors.c0 != panel.cursors.c1 {
                        // Surrounding selection never cares for unbalanced parentheses
                        c0 := panel.cursors.c0;
                        c1 := panel.cursors.c1;
                        text_location_sort(*c0, *c1);

                        text_cursors_join(*panel.cursors);

                        text_buffer_move_cursor_to(document.buffer, *panel.cursors, c0, false);
                        text_buffer_insert_char(*document.buffer, *panel.cursors, paired_char, .BARRIER);

                        c1.x += 1; // Because we just inserted the starting paren.
                        text_buffer_move_cursor_to(document.buffer, *panel.cursors, c1, false);
                        text_buffer_insert_char(*document.buffer, *panel.cursors, char, .FUSE);

                        buffer_changed = true;
                        handled = true;
                    }
                }

                if opens && !handled {
                    if panel.cursors.c0 == panel.cursors.c1 {
                        // TODO(jt): handle balancing?
                        text_buffer_insert_char(*document.buffer, *panel.cursors, char, /*.BARRIER*/);
                        text_buffer_insert_char(*document.buffer, *panel.cursors, paired_char, .FUSE);
                        text_buffer_move_cursor_x(document.buffer, *panel.cursors, -1, false);
                        buffer_changed = true;
                        handled = true;
                    } else {
                        // Surrounding selection never cares for unbalanced parentheses
                        c0 := panel.cursors.c0;
                        c1 := panel.cursors.c1;
                        text_location_sort(*c0, *c1);

                        text_cursors_join(*panel.cursors);

                        text_buffer_move_cursor_to(document.buffer, *panel.cursors, c1, false);
                        text_buffer_insert_char(*document.buffer, *panel.cursors, paired_char, .BARRIER);

                        text_buffer_move_cursor_to(document.buffer, *panel.cursors, c0, false);
                        text_buffer_insert_char(*document.buffer, *panel.cursors, char, .FUSE);

                        buffer_changed = true;
                        handled = true;
                    }
                }

                if !handled {
                    buffer_changed |= text_buffer_insert_char(*document.buffer, *panel.cursors, char);
                    panel.flags |= .CLAMP_SCROLL_TO_CURSOR;
                }
            }
        }
    }

    if cursor_moved || buffer_changed {
        // The cursor position interpolation gets setup in a centralized place instead of here, because the
        // cursor can be moved from other places than this one (e.g. mouse, SEARCH mini
        // panel...).
        //
        // :CentralizedCursorInterpolationSetup
        document.time_of_last_interaction = input.time;
        panel.flags |= .RECEIVED_KEYBOARD_INTERACTION;
        panel.flags |= .CLAMP_SCROLL_TO_CURSOR;
    }

    if buffer_changed {
        document.flags |= .MODIFIED_THIS_FRAME;
        document.flags |= .MODIFIED;

        // We have to update these after every change, because the very next edit could be needing
        // this. We could start being smarter about this (e.g. by setting a specific dirty flag),
        // becuase not every subsequent action needs these up to date.  -jt, 22 July 2026.
        update_parenthesized_scopes(document);
    }
}

open_mini_panel :: (editor: *Editor, platform: Platform, input: Input, procs: Mini_Panel_Procs, initial_text := "") {
    mini_panel := *editor.mini_panel;

    assert(!mini_panel.open);

    text_buffer_insert(*mini_panel.buffer, *mini_panel.cursors, initial_text);

    mini_panel.procs = procs;
    mini_panel.open = true;

    procs.init(editor, platform, input);
    procs.update(editor, platform, input, true, true);
}

#scope_module

close_mini_panel :: (editor: *Editor, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;
    assert(mini_panel.open);

    mini_panel.cursors.c0 = { 0, 0 };
    mini_panel.cursors.c1 = { 0, 0 };
    mini_panel.selecting = false;

    text_buffer_reset(*mini_panel.buffer);

    key_map_flush(*mini_panel.key_map);

    array_reset(*mini_panel.items);
    arena_reset(mini_panel.items_arena);
    mini_panel.item_index = 0;

    arena_reset(mini_panel.userdata_arena);
    mini_panel.userdata = null;

    mini_panel.open = false;
}

#scope_file

open_modal_interaction :: (editor: *Editor, platform: Platform, input: Input, procs: Modal_Interaction_Procs, initial_text := "") {
    modal_interaction := *editor.modal_interaction;

    assert(!modal_interaction.open);

    key_map := *modal_interaction.key_map;

    key_map_add(key_map, "C-b",         .MOVE_LEFT);
    key_map_add(key_map, "C-f",         .MOVE_RIGHT);
    key_map_add(key_map, "<left>",      .MOVE_LEFT);
    key_map_add(key_map, "<right>",     .MOVE_RIGHT);

    key_map_add(key_map, "C-a",         .MOVE_TO_START_OF_LINE);
    key_map_add(key_map, "C-e",         .MOVE_TO_END_OF_LINE);

    key_map_add(key_map, "M-f",         .MOVE_FORWARD_WORD);
    key_map_add(key_map, "M-b",         .MOVE_BACKWARD_WORD);

    key_map_add(key_map, "C-d",         .DELETE_FORWARD);
    key_map_add(key_map, "<delete>",    .DELETE_FORWARD);
    key_map_add(key_map, "<backspace>", .DELETE_BACKWARD);

    key_map_add(key_map, "<tab>",       .INDENT_OR_AUTOCOMPLETE);
    key_map_add(key_map, "C-i",         .INDENT_OR_AUTOCOMPLETE);

    key_map_add(key_map, "<enter>",     .CONFIRM);
    key_map_add(key_map, "C-m",         .CONFIRM);
    key_map_add(key_map, "C-g",         .CANCEL_OR_STOP_SELECTING);

    text_buffer_insert(*modal_interaction.buffer, *modal_interaction.cursors, initial_text);

    modal_interaction.procs = procs;
    modal_interaction.open = true;

    procs.init(editor, platform, input);
}

#scope_module

close_modal_interaction :: (editor: *Editor, platform: Platform, input: Input) {
    modal_interaction := *editor.modal_interaction;
    assert(modal_interaction.open);

    key_map_reset_keeping_memory(*modal_interaction.key_map);

    modal_interaction.cursors.c0 = { 0, 0 };
    modal_interaction.cursors.c1 = { 0, 0 };
    text_buffer_reset(*modal_interaction.buffer);

    arena_reset(modal_interaction.userdata_arena);
    modal_interaction.userdata = null;

    modal_interaction.open = false;
}

// TODO(jt): @Cleanup Once we have this sort-of defined make a Procs (+constants) struct out of
// these, like we have for other APIs.

Paren_Pair :: struct {
    open:  u32;
    close: u32;
}

PLAIN_TEXT_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

PLAIN_TEXT_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

get_surround_pairs :: (document: Document) -> /* Static */ [] Paren_Pair {
    if #complete document.mode == {
        case .PLAIN_TEXT;  return PLAIN_TEXT_SURROUND_PAREN_PAIRS;
        case .JAI;         return LANG_JAI_SURROUND_PAREN_PAIRS;
    }
}

is_part_of_surround_pair :: (document: Document, char: u32) -> opens: bool, closes: bool, paired_char: u32 {
    pairs := get_surround_pairs(document);

    opens  := false;
    closes := false;
    paired_char: u32;
    for pairs {
        if it.open == char {
            opens = true;
            paired_char = it.close;
        }

        if it.close == char {
            closes = true;
            paired_char = it.open;
        }
    }

    return opens, closes, paired_char;
}

update_syntax_highlights :: (editor: *Editor, document: *Document, platform: Platform, input: Input) {
    if #complete document.mode == {
        case .PLAIN_TEXT; // Nothing
        case .JAI;        lang_jai_update_syntax_highlights(editor, document, platform, input);
    }
}

find_or_add_document :: (editor: *Editor, platform: Platform, kind: Document.Kind, backing_file_path: string) -> *Document, newly_created: bool {
    for * editor.documents {
        if it.kind != kind                            continue;
        if it.backing_file_path != backing_file_path  continue;

        it.time_of_last_interaction = editor.input_state.time;

        return it, false;
    }

    document_arena         := make_arena(platform, .MEDIUM);
    buffer_arena           := make_arena(platform, .LARGE);
    buffer_edit_text_arena := make_arena(platform, .LARGE);

    document: Document;
    document.kind = kind;
    document.mode = .PLAIN_TEXT;
    {
        ext, ext_found := String.path_extension(backing_file_path);
        if ext_found && ext == "jai" {
            document.mode = .JAI;
        }
    }

    document.flags = .NONE;
    document.time_of_last_interaction = editor.input_state.time;

    // document.cursor0 is zero-initialized.
    // document.cursor1 is zero-initialized.
    text_buffer_init(*document.buffer, buffer_arena, buffer_edit_text_arena);

    document.arena = document_arena;
    if backing_file_path.count {
        document.backing_file_path = arena_push_string(document_arena, backing_file_path);
    }

    document.parenthesized_scopes.allocator    = arena_allocator(document_arena);
    document.syntax_highlight_tokens.allocator = arena_allocator(document_arena);

    locator, document_pointer := bucket_array_add(*editor.documents, document);
    document_pointer.locator = locator;

    return document_pointer, true;
}

close_document :: (editor: *Editor, document: *Document) {
    editor_log(editor, "Closing document % %", document.kind, document.backing_file_path);

    document_to_show: *Document;
    document_to_show_time: Apollo_Time = APOLLO_TIME_INVALID; // The maximum negative time. Anything valid will compare higher.
    for * editor.documents {
        if it != document {
            if it.time_of_last_interaction > document_to_show_time {
                document_to_show = it;
                document_to_show_time = it.time_of_last_interaction;
            }
        }
    }

    // This means we have to find a document with time_of_last_interaction > 0. If we don't find it,
    // we either have no documents (bad, becuase *scratch* shouldn't be closeable), or their
    // time_of_last_interaction was not properly set everywhere it should be. We could do a fallback
    // here to find ANY document.
    assert(document_to_show != null);

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

panel_init :: (panel: *Panel, editor: Editor, platform: Platform, document: *Document) {
    panel.highlights_arena = make_arena(platform, .LARGE);
    panel.highlights.allocator = arena_allocator(panel.highlights_arena);
    panel.highlight_index = -1;

    panel_set_document(panel, editor, document);
}

// Don't use the panel after calling this!
panel_deinit :: (panel: *Panel) {
    arena_release(panel.highlights_arena);
}

panel_set_document :: (panel: *Panel, editor: Editor, document: *Document) {
    // Save panel cursors on the document, so that they can be restored later.
    if panel.document {
        panel.document.cursors = panel.cursors;
    }

    // For now, each panel must have a document. We may later relax this and show some default
    // background, or something.
    assert(document != null);
    panel.document = document;

    panel.cursors = document.cursors;
    panel.selecting = false;

    panel.scroll_source = { 0, 0 };
    panel.scroll_target = { 0, 0 };
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes for e.g. to_float64_seconds.
    panel.scroll = { 0, 0 };

    cursor_position := get_cursor_position(panel, editor.font);

    panel.old_cursor = panel.cursors.c0;
    panel.old_cursor_position = cursor_position;

    panel.cursor_anim_source = cursor_position;
    panel.cursor_anim_target = cursor_position;
    panel.cursor_anim_time_start = {};
    panel.cursor_anim = cursor_position;

    panel.cursor_flash_source = CURSOR_COLOR;
    panel.cursor_flash_target = CURSOR_COLOR;
    panel.cursor_flash_time_start = {};
    panel.cursor_flash = CURSOR_COLOR;

    document.time_of_last_interaction = editor.input_state.time;
}

#scope_module

// TODO(jt): The user experience of this kind of sucks. The first C-l should always recenter. But
// then we need to remember if it is the first press.
recenter_active_panel :: (editor: *Editor, input: Input, force_center := false, skip_interpolation := false) {
    panel := get_panel_for_active_view(editor);
    if !panel {
        return;
    }

    document := panel.document;
    if !document {
        return;
    }

    cursor_y := panel.cursors.c0.y * editor.font.line_height_in_pixels;

    top    := cursor_y;
    center := cursor_y - 0.5 * input.window_size.y;
    bottom := cursor_y - input.window_size.y + 3 * editor.font.line_height_in_pixels;

    if editor.mini_panel.open {
        center += 0.5 * MINI_PANEL_LINES * editor.font.line_height_in_pixels;
        bottom += MINI_PANEL_LINES * editor.font.line_height_in_pixels;
    }

    target: DVector2;
    target.x = panel.scroll_target.x;

    if force_center {
        target.y = center;
    } else if panel.scroll_target.y == center {
        target.y = top;
    } else if panel.scroll_target.y == top {
        target.y = bottom;
    } else {
        target.y = center;
    }

    if skip_interpolation {
        setup_instant_scroll_interpolation(panel, target);
    } else {
        setup_scroll_interpolation(panel, input.time, panel.scroll, target);
    }
}

scroll_panel_up_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    document := panel.document;
    if !document {
        return;
    }

    top: f64 = 0; // Just here for symmetry with scrolling

    delta := cast(f64, input.window_size.y) - 3 * cell_h; // -2 for mode line and message line, another -1 to not scroll to a partially visible line.
    delta = min(delta, panel.scroll_target.y - top);

    target := panel.scroll_target;
    target.y -= delta;
    setup_scroll_interpolation(panel, input.time, panel.scroll, target);

    panel.flags |= .CLAMP_CURSOR_TO_SCROLL;
}

scroll_panel_down_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    document := panel.document;
    if !document {
        return;
    }

    bottom := cast(f64, panel.document.buffer.line_count) * cell_h;
    sanity_assert(bottom >= panel.scroll_target.y);

    delta := cast(f64, input.window_size.y) - 3 * cell_h; // -2 for mode line and message line, another -1 to not scroll to a partially visible line.
    delta = min(delta, bottom - (panel.scroll_target.y + delta));

    target := panel.scroll_target;
    target.y += delta;
    setup_scroll_interpolation(panel, input.time, panel.scroll, target);

    panel.flags |= .CLAMP_CURSOR_TO_SCROLL;
}

get_cursor_position :: (panel: Panel, font: Font) -> cursor_position: DVector2, cursor_line_end_x: f64 {
    document := panel.document;
    if !document {
        return { 0, 0 }, 0;
    }

    x := panel.cursors.c0.x;
    y := panel.cursors.c0.y;

    line_view := text_buffer_make_view_for_line(panel.document.buffer, y,, temp);

    position: DVector2;
    position.x = font_compute_position_on_line(font, line_view, x, binary = document.buffer.binary_mode);
    position.y = cast(f64, y) * font.line_height_in_pixels;

    line_end   := text_buffer_get_end_of_line(document.buffer, y);
    line_end_x := font_compute_position_on_line(font, line_view, line_end.x, binary = document.buffer.binary_mode);

    return position, line_end_x;
}

get_position_of_location :: (document: Document, font: Font, loc: Text_Location) -> DVector2 {
    line_view := text_buffer_make_view_for_line(document.buffer, loc.y,, temp);

    position: DVector2;
    position.x = font_compute_position_on_line(font, line_view, loc.x, binary = document.buffer.binary_mode);
    position.y = cast(f64, loc.y) * font.line_height_in_pixels;

    return position;
}

setup_scroll_interpolation :: (panel: *Panel, time: Apollo_Time, source: DVector2, target: DVector2) {
    // This early return prevents changing current interpolation to one that's just slightly
    // different, and thus prolonging the animation and making it jittery. This happens, when we
    // hold down a button (e.g. C-v) that triggers us setting up the interepolation.
    if target == panel.scroll_target {
        return;
    }

    panel.scroll_time_start = time;

    panel.scroll_source.x = max(source.x, 0.0);
    panel.scroll_source.y = max(source.y, 0.0);

    panel.scroll_target.x = max(target.x, 0.0);
    panel.scroll_target.y = max(target.y, 0.0);

    panel.scroll = panel.scroll_source;
}

setup_instant_scroll_interpolation :: (panel: *Panel, target: DVector2) {
    panel.scroll_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes Int128 stuff in to_float64_seconds.

    panel.scroll_source.x = max(target.x, 0.0);
    panel.scroll_source.y = max(target.y, 0.0);
    panel.scroll_target = panel.scroll_source;
    panel.scroll = panel.scroll_source;
}

setup_cursor_anim_interpolation :: (panel: *Panel, time: Apollo_Time, source: DVector2, target: DVector2, triggered_by_mouse := false, triggered_by_keyboard := false) {
    panel.cursor_anim_source = source;
    panel.cursor_anim_target = target;
    panel.cursor_anim_time_start = time;
    panel.cursor_anim = source;

    if triggered_by_mouse     panel.flags |= .CURSOR_ANIM_TRIGGERED_BY_MOUSE;
    else                      panel.flags &= ~.CURSOR_ANIM_TRIGGERED_BY_MOUSE;
    if triggered_by_keyboard  panel.flags |= .CURSOR_ANIM_TRIGGERED_BY_KEYBOARD;
    else                      panel.flags &= ~.CURSOR_ANIM_TRIGGERED_BY_KEYBOARD;
}

setup_instant_cursor_anim_interpolation :: (panel: *Panel, target: DVector2) {
    panel.cursor_anim_source = target;
    panel.cursor_anim_target = target;
    panel.cursor_anim_time_start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes Int128 stuff in to_float64_seconds.
    panel.cursor_anim = target;

    panel.flags &= ~.CURSOR_ANIM_TRIGGERED_BY_MOUSE;
    panel.flags &= ~.CURSOR_ANIM_TRIGGERED_BY_KEYBOARD;
}

setup_cursor_flash_interpolation :: (panel: *Panel, time: Apollo_Time, source: Vector4, target: Vector4) {
    panel.cursor_flash_source = source;
    panel.cursor_flash_target = target;
    panel.cursor_flash_time_start = time;
    panel.cursor_flash = source;
}

#scope_file

// :TransientDocumentFlags
clear_transient_document_flags :: (flags: *Document.Flags) {
    flags.* &= ~.TRANSIENT;
}

// :TransientPanelFlags
clear_transient_panel_flags :: (flags: *Panel.Flags) {
    flags.* &= ~.TRANSIENT;
}

draw_rect :: (render_commands: *[..] Render_Command, x0: f32, y0: f32, x1: f32, y1: f32, _color: Vector3 = { 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    color: Vector4;
    color.xyz = _color;
    color.w   = 1.0;
    inline draw_rect(render_commands, { x0, y0, x1, y1 }, color, texture);
}

draw_rect :: (render_commands: *[..] Render_Command, x0: f32, y0: f32, x1: f32, y1: f32, color: Vector4 = { 1, 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    inline draw_rect(render_commands, { x0, y0, x1, y1 }, color, texture);
}

draw_rect :: (render_commands: *[..] Render_Command, rect: Rect, _color: Vector3 = { 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    color: Vector4;
    color.xyz = _color;
    color.w   = 1.0;
    inline draw_rect(render_commands, rect, color, texture);
}

draw_rect :: (render_commands: *[..] Render_Command, rect: Rect, color: Vector4 = { 1, 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    command := array_add(render_commands);
    command.type = .DRAW_RECT;
    command.rect = rect;
    command.texture_rect = { 0, 0, 1, 1 };
    command.texture_id = texture;
    command.color = color;
}

set_scissor :: (render_commands: *[..] Render_Command, scissor_rect: Rect) {
    command := array_add(render_commands);
    command.type = .SET_SCISSOR;
    command.rect = scissor_rect;
}

// These arena sizes are upper bounds for each category, so that we don't throw a 16GB reservation for everything.
//
// TODO(jt): @Memory We should probably port our block-chaining arena to JAI, so that we don't have
// to guess these upper bounds and don't run out of address space.
Arena_Size :: enum s64 {
    SMALL  ::   2 << 20;
    MEDIUM :: 256 << 20;
    LARGE  ::  16 << 30;
}

make_arena :: (platform: Platform, size: Arena_Size) -> *Arena {
    procs: Arena_Procs;
    procs.page_size    = platform.page_size;
    procs.mem_reserve  = platform.mem_reserve;
    procs.mem_release  = platform.mem_release;
    procs.mem_commit   = platform.mem_commit;
    procs.mem_decommit = platform.mem_decommit;

    arena := arena_allocate(procs, reserve_size = cast(s64, size));

    return arena;
}

toggle_dev_view :: (dev_view: *Editor.Dev_View, value: Editor.Dev_View) {
    if dev_view.* == value {
        dev_view.* = .NONE;
    } else {
        dev_view.* = value;
    }
}
