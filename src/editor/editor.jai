/*

TODO(jt): Known serious bugs:

- On macOS, C-` (iterm) causes focus/defocus problems: C-x C-s stops working after C-`, and starts working again after Cmd-tab. Also happens with alfred.
- On macOS, launching the app creates a console.
- On macOS, clicking on the window header causes scrolling up. (probably fixed, confirm)

TODO(jt): Usage self-feedback:

- finish the compilation buffer thing
- indent line should move the cursor to the indentation level always

TODO(jt): Roadmap:

- [X] Display text on screen
- [X] Nice font rendering
- [X] Gap Buffer (or other text datastructure)
- [X] Basic file navigation
- [X] Basic file editing
- [X] Load file/Save file with file navigation in mini panel
- [X] Switching panel documents
- [X] Closing documents
- [X] Find in mini panel
- [X] Cut/Copy/Paste
- [X] Undo!
- [~] Messages (still need to do a messages view)
- [X] Modeline
- [X] Keymap support
- [X] Find/replace and modal/interactive commands.
- [X] Open non-utf8 text buffers and binary files.
- [X] Flash cursor with typing (needs tuning)
- [X] Syntax Highlighting
- [X] Mode defined parentheses (surround, autoclose)
- [X] Matching parentheses highlight
- [~] Syntax aware indentation (C-i)
- [X] Watch opened files for changes on disk
- [~] Panel tiling
- [X] FreeType subpixel rendering
- [~] Directory Lister panel
- [~] *compilation* buffer
- [~] DIRECTORY_SEARCH
- [X] SHOW_COMMANDS (M-x)
- [X] Map-like zoom
- [X] Read-only mode for documents.
- [X] Selection in mini panel text buffer.
- [ ] Selection in modal interaction text buffer.
- [ ] Create file in new directories (mkdirp)
- [ ] Delete file
- [ ] Mode defined comments
- [ ] Double click to select word (expand region)
- [ ] Triple click to select line.
- [~] Themes (got some basic ones, could have more (e.g. stb retro, delphi retro, some other nice light theme), could have custom defined themes)
- [ ] M-g g (go to line)
- [ ] C-M-p, C-M-n (move line up/down) SWAP_LINE_UP/SWAP_LINE_DOWN
- [ ] M-d, M-<backspace> DELETE_FORWARD_WORD/DELETE_BACKWARD_WORD
- [ ] C-u C-<space> and cursor undo.
- [ ] Sticky cursor (navigate to the end of long line, move up/down to a shorter line, move back to the long line and cursor goes to its original place)
- [ ] M-q (reflow)
- [ ] M-u, M-l (upcase/downcase word and move cursor)
- [ ] C-j join-next-line
- [ ] MOVE_TO_START and MOVE_TO_END in mini panel.
- [ ] Emacs-like kill ring
- [ ] CRLF
- [ ] Rotated session logs
- [ ] Support for dropping files into the window
- [ ] SEARCH items should render with syntax highlighting
- [ ] SEARCH should highlight all matches in the current view, not just the first one on the line. We should also probably add a way to navigate them (C-f, C-n).
- [ ] Animate scrolling in mini panel.
- [ ] Animate opening of the mini panel.
- [ ] Keep displaying (and updating) panel selection while SEARCH is active.
- [ ] Deduplicate path prefixes in SWITCH_VIEW and CLOSE_VIEW
- [ ] Dark text color under bright rectangles (cursor, selection, line)

- [ ] Get non-idle power usage under control (OpenGL -> D3D12/Vulkan/Metal?)
- [ ] Pretty things: blinking cursor (careful about timer precision), cursor trail, minimap, ...
- [ ] Flash pasted text
- [ ] Flash text inserted by undo/redo
- [ ] 4coder-like poor man's hex mode - substitute binary for escaped hex codes (e.g. 255 -> /ff) during layout and position calculation.
- [ ] Hex mode view
- [ ] Multiple Cursors
- [ ] Proper projects (project root, settings, compilations, text search with jumping, find/replace)
- [ ] Emacs-like undo? (If I find out I can't live without)
- [ ] if (0) and #if 0 behave like comments w.r.t. to highlighting.
- [ ] Font Kerning
- [ ] Very nice text rendering + get rid of freetype (kb_text_shape + Slug)
- [ ] Version control view (Git only?, via plugin interface?)
- [ ] 4coder style floating annotations? (e.g. name of the function or if statement expresion after closing brace)
- [ ] Customization and plugins

TODO(jt): @Stream Interesting side-projects to do:

- [ ] Visual profiler triggered by an F-key
- [ ] Visual memory profiler triggered by an F-key

*/

#module_parameters()(SANITY := false, SUBPIXEL := true);

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
#load "interpolation.jai";
#load "platform.jai";
#load "renderer.jai";
#load "input.jai";
#load "key_map.jai";
#load "font.jai";
#load "gap_buffer.jai";
#load "text_buffer.jai";
#load "parentheses.jai";
#load "line_search.jai";
#load "color.jai";
#load "theme.jai";
#load "mini_panel_search.jai";
#load "mini_panel_search_project.jai";
#load "mini_panel_open_file.jai";
#load "mini_panel_open_project_file.jai";
#load "mini_panel_switch_view.jai";
#load "mini_panel_close_view.jai";
#load "mini_panel_show_commands.jai";
#load "modal_interaction_search_and_replace.jai";
#load "modal_interaction_compile_project.jai";
#load "modal_interaction_benchgen.jai";
#load "lang_jai.jai";

// ID 0 is reserved for the texture-less pipeline. The backend must switch to a texture-less shader
// if the texture wasn't uploaded (we don't upload TEXTURE_ID_NONE). We could also reserve a few
// pixels in the font atlas for color shading, but maybe we don't want to do that?
TEXTURE_ID_NONE:        Texture_ID : 0;
TEXTURE_ID_GLYPH_ATLAS: Texture_ID : 1;

// TODO(jt): Get the monitor refresh rate from platform instead!
USUAL_DELTA_TIME: f64 : 1.0 / 60.0;

FILE_WATCH_POLL_PERIOD:  Apollo_Time : #run milliseconds_to_apollo(5000); // The maximum amount of time after which the polling fallback for file detection happens.
FILE_WATCH_BLIND_WINDOW: Apollo_Time : #run milliseconds_to_apollo(250);  // The amount of time we for which we disregard reported changes for a directory after a write.

UNDO_AUTOFUSE_PERIOD: Apollo_Time : #run milliseconds_to_apollo(500);

GUTTER_PIXELS :: 20.0; // TODO(jt): Make this configurable. :Config

PANEL_SCROLL_PADDING_CELLS_X :: 5;    // TODO(jt): Make this configurable. :Config
PANEL_SCROLL_PADDING_CELLS_Y :: 5;    // TODO(jt): Make this configurable. :Config

MINI_PANEL_LINES :: 10;   // TODO(jt): Make this configurable. :Config

STRIP_TRAILING_WHITESPACE_ON_SAVE :: true; // TODO(jt): Make this configurable. :Config

PANEL_SCROLL_DURATION:                  f32 : 0.15; // TODO(jt): Make this configurable. :Config
CURSOR_FLASH_DURATION:                  f32 : 0.20; // TODO(jt): Make flash time configurable. :Config
CURSOR_ANIM_DURATION_KEYBOARD_DIRECT:   f32 : 0.00; // TODO(jt): Make keyboard anim time configurable. :Config
CURSOR_ANIM_DURATION_KEYBOARD_INDIRECT: f32 : 0.15; // TODO(jt): Make keyboard anim time configurable. :Config
CURSOR_ANIM_DURATION_MOUSE:             f32 : 0.15; // TODO(jt): Make mouse anim time configurable. :Config

// TODO(jt): Make fonts configurable. :Config
FONT_LINE_HEIGHT_MULTIPLIER: f32 : 1.1;
FONT :: "LiberationMono";
// FONT :: "FiraCode";

// TODO(jt): None of the text editors seem to agree on what font size actually is, at least
// Emacs, VS Code and this editor have completely different ideas. Figure this out and match
// a standard, if that's even possible.
//
// UPDATE: Focus editor does the same thing as us, at least for the FiraCode font.
FONT_SIZE :: 15; // 15 for use, 20 for streaming

Editor :: struct {
    perm_arena: *Arena;

    font: Font;
    font_size: s32; // Scaled!

    input_state: Input_State;

    panel_key_map:       Key_Map(Panel_Action);
    document_key_map:    Key_Map(Document_Action);
    compilation_key_map: Key_Map(Compilation_Action);
    listing_key_map:     Key_Map(Listing_Action);
    theme: Theme;

    watched_files: [..] string;

    //
    // Documents and listings are referenced by panel views (possibly multiple times). When we close
    // a panel or switch it to a different view, the original remains. When we close/unload a
    // document/listing, we need to go through every panel and make sure it does not reference that.
    //
    panels:    [..] Panel;
    documents: Bucket_Array(Document, 16);
    listings:  Bucket_Array(Listing, 16);

    project_directory: string;

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
    };
}

Panel :: struct {
    flags: Flags;

    // Highlights are owned by the panel, but they are usually cleared/added by various minipanel and modals.
    // It could be argued that they should also own it, but then the renderer does't have a good access.
    // Let's see about this once we have more experience using this.  -jt, 10 August 2026
    highlights_arena: *Arena;
    highlights: [..] Highlight;
    highlight_index: s64 = -1;

    view: View;

    // :FloatPrecision
    //
    // Scroll vectors are f64, because buffers can be large and we actually ran into precision
    // issues with f32 vectors. Doubles suffice for now (verified up to 4GB of prose), but maybe we
    // should do our own numeric type eventually, like 58:6 fixed point?
    scroll: Interpolation(DVector2, SNAPPY = true, ROUND = true);

    Flags :: enum_flags {
        LAST_CLICK_WAS_INSIDE         :: 0x01;
        LAST_CLICK_WAS_INSIDE_CONTENT :: 0x02;
    }

    Highlight :: struct {
        x0: s64;
        x1: s64;
        y:  s64;
    }
}

View_Kind :: enum u32 {
    DOCUMENT;
    LISTING;
}

View :: struct {
    kind: View_Kind;

    union {
        _document: Document_View;
        _listing:  Listing_View;
    }
}

Document_View :: struct {
    flags: Flags;

    document: *Document; // Possibly null!

    cursors: Text_Cursors;
    selecting: bool;

    // Preserved at the start of each frame to find out if we want to kick off cursor animation, if
    // the cursor changed position due to input.
    old_cursor: Text_Location;
    old_cursor_position: DVector2;

    cursor_position: Interpolation(DVector2, SNAPPY = true, ROUND = false);
    cursor_color:    Interpolation(Vector4, SNAPPY = false, ROUND = false);

    // TODO(jt): @Cleanup Maybe some of these flags are useful to Listing_View as well, we could unify.
    Flags :: enum_flags u32 {
        NONE :: 0;

        CLAMP_CURSOR_TO_SCROLL        :: 0x01;
        CLAMP_SCROLL_TO_CURSOR        :: 0x02;
        CLAMP_SCROLL_TO_START_OF_LINE :: 0x04; // Implies CLAMP_SCROLL_TO_CURSOR;
        CLAMP_SCROLL_TO_END_OF_LINE   :: 0x08; // Implies CLAMP_SCROLL_TO_CURSOR;

        RECEIVED_DIRECT_KEYBOARD_INTERACTION   :: 0x10;
        RECEIVED_INDIRECT_KEYBOARD_INTERACTION :: 0x20;
        RECEIVED_MOUSE_INTERACTION             :: 0x20;

        // These get set during event processing and unset after update for this panel is done.
        TRANSIENT :: CLAMP_CURSOR_TO_SCROLL
            | CLAMP_SCROLL_TO_CURSOR | CLAMP_SCROLL_TO_START_OF_LINE | CLAMP_SCROLL_TO_END_OF_LINE
            | RECEIVED_DIRECT_KEYBOARD_INTERACTION | RECEIVED_INDIRECT_KEYBOARD_INTERACTION | RECEIVED_MOUSE_INTERACTION;
    }
}

Listing_View :: struct {
    flags: Flags;

    listing: *Listing; // Possibly null!
    item_index: s64;

    Flags :: enum_flags u32 {
        NONE :: 0;

        CLAMP_ITEM_INDEX_TO_SCROLL :: 0x01;
        CLAMP_SCROLL_TO_ITEM_INDEX :: 0x02;

        TRANSIENT :: CLAMP_ITEM_INDEX_TO_SCROLL | CLAMP_SCROLL_TO_ITEM_INDEX;
    }
}

Document :: struct {
    locator: Bucket_Locator;

    kind: Kind;
    mode: Mode;
    flags: Flags;
    time_of_last_interaction: Apollo_Time;

    cursors_cold: Text_Cursors; // Used to restore cursors in panel view, if the document was in the background. Otherwise, the view's cursors take precedence.
    buffer: Text_Buffer;

    arena: *Arena; // For compilation_args, backing_file_directory, backing_file_path and syntax_highlight_tokens.

    compilation_args: string; // Empty if this is not a .COMPILATION document.

    backing_directory_path: string; // In canonical format (see canonicalize_path).

    // Newly created documents (and scratch documents) do not have a backing file until saved, at
    // which point a backing file path is assigned and file created. A document with a
    // backing_file_path can also be created without the file already existing.
    backing_file_path: string; // In canonical format (see canonicalize_path).
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
        COMPILATION;
        FILE;
    }

    Mode :: enum u32 {
        PLAIN_TEXT;
        JAI;
    }

    Flags :: enum_flags u32 {
        NONE :: 0;

        MODIFIED_THIS_FRAME       :: 0x01;
        MODIFY_ATTEMPT_THIS_FRAME :: 0x02;
        MODIFIED                  :: 0x04; // Also see backing_file_exists

        // INCONSISTENT_INDENTATION  0x04;
        // INCONSISTENT_NEWLINES     0x08;

        READONLY_BY_NATURE                      :: 0x10;
        READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT :: 0x20;
        READONLY_BECAUSE_OF_MANUAL_LOCK         :: 0x40;

        READONLY :: READONLY_BY_NATURE | READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT | READONLY_BECAUSE_OF_MANUAL_LOCK;

        // These get set during event processing and unset after update for this document's panel is done.
        TRANSIENT :: MODIFIED_THIS_FRAME | MODIFY_ATTEMPT_THIS_FRAME;
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

            DIRECTIVE; // Preprocessor directive in C. Compiler directive in JAI. Macro invocation in Rust.
            ATTRIBUTE; // [[attribute]] or __attribute__() in C. @Note in JAI, #[attribute] in Rust, [Attribute] in C#;

            COMMENT;
        }
    }
}

// TODO(jt): @Cleanup Unify Listing/Listing_View with mini_panel listings?
Listing :: struct {
    locator: Bucket_Locator;

    kind: Kind;
    time_of_last_interaction: Apollo_Time;

    arena: *Arena; // For backing_directory_path and items.

    backing_directory_path: string; // In canonical format (see canonicalize_path).

    items: [..] Item;
    item_index_cold: s64; // Used to restore item_index in panel view, if the listing was in the background. Otherwise, the view's item_index takes precedence.

    Kind :: enum u32 {
        DIRECTORY;
        // TODO(jt): Add VIEWS (unified) ... this is basically entitities.
        // TODO(jt): Add SEARCH_RESULTS
        // TODO(jt): Add COMPILATION_ERRORS
    }

    Item :: struct {
        text: string;
    }
}

// TODO(jt): @Cleanup Try moving Mini_Panel, Modal_Interaction, and their APIs to their own files,
// so that we slowly start formalizing how people would do more of this stuff.

// TODO(jt): @Cleanup Try making default versions of (some?) Mini_Panel_Procs. For instance,
// "autocomplete" and "delete_backward" are mostly shared between plugins.

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
        flags: Flags;
        highlight_x0: s64;
        highlight_x1: s64;

        // The proc that fills these in can put things in here for the other procs. It can use the
        // items_arena to allocate.
        userdata: *void;

        Flags :: enum_flags u64 {
            NONE :: 0;

            BINARY  :: 0x01;
            WARNING :: 0x02;
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
        font_arena     := make_arena(platform, .LARGE);
        font_allocator := arena_allocator(font_arena);

        font_path :: (name: string, type: string) -> string {
            return tprint("./data/fonts/%1/%1-%2.ttf", name, type);
        }

        success, ttf_regular := platform.read_file(font_path(FONT, "Regular"),, font_allocator);
        assert(success);

        ttf_bold: [] u8;
        {
            success, _ttf_bold := platform.read_file(font_path(FONT, "Bold"),, font_allocator);
            if success {
                ttf_bold = _ttf_bold;
            }
        }

        ttf_italic: [] u8;
        {
            success, _ttf_italic := platform.read_file(font_path(FONT, "Italic"),, font_allocator);
            if success {
                ttf_italic = _ttf_italic;
            }
        }

        ttf_bold_italic: [] u8;
        {
            success, _ttf_bold_italic := platform.read_file(font_path(FONT, "BoldItalic"),, font_allocator);
            if success {
                ttf_bold_italic = _ttf_bold_italic;
            }
        }

        want_pixel_height := cast(s32, ceil(FONT_SIZE * input.window_scale_factor));

        editor.font_size = FONT_SIZE;
        editor.font = make_font(font_arena, ttf_regular, ttf_bold, ttf_italic, ttf_bold_italic, TEXTURE_ID_GLYPH_ATLAS, want_pixel_height, FONT_LINE_HEIGHT_MULTIPLIER);
    }

    input_state_update_on_frame_start(*editor.input_state, input);
    for input.events {
        input_state_update_with_event(*editor.input_state, it);
    }

    {
        key_map := *editor.panel_key_map;
        key_map.allocator = arena_allocator(editor.perm_arena);

        key_map_reserve(key_map, 128);

        key_map_add(key_map, "M-x",     .SHOW_COMMANDS);
        key_map_add(key_map, "C-S-p",   .SHOW_COMMANDS);
        key_map_add(key_map, "C-s",     .SEARCH);

        key_map_add(key_map, "C-x C-f", .OPEN_FILE);

        key_map_add(key_map, "C-x b",   .SWITCH_VIEW);
        key_map_add(key_map, "C-x k",   .CLOSE_VIEW);

        key_map_add(key_map, "C-l",     .RECENTER);
        key_map_add(key_map, "M-v",     .MOVE_UP_ONE_SCREEN);
        key_map_add(key_map, "C-v",     .MOVE_DOWN_ONE_SCREEN);
        key_map_add(key_map, "<pageup>", .MOVE_UP_ONE_SCREEN);
        key_map_add(key_map, "<pagedown>", .MOVE_DOWN_ONE_SCREEN);
        key_map_add(key_map, "<prior>", .MOVE_UP_ONE_SCREEN);
        key_map_add(key_map, "<next>",  .MOVE_DOWN_ONE_SCREEN);

        key_map_add(key_map, "C-x 3",   .SPLIT_PANEL_HORIZONTALLY);
        key_map_add(key_map, "C-x 0",   .CLOSE_CURRENT_PANEL);
        key_map_add(key_map, "C-x 1",   .CLOSE_OTHER_PANELS);
        key_map_add(key_map, "C-x o",   .GO_TO_NEXT_PANEL);

        key_map_add(key_map, "C-x p f", .OPEN_PROJECT_FILE);
        key_map_add(key_map, "C-c s r", .SEARCH_PROJECT); // For my muscle memory.
        key_map_add(key_map, "C-x p s", .SEARCH_PROJECT);
        key_map_add(key_map, "C-x p c", .COMPILE_PROJECT);
    }

    {
        key_map := *editor.document_key_map;
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

        key_map_add(key_map, "M-%",     .SEARCH_AND_REPLACE);

        key_map_add(key_map, "C-x C-s", .SAVE_DOCUMENT);
        key_map_add(key_map, "C-x C-r", .RELOAD_DOCUMENT);

        key_map_add(key_map, "C-M-p",   .SWAP_LINE_UP);
        key_map_add(key_map, "C-M-n",   .SWAP_LINE_DOWN);

        key_map_add(key_map, "C-a",     .MOVE_TO_START_OF_LINE);
        key_map_add(key_map, "C-e",     .MOVE_TO_END_OF_LINE);

        key_map_add(key_map, "M-<",     .MOVE_TO_START);
        key_map_add(key_map, "<home>",  .MOVE_TO_START);
        key_map_add(key_map, "M->",     .MOVE_TO_END);
        key_map_add(key_map, "<end>",   .MOVE_TO_END);

        key_map_add(key_map, "M-p",     .MOVE_TO_PREVIOUS_BLANK_LINE);
        key_map_add(key_map, "M-n",     .MOVE_TO_NEXT_BLANK_LINE);

        key_map_add(key_map, "M-f",     .MOVE_FORWARD_WORD);
        key_map_add(key_map, "M-b",     .MOVE_BACKWARD_WORD);

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

        key_map_add(key_map, "C-x C-q", .TOGGLE_READONLY);
    }

    {
        key_map := *editor.compilation_key_map;
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

        key_map_add(key_map, "C-a",     .MOVE_TO_START_OF_LINE);
        key_map_add(key_map, "C-e",     .MOVE_TO_END_OF_LINE);

        key_map_add(key_map, "M-<",     .MOVE_TO_START);
        key_map_add(key_map, "<home>",  .MOVE_TO_START);
        key_map_add(key_map, "M->",     .MOVE_TO_END);
        key_map_add(key_map, "<end>",   .MOVE_TO_END);

        key_map_add(key_map, "M-p",     .MOVE_TO_PREVIOUS_BLANK_LINE);
        key_map_add(key_map, "M-n",     .MOVE_TO_NEXT_BLANK_LINE);

        key_map_add(key_map, "M-f",     .MOVE_FORWARD_WORD);
        key_map_add(key_map, "M-b",     .MOVE_BACKWARD_WORD);

        key_map_add(key_map, "C-<space>", .START_SELECTING);
        key_map_add(key_map, "C-g",     .STOP_SELECTING);

        key_map_add(key_map, "M-w",     .COPY);
        key_map_add(key_map, "C-w",     .COPY);

        key_map_add(key_map, "p",       .MOVE_TO_PREVIOUS_ERROR);
        key_map_add(key_map, "n",       .MOVE_TO_NEXT_ERROR);

        key_map_add(key_map, "g",       .REFRESH);
    }

    {
        key_map := *editor.listing_key_map;
        key_map.allocator = arena_allocator(editor.perm_arena);

        key_map_reserve(key_map, 128);

        key_map_add(key_map, "p",       .MOVE_UP);
        key_map_add(key_map, "C-p",     .MOVE_UP);
        key_map_add(key_map, "<up>",    .MOVE_UP);
        key_map_add(key_map, "n",       .MOVE_DOWN);
        key_map_add(key_map, "C-n",     .MOVE_DOWN);
        key_map_add(key_map, "<down>",  .MOVE_DOWN);

        key_map_add(key_map, "C-m",     .OPEN);
        key_map_add(key_map, "<enter>", .OPEN);
        key_map_add(key_map, "C-o",     .OPEN_IN_OTHER_PANEL);
    }

    editor.theme = abulafia_theme();

    editor.watched_files.allocator = arena_allocator(editor.perm_arena);
    editor.documents.allocator     = arena_allocator(editor.perm_arena);
    editor.panels.allocator        = arena_allocator(editor.perm_arena);

    // Create *scratch* document
    scratch_document: *Document;
    {
        success, working_directory := platform.get_absolute_path(".",, temp);
        if !success {
            working_directory = "";
        }

        canonicalize_path(*working_directory);

        scratch_document = find_or_add_document(editor, platform, .SCRATCH, working_directory, "");
    }

    text_buffer_insert(*scratch_document.buffer, *scratch_document.cursors_cold, WELCOME, .OMIT);
    text_buffer_move_cursor_to(scratch_document.buffer, *scratch_document.cursors_cold, 0, 0, false);

    // Create first panel.
    panel := array_add(*editor.panels);
    panel_init_with_document(panel, editor, platform, scratch_document);

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

        key_map_add(key_map, "M-v",         .MOVE_UP_ONE_SCREEN);
        key_map_add(key_map, "C-v",         .MOVE_DOWN_ONE_SCREEN);

        key_map_add(key_map, "C-<space>",   .START_SELECTING);

        key_map_add(key_map, "<tab>",       .INDENT_OR_AUTOCOMPLETE);
        key_map_add(key_map, "C-i",         .INDENT_OR_AUTOCOMPLETE);

        key_map_add(key_map, "<enter>",     .CONFIRM);
        key_map_add(key_map, "C-m",         .CONFIRM);
        key_map_add(key_map, "C-g",         .CANCEL_OR_STOP_SELECTING);

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

    #if SUBPIXEL {
        atlas: [] u8;
        atlas.count = editor.font.glyph_atlas.count * 4;
        atlas.data  = cast(*u8, editor.font.glyph_atlas.data);

        renderer.create_texture_rgba8unorm(
            TEXTURE_ID_GLYPH_ATLAS,
            atlas,
            editor.font.glyph_atlas_width_in_pixels,
            editor.font.glyph_atlas_height_in_pixels,
            .NEAREST,
        );
    } else {
        renderer.create_texture_r8unorm(
            TEXTURE_ID_GLYPH_ATLAS,
            editor.font.glyph_atlas,
            editor.font.glyph_atlas_width_in_pixels,
            editor.font.glyph_atlas_height_in_pixels,
            .LINEAR,
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
    atlas_update_regions: [..] IRect;
    atlas_update_regions.allocator = temp;

    input_state_update_on_frame_start(*editor.input_state, input);

    for * editor.panels {
        if it.view.kind == .DOCUMENT {
            view := *it.view._document;
            if view.old_cursor != view.cursors.c0 {
                view.old_cursor = view.cursors.c0;
                view.old_cursor_position = get_position_at_cursor(view, editor.font);
            }
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
                        case .F1;  toggle_dev_view(*editor.dev_view, .ATLAS_TEXTURE); handled = true;
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

    for * panel, panel_index: editor.panels {
        update_panel_early(editor, platform, input, panel, panel_index);
    }

    {
        //
        // Chaging font size (zoom)
        //
        // Because we respect the mouse (or cursor) position when changing fonts, this gets its own
        // update loop, which is for now inlined here.
        //

        if editor.input_state.modifiers & .CTRL {
            delta: s32;
            if input.mouse_wheel_delta > 0 then delta = 1;
            if input.mouse_wheel_delta < 0 then delta = -1;
            editor.font_size = max(editor.font_size + delta, 1);
        }

        pixel_height := cast(s32, ceil(editor.font_size * input.window_scale_factor));
        if editor.font.pixel_height != pixel_height {
            editor_log(editor, "Font size: %, physical pixel height: %", editor.font_size, pixel_height);

            cell_h_before_zoom := editor.font.line_height_in_pixels;
            font_reset_for_options(*editor.font, pixel_height, FONT_LINE_HEIGHT_MULTIPLIER);
            cell_h_after_zoom  := editor.font.line_height_in_pixels;

            for * editor.panels {
                y: s64;
                if #complete it.view.kind == {
                    case .DOCUMENT; {
                        view := *it.view._document;
                        if input.mouse_wheel_delta == 0 {
                            y = view.cursors.c0.y;
                        } else {
                            y = cast(s64, floor(input.mouse_position.y + it.scroll.target.y) / cell_h_before_zoom);
                        }
                    }

                    case .LISTING; {
                        view := *it.view._listing;
                        if input.mouse_wheel_delta == 0 {
                            y = view.item_index;
                        } else {
                            y = cast(s64, floor(input.mouse_position.y + it.scroll.target.y) / cell_h_before_zoom);
                        }
                    }
                }

                y_position_before_zoom := y * cell_h_before_zoom;
                y_position_after_zoom  := y * cell_h_after_zoom;

                delta := y_position_after_zoom - y_position_before_zoom;

                target := it.scroll.target;
                target.y += delta;
                target.y = max(target.y, 0);
                interpolation_init(*it.scroll, target);

                if it.view.kind == .DOCUMENT {
                    view := *it.view._document;

                    // If we change zoom, we need to invalidate old cursor positions in every panel. We
                    // also want to fast-forward every every cursor animation, because the interpolants
                    // are about to get stale.
                    cursor_position := get_position_at_cursor(view, editor.font);

                    view.old_cursor_position = cursor_position;
                    interpolation_init(*view.cursor_position, cursor_position);
                }
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
    window_w := cast(f32, input.window_size.x);
    window_h := cast(f32, input.window_size.y);
    cell_w := editor.font.max_glyph_width_in_pixels;
    cell_h := editor.font.line_height_in_pixels;

    if editor.mini_panel.open {
        // TODO(jt): @Incomplete Handle mouse in mini panel. Currently we just close it if we click outside.
        mini_panel_h := (MINI_PANEL_LINES + 1) * cell_h;
        mini_panel_y := max(window_h - mini_panel_h, 0);
        mini_panel_rect := rect_from_point_and_size(0, mini_panel_y, window_w, mini_panel_h);

        if editor.input_state.keys[Key.MB_LEFT] & .PRESSED && !rect_contains_point(mini_panel_rect, input.mouse_position) {
            editor.mini_panel.procs.cancel(editor, platform, input);
        }
    } else if editor.modal_interaction.open {
        // TODO(jt): @Incomplete Handle mouse in modal interaction. Currently, we just close it if we click outside.

        message_line_y := window_h - cell_h;
        message_line_rect := rect_from_point_and_size(0, message_line_y, window_w, cell_h);

        if editor.input_state.keys[Key.MB_LEFT] & .PRESSED && !rect_contains_point(message_line_rect, input.mouse_position) {
            editor.modal_interaction.procs.cancel(editor, platform, input);
        }
    } else {
        for * panel, panel_index: editor.panels {
            wants_this_frame, wants_next_frame |= update_panel_for_mouse(editor, platform, input, panel, panel_index, dt);
        }
    }

    for * panel, panel_index: editor.panels {
        wants_this_frame, wants_next_frame |= update_panel(editor, platform, input, panel, panel_index, dt);
    }

    for * document: editor.documents {
        document.flags &= ~.TRANSIENT;
    }

    // Only draw, if we have to output this frame. According to the Windows (TM) Task Manager, this
    // reduces our power usage from Very High to Moderate. CPU fans seem to agree.
    //
    // See :BatterySaver.
    if wants_this_frame {
        for panel, panel_index: editor.panels {
            draw_panel(editor, input, *render_commands, *atlas_update_regions, panel, panel_index);
        }

        // Reset scissor for the rest of the drawing after the panels messed with it.
        set_scissor(*render_commands, { 0, 0, window_w, window_h });

        // Draw view separator
        if editor.active_view != .FULL {
            draw_rect(*render_commands, rect_from_point_and_size(window_w * 0.5 - 1.0, 0.0, 2.0, window_h), editor.theme.separator_color);
        }

        // TODO(jt): Instead of just drawing over what the panels drew, let's also use this information for culling?
        if editor.mini_panel.open {
            mini_panel := *editor.mini_panel;

            mini_panel_h := (MINI_PANEL_LINES + 1) * cell_h;
            mini_panel_x0 := GUTTER_PIXELS;
            mini_panel_x1 := window_w - GUTTER_PIXELS;
            mini_panel_y := max(window_h - mini_panel_h, 0);
            draw_rect(*render_commands, mini_panel_x0, mini_panel_y, mini_panel_x1, window_h, editor.theme.background_color);

            if mini_panel.item_index == -1 {
                draw_rect(*render_commands, mini_panel_x0, mini_panel_y, mini_panel_x1, mini_panel_y + cell_h, editor.theme.mini_panel_line_color);
            }

            action_text := mini_panel.procs.get_action_text(editor, platform, input);

            line_view := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);

            line_x    := cast(f32, _font_compute_position_on_line(editor.font, action_text, action_text.count, binary = false));
            cursor0_x := line_x + cast(f32, _font_compute_position_on_line(editor.font, line_view, mini_panel.cursors.c0.x, binary = false));
            cursor1_x := line_x + cast(f32, _font_compute_position_on_line(editor.font, line_view, mini_panel.cursors.c1.x, binary = false));

            draw_rect(*render_commands, mini_panel_x0 + cursor0_x, mini_panel_y, mini_panel_x0 + cursor1_x, mini_panel_y + cell_h, editor.theme.selection_color);
            draw_rect(*render_commands, mini_panel_x0 + cursor0_x, mini_panel_y, mini_panel_x0 + cursor0_x + cell_w, mini_panel_y + cell_h, editor.theme.cursor_color);

            main_line := tprint("%%", action_text, line_view);

            scissor := Rect.{ mini_panel_x0, mini_panel_y, mini_panel_x1, window_h };
            _font_layout_and_draw_text(*editor.font, main_line, *render_commands, *atlas_update_regions, { mini_panel_x0, mini_panel_y }, scissor, editor.theme.text_color, .[], binary = false);

            index0 := max(mini_panel.item_index - (MINI_PANEL_LINES / 2), 0);
            index1 := min(index0 + MINI_PANEL_LINES, mini_panel.items.count - 1);

            it_index := 0;
            for index0..index1 {
                item := *mini_panel.items[it];

                if it == mini_panel.item_index {
                    y0 := mini_panel_y + (it_index + 1) * cell_h;
                    y1 := mini_panel_y + (it_index + 2) * cell_h;
                    draw_rect(*render_commands, mini_panel_x0, y0, mini_panel_x1, y1, editor.theme.mini_panel_line_color);

                    // TODO(jt): @Speed We need an incremental version of font_compute_position_on_line
                    // that can resume where it left of last time. In can see multiple places in this
                    // file where that would be useful. It will become more important for long lines.
                    x0 := font_compute_position_on_line(editor.font, item.text, item.highlight_x0, binary = cast(bool, item.flags & .BINARY));
                    x1 := font_compute_position_on_line(editor.font, item.text, item.highlight_x1, binary = cast(bool, item.flags & .BINARY));

                    draw_rect(*render_commands, mini_panel_x0 + cast(f32, x0), y0, mini_panel_x0 + cast(f32, x1), y1, editor.theme.highlight_color);
                }

                offset_y: f64 = mini_panel_y + (it_index + 1) * cell_h;
                color := editor.theme.mini_panel_item_text_color;
                if item.flags & .WARNING {
                    color = editor.theme.mini_panel_item_warning_text_color;
                }

                font_layout_and_draw_text(*editor.font, item.text, *render_commands, *atlas_update_regions, { mini_panel_x0, offset_y }, scissor, color, .[], binary = cast(bool, item.flags & .BINARY));

                it_index += 1;
            }
        } else if editor.modal_interaction.open {
            modal_interaction := *editor.modal_interaction;

            modal_interaction_line_x0 := GUTTER_PIXELS;
            modal_interaction_line_x1 := window_w - GUTTER_PIXELS;
            modal_interaction_line_y := window_h - cell_h;
            draw_rect(*render_commands, modal_interaction_line_x0, modal_interaction_line_y, modal_interaction_line_x1, window_h, editor.theme.background_color);

            action_text := modal_interaction.procs.get_action_text(editor, platform, input);

            line_view := text_buffer_make_view_for_line(modal_interaction.buffer, 0,, temp);

            line_x   := cast(f32, _font_compute_position_on_line(editor.font, action_text, action_text.count, binary = false));
            cursor_x := line_x + _font_compute_position_on_line(editor.font, line_view, editor.modal_interaction.cursors.c0.x, binary = false);

            draw_rect(*render_commands, rect_from_point_and_size(modal_interaction_line_x0 + cast(f32, cursor_x), modal_interaction_line_y, cell_w, cell_h), editor.theme.cursor_color);

            main_line := tprint("%%", action_text, line_view);

            offset  := DVector2.{ modal_interaction_line_x0, modal_interaction_line_y };
            scissor := Rect.{ modal_interaction_line_x0, modal_interaction_line_y, modal_interaction_line_x1, window_h };

            _font_layout_and_draw_text(*editor.font, main_line, *render_commands, *atlas_update_regions, offset, scissor, editor.theme.text_color, .[], binary = false);
        } else {
            message_line_y := window_h - cell_h;
            message_line_x0 := GUTTER_PIXELS;
            message_line_x1 := window_w - GUTTER_PIXELS;

            draw_rect(*render_commands, message_line_x0, message_line_y, window_w, window_h, editor.theme.background_color);

            if editor.messages.count && !editor.last_message_seen {
                message := editor.messages[editor.messages.count - 1];

                offset  := DVector2.{ message_line_x0, message_line_y };
                scissor := Rect.{ message_line_x0, message_line_y, message_line_x1, window_h };
                _font_layout_and_draw_text(*editor.font, message, *render_commands, *atlas_update_regions, offset, scissor, editor.theme.text_color, .[], binary = false);
            }
        }

        if editor.font.glyph_cache_overrun {
            log_error("Glyph cache was overrun this frame. Rendering is going to be incorrect. Increase the size of the glyph cache, if this happens.");
        }
    }

    if #complete editor.dev_view == {
        case .NONE; // Nothing
        case .ATLAS_TEXTURE; {
            wants_this_frame = true;
            array_reset_keeping_memory(*render_commands);

            w := cast(f32, editor.font.glyph_atlas_width_in_pixels);
            h := cast(f32, editor.font.glyph_atlas_height_in_pixels);
            draw_rect(*render_commands, 0, 0, w, h, { 0.89, 0.89, 0.95, 1 });
            draw_rect(*render_commands, 0, 0, w, h, { 0, 0, 0, 1 }, TEXTURE_ID_GLYPH_ATLAS);
        }
    }

    // Only send things to the GPU, if we have to output this frame. In theory, both render_commands
    // and atlas_update_regions should be empty, but there could be mistakes.
    //
    // See :BatterySaver.
    if wants_this_frame {
        atlas_update_region := irect_union_or_zero(atlas_update_regions);

        // TODO(jt): @Speed OpenGL is doing some kind of synchronization here. Depending on whether
        // update_texture does early return (because the update region is empty), either it or
        // draw_rects blocks for about 10-15ms, but at least one of them does. We should probably just
        // switch to our own rendering backend (raw Vulkan/Metal, WGPU or SGPU) and tune it for latency.
        #if SUBPIXEL {
            atlas: [] u8;
            atlas.count = editor.font.glyph_atlas.count * 4;
            atlas.data  = cast(*u8, editor.font.glyph_atlas.data);

            renderer.update_texture_rgba8unorm(TEXTURE_ID_GLYPH_ATLAS, atlas, atlas_update_region);
        } else {
            renderer.update_texture_r8unorm(TEXTURE_ID_GLYPH_ATLAS, editor.font.glyph_atlas, atlas_update_region);
        }

        renderer.begin_frame(editor.theme.background_color);
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

// Returns Panel and panel_index only if *scratch* has a currently assigned panel.
// TODO(jt): Unify this with find_or_add_compilation_document later.
get_scratch :: (editor: Editor) -> *Document, *Panel, panel_index: s64 {
    document: *Document;
    panel: *Panel;
    panel_index: s64 = -1;

    for * editor.panels {
        if it.view.kind != .DOCUMENT                    continue;
        if it.view._document.document.kind != .SCRATCH  continue;

        document = it.view._document.document;
        panel = it;
        panel_index = it_index;

        return document, panel, panel_index;
    }

    for * editor.documents {
        if it.kind == .SCRATCH {
            document = it;
            break;
        }
    }

    assert(document != null, "We are missing *scratch*"); // Currently, *scratch* can't be closed, right?!

    return document, panel, panel_index;
}

// Returns Panel and panel_index only if *compilation* has a currently assigned panel,
// or it was assigned in the function because we provided show=true.
find_or_add_compilation_document :: (editor: *Editor, platform: Platform, _backing_directory_path: string, compilation_args: string, show := true) -> *Document, *Panel, panel_index: s64 {
    sanity_assert(!String.ends_with(_backing_directory_path, "/"));
    backing_directory_path := String.trim_right(_backing_directory_path, "/");

    document: *Document;
    panel: *Panel;
    panel_index: s64 = -1;

    for * editor.panels {
        if it.view.kind != .DOCUMENT                        continue;
        if it.view._document.document.kind != .COMPILATION  continue;

        document = it.view._document.document;
        panel = it;
        panel_index = it_index;

        // TODO(jt): @Memory Currently, we repurpose an already existing compilation buffer,
        // but we need to put the right directory in. If we do this a lot, we "leak" memory.
        // Should we instead just make another compilation buffer and then the user can deal
        // with all the open buffers? Same for args.  :HijackCompilationBuffer.
        if backing_directory_path.count && backing_directory_path != document.backing_directory_path {
            document.backing_directory_path = arena_push_string(document.arena, backing_directory_path);
        }

        if compilation_args.count && compilation_args != document.compilation_args {
            document.compilation_args = arena_push_string(document.arena, compilation_args);
        }

        return document, panel, panel_index;
    }

    for * editor.documents {
        if it.kind == .COMPILATION {
            document = it;

            // See :HijackCompilationBuffer.
            if document.backing_directory_path != backing_directory_path {
                document.backing_directory_path = arena_push_string(document.arena, backing_directory_path);
            }

            if compilation_args.count && compilation_args != document.compilation_args {
                document.compilation_args = arena_push_string(document.arena, compilation_args);
            }

            break;
        }
    }

    if !document {
        document = find_or_add_document(editor, platform, .COMPILATION, backing_directory_path, "");
        document.flags |= .READONLY_BY_NATURE;
        if compilation_args.count {
            document.compilation_args = arena_push_string(document.arena, compilation_args);
        }
    }

    if show {
        if editor.active_view == {
            case .FULL; {
                assert(editor.panels.count == 1);

                panel = array_add(*editor.panels);
                panel_index = 1;

                panel_init_with_document(panel, editor, platform, document);

                editor.left_view_panel_index  = 0;
                editor.right_view_panel_index = 1;

                editor.active_view = .RIGHT;
            }
            case .LEFT; #through;
            case .RIGHT; {
                panel, panel_index = get_panel_for_inactive_view(editor);
                panel_set_document(panel, editor, document);

                if editor.active_view == {
                    case .FULL;   // Shouldn't get here.
                    case .LEFT;   editor.active_view = .RIGHT;
                    case .RIGHT;  editor.active_view = .LEFT;
                }
            }
        }
    }

    return document, panel, panel_index;
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

get_panel_for_inactive_view :: (editor: Editor) -> *Panel, panel_index: s64 {
    index: s64;
    if #complete editor.active_view == {
        case .FULL;   index = editor.full_view_panel_index;
        case .LEFT;   index = editor.right_view_panel_index;
        case .RIGHT;  index = editor.left_view_panel_index;
    }

    panel: *Panel = null;
    if editor.panels.count {
        panel = *editor.panels[index];
    }

    return panel, index;
}

get_panel_directory :: (editor: Editor, panel: Panel) -> /* Pointing to underlying thing */ string {
    directory: string;

    if #complete panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            document := view.document;

            if document.backing_directory_path.count {
                directory = document.backing_directory_path;
            }
        }

        case .LISTING; {
            view := *panel.view._listing;
            listing := view.listing;

            if listing.backing_directory_path.count {
                directory = listing.backing_directory_path;
            }
        }
    }

    return directory;
}

get_panel_rect :: (editor: Editor, panel_index: s64) -> Rect, content_rect: Rect {
    window_w := cast(f32, editor.input_state.window_size.x);
    window_h := cast(f32, editor.input_state.window_size.y);
    cell_h := editor.font.line_height_in_pixels;

    panel_x: f32 = 0.0;
    panel_content_x: f32 = GUTTER_PIXELS;
    if editor.active_view != .FULL && editor.right_view_panel_index == panel_index {
        panel_x = window_w * 0.5;
        panel_content_x = window_w * 0.5 + GUTTER_PIXELS;
    }

    panel_y: f32 = 0.0;
    panel_content_y: f32 = 0.0;

    panel_w         := ifx editor.active_view == .FULL then window_w else window_w * 0.5;
    panel_content_w := ifx editor.active_view == .FULL then window_w - 2 * GUTTER_PIXELS else window_w * 0.5 - 2 * GUTTER_PIXELS;

    panel_h := window_h - cell_h; // cell_h is the message line
    panel_content_h := window_h - 2 * cell_h; // 2*cell_h is the mode line and message line.
    if editor.mini_panel.open {
        // Currently, this only affects culling.
        //
        // TODO(jt): In Emacs, this would also modify the scroll offset, if the cursor would be
        // occluded by the newly visible mini panel. Should we do that?
        panel_h = window_h - (1 + MINI_PANEL_LINES) * cell_h;
        panel_content_h = window_h - (2 + MINI_PANEL_LINES) * cell_h;
    }

    // TODO(jt): @Speed This is slightly wasteful, that we convert xywh into a point rect, only for
    // the callers to convert it back into xywh. Maybe rethink this once we do this too often?
    panel_rect         := rect_from_point_and_size(panel_x, panel_y, panel_w, panel_h);
    panel_content_rect := rect_from_point_and_size(panel_content_x, panel_content_y, panel_content_w, panel_content_h);

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

                        // If the document is displayed by a panel, flash the cursor.
                        // (This also sets the cursor_color to the readonly color.)
                        for * editor.panels {
                            if it.view.kind == .DOCUMENT {
                                view := *it.view._document;
                                if view.document == document {
                                    interpolation_start(*view.cursor_color,
                                                        editor.theme.cursor_color_active, editor.theme.cursor_color_readonly,
                                                        input.time, CURSOR_FLASH_DURATION);
                                }
                            }
                        }

                        save_shortcut := shortcut_sprint(key_map_find_shortcut(editor.document_key_map, .SAVE_DOCUMENT),, temp);
                        reload_shortcut := shortcut_sprint(key_map_find_shortcut(editor.document_key_map, .RELOAD_DOCUMENT),, temp);
                        editor_log(editor, "% modified, but file changed on filesystem. % or % to exit read only mode", String.path_filename(document.backing_file_path), save_shortcut, reload_shortcut);
                    } else {
                        // TODO(jt): @Speed @Memory Figure out a diff instead of changing the whole file?

                        cursor_before_reload := document.cursors_cold.c0;

                        text_buffer_delete_all(*document.buffer, *document.cursors_cold);
                        text_buffer_insert(*document.buffer, *document.cursors_cold, contents, .FUSE);
                        text_buffer_move_cursor_to(document.buffer, *document.cursors_cold, cursor_before_reload, false);

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

    MOVE_UP_ONE_SCREEN;
    MOVE_DOWN_ONE_SCREEN;

    START_SELECTING;

    INDENT_OR_AUTOCOMPLETE;

    CONFIRM;
    CANCEL_OR_STOP_SELECTING;
}

route_event_to_mini_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    mini_panel := *editor.mini_panel;

    min_item_index := ifx mini_panel.procs.can_select_text_line(editor, platform, input) then -1 else 0;

    buffer_changed := false;
    old_item_index := mini_panel.item_index;

    buffered, action := key_map_input(*mini_panel.key_map, event, editor.input_state.modifiers);
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

        case .MOVE_UP_ONE_SCREEN;      mini_panel.item_index = clamp(mini_panel.item_index - MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);
        case .MOVE_DOWN_ONE_SCREEN;    mini_panel.item_index = clamp(mini_panel.item_index + MINI_PANEL_LINES, min_item_index, mini_panel.items.count - 1);

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

#scope_module

Panel_Action :: enum {
    NONE;

    SHOW_COMMANDS;
    SEARCH;

    OPEN_FILE;

    SWITCH_VIEW;
    CLOSE_VIEW;

    RECENTER;
    MOVE_UP_ONE_SCREEN;
    MOVE_DOWN_ONE_SCREEN;

    SPLIT_PANEL_HORIZONTALLY;
    CLOSE_CURRENT_PANEL;
    CLOSE_OTHER_PANELS;
    GO_TO_NEXT_PANEL;

    // TODO(jt): @Cleanup Move things below to the Global_Action, because they don't need a panel to do their thing.

    OPEN_PROJECT_FILE;
    SEARCH_PROJECT;
    COMPILE_PROJECT;

    ABULAFIA_THEME;
    NAYSAYER_THEME;
    HANDMADE_THEME;
    STB_THEME;
    ZENBURN_THEME;
}

Document_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;

    SEARCH_AND_REPLACE;

    SAVE_DOCUMENT;
    RELOAD_DOCUMENT;

    SWAP_LINE_UP;
    SWAP_LINE_DOWN;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_TO_START;
    MOVE_TO_END;

    MOVE_TO_PREVIOUS_BLANK_LINE;
    MOVE_TO_NEXT_BLANK_LINE;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

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

    TOGGLE_READONLY;

    STRIP_TRAILING_WHITESPACE;

    BENCHGEN_TEXT;
}

Compilation_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_TO_START;
    MOVE_TO_END;

    MOVE_TO_PREVIOUS_BLANK_LINE;
    MOVE_TO_NEXT_BLANK_LINE;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    START_SELECTING;
    STOP_SELECTING;

    COPY;

    MOVE_TO_PREVIOUS_ERROR;
    MOVE_TO_NEXT_ERROR;

    REFRESH;
}

Listing_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;

    OPEN;
    OPEN_IN_OTHER_PANEL;

    SET_PROJECT_DIRECTORY;
    UNSET_PROJECT_DIRECTORY;
}

#scope_file

route_event_to_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    panel := get_panel_for_active_view(editor);
    if !panel {
        return;
    }

    did_buffer_event   := false;
    did_execute_action := false;

    {
        buffered, action   := key_map_input(*editor.panel_key_map, event, editor.input_state.modifiers);
        did_buffer_event   |= buffered;
        did_execute_action |= execute_panel_action(editor, platform, input, panel, action);
    }

    if did_execute_action {
        key_map_flush(*editor.document_key_map);
        key_map_flush(*editor.listing_key_map);

        return;
    }

    if #complete panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;

            document := view.document;
            if !document {
                return;
            }

            if document.kind == .COMPILATION {
                buffered, action   := key_map_input(*editor.compilation_key_map, event, editor.input_state.modifiers);
                did_buffer_event   |= buffered;
                did_execute_action |= execute_compilation_action(editor, platform, input, panel, view, document, action);
            } else {
                buffered, action   := key_map_input(*editor.document_key_map, event, editor.input_state.modifiers);
                did_buffer_event   |= buffered;
                did_execute_action |= execute_document_action(editor, platform, input, panel, view, document, action);
            }

            if !did_buffer_event && !did_execute_action && event.flags & .PRESSED {
                if event.type == .CODEPOINT {
                    document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
                    if !(document.flags & .READONLY) {
                        view.selecting = false;

                        char := cast(u32, event.codepoint);

                        handled := false;
                        opens, closes, paired_char := is_part_of_surround_pair(document, char);

                        if closes {
                            if view.cursors.c0 == view.cursors.c1 {
                                c0 := view.cursors.c0;
                                if text_buffer_can_read_at_location(document.buffer, c0) {
                                    curr_byte := text_buffer_get_byte_at_location(document.buffer, c0);
                                    if char == curr_byte {
                                        text_buffer_move_cursor_x(document.buffer, *view.cursors, 1, false);
                                        handled = true;
                                    }
                                }
                            } else {
                                // Surrounding selection never cares for unbalanced parentheses
                                c0 := view.cursors.c0;
                                c1 := view.cursors.c1;
                                text_location_sort(*c0, *c1);

                                text_cursors_join(*view.cursors);

                                text_buffer_move_cursor_to(document.buffer, *view.cursors, c0, false);
                                text_buffer_insert_char(*document.buffer, *view.cursors, paired_char, .NONE);

                                c1.x += 1; // Because we just inserted the starting paren.
                                text_buffer_move_cursor_to(document.buffer, *view.cursors, c1, false);
                                text_buffer_insert_char(*document.buffer, *view.cursors, char, .FUSE);

                                handled = true;
                            }
                        }

                        if opens && !handled {
                            if view.cursors.c0 == view.cursors.c1 {
                                text_buffer_insert_char(*document.buffer, *view.cursors, char, .NONE);
                                text_buffer_insert_char(*document.buffer, *view.cursors, paired_char, .FUSE);
                                text_buffer_move_cursor_x(document.buffer, *view.cursors, -1, false);

                                handled = true;
                            } else {
                                // Surrounding selection never cares for unbalanced parentheses
                                c0 := view.cursors.c0;
                                c1 := view.cursors.c1;
                                text_location_sort(*c0, *c1);

                                text_cursors_join(*view.cursors);

                                text_buffer_move_cursor_to(document.buffer, *view.cursors, c1, false);
                                text_buffer_insert_char(*document.buffer, *view.cursors, paired_char, .NONE);

                                text_buffer_move_cursor_to(document.buffer, *view.cursors, c0, false);
                                text_buffer_insert_char(*document.buffer, *view.cursors, char, .FUSE);

                                handled = true;
                            }
                        }

                        if !handled {
                            undo_modifier: Undo_Modifier_For_Insert = .NONE;
                            if input.time - document.time_of_last_interaction < UNDO_AUTOFUSE_PERIOD {
                                undo_modifier = .CAN_AUTOFUSE;
                            }

                            text_buffer_insert_char(*document.buffer, *view.cursors, char, undo_modifier);
                        }

                        //
                        // The code below is a slightly modified copypaste from
                        // execute_documment_action, but here we know the cursor moved and buffer
                        // changed for sure.
                        //

                        document.time_of_last_interaction = input.time;
                        document.flags |= .MODIFIED_THIS_FRAME;
                        document.flags |= .MODIFIED;

                        // The cursor position interpolation gets setup in a centralized place instead of here, because the
                        // cursor can be moved from other places than this one (e.g. mouse, SEARCH minipanel...).
                        //
                        // :CentralizedCursorInterpolationSetup
                        view.flags |= .RECEIVED_DIRECT_KEYBOARD_INTERACTION;
                        view.flags |= .CLAMP_SCROLL_TO_CURSOR;

                        // We have to update these after every change, because the very next edit could be needing
                        // this. We could start being smarter about this (e.g. by setting a specific dirty flag),
                        // becuase not every subsequent action needs these up to date.  -jt, 22 July 2026.
                        update_parenthesized_scopes(document);
                    }
                }
            }
        }

        case .LISTING; {
            view := *panel.view._listing;

            listing := view.listing;
            if !listing {
                return;
            }

            buffered, action   := key_map_input(*editor.listing_key_map, event, editor.input_state.modifiers);
            did_buffer_event   |= buffered;
            did_execute_action |= execute_listing_action(editor, platform, input, panel, view, listing, action);
        }
    }
}

#scope_module

execute_panel_action :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, action: Panel_Action) -> executed: bool {
    theme_changed := false;

    if #complete action == {
        case .NONE;  return false;

        case .SHOW_COMMANDS;         open_mini_panel(editor, platform, input, mini_panel_show_commands_procs);
        case .SEARCH;                open_mini_panel(editor, platform, input, mini_panel_search_procs);

        case .OPEN_FILE;             open_mini_panel(editor, platform, input, mini_panel_open_file_procs);

        case .SWITCH_VIEW;           open_mini_panel(editor, platform, input, mini_panel_switch_view_procs);
        case .CLOSE_VIEW;            open_mini_panel(editor, platform, input, mini_panel_close_view_procs);

        case .RECENTER;              recenter_panel(panel, editor, input);
        case .MOVE_UP_ONE_SCREEN;    scroll_panel_up_one_screen(panel, input, editor.font.line_height_in_pixels);
        case .MOVE_DOWN_ONE_SCREEN;  scroll_panel_down_one_screen(panel, input, editor.font.line_height_in_pixels);

        case .SPLIT_PANEL_HORIZONTALLY; {
            if editor.active_view == .FULL {
                assert(editor.panels.count == 1);

                if panel.view.kind == {
                    case .DOCUMENT; {
                        view := *panel.view._document;
                        document := view.document;
                        if document {
                            right_panel := array_add(*editor.panels);
                            panel_init_with_document(right_panel, editor, platform, document);
                        }
                    }
                    case .LISTING; {
                        view := *panel.view._listing;
                        listing := view.listing;
                        if listing {
                            right_panel := array_add(*editor.panels);
                            panel_init_with_listing(right_panel, editor, platform, listing);
                        }
                    }
                }

                editor.left_view_panel_index  = 0;
                editor.right_view_panel_index = 1;

                editor.active_view = .LEFT;
            }
        }
        case .CLOSE_CURRENT_PANEL; {
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
        case .CLOSE_OTHER_PANELS; {
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
        case .GO_TO_NEXT_PANEL; {
            if #complete editor.active_view == {
                case .FULL;   // No-op
                case .LEFT;   editor.active_view = .RIGHT;
                case .RIGHT;  editor.active_view = .LEFT;
            }
        }

        case .OPEN_PROJECT_FILE;  open_mini_panel(editor, platform, input, mini_panel_open_project_file_procs);
        case .SEARCH_PROJECT;     open_mini_panel(editor, platform, input, mini_panel_search_project_procs);
        case .COMPILE_PROJECT;    open_modal_interaction(editor, platform, input, modal_interaction_compile_project_procs);

        case .ABULAFIA_THEME;     editor.theme = abulafia_theme(); theme_changed = true;
        case .NAYSAYER_THEME;     editor.theme = naysayer_theme(); theme_changed = true;
        case .HANDMADE_THEME;     editor.theme = handmade_theme(); theme_changed = true;
        case .STB_THEME;          editor.theme = stb_theme(); theme_changed = true;
        case .ZENBURN_THEME;      editor.theme = zenburn_theme();  theme_changed = true;
    }

    if theme_changed {
        for * panel: editor.panels {
            if panel.view.kind == .DOCUMENT {
                view := *panel.view._document;
                document := view.document;

                color := ifx document.flags & .READONLY then editor.theme.cursor_color_readonly else editor.theme.cursor_color;
                interpolation_init(*view.cursor_color, color);
            }
        }
    }

    return true;
}

// Panel, view and document correspond to each other here. Not sure if I like this amount aliasing, but eh?
execute_document_action :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, view: *Document_View, document: *Document, action: Document_Action) -> executed: bool, cursor_moved: bool, buffer_changed: bool {
    sanity_assert(document.kind != .COMPILATION);
    if document.kind == .COMPILATION {
        return false, false, false;
    }

    cursor_moved   := false;
    buffer_changed := false;

    shift_selecting := editor.input_state.modifiers & .SHIFT;

    if #complete action == {
        case .NONE;  return false, cursor_moved, buffer_changed;

        case .MOVE_UP; {
            cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_DOWN; {
            cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_LEFT; {
            cursor_moved |= text_buffer_move_cursor_x(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_RIGHT; {
            cursor_moved |= text_buffer_move_cursor_x(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }

        case .SEARCH_AND_REPLACE; {
            document.flags &= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                open_modal_interaction(editor, platform, input, modal_interaction_search_and_replace_procs);
            }
        }

        case .SAVE_DOCUMENT; {
            if document.backing_file_path.count {
                if !document.backing_file_exists || document.flags & .MODIFIED {
                    buffer := *document.buffer;

                    if STRIP_TRAILING_WHITESPACE_ON_SAVE {
                        strip_trailing_whitespace(view);
                    }

                    gap_buffer_move_gap_to(*buffer.gb, 0);
                    contents := gap_buffer_make_view(buffer.gb, 0, buffer.gb.count, assert_no_allocations = true);
                    success := platform.write_file(document.backing_file_path, contents);
                    if success {
                        editor_log(editor, "Saved file %", document.backing_file_path);

                        document.flags &= ~.MODIFIED;
                        document.flags &= ~.READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT;

                        interpolation_start(*view.cursor_color,
                                            editor.theme.cursor_color_active, editor.theme.cursor_color,
                                            input.time, CURSOR_FLASH_DURATION);


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

                    view.cursors.c0 = { 0, 0 };
                    view.cursors.c1 = { 0, 0 };
                    text_buffer_reset(*document.buffer);

                    text_buffer_insert(*document.buffer, *view.cursors, file_contents, .OMIT);
                    text_buffer_move_cursor_to(document.buffer, *view.cursors, 0, 0, false);

                    document.flags &= ~.MODIFIED;
                    document.flags &= ~.READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT;

                    interpolation_start(*view.cursor_color,
                                        editor.theme.cursor_color_active, editor.theme.cursor_color,
                                        input.time, CURSOR_FLASH_DURATION);

                    update_parenthesized_scopes(document);
                    update_syntax_highlights(editor, document, platform, input);

                    editor_log(editor, "Reloaded file: %", document.backing_file_path);
                }
            }
        }

        case .SWAP_LINE_UP;                 // TODO(jt): text_buffer_swap_line_up
        case .SWAP_LINE_DOWN;               // TODO(jt): text_buffer_swap_line_down

        case .MOVE_TO_START_OF_LINE;        cursor_moved |= text_buffer_move_cursor_to_start_of_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END_OF_LINE;          cursor_moved |= text_buffer_move_cursor_to_end_of_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_START;                cursor_moved |= text_buffer_move_cursor_to_start(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END;                  cursor_moved |= text_buffer_move_cursor_to_end(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_PREVIOUS_BLANK_LINE;  cursor_moved |= text_buffer_move_cursor_to_previous_blank_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_NEXT_BLANK_LINE;      cursor_moved |= text_buffer_move_cursor_to_next_blank_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_FORWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_cursor_to_next_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_START_OF_LINE;
            }
        }
        case .MOVE_BACKWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_cursor_to_previous_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_END_OF_LINE;
            }
        }

        case .START_SELECTING;              view.selecting = true;  text_cursors_join(*view.cursors);
        case .STOP_SELECTING;               view.selecting = false; text_cursors_join(*view.cursors);

        case .DELETE_LINE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                text := text_buffer_delete_line(*document.buffer, *view.cursors);
                if text {
                    buffer_changed = true;
                    platform.set_clipboard_text(text);
                }
            }
        }
        case .DELETE_FORWARD; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                buffer_changed |= text_buffer_delete_forward(*document.buffer, *view.cursors, .CAN_AUTOFUSE);
            }
        }
        case .DELETE_BACKWARD; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                handled := false;

                if view.cursors.c0 == view.cursors.c1 && view.cursors.c0.x > 0 {
                    curr_loc := view.cursors.c0;
                    prev_loc := view.cursors.c0;
                    prev_loc.x -= 1;

                    if text_buffer_can_read_at_location(document.buffer, curr_loc) {
                        prev_byte := text_buffer_get_byte_at_location(document.buffer, prev_loc);
                        curr_byte := text_buffer_get_byte_at_location(document.buffer, curr_loc);

                        opens, closes, paired_char := is_part_of_surround_pair(document, prev_byte);
                        if opens && paired_char == curr_byte {
                            buffer_changed |= text_buffer_delete_forward(*document.buffer, *view.cursors, .NONE);
                            buffer_changed |= text_buffer_delete_backward(*document.buffer, *view.cursors, .FUSE);

                            handled = true;
                        }
                    }
                }

                if !handled {
                    view.selecting = false;
                    buffer_changed |= text_buffer_delete_backward(*document.buffer, *view.cursors, .CAN_AUTOFUSE);
                }
            }
        }

        case .DELETE_FORWARD_WORD;   // TODO(jt): text_buffer_delete_until_next_word_boundary
        case .DELETE_BACKWARD_WORD;  // TODO(jt): text_buffer_delete_until_previous_word_boundary

        case .INSERT_LINE_BEFORE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                should_make_space_for_block := false;
                if view.cursors.c0.x > 0 {
                    curr_loc := view.cursors.c0;
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
                view.selecting = false;
                buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, "\n", .NONE);

                if should_make_space_for_block {
                    buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, "\n", .FUSE);

                    cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors, -1, false);
                    if document.parenthesized_scopes.count {
                        update_parenthesized_scopes(document);

                        level := find_indentation_level_for_location(document, view.cursors.c0);
                        buffer_changed |= text_buffer_indent_line(*document.buffer, *view.cursors, level, .FUSE);
                    }
                    cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors, 1, false);
                }

                if document.parenthesized_scopes.count {
                    update_parenthesized_scopes(document);

                    level := find_indentation_level_for_location(document, view.cursors.c0);
                    buffer_changed |= text_buffer_indent_line(*document.buffer, *view.cursors, level, .FUSE);
                }

                if should_make_space_for_block {
                    cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors, -1, false);
                    cursor_moved |= text_buffer_move_cursor_to_end_of_line(document.buffer, *view.cursors, false);
                }
            }
        }
        case .INSERT_LINE_AFTER; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                // TODO(jt): Preserve CRLF in CRLF-only documents.
                view.selecting = false;
                buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, "\n", .NONE);
                cursor_moved   |= text_buffer_move_cursor_y(document.buffer, *view.cursors, -1, false);
                cursor_moved   |= text_buffer_move_cursor_to_end_of_line(document.buffer, *view.cursors, false);
            }
        }

        // TODO(jt): Preserve tabness in tab-only documents.
        case .INDENT_OR_AUTOCOMPLETE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                if document.parenthesized_scopes.count {
                    view.selecting = false;

                    original_y0 := view.cursors.c0.y;
                    original_y1 := view.cursors.c1.y;
                    y0 := min(view.cursors.c0.y, view.cursors.c1.y);
                    y1 := max(view.cursors.c0.y, view.cursors.c1.y);

                    first := true;
                    for y0..y1 {
                        level := find_indentation_level_for_location(document, { 0, it });
                        text_buffer_move_cursor_to(document.buffer, *view.cursors, { 0, it }, false);
                        changed := text_buffer_indent_line(*document.buffer, *view.cursors, level, ifx first then .NONE else .FUSE);

                        if changed {
                            update_parenthesized_scopes(document);
                            first = false;
                        }

                        buffer_changed |= changed;
                    }

                    // Restore cursor's vertical position if the selection is backwards.
                    if original_y0 < original_y1 {
                        text_buffer_move_cursor_to(document.buffer, *view.cursors, view.cursors.c0.x, original_y0, false);
                    }
                } else {
                    if view.cursors.c0 == view.cursors.c1 {
                        buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, "    ", .NONE);
                    }
                }
            }
        }

        case .UNDO_EDIT; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                buffer_changed |= text_buffer_undo_edit(*document.buffer, *view.cursors);
            }
        }
        case .REDO_EDIT; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                buffer_changed |= text_buffer_redo_edit(*document.buffer, *view.cursors);
            }
        }

        case .COPY; {
            view.selecting = false;
            text := text_buffer_make_view_for_interval(document.buffer, view.cursors.c0, view.cursors.c1,, temp);
            if text {
                platform.set_clipboard_text(text);
            }

            text_cursors_join(*view.cursors);
        }
        case .CUT; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                deleted := text_buffer_delete_selection(*document.buffer, *view.cursors);
                if deleted {
                    buffer_changed = true;
                    platform.set_clipboard_text(deleted);
                }
            }
        }
        case .PASTE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                text := platform.get_clipboard_text(,, temp);
                if text {
                    buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, text, .NONE);
                }
            }
        }

        case .TOGGLE_READONLY; {
            if document.flags & .READONLY_BECAUSE_OF_MANUAL_LOCK {
                document.flags &= ~.READONLY_BECAUSE_OF_MANUAL_LOCK;
                if document.flags & .READONLY {
                    editor_log(editor, "% is now unlocked; however, it is still read-only for other reasons.", document.backing_file_path);
                } else {
                    interpolation_start(*view.cursor_color,
                                        editor.theme.cursor_color_active, editor.theme.cursor_color,
                                        input.time, CURSOR_FLASH_DURATION);
                    editor_log(editor, "% is now unlocked", document.backing_file_path);
                }
            } else {
                document.flags |= .READONLY_BECAUSE_OF_MANUAL_LOCK;
                interpolation_start(*view.cursor_color,
                                    editor.theme.cursor_color_active, editor.theme.cursor_color_readonly,
                                    input.time, CURSOR_FLASH_DURATION);

                editor_log(editor, "% is now locked (read-only)", document.backing_file_path);
            }
        }

        case .STRIP_TRAILING_WHITESPACE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                buffer_changed |= strip_trailing_whitespace(view);
            }
        }

        case .BENCHGEN_TEXT; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                open_modal_interaction(editor, platform, input, modal_interaction_benchgen_procs);
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
        view.flags |= .RECEIVED_DIRECT_KEYBOARD_INTERACTION;
        view.flags |= .CLAMP_SCROLL_TO_CURSOR;
    }

    if buffer_changed {
        document.flags |= .MODIFIED_THIS_FRAME;
        document.flags |= .MODIFIED;

        // We have to update these after every change, because the very next edit could be needing
        // this. We could start being smarter about this (e.g. by setting a specific dirty flag),
        // becuase not every subsequent action needs these up to date.  -jt, 22 July 2026.
        update_parenthesized_scopes(document);
    }

    return true, cursor_moved, buffer_changed;
}

// Panel, view and document correspond to each other here. Not sure if I like this amount aliasing, but eh?
execute_compilation_action :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, view: *Document_View, document: *Document, action: Compilation_Action) -> executed: bool, cursor_moved: bool, buffer_changed: bool {
    sanity_assert(document.kind == .COMPILATION);
    if document.kind != .COMPILATION {
        return false, false, false;
    }

    cursor_moved   := false;
    buffer_changed := false;

    shift_selecting := editor.input_state.modifiers & .SHIFT;

    if #complete action == {
        case .NONE;  return false, cursor_moved, buffer_changed;

        case .MOVE_UP; {
            cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_DOWN; {
            cursor_moved |= text_buffer_move_cursor_y(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_LEFT; {
            cursor_moved |= text_buffer_move_cursor_x(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_RIGHT; {
            cursor_moved |= text_buffer_move_cursor_x(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }

        case .MOVE_TO_START_OF_LINE;        cursor_moved |= text_buffer_move_cursor_to_start_of_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END_OF_LINE;          cursor_moved |= text_buffer_move_cursor_to_end_of_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_START;                cursor_moved |= text_buffer_move_cursor_to_start(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END;                  cursor_moved |= text_buffer_move_cursor_to_end(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_PREVIOUS_BLANK_LINE;  cursor_moved |= text_buffer_move_cursor_to_previous_blank_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_NEXT_BLANK_LINE;      cursor_moved |= text_buffer_move_cursor_to_next_blank_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_FORWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_cursor_to_next_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_START_OF_LINE;
            }
        }
        case .MOVE_BACKWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_cursor_to_previous_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_END_OF_LINE;
            }
        }

        case .START_SELECTING;              view.selecting = true;  text_cursors_join(*view.cursors);
        case .STOP_SELECTING;               view.selecting = false; text_cursors_join(*view.cursors);

        case .COPY; {
            view.selecting = false;
            text := text_buffer_make_view_for_interval(document.buffer, view.cursors.c0, view.cursors.c1,, temp);
            if text {
                platform.set_clipboard_text(text);
            }

            text_cursors_join(*view.cursors);
        }

        case .MOVE_TO_PREVIOUS_ERROR; {
            // nocheckin
        }
        case .MOVE_TO_NEXT_ERROR; {
            // nocheckin
        }

        case .REFRESH;  run_compilation(editor, platform, panel);
    }

    if cursor_moved || buffer_changed {
        // The cursor position interpolation gets setup in a centralized place instead of here, because the
        // cursor can be moved from other places than this one (e.g. mouse, SEARCH mini
        // panel...).
        //
        // :CentralizedCursorInterpolationSetup
        document.time_of_last_interaction = input.time;
        view.flags |= .RECEIVED_DIRECT_KEYBOARD_INTERACTION;
        view.flags |= .CLAMP_SCROLL_TO_CURSOR;
    }

    if buffer_changed {
        document.flags |= .MODIFIED_THIS_FRAME;
        document.flags |= .MODIFIED;

        // We have to update these after every change, because the very next edit could be needing
        // this. We could start being smarter about this (e.g. by setting a specific dirty flag),
        // becuase not every subsequent action needs these up to date.  -jt, 22 July 2026.
        update_parenthesized_scopes(document);
    }

    return true, cursor_moved, buffer_changed;
}

// Panel, view and listing correspond to each other here. Not sure if I like this amount aliasing, but eh?
execute_listing_action :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, view: *Listing_View, listing: *Listing, action: Listing_Action) -> executed: bool {
    original_item_index := view.item_index;

    if #complete action == {
        case .NONE;       return false;

        case .MOVE_UP;    view.item_index = clamp(view.item_index - 1, 0, listing.items.count - 1);
        case .MOVE_DOWN;  view.item_index = clamp(view.item_index + 1, 0, listing.items.count - 1);

        case .OPEN;  #through;
        case .OPEN_IN_OTHER_PANEL; {
            open_in_panel := panel;
            if action == .OPEN_IN_OTHER_PANEL {
                if editor.active_view == .FULL {
                    assert(editor.panels.count == 1);

                    // The panel is not actually valid, until we set a view (a document or
                    // listing). We are going to do that soon after, in open_file.
                    open_in_panel = array_add(*editor.panels);
                    panel_init(open_in_panel, platform);

                    editor.left_view_panel_index  = 0;
                    editor.right_view_panel_index = 1;

                    editor.active_view = .RIGHT;
                } else {
                    open_in_panel = get_panel_for_inactive_view(editor);

                    if editor.active_view == {
                        case .FULL;   // Shouldn't get here.
                        case .LEFT;   editor.active_view = .RIGHT;
                        case .RIGHT;  editor.active_view = .LEFT;
                    }
                }
            }

            item_path := listing.items[view.item_index].text;
            full_path := String.path_join(listing.backing_directory_path, item_path, separator = "/",, temp);

            open_file(editor, platform, input, full_path, open_in_panel);
        }

        case .SET_PROJECT_DIRECTORY; {
            // TODO(jt): @Leak Not a big problem, but still a leak.
            editor.project_directory = arena_push_string(editor.perm_arena, listing.backing_directory_path);
            editor_log(editor, "Project directory set to %", editor.project_directory);
        }
        case .UNSET_PROJECT_DIRECTORY; {
            editor.project_directory = "";
            editor_log(editor, "Project directory unset");
        }
    }

    if view.item_index != original_item_index {
        view.flags |= .CLAMP_SCROLL_TO_ITEM_INDEX;
    }

    return true;
}

#scope_file

update_panel_early :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, panel_index: s64) {
    ProfileZone("update_panel_early");

    mouse := input.mouse_position;

    panel_rect, panel_content_rect := get_panel_rect(editor, panel_index);

    //
    // Switch active view by clicking
    //
    if editor.input_state.keys[Key.MB_LEFT] & .PRESSED {
        if rect_contains_point(panel_rect, mouse) {
            panel.flags |= .LAST_CLICK_WAS_INSIDE;

            if #complete editor.active_view == {
                case .FULL;   // No-op
                case .LEFT;   if panel_index == editor.right_view_panel_index  editor.active_view = .RIGHT;
                case .RIGHT;  if panel_index == editor.left_view_panel_index   editor.active_view = .LEFT;
            }

            if rect_contains_point(panel_content_rect, mouse) {
                panel.flags |= .LAST_CLICK_WAS_INSIDE_CONTENT;
            } else {
                panel.flags &= ~.LAST_CLICK_WAS_INSIDE_CONTENT;
            }
        } else {
            panel.flags &= ~.LAST_CLICK_WAS_INSIDE;
            panel.flags &= ~.LAST_CLICK_WAS_INSIDE_CONTENT;
        }
    }
}

update_panel_for_mouse :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, panel_index: s64, dt: f64) -> wants_this_frame: bool, wants_next_frame: bool {
    ProfileZone("update_panel_for_mouse");

    wants_this_frame := false;
    wants_next_frame := false;

    mouse := input.mouse_position;

    cell_w := editor.font.max_glyph_width_in_pixels;
    cell_h := editor.font.line_height_in_pixels;

    panel_rect, panel_content_rect := get_panel_rect(editor, panel_index);
    panel_content_w := rect_width(panel_content_rect);
    panel_is_active := false;
    {
        _, active_panel_index := get_panel_for_active_view(editor);
        panel_is_active = panel_index == active_panel_index;
    }

    //
    // Mouse hover update
    //
    if rect_contains_point(panel_content_rect, input.mouse_position) {
        //
        // Mouse wheel scrolling
        //
        // We scroll the hovered panel regardless of whether it is active.
        //

        if input.mouse_wheel_delta != 0 && !(editor.input_state.modifiers & .CTRL) {
            target := panel.scroll.target;
            target.y -= cast(f64, input.mouse_wheel_delta);
            if #complete panel.view.kind == {
                case .DOCUMENT; {
                    view := *panel.view._document;
                    target.y = clamp(target.y, 0, cell_h * cast(f64, view.document.buffer.line_count - 1));

                    view.flags |= .CLAMP_CURSOR_TO_SCROLL;
                    view.flags |= .RECEIVED_MOUSE_INTERACTION;
                }
                case. LISTING; {
                    view := *panel.view._listing;
                    target.y = clamp(target.y, 0, cell_h * cast(f64, view.listing.items.count - 1));

                    view.flags |= .CLAMP_ITEM_INDEX_TO_SCROLL;
                    // view.flags |= .RECEIVED_MOUSE_INTERACTION;
                }
            }

            interpolation_init(*panel.scroll, target);
        }
    }

    //
    // Mouse selection/drag update
    //
    // Unlike wheel scrolling, mouse selection is sticky to the panel where it started.
    //
    if panel_is_active && editor.input_state.keys[Key.MB_LEFT] & .DOWN && panel.flags & .LAST_CLICK_WAS_INSIDE_CONTENT {
        if #complete panel.view.kind == {
            case .DOCUMENT; {
                view     := *panel.view._document;
                document := view.document;

                //
                // Mouse selection scrolling in DOCUMENT views.
                //
                {
                    SCROLL_ZONE:  f32 :  20.0;
                    SCROLL_SPEED: f64 :  10.0;
                    SCROLL_BOOST: f64 :   5.0;

                    left_edge   := panel_content_rect.x0 + SCROLL_ZONE;
                    right_edge  := panel_content_rect.x1 - SCROLL_ZONE;
                    top_edge    := panel_content_rect.y0 + SCROLL_ZONE;
                    bottom_edge := panel_content_rect.y1 - SCROLL_ZONE;

                    if mouse.x < left_edge {
                        boost := (left_edge - mouse.x) * SCROLL_BOOST;

                        target := panel.scroll.target;
                        target.x -= SCROLL_SPEED * boost * dt;
                        target.x = max(target.x, 0);
                        interpolation_init(*panel.scroll, target);

                        wants_this_frame = true;
                        wants_next_frame = true;
                    } else if mouse.x > right_edge {
                        boost := (mouse.x - right_edge) * SCROLL_BOOST;

                        // Apron contains at least the horizontal space to place the cursor after
                        // scroll, and optionally the configurable horizontal padding, so that it
                        // behaves the same as if we scrolled there by moving the cursor with the
                        // keyboard.
                        apron := (1 + PANEL_SCROLL_PADDING_CELLS_X) * cell_w + GUTTER_PIXELS;

                        line_view := text_buffer_make_view_for_line(document.buffer, view.cursors.c0.y,, temp);

                        // Clamp to zero, so we don't end up scrolling the other way if the line is
                        // short. (Happens if you start scrolling on a long line, but then vertically
                        // scroll to a short line.)
                        max_x := max(font_compute_line_length(editor.font, line_view, binary = document.buffer.binary_mode) - panel_content_w + apron, 0);

                        target := panel.scroll.target;
                        target.x += SCROLL_SPEED * boost * dt;
                        target.x = min(target.x, max_x);
                        interpolation_init(*panel.scroll, target);

                        wants_this_frame = true;
                        wants_next_frame = true;
                    }

                    if mouse.y < top_edge {
                        boost := (top_edge - mouse.y) * SCROLL_BOOST;

                        target := panel.scroll.target;
                        target.y -= SCROLL_SPEED * boost * dt;
                        target.y = max(target.y, 0);
                        interpolation_init(*panel.scroll, target);

                        wants_this_frame = true;
                        wants_next_frame = true;
                    } else if mouse.y > bottom_edge {
                        boost := (mouse.y - bottom_edge) * SCROLL_BOOST;

                        target := panel.scroll.target;
                        target.y += SCROLL_SPEED * boost * dt;
                        target.y = min(target.y, cell_h * cast(f64, document.buffer.line_bytes.count - 1));
                        interpolation_init(*panel.scroll, target);

                        wants_this_frame = true;
                        wants_next_frame = true;
                    }
                }

                //
                // Mouse selection in DOCUMENT views.
                //

                row := cast(s64, floor((mouse.y + panel.scroll.value.y) / cell_h));
                col := 0;

                if row < 0 {
                    row = 0;
                    col = 0;
                } else if row > document.buffer.line_bytes.count - 1 {
                    row = document.buffer.line_bytes.count - 1;

                    // Include newline, so that the cursor can go there.
                    line_view := text_buffer_make_view_for_line(document.buffer, row, include_newline = true,, temp);
                    col = font_compute_character_index_on_line(editor.font, line_view, mouse.x - panel_content_rect.x0 + panel.scroll.value.x, binary = document.buffer.binary_mode);
                } else {
                    // Include newline, so that the cursor can go there.
                    line_view := text_buffer_make_view_for_line(document.buffer, row, include_newline = true,, temp);
                    col = font_compute_character_index_on_line(editor.font, line_view, mouse.x - panel_content_rect.x0 + panel.scroll.value.x, binary = document.buffer.binary_mode);
                }

                text_buffer_move_cursor_to(document.buffer, *view.cursors, col, row, !(editor.input_state.keys[Key.MB_LEFT] & .PRESSED));

                view.flags |= .RECEIVED_MOUSE_INTERACTION;
            }

            case .LISTING;  // Nothing yet.
        }
    }

    return wants_this_frame, wants_next_frame;
}

update_panel :: (editor: *Editor, platform: Platform, input: Input, panel: *Panel, panel_index: s64, dt: f64) -> wants_this_frame: bool, wants_next_frame: bool {
    ProfileZone("update_panel");
    // The name of this procedure is a little untrue, because some updates already happened when the
    // panel received keyboard events (route_event_to_panel) and mouse input
    // (update_panel_for_mouse). In general, those earlier pieces of code tried to do as little work
    // as possible, deferring serious updates to this loop (e.g. update_syntax_highlights) by
    // setting various flags on the panel.  -jt, 26 July 2026.

    wants_this_frame := false;
    wants_next_frame := false;

    cell_w := editor.font.max_glyph_width_in_pixels;
    cell_h := editor.font.line_height_in_pixels;

    panel_rect, panel_content_rect := get_panel_rect(editor, panel_index);
    panel_w := rect_width(panel_rect);
    panel_h := rect_height(panel_rect);
    panel_content_w := rect_width(panel_content_rect);
    panel_is_active := false;
    {
        _, active_panel_index := get_panel_for_active_view(editor);
        panel_is_active = panel_index == active_panel_index;
    }

    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            document := view.document;
            if !document {
                return wants_this_frame, wants_next_frame;
            }

            // Because other panels could have edited the same document before this code runs (either this
            // frame, if they ran before us in the loop, or in the previous frame, if they ran after), we
            // need to make sure the cursors are still valid. We could also be clamping for each operation,
            // but I am not sure I like that.  -jt, 24 July 2026.
            text_buffer_clamp_cursors(document.buffer, *view.cursors);

            //
            // Compute cursor position.
            //
            cursor0_position    := get_position_at_cursor(view, editor.font);
            cursor0_line_length := get_line_length_at_cursor(view, editor.font);

            //
            // Clamp cursor to buffer
            //
            if view.flags & .CLAMP_CURSOR_TO_SCROLL {
                viewport_rect := drect_from_point_and_size(panel.scroll.target.x, panel.scroll.target.y, panel_w, panel_h);
                cursor_rect   := drect_from_point_and_size(cursor0_position.x, cursor0_position.y, cell_w, cell_h);

                cursor_position_dirty := false;
                if viewport_rect.y0 > cursor_rect.y1 {
                    // Move cursor down
                    delta := cast(s64, ceil((viewport_rect.y0 - cursor_rect.y1) / cell_h)) + PANEL_SCROLL_PADDING_CELLS_Y;
                    text_buffer_move_cursor_y(document.buffer, *view.cursors, delta, view.selecting);

                    cursor_position_dirty = true;
                } else if viewport_rect.y1 < cursor_rect.y0 {
                    // Move cursor up
                    delta := cast(s64, ceil((cursor_rect.y0 - viewport_rect.y1) / cell_h)) + PANEL_SCROLL_PADDING_CELLS_Y;
                    text_buffer_move_cursor_y(document.buffer, *view.cursors, -delta, view.selecting);

                    cursor_position_dirty = true;
                }

                if cursor_position_dirty {
                    cursor0_position    = get_position_at_cursor(view, editor.font);
                    cursor0_line_length = get_line_length_at_cursor(view, editor.font);
                }
            }

            //
            // Scroll buffer to cursor
            //
            if view.flags & .CLAMP_SCROLL_TO_CURSOR || view.flags & .CLAMP_SCROLL_TO_START_OF_LINE || view.flags & .CLAMP_SCROLL_TO_END_OF_LINE {
                scroll_padding_x := min(panel_w * 0.25, cell_w * PANEL_SCROLL_PADDING_CELLS_X);
                scroll_padding_y := min(panel_h * 0.25, cell_h * PANEL_SCROLL_PADDING_CELLS_Y);

                viewport_rect := drect_from_point_and_size(panel.scroll.target.x + GUTTER_PIXELS, panel.scroll.target.y, panel_content_w, panel_h);
                scroll_to_rect: DRect;
                if view.flags & .CLAMP_SCROLL_TO_START_OF_LINE {
                    scroll_to_rect = drect_from_point_and_size(GUTTER_PIXELS, cursor0_position.y, cell_w, cell_h);
                } else if view.flags & .CLAMP_SCROLL_TO_END_OF_LINE {
                    scroll_to_rect = drect_from_point_and_size(GUTTER_PIXELS + cursor0_line_length, cursor0_position.y, cell_w, cell_h);
                } else {
                    scroll_to_rect = drect_from_point_and_size(GUTTER_PIXELS + cursor0_position.x, cursor0_position.y, cell_w, cell_h);
                }

                if scroll_to_rect.x1 > viewport_rect.x1 {
                    target := panel.scroll.target;
                    target.x = scroll_to_rect.x0 - panel_w + drect_width(scroll_to_rect) + scroll_padding_x;
                    target.x = max(target.x, 0);

                    interpolation_chain(*panel.scroll, target, input.time, PANEL_SCROLL_DURATION);
                } else if scroll_to_rect.x0 < viewport_rect.x0 {
                    target := panel.scroll.target;
                    target.x = scroll_to_rect.x0 - scroll_padding_x;
                    target.x = max(target.x, 0);

                    interpolation_chain(*panel.scroll, target, input.time, PANEL_SCROLL_DURATION);
                }

                if scroll_to_rect.y1 > viewport_rect.y1 {
                    target := panel.scroll.target;
                    target.y = scroll_to_rect.y0 - panel_h + drect_height(scroll_to_rect) + scroll_padding_y;
                    target.y = max(target.y, 0);

                    interpolation_chain(*panel.scroll, target, input.time, PANEL_SCROLL_DURATION);
                } else if scroll_to_rect.y0 < viewport_rect.y0 {
                    target := panel.scroll.target;
                    target.y = scroll_to_rect.y0 - scroll_padding_y;
                    target.y = max(target.y, 0);

                    interpolation_chain(*panel.scroll, target, input.time, PANEL_SCROLL_DURATION);
                }
            }

            //
            // Update Syntax Highlighting
            //
            if document.flags & .MODIFIED_THIS_FRAME {
                update_syntax_highlights(editor, document, platform, input);
            }

            //
            // Animate Cursor
            //
            {
                new_cursor_position := cursor0_position;

                // :CentralizedCursorInterpolationSetup
                //
                // Because the cursor position can be changed by both editing, mouse interaction,
                // scrolling, etc, we detect cursor changes every frame here (instead of in all the
                // places where the cursor can change).
                //
                // UPDATE: Now we do the same for cursor flash animation.
                if view.old_cursor != view.cursors.c0 {
                    anim_duration: f32 = 0.0;
                    if view.flags & .RECEIVED_MOUSE_INTERACTION              anim_duration = max(anim_duration, CURSOR_ANIM_DURATION_MOUSE);
                    if view.flags & .RECEIVED_INDIRECT_KEYBOARD_INTERACTION  anim_duration = max(anim_duration, CURSOR_ANIM_DURATION_KEYBOARD_INDIRECT);
                    if view.flags & .RECEIVED_DIRECT_KEYBOARD_INTERACTION    anim_duration = max(anim_duration, CURSOR_ANIM_DURATION_KEYBOARD_DIRECT);

                    interpolation_start(*view.cursor_position, view.old_cursor_position, new_cursor_position, input.time, anim_duration);
                }

                if document.flags & (.MODIFIED_THIS_FRAME | .MODIFY_ATTEMPT_THIS_FRAME) {
                    color := ifx document.flags & .READONLY then editor.theme.cursor_color_readonly else editor.theme.cursor_color;
                    interpolation_start(*view.cursor_color, editor.theme.cursor_color_active, color, input.time, CURSOR_FLASH_DURATION);
                }

                interpolation_running := false;
                interpolation_running |= interpolation_update(*view.cursor_position, input.time);
                interpolation_running |= interpolation_update(*view.cursor_color, input.time);
                if interpolation_running {
                    wants_this_frame = true;
                    wants_next_frame = true;
                }
            }

            view.flags &= ~.TRANSIENT;
        }

        case .LISTING; {
            view := *panel.view._listing;
            listing := view.listing;

            if !listing {
                return wants_this_frame, wants_next_frame;
            }

            // Because other panels could have edited the same listing before this code runs (either this
            // frame, if they ran before us in the loop, or in the previous frame, if they ran after), we
            // need to make sure the index is still valid.
            view.item_index = clamp(view.item_index, 0, listing.items.count - 1);

            item_index_y := cast(f64, view.item_index) * cell_h;

            //
            // Clamp item index to buffer
            //
            if view.flags & .CLAMP_ITEM_INDEX_TO_SCROLL {
                viewport_rect := drect_from_point_and_size(panel.scroll.target.x, panel.scroll.target.y, panel_w, panel_h);
                line_rect   := drect_from_point_and_size(0, item_index_y, panel_w, cell_h);

                if viewport_rect.y0 > line_rect.y1 {
                    // Move item index down
                    delta := cast(s64, ceil((viewport_rect.y0 - line_rect.y1) / cell_h)) + PANEL_SCROLL_PADDING_CELLS_Y;
                    view.item_index += delta;

                    item_index_y = cast(f64, view.item_index) * cell_h;
                } else if viewport_rect.y1 < line_rect.y0 {
                    // Move item index up
                    delta := cast(s64, ceil((line_rect.y0 - viewport_rect.y1) / cell_h)) + PANEL_SCROLL_PADDING_CELLS_Y;
                    view.item_index -= delta;

                    item_index_y = cast(f64, view.item_index) * cell_h;
                }
            }

            //
            // Scroll buffer to item index
            //
            if view.flags & .CLAMP_SCROLL_TO_ITEM_INDEX {
                scroll_padding_x := min(panel_w * 0.25, cell_w * PANEL_SCROLL_PADDING_CELLS_X);
                scroll_padding_y := min(panel_h * 0.25, cell_h * PANEL_SCROLL_PADDING_CELLS_Y);

                viewport_rect := drect_from_point_and_size(panel.scroll.target.x + GUTTER_PIXELS, panel.scroll.target.y, panel_content_w, panel_h);
                scroll_to_rect := drect_from_point_and_size(GUTTER_PIXELS, item_index_y, cell_w, cell_h);

                if scroll_to_rect.y1 > viewport_rect.y1 {
                    target := panel.scroll.target;
                    target.y = scroll_to_rect.y0 - panel_h + drect_height(scroll_to_rect) + scroll_padding_y;
                    target.y = max(target.y, 0);

                    interpolation_chain(*panel.scroll, target, input.time, PANEL_SCROLL_DURATION);
                } else if scroll_to_rect.y0 < viewport_rect.y0 {
                    target := panel.scroll.target;
                    target.y = scroll_to_rect.y0 - scroll_padding_y;
                    target.y = max(target.y, 0);

                    interpolation_chain(*panel.scroll, target, input.time, PANEL_SCROLL_DURATION);
                }
            }

            view.flags &= ~.TRANSIENT;
        }
    }

    //
    // Animate Scroll
    //
    {
        interpolation_running := interpolation_update(*panel.scroll, input.time);
        if interpolation_running {
            wants_this_frame = true;
            wants_next_frame = true;
        }
    }

    return wants_this_frame, wants_next_frame;
}

draw_panel :: (editor: *Editor, input: Input, render_commands: *[..] Render_Command, atlas_update_regions: *[..] IRect, panel: Panel, panel_index: s64) {
    ProfileZone("draw_panel");

    window_h := cast(f32, input.window_size.y);
    cell_w := editor.font.max_glyph_width_in_pixels;
    cell_h := editor.font.line_height_in_pixels;

    panel_rect, panel_content_rect := get_panel_rect(editor, panel_index);
    panel_x := panel_rect.x0;
    panel_y := panel_rect.y0;
    panel_w := rect_width(panel_rect);
    panel_h := rect_height(panel_rect);
    panel_content_x := panel_content_rect.x0;
    panel_content_y := panel_content_rect.y0;
    panel_content_w := rect_width(panel_content_rect);
    panel_is_active := false;
    {
        _, active_panel_index := get_panel_for_active_view(editor);
        panel_is_active = panel_index == active_panel_index;
    }

    viewport_y0 := panel.scroll.value.y;
    viewport_y1 := panel.scroll.value.y + panel_h;

    set_scissor(render_commands, panel_content_rect);

    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;

            document := view.document;
            if !document {
                // TODO(jt): Draw something in empty document views?
                return;
            }

            viewport_line0 := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, document.buffer.line_bytes.count - 1);
            viewport_line1 := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, document.buffer.line_bytes.count - 1);

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
                highlight_rect_screen := panel_content_rect.p0 + drect_to_rect(highlight_rect_world - panel.scroll.value);
                highlight_rect_screen = rect_clamp(highlight_rect_screen, panel_content_rect);

                if it_index == panel.highlight_index {
                    draw_rect(render_commands, highlight_rect_screen, editor.theme.highlight_color_active);
                } else {
                    draw_rect(render_commands, highlight_rect_screen, editor.theme.highlight_color);
                }
            }

            //
            // Layout and draw selection
            //
            if panel_is_active && view.cursors.c0 != view.cursors.c1 {
                cursor_start := text_location_min(view.cursors.c0, view.cursors.c1);
                cursor_end   := text_location_max(view.cursors.c0, view.cursors.c1);

                if cursor_start.y == cursor_end.y {
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

                    selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll.value);
                    selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                    draw_rect(render_commands, selection_rect_screen, editor.theme.selection_color);
                } else {
                    // TODO(jt): @Speed Horizontal culling?

                    // Because we start the layout just before the current viewport, the rendering scroll Y offset
                    // is just the fractional part of the cell.
                    //
                    // Because we expect scroll_offset to be small, we keep it in f32.
                    scroll_offset: Vector2;
                    scroll_offset.x = cast(f32, panel.scroll.value.x);
                    scroll_offset.y = cast(f32, viewport_y0 - cell_h * cast(f64, viewport_line0));

                    // First line, if in viewport
                    if cursor_start.y >= viewport_line0 && cursor_start.y <= viewport_line1 {
                        line_start := text_buffer_get_start_of_line(document.buffer, cursor_start.y);
                        line_end   := text_buffer_get_end_of_line(document.buffer, cursor_start.y, include_newline = true);

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

                        selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll.value);
                        selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                        draw_rect(render_commands, selection_rect_screen, editor.theme.selection_color);
                    }

                    // Center lines, if in viewport
                    for (cursor_start.y + 1)..(cursor_end.y - 1) {
                        // TODO(jt): @Speed Clamp center lines range instead.
                        if it < viewport_line0 || it > viewport_line1 {
                            continue;
                        }

                        line_end  := text_buffer_get_end_of_line(document.buffer, it, include_newline = true);
                        line_view := text_buffer_make_view_for_line(document.buffer, it, include_newline = true,, temp);

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

                        selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll.value);
                        selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                        draw_rect(render_commands, selection_rect_screen, editor.theme.selection_color);
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

                        selection_rect_screen := panel_content_rect.p0 + drect_to_rect(selection_rect_world - panel.scroll.value);
                        selection_rect_screen = rect_clamp(selection_rect_screen, panel_content_rect);

                        draw_rect(render_commands, selection_rect_screen, editor.theme.selection_color);
                    }
                }
            }

            //
            // Draw matching parenthesis
            //
            {
                found := false;
                highlight_loc: Text_Location;

                scope := find_parenthesized_scope_for_location(document, view.cursors.c0);
                if scope && scope.parent_index != -1 {
                    if scope.loc0 == view.cursors.c0 {
                        found = true;
                        highlight_loc = scope.loc1;
                    }

                    if scope.loc1 == view.cursors.c0 {
                        found = true;
                        highlight_loc = scope.loc0;
                    }
                }

                if found {
                    highlight_position := get_position_for_location(document, editor.font, highlight_loc) - panel.scroll.value;
                    highlight_rect := rect_from_point_and_size(panel_content_x + cast(f32, highlight_position.x), cast(f32, highlight_position.y), cell_w, cell_h);

                    draw_rect(render_commands, highlight_rect, editor.theme.matching_parenthesis_color);
                }
            }

            //
            // Draw cursor
            //
            if panel_is_active {
                cursor_position := view.cursor_position.value;

                line_rect := rect_from_point_and_size(
                    panel_content_x,
                    cast(f32, cursor_position.y - panel.scroll.value.y),
                    panel_w,
                    cell_h,
                );

                draw_rect(render_commands, line_rect, editor.theme.line_color);

                r := drect_from_point_and_size(panel_content_x + cursor_position.x, cursor_position.y, cell_w, cell_h) - panel.scroll.value;

                cursor_rect := drect_to_rect(r);
                cursor_rect = rect_clamp(cursor_rect, panel_content_rect);

                draw_rect(render_commands, cursor_rect, view.cursor_color.value);
            }

            //
            // Layout and draw document text
            //
            {
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
                offset.x = panel_content_x + -panel.scroll.value.x;
                offset.y = -viewport_y0 + cell_h * cast(f64, viewport_line0);

                style_ranges: [..] Font_Style_Range;
                style_ranges.allocator = temp;

                //
                // Find syntax highlights for current screen
                //
                {
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
                            case .KEYWORD;         r.color = editor.theme.keyword_color; r.variant = editor.theme.keyword_variant;
                            case .ATTRIBUTE;       r.color = editor.theme.attribute_color; r.variant = editor.theme.attribute_variant;
                            case .DIRECTIVE;       r.color = editor.theme.directive_color; r.variant = editor.theme.directive_variant;
                            case .STRING_LITERAL;  r.color = editor.theme.string_literal_color; r.variant = editor.theme.string_literal_variant;
                            case .NUMBER_LITERAL;  r.color = editor.theme.number_literal_color; r.variant = editor.theme.number_literal_variant;
                            case .COMMENT;         r.color = editor.theme.comment_color; r.variant = editor.theme.comment_variant;

                            case; continue;
                        }

                        array_add(*style_ranges, r);
                    }
                }

                scissor_rect := rect_from_point_and_size(panel_content_x, 0.0, panel_content_w, panel_h);
                font_layout_and_draw_text(*editor.font, cast(string, viewport_view), render_commands, atlas_update_regions, offset, scissor_rect, editor.theme.text_color, style_ranges, binary = document.buffer.binary_mode);
            }

            //
            // Draw modeline
            //
            {
                // TODO(jt): @Cleanup Reformulate the modeline rect as cutting into the current panel instead of using absolute coordinates.
                modeline_y      := ifx editor.mini_panel.open then window_h - (MINI_PANEL_LINES + 2) * cell_h else window_h - 2 * cell_h;
                modeline_rect   := rect_from_point_and_size(panel_x, modeline_y, panel_w, cell_h);
                modeline_offset := DVector2.{ panel_x, modeline_y };

                set_scissor(render_commands, modeline_rect);
                draw_rect(render_commands, modeline_rect, ifx panel_is_active then editor.theme.modeline_color_active else editor.theme.modeline_color);

                cursor  := view.cursors.c0;
                percent := cast(s64, 100.0 * cast(f32, cursor.y) / cast(f32, document.buffer.line_bytes.count));

                document_name: string;
                if #complete document.kind == {
                    case .SCRATCH;      document_name = "*scratch*";
                    case .COMPILATION;  document_name = "*compilation*";
                    case .FILE;         document_name = String.path_filename(document.backing_file_path);
                }

                percent_string := temp_right_pad(tprint("%\%", percent), 4);

                s := tprint("    % % L% C%", temp_right_pad(document_name, 15), percent_string, cursor.y + 1, cursor.x + 1);
                _font_layout_and_draw_text(*editor.font, s, render_commands, atlas_update_regions, modeline_offset, modeline_rect, editor.theme.system_text_color, .[], binary = false);
            }
        }

        case .LISTING; {
            view := *panel.view._listing;

            listing := view.listing;

            viewport_line0 := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, listing.items.count - 1);
            viewport_line1 := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, listing.items.count - 1);

            for viewport_line0..viewport_line1 {
                item := *listing.items[it];

                line_y_world  := cast(f64, it) * cell_h;
                line_y_screen := panel_content_y + cast(f32, line_y_world - panel.scroll.value.y);
                line_rect_screen := rect_from_point_and_size(panel_content_x, line_y_screen, panel_content_w, cell_h);

                if it == view.item_index {
                    draw_rect(render_commands, line_rect_screen, editor.theme.selection_color);
                }

                // Because we start the layout just before the current viewport, the rendering scroll Y offset
                // is just the fractional part of the cell.
                offset: DVector2;
                offset.x = panel_content_x + -panel.scroll.value.x;
                offset.y = -viewport_y0 + cell_h * cast(f64, it);

                scissor_rect := rect_from_point_and_size(panel_content_x, 0.0, panel_content_w, panel_h);

                _font_layout_and_draw_text(*editor.font, item.text, render_commands, atlas_update_regions, offset, scissor_rect, editor.theme.listing_item_text_color, .[], binary = false);
            }

            //
            // Draw modeline
            //
            {
                // TODO(jt): @Cleanup Reformulate the modeline rect as cutting into the current panel instead of using absolute coordinates.
                modeline_y      := ifx editor.mini_panel.open then window_h - (MINI_PANEL_LINES + 2) * cell_h else window_h - 2 * cell_h;
                modeline_rect   := rect_from_point_and_size(panel_x, modeline_y, panel_w, cell_h);
                modeline_offset := DVector2.{ panel_x, modeline_y };

                set_scissor(render_commands, modeline_rect);
                draw_rect(render_commands, modeline_rect, ifx panel_is_active then editor.theme.modeline_color_active else editor.theme.modeline_color);

                item_index := view.item_index;
                percent := cast(s64, 100.0 * cast(f32, item_index) / cast(f32, listing.items.count));

                listing_name: string;
                if #complete listing.kind == {
                    case .DIRECTORY;  listing_name = String.path_filename(listing.backing_directory_path);
                }

                percent_string := temp_right_pad(tprint("%\%", percent), 4);

                s := tprint("    % % L%", temp_right_pad(listing_name, 15), percent_string, item_index + 1);
                _font_layout_and_draw_text(*editor.font, s, render_commands, atlas_update_regions, modeline_offset, modeline_rect, editor.theme.system_text_color, .[], binary = false);
            }
        }
    }
}

open_mini_panel :: (editor: *Editor, platform: Platform, input: Input, procs: Mini_Panel_Procs) {
    mini_panel := *editor.mini_panel;

    assert(!mini_panel.open);

    mini_panel.procs = procs;
    mini_panel.open = true;

    procs.init(editor, platform, input);

    // init is allowed to close the mini_panel, so we have to check whether it didn't do so.
    if mini_panel.open {
        procs.update(editor, platform, input, true, true);
    }
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

open_modal_interaction :: (editor: *Editor, platform: Platform, input: Input, procs: Modal_Interaction_Procs) {
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

open_file :: (editor: *Editor, platform: Platform, input: Input, file_path: string, open_in_panel: *Panel = null) -> opened_in_panel: *Panel {
    panel: *Panel;
    if open_in_panel {
        panel = open_in_panel;
    } else {
        panel = get_panel_for_active_view(editor);
    }
    sanity_assert(panel != null);
    if !panel {
        return panel;
    }

    file_exists       := platform.file_exists(file_path);
    file_is_directory := platform.file_is_directory(file_path);

    if file_is_directory {
        success, file_absolute_path := platform.get_absolute_path(file_path,, temp);
        if success {
            canonicalize_path(*file_absolute_path);

            listing, listing_added := find_or_add_listing(editor, platform, .DIRECTORY, file_absolute_path);
            editor_log(editor, "Opening directory: %", file_absolute_path);

            if listing_added {
                file_list := platform.list_directory(file_absolute_path, recursive = false, files = true, directories = true,, temp);

                {
                    self_dir := array_add(*listing.items);
                    self_dir.text = ".";
                }

                {
                    parent_dir := array_add(*listing.items);
                    parent_dir.text = "..";
                }

                for file_list {
                    listed_file_path := it.absolute_path;
                    listed_filename := String.path_filename(it.absolute_path);

                    s := "";
                    if listed_filename.count {
                        s = arena_push_string(listing.arena, listed_filename);

                        item := array_add(*listing.items);
                        item.text = s;
                    }
                }
            }

            panel_set_listing(panel, editor, listing);
        } else {
            log_error("Failed to get absolute_path for %", file_path);
        }
    } else {
        success, file_absolute_path := platform.get_absolute_path(file_path,, temp);
        if success {
            canonicalize_path(*file_absolute_path);

            directory_absolute_path := String.path_strip_filename(file_absolute_path);
            canonicalize_path(*directory_absolute_path);

            document, document_added := find_or_add_document(editor, platform, .FILE, directory_absolute_path, file_absolute_path);
            if document_added {
                if file_exists {
                    editor_log(editor, "Opening file: %", file_absolute_path);

                    document.backing_file_exists = true;
                    document.backing_file_time_of_last_sync = input.time;

                    _, modification_time, size := platform.file_modification_time_and_size(document.backing_file_path);
                    document.backing_file_last_synced_modification_time = modification_time;
                    document.backing_file_last_synced_size = size;

                    success, file_contents := platform.read_file(file_absolute_path,, temp);
                    if success {
                        // TODO(jt): @Speed This is slow, because we are going over the data
                        // twice. Once to make the hash, and the second time to insert into the text
                        // buffer. We should probably do it in a single pass, or in a chunked
                        // manner, so we can read from the L1 cache.
                        document.backing_file_last_synced_hash = hash_file_contents(file_contents);

                        text_buffer_insert(*document.buffer, *document.cursors_cold, file_contents, .OMIT);
                        text_buffer_move_cursor_to(document.buffer, *document.cursors_cold, 0, 0, false);

                        update_parenthesized_scopes(document);
                        update_syntax_highlights(editor, document, platform, input);

                        watch_file(editor, platform, input, document.backing_file_path);
                    }
                } else {
                    editor_log(editor, "Opening new file with path: %", file_absolute_path);
                }
            }

            panel_set_document(panel, editor, document);
        }
    }

    return panel;
}

find_or_add_document :: (editor: *Editor, platform: Platform, kind: Document.Kind, _backing_directory_path: string, _backing_file_path: string) -> *Document, added: bool {
    sanity_assert(!String.ends_with(_backing_directory_path, "/"));
    sanity_assert(!String.ends_with(_backing_file_path, "/"));

    backing_directory_path := String.trim_right(_backing_directory_path, "/");
    backing_file_path      := String.trim_right(_backing_file_path, "/");

    for * editor.documents {
        if it.kind != kind                                      continue;
        if it.backing_directory_path != backing_directory_path  continue;
        if it.backing_file_path != backing_file_path            continue;

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
    if backing_directory_path.count {
        document.backing_directory_path = arena_push_string(document_arena, backing_directory_path);
    }

    if backing_file_path.count {
        document.backing_file_path = arena_push_string(document_arena, backing_file_path);
    }

    document.parenthesized_scopes.allocator    = arena_allocator(document_arena);
    document.syntax_highlight_tokens.allocator = arena_allocator(document_arena);

    locator, pointer := bucket_array_add(*editor.documents, document);
    pointer.locator = locator;

    return pointer, true;
}

find_or_add_listing :: (editor: *Editor, platform: Platform, kind: Listing.Kind, _backing_directory_path: string) -> *Listing, added: bool {
    sanity_assert(!String.ends_with(_backing_directory_path, "/"));
    backing_directory_path := String.trim_right(_backing_directory_path, "/");

    for * editor.listings {
        if it.kind != kind                                      continue;
        if it.backing_directory_path != backing_directory_path  continue;

        it.time_of_last_interaction = editor.input_state.time;

        return it, false;
    }

    listing_arena := make_arena(platform, .MEDIUM);

    listing: Listing;
    listing.kind = .DIRECTORY;
    listing.time_of_last_interaction = editor.input_state.time;

    listing.arena = listing_arena;
    if backing_directory_path.count {
        listing.backing_directory_path = arena_push_string(listing_arena, backing_directory_path);
    }

    listing.items.allocator = arena_allocator(listing_arena);

    locator, pointer := bucket_array_add(*editor.listings, listing);
    pointer.locator = locator;

    return pointer, true;
}

close_document :: (editor: *Editor, input: Input, document: *Document) {
    editor_log(editor, "Closing document % %", document.kind, document.backing_file_path);

    thing_to_show: *void;
    thing_to_show_kind: View_Kind;
    thing_to_show_time: Apollo_Time = APOLLO_TIME_INVALID; // The maximum negative time. Anything valid will compare higher.

    for * editor.documents {
        if it != document && it.time_of_last_interaction > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .DOCUMENT;
            thing_to_show_time = it.time_of_last_interaction;
        }
    }

    for * editor.listings {
        if it.time_of_last_interaction > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .LISTING;
            thing_to_show_time = it.time_of_last_interaction;
        }
    }

    // Find a document/listing with time_of_last_interaction > 0. If we don't, we either have no
    // documents/listings (bad, becuase at least *scratch* shouldn't be closeable), or their
    // time_of_last_interaction was not properly set everywhere it should be. We could do a fallback
    // here to find ANYTHING.  -jt, 25 July 2026.
    assert(thing_to_show != null);

    // Make sure nobody references the document anymore.
    for * editor.panels {
        if it.view.kind == .DOCUMENT && it.view._document.document == document {
            it.view._document.document = null; // So that the panel_set_xyz routines don't try to read from it.

            if #complete thing_to_show_kind == {
                case .DOCUMENT; {
                    panel_set_document(it, editor, thing_to_show);
                    recenter_panel(it, editor, input, force_center = true, skip_interpolation = true);
                }
                case .LISTING; {
                    panel_set_listing(it, editor, thing_to_show);
                    recenter_panel(it, editor, input, force_center = true, skip_interpolation = true);
                }
            }
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

close_listing :: (editor: *Editor, input: Input, listing: *Listing) {
    // TODO(jt): @Cleanup close_listing is very similar to close_document. They are both
    // things/entities. Maybe we should have a generic close_thing and deal with the special-case
    // code with polymorphism?

    editor_log(editor, "Closing listing %", listing.backing_directory_path);

    thing_to_show: *void;
    thing_to_show_kind: View_Kind;
    thing_to_show_time: Apollo_Time = APOLLO_TIME_INVALID; // The maximum negative time. Anything valid will compare higher.

    for * editor.documents {
        if it.time_of_last_interaction > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .DOCUMENT;
            thing_to_show_time = it.time_of_last_interaction;
        }
    }

    for * editor.listings {
        if it != listing && it.time_of_last_interaction > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .LISTING;
            thing_to_show_time = it.time_of_last_interaction;
        }
    }

    // See analogous comment in close_document.
    assert(thing_to_show != null);

    // Make sure nobody references the listing anymore.
    for * editor.panels {
        if it.view.kind == .LISTING && it.view._listing.listing == listing {
            it.view._listing.listing = null; // So that the panel_set_xyz routines don't try to read from it.

            if #complete thing_to_show_kind == {
                case .DOCUMENT; {
                    panel_set_document(it, editor, thing_to_show);
                    recenter_panel(it, editor, input, force_center = true, skip_interpolation = true);
                }
                case .LISTING; {
                    panel_set_listing(it, editor, thing_to_show);
                    recenter_panel(it, editor, input, force_center = true, skip_interpolation = true);
                }
            }
        }
    }

    // Release arena. Can't touch anything dynamically allocated on the listing after.
    arena_release(listing.arena);

    locator := listing.locator;

    // Remove listing itself.
    bucket_array_remove(*editor.listings, locator);
}

// WARNING: At the moment, panels without views (documents/listings) are invalid, so only use this
// if you know you are going to set the view soon after.
panel_init :: (panel: *Panel, platform: Platform) {
    panel.highlights_arena = make_arena(platform, .LARGE);
    panel.highlights.allocator = arena_allocator(panel.highlights_arena);
    panel.highlight_index = -1;
}

panel_init_with_document :: (panel: *Panel, editor: Editor, platform: Platform, document: *Document) {
    panel_init(panel, platform);
    panel_set_document(panel, editor, document);
}

panel_init_with_listing :: (panel: *Panel, editor: Editor, platform: Platform, listing: *Listing) {
    panel_init(panel, platform);
    panel_set_listing(panel, editor, listing);
}

// Don't use the panel after calling this!
panel_deinit :: (panel: *Panel) {
    arena_release(panel.highlights_arena);
}

panel_set_document :: (panel: *Panel, editor: Editor, document: *Document) {
    // For now, each (Document_View) panel must have a document. We may later relax this and show
    // some default background, or something.
    assert(document != null);

    // If this was a document-viewing panel, save the cursors on the document, so that they can be
    // restored later, once the document comes back to the foreground.
    //
    // Analogous for listing-viewing panel and item_index.
    //
    // TODO(jt): @Cleanup @Copypasta This is a copypasta between document/listing code.
    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;

            if view.document {
                view.document.cursors_cold = view.cursors;
            }
        }
        case .LISTING; {
            view := *panel.view._listing;

            if view.listing {
                view.listing.item_index_cold = view.item_index;
            }
        }
    }

    panel.view.kind = .DOCUMENT;

    view := *panel.view._document;

    view.document = document;

    view.cursors = document.cursors_cold;
    view.selecting = false;

    cursor_position := get_position_at_cursor(view, editor.font);

    view.old_cursor = view.cursors.c0;
    view.old_cursor_position = cursor_position;

    interpolation_init(*view.cursor_position, cursor_position);
    interpolation_init(*view.cursor_color, ifx document.flags & .READONLY then editor.theme.cursor_color_readonly else editor.theme.cursor_color);

    interpolation_init(*panel.scroll, { 0, 0 });

    document.time_of_last_interaction = editor.input_state.time;
}

panel_set_listing :: (panel: *Panel, editor: Editor, listing: *Listing) {
    // For now, each (Listing_View) panel must have a document. We may later relax this and show
    // some default background, or something.
    assert(listing != null);

    // If this was a document-viewing panel, save the cursors on the document, so that they can be
    // restored later, once the document comes back to the foreground.
    //
    // Analogous for listing-viewing panel and item_index.
    //
    // TODO(jt): @Cleanup @Copypasta This is a copypasta between document/listing code.
    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;

            if view.document {
                view.document.cursors_cold = view.cursors;
            }
        }
        case .LISTING; {
            view := *panel.view._listing;

            if view.listing {
                view.listing.item_index_cold = view.item_index;
            }
        }
    }

    panel.view.kind = .LISTING;

    view := *panel.view._listing;

    view.listing = listing;
    view.item_index = listing.item_index_cold;

    interpolation_init(*panel.scroll, { 0, 0 });

    listing.time_of_last_interaction = editor.input_state.time;
}

strip_trailing_whitespace :: (view: *Document_View) -> buffer_changed: bool {
    document := view.document;

    trimmed := false;
    if !document.buffer.binary_mode {
        cursor0 := view.cursors.c0;
        cursor1 := view.cursors.c1;

        start_line_index := cursor0.y;
        end_line_index   := cursor1.y;
        if cursor0 == cursor1 {
            start_line_index = 0;
            end_line_index   = document.buffer.line_count - 1;
        }

        line_gb_index := text_buffer_get_gap_buffer_index_for_line(document.buffer, start_line_index);
        for start_line_index..end_line_index {
            view.cursors.c0 = { 0, it };
            view.cursors.c1 = { 0, it };
            trimmed |= text_buffer_trim_line(*document.buffer, *view.cursors, ifx trimmed then .FUSE else .NONE, __line_gb_index = line_gb_index);

            line_gb_index += document.buffer.line_bytes[it];
        }

        view.cursors.c0 = cursor0;
        view.cursors.c1 = cursor1;
        text_buffer_clamp_cursors(document.buffer, *view.cursors);
    }

    return trimmed;
}

run_compilation :: (editor: *Editor, platform: Platform, panel: *Panel) {
    sanity_assert(panel.view.kind == .DOCUMENT);
    if panel.view.kind != .DOCUMENT {
        return;
    }

    view := *panel.view._document;
    document := view.document;

    sanity_assert(document.kind == .COMPILATION);
    if document.kind != .COMPILATION {
        return;
    }

    working_directory := get_panel_directory(editor, panel);
    if working_directory.count == 0 {
        editor_log(editor, "Failed to get working directory for *compilation*");
        return;
    }

    args := document.compilation_args;

    view.cursors.c0 = { 0, 0 };
    view.cursors.c1 = { 0, 0 };
    text_buffer_reset(*document.buffer);
    text_buffer_insert(*document.buffer, *view.cursors, "Compilation directory: ", .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, working_directory, .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, "\n", .OMIT );
    text_buffer_insert(*document.buffer, *view.cursors, "Compiling with args: ", .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, args, .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, "\n", .OMIT );

    time_before := platform.get_current_time_monotonic();
    exit_code, output, error := platform.run_in_process(args, working_directory,, temp);
    time_after  := platform.get_current_time_monotonic();

    time_elapsed := time_after - time_before;

    // TODO(jt): Interleave stdout and stderr as the process writes to them.
    if error.count == 0 {
        text_buffer_insert(*document.buffer, *view.cursors, output, undo_modifier = .OMIT);
    } else if output.count == 0 {
        text_buffer_insert(*document.buffer, *view.cursors, error, undo_modifier = .OMIT);
    } else {
        text_buffer_insert(*document.buffer, *view.cursors, output, undo_modifier = .OMIT);
        text_buffer_insert(*document.buffer, *view.cursors, "Compilation also wrote to standard error (this will eventually be properly interleaved):\n\n", .OMIT);
        text_buffer_insert(*document.buffer, *view.cursors, error, undo_modifier = .OMIT);
    }

    text_buffer_insert(*document.buffer, *view.cursors, tprint("\nCompilation exited after % seconds with code: %\n\n", to_float64_seconds(time_elapsed), exit_code), undo_modifier = .OMIT);
}

// TODO(jt): The user experience of this kind of sucks. The first C-l should always recenter. But
// then we need to remember if it is the first press.
recenter_panel :: (panel: *Panel, editor: Editor, input: Input, force_center := false, skip_interpolation := false) {
    if !panel {
        return;
    }

    y: f32;
    if #complete panel.view.kind == {
        case .DOCUMENT;  y = panel.view._document.cursors.c0.y * editor.font.line_height_in_pixels;
        case .LISTING;   y = panel.view._listing.item_index * editor.font.line_height_in_pixels;
    }

    top    := y;
    center := y - 0.5 * input.window_size.y;
    bottom := y - input.window_size.y + 3 * editor.font.line_height_in_pixels;

    if editor.mini_panel.open {
        center += 0.5 * MINI_PANEL_LINES * editor.font.line_height_in_pixels;
        bottom += MINI_PANEL_LINES * editor.font.line_height_in_pixels;
    }

    target: DVector2;
    target.x = panel.scroll.target.x;

    if force_center {
        target.y = center;
    } else if panel.scroll.target.y == center {
        target.y = top;
    } else if panel.scroll.target.y == top {
        target.y = bottom;
    } else {
        target.y = center;
    }

    target.y = max(target.y, 0);

    if skip_interpolation {
        interpolation_init(*panel.scroll, target);
    } else {
        interpolation_start(*panel.scroll, panel.scroll.value, target, input.time, PANEL_SCROLL_DURATION);
    }
}

scroll_panel_up_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    // -2 for mode line and message line
    delta := cast(s64, floor(input.window_size.y / cell_h) - 2 - PANEL_SCROLL_PADDING_CELLS_Y);

    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            text_buffer_move_cursor_y(view.document.buffer, *view.cursors, -delta, view.selecting);

            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
        }
        case .LISTING; {
            view := *panel.view._listing;
            view.item_index = clamp(view.item_index - delta, 0, view.listing.items.count - 1);

            view.flags |= .CLAMP_SCROLL_TO_ITEM_INDEX;
        }
    }
}

scroll_panel_down_one_screen :: (panel: *Panel, input: Input, cell_h: f32) {
    // -2 for mode line and message line
    delta := cast(s64, floor(input.window_size.y / cell_h) - 2 - PANEL_SCROLL_PADDING_CELLS_Y);

    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;
            text_buffer_move_cursor_y(view.document.buffer, *view.cursors, delta, view.selecting);

            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
        }
        case .LISTING; {
            view := *panel.view._listing;
            view.item_index = clamp(view.item_index + delta, 0, view.listing.items.count - 1);

            view.flags |= .CLAMP_SCROLL_TO_ITEM_INDEX;
        }
    }
}

// TODO(jt): @Memory Calling multiple of these get_xyz_at_cursor getters is wasteful, as each one
// makes their own view of the buffer, iterates the line, etc. We could do some fusion here, if it
// shows up on profiles.

get_position_at_cursor :: (view: Document_View, font: Font) -> DVector2 {
    document := view.document;
    if !document {
        return { 0, 0 };
    }

    position := get_position_for_location(document, font, view.cursors.c0);

    return position;
}

get_line_length_at_cursor :: (view: Document_View, font: Font) -> f64 {
    document := view.document;
    if !document {
        0;
    }

    line_length := get_line_length_for_line_index(document, font, view.cursors.c0.y);

    return line_length;
}

get_position_for_location :: (document: Document, font: Font, loc: Text_Location) -> DVector2 {
    line_view := text_buffer_make_view_for_line(document.buffer, loc.y,, temp);

    position: DVector2;
    position.x = font_compute_position_on_line(font, line_view, loc.x, binary = document.buffer.binary_mode);
    position.y = cast(f64, loc.y) * font.line_height_in_pixels;

    return position;
}

get_line_length_for_line_index :: (document: Document, font: Font, line_index: s64) -> f64 {
    line_view   := text_buffer_make_view_for_line(document.buffer, line_index,, temp);
    line_length := font_compute_line_length(font, line_view, binary = document.buffer.binary_mode);

    return line_length;
}

canonicalize_path :: (path: *string) {
    String.path_overwrite_separators(path.*, "/");
    path.* = String.trim_right(path.*, "/");
}

#scope_file

draw_rect :: (render_commands: *[..] Render_Command, x0: f32, y0: f32, x1: f32, y1: f32, color: Vector4 = { 1, 1, 1, 1 }, texture := TEXTURE_ID_NONE) {
    inline draw_rect(render_commands, { x0, y0, x1, y1 }, color, texture);
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

// These arena sizes are upper bounds for each category, so that we don't make a 16GB reservation for everything.
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

WELCOME :: #string DONE




    Welcome to the untitled text editor!

DONE;
