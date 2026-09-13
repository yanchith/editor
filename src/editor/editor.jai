/*

TODO(jt): Known bugs:

- Windows: file watching sometimes loops infinitely? we modify a file and keep getting events about it.
- Clicking on an item in a listing scrolls/selects the resulting document immediately after clicking.

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
- [~] Messages ; Still need to do a messages view
- [X] Modeline
- [X] Keymap support
- [X] Find/replace and modal/interactive commands.
- [X] Open non-utf8 text buffers and binary files.
- [X] Flash cursor with typing (needs tuning)
- [X] Syntax Highlighting
- [X] Mode defined parentheses (surround, autoclose)
- [X] Matching parentheses highlight
- [X] Syntax aware indentation (C-i)
- [X] Watch opened files for changes on disk
- [~] Panel tiling ; Needs a few more features? 4-split/N-split, moving split boundaries
- [X] FreeType subpixel rendering
- [~] Directory Lister panel ; Needs a few more info like directory size, item type, etc.
- [X] *compilation* buffer
- [X] DIRECTORY_SEARCH
- [X] SHOW_COMMANDS (M-x)
- [X] Map-like zoom
- [X] Read-only mode for documents.
- [X] Selection in mini panel text buffer.
- [X] Selection in modal interaction text buffer.
- [X] COPY, CUT and PASTE in mini panel and modal interaction.
- [X] MOVE_TO_START and MOVE_TO_END in mini panel.
- [~] Create file in new directories (mkdirp) ; Needs to get absolute path of nonexistent directory on macOS!
- [X] Refresh lister
- [X] Delete file in lister
- [X] Click to open file in lister
- [X] Mode defined comments (C-x C-;) ; Still want to play with single-line block comments
- [X] Themes
- [X] Dark text color under bright rectangles (cursor, selection, line)
- [X] Rotated session logs
- [X] M-g g (go to line)
- [~] C-M-p, C-M-n (move line up/down) SWAP_LINE_UP/SWAP_LINE_DOWN ; Should also work for selections
- [X] M-d, M-<backspace> DELETE_FORWARD_WORD/DELETE_BACKWARD_WORD
- [X] C-j join-next-line
- [X] GO_TO_MATCHING_PAREN (forward/backward)? Maybe we want to go to start/end of current scope to be more flexible than Emacs?
- [X] Sticky cursor (navigate to the end of long line, move up/down to a shorter line, move back to the long line and cursor goes to its original place)
- [X] Reading tabs
- [X] Writintg tabs
- [X] Language: JAI
- [X] Language: C
- [~] Language: C++ ; Currently serviced by the C lexer
- [X] Language: GLSL
- [X] Reading and rendering CRLF
- [X] Disambiguate path prefixes in SWITCH_VIEW, CLOSE_VIEW, and modeline
- [X] Minimal config files (keybinds, theme, language file association)
- [X] Prettier modeline layout

... after alpha ...

- [ ] C-: or double-click (expand region)
- [ ] Triple click to select line. (expand to line)
- [ ] Speed improvements to scope parsing
- [ ] Speed improvements to lexing for syntax highlighting
- [ ] C-u C-<space> (cursor undo)
- [ ] M-q (reflow)
- [ ] M-u, M-l (upcase/downcase word and move cursor)
- [ ] q to hide compilation or listing
- [ ] Mouse interaction in the mini panel (text selection, item clicking, item hover?)
- [ ] Mouse interaction in the modal interaction (text selection)
- [ ] Mouse interaction in the mode line (click change view, lang, crlf, indentation level)
- [ ] SEARCH should highlight all matches in the current view, not just the first one on the line.
- [ ] OPEN_FILE_IN_PROJECT and SEARCH_IN_PROJECT should be (globally) configurable to ignore paths (e.g. contents of .git)
- [ ] Animate scrolling in mini panel.
- [ ] Animate opening of the mini panel.
- [ ] F11 fullscreen on Windows
- [ ] macOS packaging
- [ ] Linux build
- [ ] Load System fonts
- [ ] Multiple Cursors
- [ ] Language: HLSL
- [ ] Language: Slang
- [ ] Language: WGSL
- [ ] Language: Rust
- [ ] Language: Javascript
- [ ] Language: Typescript
- [ ] Language: C#
- [ ] Language: Odin
- [ ] Language: Lua
- [ ] Language: Java
- [ ] Language: Python
- [ ] Theme: Solarized Light
- [ ] Theme: Solarized Dark
- [ ] Theme: Visual Studio Dark
- [ ] Theme: Delphi
- [ ] Emacs-like kill ring
- [ ] Keep displaying (and updating) panel selection while SEARCH is active.
- [ ] Render subtle symbols for whitespace characters (space, tab, cr, lf)
- [ ] Support for dropping files into the window
- [ ] Pretty things: blinking cursor, cursor trail, ...
- [ ] Flash pasted text
- [ ] Flash text inserted by undo/redo
- [ ] Writing CRLF

... after beta ...

- [ ] 4coder-like poor man's hex mode - substitute binary for escaped hex codes (e.g. 255 -> /ff) during layout and position calculation.
- [ ] Hex mode view
- [ ] Proper projects (project config, compilations, search ignore list, find/replace)
- [ ] if (0) and #if 0 produce desaturated syntax highlighting
- [ ] Get rid of FreeType without compromising quality (kb_text_shape + Slug)
- [ ] Version control view (Git only?, via plugin interface?)
- [ ] 4coder style floating annotations? (e.g. name of the function or if statement expresion after closing brace)

*/

#module_parameters()(VERSION_MAJOR := 0, VERSION_MINOR := 0, VERSION_PATCH := 0, BUILD_TIMESTAMP := "unknown date", SANITY := false);

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena"(ENABLE_DEBUG = true, ENABLE_SANITY_ASSERTS = SANITY, DEFAULT_OVERWRITE_MEMORY = SANITY);
// TODO(jt): @Speed We could do a better job at the bucket array without complicating it too much by bitpacking
// the occupancy mask and having a freelist for insertion.
#import "Bucket_Array";
#import "Hash_Table";
#import "Profiler";

String  :: #import "String";
Math    :: #import "Math";
Unicode :: #import "Unicode";

S64_MAX        :: Math.S64_MAX;
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
#load "sort.jai";
#load "hash.jai";
#load "array.jai";
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
#load "line_search.jai";
#load "color.jai";
#load "theme.jai";
#load "scope.jai";
#load "lexer.jai";
#load "lang_c.jai";
#load "lang_jai.jai";
#load "lang_glsl.jai";
#load "mini_panel_search.jai";
#load "mini_panel_search_in_project.jai";
#load "mini_panel_open_file.jai";
#load "mini_panel_open_file_in_project.jai";
#load "mini_panel_switch_view.jai";
#load "mini_panel_close_view.jai";
#load "mini_panel_show_commands.jai";
#load "modal_interaction_search_and_replace.jai";
#load "modal_interaction_go_to_line.jai";
#load "modal_interaction_compile.jai";
#load "modal_interaction_benchgen.jai";
#load "config.jai";

TEXTURE_ID_NONE:                 Texture_ID : 0; // Not really used, just a 0 default.
TEXTURE_ID_GLYPH_ATLAS:          Texture_ID : 1;
TEXTURE_ID_GLYPH_ATLAS_SUBPIXEL: Texture_ID : 2;

FILE_WATCH_POLL_PERIOD:  Apollo_Time : #run milliseconds_to_apollo(5000); // The maximum amount of time after which the polling fallback for file detection happens.
FILE_WATCH_BLIND_WINDOW: Apollo_Time : #run milliseconds_to_apollo(250);  // The amount of time we for which we disregard reported changes for a directory after a write.

UNDO_AUTOFUSE_PERIOD: Apollo_Time : #run milliseconds_to_apollo(500);

HIGHLIGHT_CUTOFF_SIZE:   s64 : 10 << 20;
INDENTATION_CUTOFF_SIZE: s64 : 10 << 20;

INDENTATION_STEP :: 4; // Also controls tab width. TODO(jt): Make this configurable (also per project). :Config

GUTTER_PIXELS :: 20.0; // TODO(jt): Make this configurable. :Config

PANEL_SCROLL_PADDING_CELLS_X :: 5;    // TODO(jt): Make this configurable. :Config
PANEL_SCROLL_PADDING_CELLS_Y :: 5;    // TODO(jt): Make this configurable. :Config

MINI_PANEL_LINES :: 10;   // TODO(jt): Make this configurable. :Config

STRIP_TRAILING_WHITESPACE_ON_SAVE :: true; // TODO(jt): Make this configurable. :Config

PANEL_SCROLL_DURATION:                  f32 : 0.15; // TODO(jt): Make this configurable. :Config
CURSOR_FLASH_DURATION:                  f32 : 0.50; // TODO(jt): Make flash time configurable. :Config
CURSOR_ANIM_DURATION_KEYBOARD_DIRECT:   f32 : 0.00; // TODO(jt): Make keyboard anim time configurable. :Config
CURSOR_ANIM_DURATION_KEYBOARD_INDIRECT: f32 : 0.15; // TODO(jt): Make keyboard anim time configurable. :Config
CURSOR_ANIM_DURATION_MOUSE:             f32 : 0.15; // TODO(jt): Make mouse anim time configurable. :Config

THIN_CURSOR_WIDTH:          f32 : 2;
THIN_CURSOR_WIDTH_INACTIVE: f32 : 1;

// TODO(jt): Make fonts configurable. :Config
FONT_LINE_HEIGHT_MULTIPLIER: f32 : 1.2;
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

    arenas: [..] *Arena; // Used for memory debug view.

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

    project_directories: [..] string;

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

    debug_view: Debug_View;
    debug_view_state: Debug_View_State;

    DEBUG_FRAME_PROFILE_COUNT: s64 : 256;
    debug_frame_profiles: *Frame_Profiles;
    debug_frame_profile_index: s64;

    DEBUG_FRAME_TIMELINE_COUNT: s64 : 128;
    debug_frame_timeline: *Frame_Timeline;
    debug_frame_timeline_index: s64;

    Debug_View :: enum u8 {
        NONE;
        ATLAS_TEXTURE;
        MEMORY_ABSOLUTE;
        MEMORY_RELATIVE;
        FRAME_PROFILE;
        FRAME_TIMELINE;
    };

    Debug_View_State :: struct {
        data: [64] u8;

        #overlay (data) _frame_profile: Frame_Profile_State;

        Frame_Profile_State :: struct {
            index: s64;
            paused: bool;
        }
    }

    Frame_Profiles :: struct {
        entries: [DEBUG_FRAME_PROFILE_COUNT] Frame_Profile_Entry;
    }

    Frame_Profile_Entry :: struct {
        zones:       [] Profiler_Zone;
        zone_labels: [] string;
        time_scale:  f64;
    }

    Frame_Timeline :: struct {
        entries: [DEBUG_FRAME_TIMELINE_COUNT] Frame_Timeline_Entry;
    }

    Frame_Timeline_Entry :: struct {
        time_start:  Apollo_Time;
        time_render: Apollo_Time;
        time_end:    Apollo_Time;
    }
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
    lang: Lang;
    flags: Flags;
    time_of_last_activation: Apollo_Time;
    time_of_last_simple_edit: Apollo_Time; // Insert by typing characters or delete forward/backward.

    cursors_cold: Text_Cursors; // Used to restore cursors in panel view, if the document was in the background. Otherwise, the view's cursors take precedence.
    buffer: Text_Buffer;

    arena: *Arena; // For scopes, tokens, compilation_args, compilation_errors, backing_file_directory, backing_file_path...

    backing_directory_path: string; // In canonical format (see canonicalize_path).

    // Newly created documents (and scratch documents) do not have a backing file until saved, at
    // which point a backing file path is assigned and file created. A document with a
    // backing_file_path can also be created without the file already existing.
    backing_file_path: string; // In canonical format (see canonicalize_path).
    backing_file_exists: bool;

    backing_file_time_of_last_save: Apollo_Time; // Used to filter out modifications from the filesystem done by us.
    backing_file_time_of_last_sync: Apollo_Time;

    backing_file_last_synced_modification_time: Apollo_Time;
    backing_file_last_synced_size: s64;
    backing_file_last_synced_hash: u64;

    scopes: [..] Scope; // For indentation, parentheses matching, navigation.
    tokens: [..] Token; // For syntax highlighting. Sparse!

    // Compilation fields are empty if this is not a .COMPILATION document.
    compilation_args:   string;
    compilation_errors: [..] Compilation_Error;
    compilation_error_index: s64;

    Kind :: enum u32 {
        SCRATCH;
        COMPILATION;
        FILE;
    }

    Lang :: enum u32 {
        TEXT;
        C;
        JAI;
        GLSL;
    }

    Flags :: enum_flags u32 {
        NONE :: 0;

        MODIFIED                  :: 0x01; // Also see backing_file_exists

        // TODO(jt): @Cleanup These should live on Document_View?
        MODIFIED_THIS_FRAME       :: 0x02;
        MODIFY_ATTEMPT_THIS_FRAME :: 0x04;

        // INCONSISTENT_INDENTATION  0x04;
        // INCONSISTENT_NEWLINES     0x08;

        READONLY_BY_NATURE                      :: 0x10;
        READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT :: 0x20;
        READONLY_BECAUSE_OF_MANUAL_LOCK         :: 0x40;

        READONLY :: READONLY_BY_NATURE | READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT | READONLY_BECAUSE_OF_MANUAL_LOCK;

        // These get set during event processing and unset after update for this document's panel is done.
        TRANSIENT :: MODIFIED_THIS_FRAME | MODIFY_ATTEMPT_THIS_FRAME;
    }

    Compilation_Error :: struct {
        x0: s64;
        x1: s64;
        y: s64;

        line_number: s64;
        column_number: s64;
        path: string;
    }
}

// TODO(jt): Rename to Directory_Listing and remove kind?
Listing :: struct {
    locator: Bucket_Locator;

    kind: Kind;
    time_of_last_activation: Apollo_Time;

    arena: *Arena; // For backing_directory_path, items and item text.
    arena_base_data_mark: Arena_Mark;

    backing_directory_path: string; // In canonical format (see canonicalize_path).

    items: [..] Item;
    item_index_cold: s64; // Used to restore item_index in panel view, if the listing was in the background. Otherwise, the view's item_index takes precedence.

    // TODO(jt): @Speed @Memory Should use Bit_Array here, but I think we'd need to make our own that can resize and stuff.
    marked_items: Table(s64, void);

    Kind :: enum u32 {
        DIRECTORY;
        // TODO(jt): Add VIEWS (unified) ... this is basically entitities.
        // TODO(jt): Add SEARCH_RESULTS?
        // TODO(jt): Add COMPILATION_ERRORS?
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

    key_map: Key_Map(Modal_Interaction_Action);

    cursors: Text_Cursors;
    selecting: bool;

    buffer: Text_Buffer;

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
Modal_Interaction_Init_Proc            :: #type (editor: *Editor, platform: Platform, input: Input, params: *void);
Modal_Interaction_Handle_Event_Proc    :: #type (editor: *Editor, event: Input_Event, platform: Platform, input: Input) -> handled: bool;
Modal_Interaction_Advance_Proc         :: #type (editor: *Editor, platform: Platform, input: Input);
Modal_Interaction_Cancel_Proc          :: #type (editor: *Editor, platform: Platform, input: Input);

init :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) {
    ProfileZone("Editor.init");

    // Delay attaching debug procs to perm, because the list of arenas itself is going to be in perm.
    // So we add it to the list manually and attach procs after.
    editor.perm_arena = make_arena(editor, platform, .MEDIUM, "Perm", attach_debug_procs = false);
    editor.arenas.allocator = arena_allocator(editor.perm_arena);
    array_add(*editor.arenas, editor.perm_arena);
    editor.perm_arena.debug_procs = make_arena_debug_procs(editor);

    editor.debug_frame_profiles = arena_push(editor.perm_arena, Editor.Frame_Profiles);
    {
        count := profiler_get_zone_count();
        if count {
            for * editor.debug_frame_profiles.entries {
                it.zones       = arena_push_array(editor.perm_arena, Profiler_Zone, count);
                it.zone_labels = arena_push_array(editor.perm_arena, string, count);
            }
        }
    }
    editor.debug_frame_timeline = arena_push(editor.perm_arena, Editor.Frame_Timeline);

    //
    // Init font
    //
    {
        font_arena     := make_arena(editor, platform, .MEDIUM, "Font");
        font_allocator := arena_allocator(font_arena);

        font_path :: (name: string, type: string) -> string #expand {
            return tprint("%1/fonts/%2/%2-%3.ttf", input.data_path, name, type);
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
        editor.font = make_font(font_arena, ttf_regular, ttf_bold, ttf_italic, ttf_bold_italic, TEXTURE_ID_GLYPH_ATLAS, want_pixel_height, FONT_LINE_HEIGHT_MULTIPLIER, true);
    }

    input_state_update_on_frame_start(*editor.input_state, input);
    for input.events {
        input_state_update_with_event(*editor.input_state, it);
    }

    editor.panel_key_map.allocator = arena_allocator(editor.perm_arena);
    editor.document_key_map.allocator = arena_allocator(editor.perm_arena);
    editor.compilation_key_map.allocator = arena_allocator(editor.perm_arena);
    editor.listing_key_map.allocator = arena_allocator(editor.perm_arena);

    key_map_reserve(*editor.panel_key_map, 128);
    key_map_reserve(*editor.document_key_map, 128);
    key_map_reserve(*editor.compilation_key_map, 128);
    key_map_reserve(*editor.listing_key_map, 128);

    editor.theme = abulafia_theme(); // In case config doesn't load.

    editor.watched_files.allocator = arena_allocator(editor.perm_arena);

    editor.documents.allocator     = arena_allocator(editor.perm_arena);
    editor.listings.allocator      = arena_allocator(editor.perm_arena);
    editor.panels.allocator        = arena_allocator(editor.perm_arena);

    editor.project_directories.allocator = arena_allocator(editor.perm_arena);

    // Create *scratch* document
    {
        success, working_directory := platform.get_absolute_path(".",, temp);
        if !success {
            working_directory = "";
        }

        canonicalize_path(*working_directory);

        scratch_document := find_or_add_document(editor, platform, .SCRATCH, working_directory, "");

        text_buffer_insert(*scratch_document.buffer, *scratch_document.cursors_cold, WELCOME, .OMIT);
        text_buffer_move_to(scratch_document.buffer, *scratch_document.cursors_cold, 0, 0, false);

        // Create first panel.
        panel := array_add(*editor.panels);
        panel_init_with_document(panel, editor, platform, scratch_document);

        update_scopes(scratch_document);
    }

    //
    // Init mini panel
    //
    {
        mini_panel := *editor.mini_panel;

        mini_panel.key_map.allocator = arena_allocator(editor.perm_arena);
        key_map_reserve(*mini_panel.key_map, 128);

        // Mini text buffer gets its own arena, because it survives longer than the items.
        text_buffer_init(*mini_panel.buffer, make_arena(editor, platform, .SMALL, "Minipanel Buffer"));

        mini_panel.items_arena = make_arena(editor, platform, .LARGE, "Minipanel Items");
        mini_panel.items.allocator = arena_allocator(mini_panel.items_arena);

        mini_panel.userdata_arena = make_arena(editor, platform, .SMALL, "Minipanel Userdata");
    }

    //
    // Init modal interaction
    //
    {
        modal_interaction := *editor.modal_interaction;

        modal_interaction.key_map.allocator = arena_allocator(editor.perm_arena);
        key_map_reserve(*editor.modal_interaction.key_map, 128);

        // Modal text buffer gets its own arena, because it survives longer than the items.
        text_buffer_init(*modal_interaction.buffer, make_arena(editor, platform, .SMALL, "Modal Buffer"));

        modal_interaction.userdata_arena = make_arena(editor, platform, .SMALL, "Modal Userdata");
    }

    editor.messages.allocator = arena_allocator(editor.perm_arena);

    {
        renderer.create_texture_r8unorm(
            TEXTURE_ID_GLYPH_ATLAS,
            editor.font.glyph_atlas,
            editor.font.glyph_atlas_width_in_pixels,
            editor.font.glyph_atlas_height_in_pixels,
            .LINEAR,
        );
    }

    {
        atlas: [] u8;
        atlas.count = editor.font.glyph_atlas_subpixel.count * 4;
        atlas.data  = cast(*u8, editor.font.glyph_atlas_subpixel.data);

        renderer.create_texture_rgba8unorm(
            TEXTURE_ID_GLYPH_ATLAS_SUBPIXEL,
            atlas,
            editor.font.glyph_atlas_width_in_pixels,
            editor.font.glyph_atlas_height_in_pixels,
            .NEAREST,
        );
    }

    editor.is_first_frame = true;

    load_config(editor, platform, input, fall_back_to_emergency_config = true);
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> wants_this_frame: bool, wants_next_frame: bool {
    ProfileZone("Editor.update_and_render");

    mark_frame_timeline_point(editor, platform, input, .START);
    mark_frame_profile(editor, input);

    dt: f64;
    if input.frame_requested_by_editor {
        dt = to_float64_seconds(input.dtime);
    } else {
        // No way to tell delta if we were sleeping.
        dt = 1.0 / input.monitor_refresh_rate;
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
        input.window_scale_factor != editor.input_state.window_scale_factor ||
        input.frame_requested_by_editor ||
        input.mouse_wheel_delta != 0 ||
        input.watched_directory_changes.count > 0 ||
        input.events.count > 0;

    // TODO(jt): @Cleanup @Hack Our Simp/OpenGL rendering backend has some render target synchronization issue.
    // After we resize the window, it clears and draws to the old surface on the first frame after resize.
    // We just poll the next frame here, so people don't notice. We really need a better rendering backend.
    //
    // wants_next_frame := false;
    wants_next_frame := input.window_size != editor.input_state.window_size ||
        input.window_scale_factor != editor.input_state.window_scale_factor;

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
                // modification done by someone else, we'll discover it in the fallback.
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

    for input.events {
        input_state_update_with_event(*editor.input_state, it);
        if it.flags & .PRESSED {
            if !(it.flags & .REPEAT) {
                editor.last_message_seen = true;
            }
        }

        if editor.mini_panel.open {
            route_event_to_mini_panel(editor, it, platform, input);
        } else if editor.modal_interaction.open {
            route_event_to_modal_interaction(editor, it, platform, input);
        } else {
            route_event_to_panel(editor, it, platform, input);
        }
    }

    if editor.debug_view != .NONE {
        wants_this_frame = true;
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
            font_reset_for_options(*editor.font, pixel_height, FONT_LINE_HEIGHT_MULTIPLIER, editor.font.subpixel);
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

    font_new_frame(*editor.font);

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

            invert_ranges: [..] Font_Invert_Range;
            invert_ranges.allocator = temp;

            if mini_panel.item_index == -1 {
                draw_rect(*render_commands, mini_panel_x0, mini_panel_y, mini_panel_x1, mini_panel_y + cell_h, editor.theme.mini_panel_line_color);
                if editor.theme.invert_color_under_selected_mini_panel_line {
                    invert_range := array_add(*invert_ranges);
                    invert_range.x0 = 0;
                    invert_range.x1 = S64_MAX; // @Hack We want to invert the whole line anyway.
                }
            }

            action_text := mini_panel.procs.get_action_text(editor, platform, input);

            line_view := text_buffer_make_view_for_line(mini_panel.buffer, 0,, temp);

            line_x    := _font_compute_line_length(editor.font, action_text, binary = false);
            cursor0_x := line_x + _font_compute_position_on_line(editor.font, line_view, mini_panel.cursors.c0.x, binary = false);
            cursor1_x := line_x + _font_compute_position_on_line(editor.font, line_view, mini_panel.cursors.c1.x, binary = false);

            cursor_w := cell_w;
            if editor.theme.cursor_style == .THIN {
                w  := round(THIN_CURSOR_WIDTH * editor.input_state.window_scale_factor);
                hw := round(0.5 * w);

                cursor_w = w;
                cursor0_x -= hw;
            }

            draw_rect(*render_commands,
                      mini_panel_x0 + cast(f32, cursor0_x), mini_panel_y,
                      mini_panel_x0 + cast(f32, cursor1_x), mini_panel_y + cell_h,
                      editor.theme.selection_color);
            draw_rect(*render_commands,
                      mini_panel_x0 + cast(f32, cursor0_x), mini_panel_y,
                      mini_panel_x0 + cast(f32, cursor0_x) + cursor_w, mini_panel_y + cell_h,
                      editor.theme.cursor_color);

            if editor.theme.invert_color_under_selection && mini_panel.item_index != -1 {
                c0 := mini_panel.cursors.c0;
                c1 := mini_panel.cursors.c1;
                text_location_sort(*c0, *c1);

                action_text_length := count_utf8_chars(action_text);

                invert_range := array_add(*invert_ranges);
                invert_range.x0 = action_text_length + c0.x;
                invert_range.x1 = action_text_length + c1.x;
            }

            main_line := tprint("%%", action_text, line_view);

            scissor := Rect.{ mini_panel_x0, mini_panel_y, mini_panel_x1, window_h };
            _font_layout_and_draw_text(*editor.font, main_line,
                                       *render_commands, *atlas_update_regions,
                                       { mini_panel_x0, mini_panel_y }, scissor,
                                       editor.theme.text_color, editor.theme.text_variant,
                                       .[], invert_ranges,
                                       binary = false);

            index0 := max(mini_panel.item_index - (MINI_PANEL_LINES / 2), 0);
            index1 := min(index0 + MINI_PANEL_LINES, mini_panel.items.count - 1);

            it_index := 0;
            for index0..index1 {
                item := *mini_panel.items[it];

                invert_ranges: [..] Font_Invert_Range;
                invert_ranges.allocator = temp;

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

                    if editor.theme.invert_color_under_selected_mini_panel_line {
                        invert_range := array_add(*invert_ranges);
                        invert_range.x0 = 0;
                        invert_range.x1 = S64_MAX; // @Hack We want to invert the whole line anyway.
                    }
                }

                offset_y: f64 = mini_panel_y + (it_index + 1) * cell_h;
                color := editor.theme.mini_panel_item_text_color;
                if item.flags & .WARNING {
                    color = editor.theme.mini_panel_item_warning_text_color;
                }

                font_layout_and_draw_text(*editor.font, item.text,
                                          *render_commands, *atlas_update_regions,
                                          { mini_panel_x0, offset_y }, scissor,
                                          color, .REGULAR,
                                          .[], invert_ranges,
                                          binary = cast(bool, item.flags & .BINARY));

                it_index += 1;
            }
        } else if editor.modal_interaction.open {
            modal_interaction := *editor.modal_interaction;

            modal_interaction_line_x0 := GUTTER_PIXELS;
            modal_interaction_line_x1 := window_w - GUTTER_PIXELS;
            modal_interaction_line_y := window_h - cell_h;
            draw_rect(*render_commands, modal_interaction_line_x0, modal_interaction_line_y, modal_interaction_line_x1, window_h, editor.theme.background_color);

            invert_ranges: [..] Font_Invert_Range;
            invert_ranges.allocator = temp;

            action_text := modal_interaction.procs.get_action_text(editor, platform, input);

            line_view := text_buffer_make_view_for_line(modal_interaction.buffer, 0,, temp);

            line_x    := _font_compute_line_length(editor.font, action_text, binary = false);
            cursor0_x := line_x + _font_compute_position_on_line(editor.font, line_view, editor.modal_interaction.cursors.c0.x, binary = false);
            cursor1_x := line_x + _font_compute_position_on_line(editor.font, line_view, editor.modal_interaction.cursors.c1.x, binary = false);

            cursor_w := cell_w;
            if editor.theme.cursor_style == .THIN {
                w  := round(THIN_CURSOR_WIDTH * editor.input_state.window_scale_factor);
                hw := round(0.5 * w);

                cursor_w = w;
                cursor0_x -= hw;
            }

            draw_rect(*render_commands,
                      modal_interaction_line_x0 + cast(f32, cursor0_x), modal_interaction_line_y,
                      modal_interaction_line_x0 + cast(f32, cursor1_x), modal_interaction_line_y + cell_h,
                      editor.theme.selection_color);
            draw_rect(*render_commands,
                      modal_interaction_line_x0 + cast(f32, cursor0_x), modal_interaction_line_y,
                      modal_interaction_line_x0 + cast(f32, cursor0_x) + cursor_w, modal_interaction_line_y + cell_h,
                      editor.theme.cursor_color);

            if editor.theme.invert_color_under_selection {
                c0 := modal_interaction.cursors.c0;
                c1 := modal_interaction.cursors.c1;
                text_location_sort(*c0, *c1);

                action_text_length := count_utf8_chars(action_text);

                invert_range := array_add(*invert_ranges);
                invert_range.x0 = action_text_length + c0.x;
                invert_range.x1 = action_text_length + c1.x;
            }

            main_line := tprint("%%", action_text, line_view);

            offset  := DVector2.{ modal_interaction_line_x0, modal_interaction_line_y };
            scissor := Rect.{ modal_interaction_line_x0, modal_interaction_line_y, modal_interaction_line_x1, window_h };

            _font_layout_and_draw_text(*editor.font, main_line,
                                       *render_commands, *atlas_update_regions,
                                       offset, scissor,
                                       editor.theme.text_color, .REGULAR,
                                       .[], invert_ranges,
                                       binary = false);
        } else {
            message_line_y := window_h - cell_h;
            message_line_x0 := GUTTER_PIXELS;
            message_line_x1 := window_w - GUTTER_PIXELS;

            draw_rect(*render_commands, message_line_x0, message_line_y, window_w, window_h, editor.theme.background_color);

            if editor.messages.count && !editor.last_message_seen {
                message := editor.messages[editor.messages.count - 1];

                offset  := DVector2.{ message_line_x0, message_line_y };
                scissor := Rect.{ message_line_x0, message_line_y, message_line_x1, window_h };
                _font_layout_and_draw_text(*editor.font, message,
                                           *render_commands, *atlas_update_regions,
                                           offset, scissor,
                                           editor.theme.text_color, .REGULAR,
                                           .[], .[],
                                           binary = false);
            }
        }

        if editor.font.glyph_cache_overrun {
            log_error("Glyph cache was overrun this frame. Rendering is going to be incorrect. Increase the size of the glyph cache, if this happens.");
        }
    }

    if editor.debug_view != .NONE {
        window_w := cast(f32, input.window_size.x);
        window_h := cast(f32, input.window_size.y);

        draw_rect(*render_commands, 0, 0, window_w, window_h, { 0, 0, 0, 0.5 });

        if editor.debug_view == {
            case .ATLAS_TEXTURE; {
                message := "Debug view: Font Atlas";
                scissor := Rect.{ 0, 0, window_w, window_h };
                _font_layout_and_draw_text(*editor.font, message,
                                           *render_commands, *atlas_update_regions,
                                           { 0, 0 }, scissor,
                                           { 1, 1, 1, 1 }, .REGULAR,
                                           .[], .[],
                                           binary = false);

                atlas_w := cast(f32, editor.font.glyph_atlas_width_in_pixels);
                atlas_h := cast(f32, editor.font.glyph_atlas_height_in_pixels);
                atlas_x := ifx window_w > atlas_w then 0.5 * window_w - 0.5 * atlas_w else 0.0;
                atlas_y := ifx window_h > atlas_h then 0.5 * window_h - 0.5 * atlas_h else 0.0;

                draw_rect(*render_commands, atlas_x, atlas_y, atlas_x + atlas_w, atlas_y + atlas_h, { 0, 0, 0, 1 });
                if editor.font.subpixel {
                    command := array_add(*render_commands);
                    command.type = .DRAW_TEXT_SUBPIXEL;
                    command.rect = { atlas_x, atlas_y, atlas_x + atlas_w, atlas_y + atlas_h };
                    command.texture_rect = { 0, 0, 1, 1 };
                    command.texture_id   = TEXTURE_ID_GLYPH_ATLAS_SUBPIXEL;
                    command.color        = { 1, 1, 1, 1 };
                } else {
                    command := array_add(*render_commands);
                    command.type = .DRAW_TEXT;
                    command.rect = { atlas_x, atlas_y, atlas_x + atlas_w, atlas_y + atlas_h };
                    command.texture_rect = { 0, 0, 1, 1 };
                    command.texture_id   = TEXTURE_ID_GLYPH_ATLAS;
                    command.color        = { 1, 1, 1, 1 };
                }
            }

            case .MEMORY_ABSOLUTE; #through;
            case .MEMORY_RELATIVE; {
                format_size :: (n: s64) -> /* Temporary_Storage */ string {
                    if n > (1 << 30) {
                        n = n >> 30;
                        return tprint("% GB", n);
                    } else if n > (1 << 20) {
                        n = n >> 20;
                        return tprint("% MB", n);
                    } else if n > (1 << 10) {
                        n = n >> 10;
                        return tprint("% KB", n);
                    } else {
                        return tprint("% B", n);
                    }
                }

                compare_size     :: (a: *Arena) -> f32 { return -cast(f32, a.allocated); }
                compare_fullness :: (a: *Arena) -> f32 { return -cast(f32, a.allocated) / cast(f32, a.reserve_size); }

                if editor.debug_view == {
                    case .MEMORY_ABSOLUTE;  bubble_sort(editor.arenas, compare_size);
                    case .MEMORY_RELATIVE;  bubble_sort(editor.arenas, compare_fullness);
                }

                scissor := Rect.{ 0, 0, window_w, window_h };
                {
                    message: string;
                    if editor.debug_view == {
                        case .MEMORY_ABSOLUTE;  message = "Debug view: Memory (absolute)";
                        case .MEMORY_RELATIVE;  message = "Debug view: Memory (relative)";
                    }

                    _font_layout_and_draw_text(*editor.font, message,
                                               *render_commands, *atlas_update_regions,
                                               { 0, 0 }, scissor,
                                               { 1, 1, 1, 1 }, .REGULAR,
                                               .[], .[],
                                               binary = false);
                }

                y := 2 * cell_h;

                PADDING_X :: 20.0;
                PADDING_Y :: 2.0;
                graph_x := 0.5 * window_w + PADDING_X;
                graph_w := max(0.5 * window_w - 2 * PADDING_X, 0);

                {
                    ts := context.temporary_storage;

                    total     := ts.high_water_mark;
                    allocated := ts.total_bytes_occupied; // TODO(jt): This is not true. Figure out how to get current size of Temporary_Storage.

                    message := tprint("% % / %", temp_right_pad("Temp", 45), format_size(allocated), format_size(total));
                    offset  := DVector2.{ 0, y };
                    _font_layout_and_draw_text(*editor.font, message,
                                               *render_commands, *atlas_update_regions,
                                               offset, scissor,
                                               { 1, 1, 1, 1 }, .REGULAR,
                                               .[], .[],
                                               binary = false);

                    arena_max_size := ifx editor.debug_view == .MEMORY_ABSOLUTE then cast(f32, Arena_Size.LARGE) else cast(f32, total);

                    t_total     := cast(f32, total) / arena_max_size;
                    t_allocated := cast(f32, allocated) / arena_max_size;

                    x0 := graph_x;
                    x1 := x0 + graph_w;
                    x_total     := x0 + t_total * graph_w;
                    x_allocated := x0 + t_allocated * graph_w;

                    y0 := y + PADDING_Y;
                    y1 := y + cell_h;

                    draw_rect(*render_commands, x0, y0, x1, y1, { 0.2, 0.2, 0.2, 1 });
                    draw_rect(*render_commands, x0, y0, x_total, y1, { 0.7, 0.7, 0.7, 1 });
                    draw_rect(*render_commands, x0, y0, x_allocated, y1, { 0, 1, 0, 1 });

                    y += cell_h;
                }

                for editor.arenas {
                    total     := it.reserve_size;
                    committed := it.committed;
                    allocated := it.allocated;

                    message := tprint("% % / % / %", temp_right_pad(it.debug_label, 45), format_size(allocated), format_size(committed), format_size(total));
                    offset  := DVector2.{ 0, y };
                    _font_layout_and_draw_text(*editor.font, message,
                                               *render_commands, *atlas_update_regions,
                                               offset, scissor,
                                               { 1, 1, 1, 1 }, .REGULAR,
                                               .[], .[],
                                               binary = false);

                    arena_max_size := ifx editor.debug_view == .MEMORY_ABSOLUTE then cast(f32, Arena_Size.LARGE) else cast(f32, total);

                    t_total     := cast(f32, total) / arena_max_size;
                    t_committed := cast(f32, committed) / arena_max_size;
                    t_allocated := cast(f32, allocated) / arena_max_size;

                    x0 := graph_x;
                    x1 := x0 + graph_w;
                    x_total     := x0 + t_total * graph_w;
                    x_committed := x0 + t_committed * graph_w;
                    x_allocated := x0 + t_allocated * graph_w;

                    y0 := y + PADDING_Y;
                    y1 := y + cell_h;

                    draw_rect(*render_commands, x0, y0, x1, y1, { 0.2, 0.2, 0.2, 1 });
                    draw_rect(*render_commands, x0, y0, x_total, y1, { 0.7, 0.7, 0.7, 1 });
                    draw_rect(*render_commands, x0, y0, x_committed, y1, { 0, 0, 1, 1 });
                    draw_rect(*render_commands, x0, y0, x_allocated, y1, { 0, 1, 0, 1 });

                    y += cell_h;
                }
            }

            case .FRAME_PROFILE; {
                message := "Debug view: Frame profile";
                scissor := Rect.{ 0, 0, window_w, window_h };
                _font_layout_and_draw_text(*editor.font, message,
                                           *render_commands, *atlas_update_regions,
                                           { 0, 0 }, scissor,
                                           { 1, 1, 1, 1 }, .REGULAR,
                                           .[], .[],
                                           binary = false);

                state := *editor.debug_view_state._frame_profile;

                if profiler_get_zone_count() {
                    last_frame_index := (editor.debug_frame_profile_index - 1) & (editor.DEBUG_FRAME_PROFILE_COUNT - 1);

                    if editor.input_state.keys[Key.ARROW_LEFT] & .PRESSED {
                        if !state.paused {
                            state.index = editor.debug_frame_profile_index;
                        }

                        state.index -= 1;
                        state.index &= editor.DEBUG_FRAME_PROFILE_COUNT - 1;
                        state.paused = true;
                    }

                    if editor.input_state.keys[Key.ARROW_RIGHT] & .PRESSED {
                        if !state.paused {
                            state.index = editor.debug_frame_profile_index;
                        }

                        state.index += 1;
                        state.index &= editor.DEBUG_FRAME_PROFILE_COUNT - 1;
                        state.paused = true;
                    }

                    if editor.input_state.keys[Key.ARROW_UP] & .PRESSED {
                        state.paused = false;
                    }

                    PADDING_X :: 20.0;
                    REGULAR_BAR_HEIGHT   :: 150.0;
                    EXCEEDING_BAR_HEIGHT :: 350.0;
                    R_COUNT :: 1.0 / editor.DEBUG_FRAME_PROFILE_COUNT;

                    graph_width := max(window_w - 2 * PADDING_X, 0);
                    bar_y       := 2 * cell_h;
                    bar_width   := graph_width / editor.DEBUG_FRAME_PROFILE_COUNT - 2.0;
                    desired_frame_time: f64 = 1.0 / input.monitor_refresh_rate;

                    displayed_frame_index := last_frame_index;
                    if state.paused {
                        displayed_frame_index = state.index;
                    }

                    for profile, profile_index: editor.debug_frame_profiles.entries {
                        time_scale := profile.time_scale;
                        zone0      := *profile.zones[0];

                        frame_time := time_scale * zone0.elapsed_inclusive;
                        th := frame_time / desired_frame_time;
                        h  := cast(f32, th * REGULAR_BAR_HEIGHT);

                        tx := profile_index * R_COUNT;
                        x := PADDING_X + tx * graph_width;

                        color: Vector4 = { 0.7, 0.7, 0.7, 1 };
                        if profile_index == displayed_frame_index {
                            color = { 1, 1, 1, 1 };
                        }

                        draw_rect(*render_commands, x, bar_y, x + bar_width, bar_y + h, color);
                    }

                    {
                        profile    := *editor.debug_frame_profiles.entries[displayed_frame_index];
                        time_scale := profile.time_scale;
                        cursor_y := 0;
                        for zone, zone_index: profile.zones {
                            s := tprint("% %      %     %     %",
                                        temp_right_pad(tprint("[%]", zone_index), 5),
                                        temp_right_pad(profile.zone_labels[zone_index], 50),
                                        formatInt(zone.hits, minimum_digits = 15, padding = #char " "),
                                        formatFloat(1000 * time_scale * zone.elapsed_inclusive, width = 15, trailing_width = 3),
                                        formatFloat(1000 * time_scale * zone.elapsed_exclusive, width = 15, trailing_width = 3));

                            y := bar_y + EXCEEDING_BAR_HEIGHT + zone_index * cell_h;
                            _font_layout_and_draw_text(*editor.font, s,
                                                       *render_commands, *atlas_update_regions,
                                                       { 0, y }, scissor,
                                                       { 1, 1, 1, 1 }, .REGULAR,
                                                       .[], .[],
                                                       binary = false);
                        }
                    }
                } else {
                    _font_layout_and_draw_text(*editor.font, "(Profiling info unavailable)",
                                               *render_commands, *atlas_update_regions,
                                               { 0, 3 * cell_h }, scissor,
                                               { 1, 1, 1, 1 }, .REGULAR,
                                               .[], .[],
                                               binary = false);
                }
            }

            case .FRAME_TIMELINE; {
                message := tprint("Debug view: Frame timeline (blue=update; red=render+VSync; white=refresh(%), informative only)", input.monitor_refresh_rate);
                scissor := Rect.{ 0, 0, window_w, window_h };
                _font_layout_and_draw_text(*editor.font, message,
                                           *render_commands, *atlas_update_regions,
                                           { 0, 0 }, scissor,
                                           { 1, 1, 1, 1 }, .REGULAR,
                                           .[], .[],
                                           binary = false);


                TIMELINE_WINDOW_SECONDS: f64 : 1.0;
                PADDING_X :: 20.0;

                graph_width := max(window_w - 2 * PADDING_X, 0);

                {
                    desired_frame_time: f64 = 1.0 / input.monitor_refresh_rate;

                    time: f64 = to_float64_seconds(input.time);
                    while time > (to_float64_seconds(input.time) - TIMELINE_WINDOW_SECONDS) {
                        t := 1.0 - (to_float64_seconds(input.time) - time) / TIMELINE_WINDOW_SECONDS;
                        x := cast(f32, PADDING_X + t * graph_width);

                        draw_rect(*render_commands, x, 100.0, x + 1, 200.0, { 1, 1, 1, 1 });

                        time -= desired_frame_time;
                    }
                }

                for editor.debug_frame_timeline.entries {
                    if it_index == editor.debug_frame_timeline_index {
                        continue; // This is the current frame. It is not yet finalized.
                    }

                    t_start  := 1.0 - to_float64_seconds(input.time - it.time_start) / TIMELINE_WINDOW_SECONDS;
                    t_render := 1.0 - to_float64_seconds(input.time - it.time_render) / TIMELINE_WINDOW_SECONDS;
                    t_end    := 1.0 - to_float64_seconds(input.time - it.time_end) / TIMELINE_WINDOW_SECONDS;
                    x_start  := cast(f32, PADDING_X + t_start * graph_width);
                    x_render := cast(f32, PADDING_X + t_render * graph_width);
                    x_end    := cast(f32, PADDING_X + t_end * graph_width);

                    draw_rect(*render_commands, x_start, 200.0, x_render, 300.0, { 0, 0, 1, 1 });
                    draw_rect(*render_commands, x_render, 300.0, x_end + 2.0, 400.0, { 1, 0, 0, 1 });
                }
            }
        }
    }

    // Only send things to the GPU, if we have to output this frame. In theory, both render_commands
    // and atlas_update_regions should be empty, but there could be mistakes.
    //
    // See :BatterySaver.
    mark_frame_timeline_point(editor, platform, input, .RENDER);

    if wants_this_frame {
        if atlas_update_regions.count {
            atlas_update_region := irect_union_or_zero(atlas_update_regions);
            if editor.font.subpixel {
                atlas: [] u8;
                atlas.count = editor.font.glyph_atlas_subpixel.count * 4;
                atlas.data  = cast(*u8, editor.font.glyph_atlas_subpixel.data);

                renderer.update_texture_rgba8unorm(TEXTURE_ID_GLYPH_ATLAS, atlas, atlas_update_region);
            } else {
                renderer.update_texture_r8unorm(TEXTURE_ID_GLYPH_ATLAS, editor.font.glyph_atlas, atlas_update_region);
            }
        }

        renderer.begin_frame(editor.theme.background_color);
        renderer.draw(render_commands);
        renderer.submit_frame();
    }

    mark_frame_timeline_point(editor, platform, input, .END);

    editor.is_first_frame = false;

    return wants_this_frame, wants_next_frame;
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

touch_panel :: (panel: *Panel, time: Apollo_Time) {
    if #complete panel.view.kind == {
        case .DOCUMENT;  panel.view._document.document.time_of_last_activation = time;
        case .LISTING;   panel.view._listing.listing.time_of_last_activation = time;
    }
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

get_document_lang :: (document: Document) -> string {
    if #complete document.lang == {
        case .TEXT;  return "Text";
        case .C;     return "C";
        case .JAI;   return "Jai";
        case .GLSL;  return "GLSL";
    }
}

get_document_name :: (editor: Editor, document: Document) -> string {
    if #complete document.kind == {
        case .SCRATCH;      return "*scratch*";
        case .COMPILATION;  return "*compilation*";
        case .FILE; {
            name_parts := 1;
            name       := String.path_filename(document.backing_file_path);

            // TODO(jt): @Speed This is slow, and it doesn't help that we also call get_document_name in a loop. Do better!
            for editor.documents {
                if it.kind != .FILE                continue;
                if it.locator == document.locator  continue;

                it_name, it_name_parts := path_trailing_parts(it.backing_file_path, name_parts);

                while name != document.backing_file_path && it_name != it.backing_file_path && it_name_parts == name_parts && it_name == name {
                    name, name_parts = path_trailing_parts(document.backing_file_path, name_parts + 1);
                    it_name, it_name_parts = path_trailing_parts(it.backing_file_path, name_parts);
                }
            }

            return name;
        }
    }
}

get_listing_name :: (editor: Editor, listing: Listing) -> string {
    if #complete listing.kind == {
        case .DIRECTORY; {
            name_parts := 1;
            name       := String.path_filename(listing.backing_directory_path);
            if name.count == 0 {
                name = listing.backing_directory_path;
            } else {
                // TODO(jt): @Speed This is slow, and it doesn't help that we also call get_listing_name in a loop. Do better!
                for editor.listings {
                    if it.kind != .DIRECTORY          continue;
                    if it.locator == listing.locator  continue;

                    it_name, it_name_parts := path_trailing_parts(it.backing_directory_path, name_parts);

                    while name != listing.backing_directory_path && it_name != it.backing_directory_path && it_name_parts == name_parts && it_name == name {
                        name, name_parts = path_trailing_parts(listing.backing_directory_path, name_parts + 1);
                        it_name, it_name_parts = path_trailing_parts(it.backing_directory_path, name_parts);
                    }
                }
            }

            return name;
        }
    }
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
                                                        editor.theme.cursor_color_hot, editor.theme.cursor_color_readonly,
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
                        text_buffer_move_to(document.buffer, *document.cursors_cold, cursor_before_reload, false);

                        update_scopes(document);
                        document_update_tokens(document);

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

route_event_to_mini_panel :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    mp := *editor.mini_panel;

    min_item_index := ifx mp.procs.can_select_text_line(editor, platform, input) then -1 else 0;

    buffer_changed := false;
    old_item_index := mp.item_index;

    buffered, action := key_map_input(*mp.key_map, event);
    if action == {
        case .MOVE_UP;                 mp.item_index = clamp(mp.item_index - 1, min_item_index, mp.items.count - 1);
        case .MOVE_DOWN;               mp.item_index = clamp(mp.item_index + 1, min_item_index, mp.items.count - 1);
        case .MOVE_BACKWARD;           text_buffer_move_x(mp.buffer, *mp.cursors, -1, mp.selecting);
        case .MOVE_FORWARD;            text_buffer_move_x(mp.buffer, *mp.cursors,  1, mp.selecting);

        case .MOVE_TO_START_OF_LINE;   text_buffer_move_to_start_of_line(mp.buffer, *mp.cursors, mp.selecting);
        case .MOVE_TO_END_OF_LINE;     text_buffer_move_to_end_of_line(mp.buffer, *mp.cursors, mp.selecting);

        case .MOVE_TO_START;           mp.item_index = 0; // Not -1, even if the particular procs support it.
        case .MOVE_TO_END;             mp.item_index = max(mp.items.count - 1, 0);

        case .MOVE_FORWARD_WORD;       text_buffer_move_to_next_word_boundary(mp.buffer, *mp.cursors, mp.selecting);
        case .MOVE_BACKWARD_WORD;      text_buffer_move_to_previous_word_boundary(mp.buffer, *mp.cursors, mp.selecting);

        case .MOVE_UP_ONE_SCREEN;      mp.item_index = clamp(mp.item_index - MINI_PANEL_LINES, min_item_index, mp.items.count - 1);
        case .MOVE_DOWN_ONE_SCREEN;    mp.item_index = clamp(mp.item_index + MINI_PANEL_LINES, min_item_index, mp.items.count - 1);

        case .DELETE_FORWARD;          text_buffer_delete_forward(*mp.buffer, *mp.cursors, 1); buffer_changed = true;
        case .DELETE_BACKWARD;         buffer_changed |= mp.procs.delete_backward(editor, platform, input);
        case .DELETE_FORWARD_WORD; {
            deleted := text_buffer_delete_forward_word(*mp.buffer, *mp.cursors);
            if deleted.count {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }
        case .DELETE_BACKWARD_WORD; {
            deleted := text_buffer_delete_backward_word(*mp.buffer, *mp.cursors);
            if deleted.count {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }

        case .START_SELECTING;         mp.selecting = true; text_cursors_join(*mp.cursors);

        case .INDENT_OR_AUTOCOMPLETE;  buffer_changed |= mp.procs.autocomplete(editor, platform, input);

        case .COPY; {
            mp.selecting = false;
            text := text_buffer_make_view_for_interval(mp.buffer, mp.cursors.c0, mp.cursors.c1,, temp);
            if text {
                platform.set_clipboard_text(text);
            }

            text_cursors_join(*mp.cursors);
        }
        case .CUT; {
            mp.selecting = false;
            deleted := text_buffer_delete_selection(*mp.buffer, *mp.cursors, .NONE);
            if deleted.count {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }
        case .PASTE; {
            mp.selecting = false;
            text := platform.get_clipboard_text(,, temp);
            if text.count {
                buffer_changed |= text_buffer_insert(*mp.buffer, *mp.cursors, text, .NONE);
            }
        }

        case .CONFIRM;                 buffer_changed |= mp.procs.confirm(editor, platform, input);
        case .CANCEL_OR_STOP_SELECTING; {
            if mp.selecting {
                text_cursors_join(*mp.cursors);
                mp.selecting = false;
            } else {
                mp.procs.cancel(editor, platform, input);
            }
        }
    }

    // TODO(jt): Animated cursor in mini panel
    // TODO(jt): Do animated horizontal scroll of buffer in mini panel.
    // TODO(jt): Do animated vertical scroll of item list in mini panel.
    if !buffered
    && action == .NONE && event.flags & .PRESSED
    && !(event.modifiers & (.CTRL | .ALT | .META))
    && event.type == .CODEPOINT
    && (event.codepoint >= 32 || event.codepoint == .TAB)
    && event.codepoint != .DELETE
    {
        char := cast(u32, event.codepoint);
        buffer_changed |= text_buffer_insert_char(*mp.buffer, *mp.cursors, char);
    }

    if mp.open {
        // TODO(jt): @Speed In case we'll be processing multiple events this frame, we want to delay
        // calling this until they have all been processed. Otherwise we'll be doing expensive stuff
        // multiple times per frame. Maybe we need to move this one level up and track the dirty
        // flags on the mini panel itself?
        mp.procs.update(editor, platform, input, buffer_changed, mp.item_index != old_item_index);
    }
}

route_event_to_modal_interaction :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) {
    mi := *editor.modal_interaction;

    if mi.procs.handle_event(editor, event, platform, input) {
        return;
    }

    buffer_changed := false;

    buffered, action := key_map_input(*mi.key_map, event);
    if action == {
        case .MOVE_BACKWARD;           text_buffer_move_x(mi.buffer, *mi.cursors, -1, mi.selecting);
        case .MOVE_FORWARD;            text_buffer_move_x(mi.buffer, *mi.cursors,  1, mi.selecting);

        case .MOVE_TO_START_OF_LINE;   text_buffer_move_to_start_of_line(mi.buffer, *mi.cursors, mi.selecting);
        case .MOVE_TO_END_OF_LINE;     text_buffer_move_to_end_of_line(mi.buffer, *mi.cursors, mi.selecting);

        case .MOVE_FORWARD_WORD;       text_buffer_move_to_next_word_boundary(mi.buffer, *mi.cursors, mi.selecting);
        case .MOVE_BACKWARD_WORD;      text_buffer_move_to_previous_word_boundary(mi.buffer, *mi.cursors, mi.selecting);

        case .DELETE_FORWARD;          text_buffer_delete_forward(*mi.buffer, *mi.cursors, 1); buffer_changed = true;
        case .DELETE_BACKWARD;         text_buffer_delete_backward(*mi.buffer, *mi.cursors); buffer_changed = true;
        case .DELETE_FORWARD_WORD; {
            deleted := text_buffer_delete_forward_word(*mi.buffer, *mi.cursors);
            if deleted.count {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }
        case .DELETE_BACKWARD_WORD; {
            deleted := text_buffer_delete_backward_word(*mi.buffer, *mi.cursors);
            if deleted.count {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }

        case .START_SELECTING;         mi.selecting = true; text_cursors_join(*mi.cursors);

        case .INDENT_OR_AUTOCOMPLETE;  // No-op for now.

        case .COPY; {
            mi.selecting = false;
            text := text_buffer_make_view_for_interval(mi.buffer, mi.cursors.c0, mi.cursors.c1,, temp);
            if text {
                platform.set_clipboard_text(text);
            }

            text_cursors_join(*mi.cursors);
        }
        case .CUT; {
            mi.selecting = false;
            deleted := text_buffer_delete_selection(*mi.buffer, *mi.cursors, .NONE);
            if deleted.count {
                buffer_changed = true;
                platform.set_clipboard_text(deleted);
            }
        }
        case .PASTE; {
            mi.selecting = false;
            text := platform.get_clipboard_text(,, temp);
            if text.count {
                buffer_changed |= text_buffer_insert(*mi.buffer, *mi.cursors, text, .NONE);
            }
        }

        case .CONFIRM;                 mi.procs.advance(editor, platform, input);
        case .CANCEL_OR_STOP_SELECTING; {
            if mi.selecting {
                text_cursors_join(*mi.cursors);
                mi.selecting = false;
            } else {
                mi.procs.cancel(editor, platform, input);
            }
        }
    }

    // TODO(jt): Animated cursor in modal interaction
    if !buffered
    && action == .NONE
    && event.flags & .PRESSED
    && !(event.modifiers & (.CTRL | .ALT | .META))
    && event.type == .CODEPOINT
    && (event.codepoint >= 32 || event.codepoint == .TAB)
    && event.codepoint != .DELETE
    {
        char := cast(u32, event.codepoint);
        buffer_changed |= text_buffer_insert_char(*mi.buffer, *mi.cursors, char);
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
    GO_TO_OTHER_PANEL;

    OPEN_FILE_IN_PROJECT;
    SEARCH_IN_PROJECT;
    COMPILE_IN_PROJECT_OR_DIRECTORY;
    COMPILE_IN_DIRECTORY;

    // Things below could be in Global_Action, if we ever create it.

    FONT_SIZE_INCREASE;
    FONT_SIZE_DECREASE;
    FONT_SUBPIXEL_RENDERING_ENABLE;
    FONT_SUBPIXEL_RENDERING_DISABLE;

    THEME_ABULAFIA;
    THEME_NAYSAYER;
    THEME_HANDMADE;
    THEME_STB;
    THEME_ZENBURN;
    THEME_VISUAL_STUDIO_LIGHT;

    RELOAD_CONFIG;

    DEBUG_VIEW_ATLAS_TEXTURE;
    DEBUG_VIEW_MEMORY_ABSOLUTE;
    DEBUG_VIEW_MEMORY_RELATIVE;
    DEBUG_VIEW_FRAME_PROFILE;
    DEBUG_VIEW_FRAME_TIMELINE;
}

Document_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_BACKWARD;
    MOVE_FORWARD;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_TO_START;
    MOVE_TO_END;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    MOVE_TO_PREVIOUS_BLANK_LINE;
    MOVE_TO_NEXT_BLANK_LINE;

    MOVE_TO_START_OF_SCOPE;
    MOVE_TO_END_OF_SCOPE;

    SEARCH_AND_REPLACE;

    SAVE_DOCUMENT;
    RELOAD_DOCUMENT;

    SWAP_LINE_UP;
    SWAP_LINE_DOWN;

    GO_TO_LINE;

    START_SELECTING;
    STOP_SELECTING;

    DELETE_FORWARD;
    DELETE_BACKWARD;

    DELETE_FORWARD_WORD;
    DELETE_BACKWARD_WORD;

    DELETE_LINE;
    JOIN_NEXT_LINE;

    INSERT_LINE_BEFORE;
    INSERT_LINE_AFTER;

    INDENT_OR_AUTOCOMPLETE;

    TOGGLE_COMMENT;

    UNDO_EDIT;
    REDO_EDIT;

    COPY;
    CUT;
    PASTE;

    TOGGLE_READONLY;

    STRIP_TRAILING_WHITESPACE;

    LANGUAGE_TEXT;
    LANGUAGE_C;
    LANGUAGE_JAI;
    LANGUAGE_GLSL;

    DEBUG_PRINT_BYTE_AT_CURSOR;
    DEBUG_INSERT_BENCHMARK_TEXT;
}

Compilation_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_BACKWARD;
    MOVE_FORWARD;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_TO_START;
    MOVE_TO_END;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    MOVE_TO_PREVIOUS_ERROR;
    MOVE_TO_NEXT_ERROR;

    START_SELECTING;
    STOP_SELECTING;

    COPY;

    GO_TO_CURRENT_ERROR;

    REFRESH;

    DEBUG_BYTE_AT_CURSOR;
}

Listing_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;

    OPEN;
    OPEN_IN_OTHER_PANEL;

    MARK_ITEM;
    UNMARK_ITEM;

    DELETE_MARKED_ITEMS;

    REFRESH;

    ADD_PROJECT_DIRECTORY;
    REMOVE_PROJECT_DIRECTORY;
}

Mini_Panel_Action :: enum {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_BACKWARD;
    MOVE_FORWARD;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_TO_START;
    MOVE_TO_END;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    MOVE_UP_ONE_SCREEN;
    MOVE_DOWN_ONE_SCREEN;

    DELETE_FORWARD;
    DELETE_BACKWARD;
    DELETE_FORWARD_WORD;
    DELETE_BACKWARD_WORD;

    START_SELECTING;

    INDENT_OR_AUTOCOMPLETE;

    COPY;
    CUT;
    PASTE;

    CONFIRM;
    CANCEL_OR_STOP_SELECTING;
}

Modal_Interaction_Action :: enum {
    NONE;

    MOVE_BACKWARD;
    MOVE_FORWARD;

    MOVE_TO_START_OF_LINE;
    MOVE_TO_END_OF_LINE;

    MOVE_FORWARD_WORD;
    MOVE_BACKWARD_WORD;

    DELETE_FORWARD;
    DELETE_BACKWARD;
    DELETE_FORWARD_WORD;
    DELETE_BACKWARD_WORD;

    START_SELECTING;

    INDENT_OR_AUTOCOMPLETE;

    COPY;
    CUT;
    PASTE;

    CONFIRM;
    CANCEL_OR_STOP_SELECTING;
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
        buffered, action   := key_map_input(*editor.panel_key_map, event);
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
                buffered, action   := key_map_input(*editor.compilation_key_map, event);
                did_buffer_event   |= buffered;
                did_execute_action |= execute_compilation_action(editor, platform, input, panel, view, document, action);
            } else {
                buffered, action   := key_map_input(*editor.document_key_map, event);
                did_buffer_event   |= buffered;
                did_execute_action |= execute_document_action(editor, platform, input, panel, view, document, action);
            }

            // TODO(jt): @Bug This is what our indentation does. I actually like it, but people will expect something else?
            if !did_buffer_event
            && !did_execute_action && event.flags & .PRESSED
            && !(event.modifiers & (.CTRL | .ALT | .META))
            && event.type == .CODEPOINT
            && (event.codepoint >= 32 || event.codepoint == .TAB)
            && event.codepoint != .DELETE
            {
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
                                    text_buffer_move_x(document.buffer, *view.cursors, 1, false);
                                    handled = true;
                                }
                            }
                        } else {
                            // Surrounding selection never cares for unbalanced parentheses
                            c0 := view.cursors.c0;
                            c1 := view.cursors.c1;
                            text_location_sort(*c0, *c1);

                            text_cursors_join(*view.cursors);

                            text_buffer_move_to(document.buffer, *view.cursors, c0, false);
                            text_buffer_insert_char(*document.buffer, *view.cursors, paired_char, .NONE);

                            c1.x += 1; // Because we just inserted the starting paren.
                            text_buffer_move_to(document.buffer, *view.cursors, c1, false);
                            text_buffer_insert_char(*document.buffer, *view.cursors, char, .FUSE);

                            handled = true;
                        }
                    }

                    if opens && !handled {
                        if view.cursors.c0 == view.cursors.c1 {
                            text_buffer_insert_char(*document.buffer, *view.cursors, char, .NONE);
                            text_buffer_insert_char(*document.buffer, *view.cursors, paired_char, .FUSE);
                            text_buffer_move_x(document.buffer, *view.cursors, -1, false);

                            handled = true;
                        } else {
                            // Surrounding selection never cares for unbalanced parentheses
                            c0 := view.cursors.c0;
                            c1 := view.cursors.c1;
                            text_location_sort(*c0, *c1);

                            text_cursors_join(*view.cursors);

                            text_buffer_move_to(document.buffer, *view.cursors, c1, false);
                            text_buffer_insert_char(*document.buffer, *view.cursors, paired_char, .NONE);

                            text_buffer_move_to(document.buffer, *view.cursors, c0, false);
                            text_buffer_insert_char(*document.buffer, *view.cursors, char, .FUSE);

                            handled = true;
                        }
                    }

                    if !handled {
                        undo_modifier: Undo_Modifier = .NONE;
                        if input.time - document.time_of_last_simple_edit < UNDO_AUTOFUSE_PERIOD {
                            undo_modifier = .CAN_AUTOFUSE;
                        }

                        text_buffer_insert_char(*document.buffer, *view.cursors, char, undo_modifier);

                        document.time_of_last_simple_edit = input.time;
                    }

                    //
                    // The code below is a slightly modified copypaste from
                    // execute_documment_action, but here we know the cursor moved and buffer
                    // changed for sure.
                    //

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
                    update_scopes(document);
                }
            }
        }

        case .LISTING; {
            view := *panel.view._listing;

            listing := view.listing;
            if !listing {
                return;
            }

            buffered, action   := key_map_input(*editor.listing_key_map, event);
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

                newly_active_panel := *editor.panels[editor.full_view_panel_index];
                touch_panel(newly_active_panel, input.time);
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

                newly_active_panel := *editor.panels[editor.full_view_panel_index];
                touch_panel(newly_active_panel, input.time);
            }
        }
        case .GO_TO_OTHER_PANEL; {
            if #complete editor.active_view == {
                case .FULL; // No-op
                case .LEFT; {
                    editor.active_view = .RIGHT;

                    newly_active_panel := *editor.panels[editor.right_view_panel_index];
                    touch_panel(newly_active_panel, input.time);
                }
                case .RIGHT; {
                    editor.active_view = .LEFT;

                    newly_active_panel := *editor.panels[editor.left_view_panel_index];
                    touch_panel(newly_active_panel, input.time);
                }
            }
        }

        case .OPEN_FILE_IN_PROJECT;             open_mini_panel(editor, platform, input, mini_panel_open_file_in_project_procs);
        case .SEARCH_IN_PROJECT;                open_mini_panel(editor, platform, input, mini_panel_search_in_project_procs);
        case .COMPILE_IN_PROJECT_OR_DIRECTORY;  open_modal_interaction(editor, platform, input, modal_interaction_compile_procs, cast(*void, Modal_Interaction_Compile_Mode.PROJECT_OR_DIRECTORY));
        case .COMPILE_IN_DIRECTORY;             open_modal_interaction(editor, platform, input, modal_interaction_compile_procs, cast(*void, Modal_Interaction_Compile_Mode.DIRECTORY));

        case .FONT_SIZE_INCREASE;               editor.font_size += 1;
        case .FONT_SIZE_DECREASE;               editor.font_size = max(editor.font_size - 1, 1);
        case .FONT_SUBPIXEL_RENDERING_ENABLE;   font_reset_for_options(*editor.font, editor.font.pixel_height, editor.font.line_height_multiplier, true); editor_log(editor, "Subpixel rendering on");
        case .FONT_SUBPIXEL_RENDERING_DISABLE;  font_reset_for_options(*editor.font, editor.font.pixel_height, editor.font.line_height_multiplier, false); editor_log(editor, "Subpixel rendering off");

        case .THEME_ABULAFIA;                   change_theme(editor, "abulafia");
        case .THEME_NAYSAYER;                   change_theme(editor, "naysayer");
        case .THEME_HANDMADE;                   change_theme(editor, "handmade");
        case .THEME_STB;                        change_theme(editor, "stb");
        case .THEME_ZENBURN;                    change_theme(editor, "zenburn");
        case .THEME_VISUAL_STUDIO_LIGHT;        change_theme(editor, "visual_studio_light");

        case .RELOAD_CONFIG;                    load_config(editor, platform, input, fall_back_to_emergency_config = false);

        case .DEBUG_VIEW_ATLAS_TEXTURE;         toggle_debug_view(editor, .ATLAS_TEXTURE);
        case .DEBUG_VIEW_MEMORY_ABSOLUTE;       toggle_debug_view(editor, .MEMORY_ABSOLUTE);
        case .DEBUG_VIEW_MEMORY_RELATIVE;       toggle_debug_view(editor, .MEMORY_RELATIVE);
        case .DEBUG_VIEW_FRAME_PROFILE;         toggle_debug_view(editor, .FRAME_PROFILE);
        case .DEBUG_VIEW_FRAME_TIMELINE;        toggle_debug_view(editor, .FRAME_TIMELINE);
    }

    //
    // Careful, even though we get a valid panel as an argument in this function, the things we do here (e.g. CLOSE_CURRENT_PANEL)
    // can destroy it. Don't assume it is still valid down here.
    //

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
            cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_DOWN; {
            cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_BACKWARD; {
            cursor_moved |= text_buffer_move_x(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_FORWARD; {
            cursor_moved |= text_buffer_move_x(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }

        case .MOVE_TO_START_OF_LINE;  cursor_moved |= text_buffer_move_to_start_of_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END_OF_LINE;    cursor_moved |= text_buffer_move_to_end_of_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_START;          cursor_moved |= text_buffer_move_to_start(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END;            cursor_moved |= text_buffer_move_to_end(document.buffer, *view.cursors, view.selecting);

        case .MOVE_FORWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_to_next_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_START_OF_LINE;
            }
        }
        case .MOVE_BACKWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_to_previous_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_END_OF_LINE;
            }
        }

        case .MOVE_TO_PREVIOUS_BLANK_LINE;  cursor_moved |= text_buffer_move_to_previous_blank_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_NEXT_BLANK_LINE;      cursor_moved |= text_buffer_move_to_next_blank_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_START_OF_SCOPE; {
            scope := find_scope_for_location(document, view.cursors.c0);
            if scope {
                text_buffer_move_to(document.buffer, *view.cursors, scope.loc0, view.selecting);
                cursor_moved = true;
            }
        }
        case .MOVE_TO_END_OF_SCOPE; {
            scope := find_scope_for_location(document, view.cursors.c0);
            if scope {
                text_buffer_move_to(document.buffer, *view.cursors, scope.loc1, view.selecting);
                cursor_moved = true;
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

                    ensure_directory(editor, platform, document.backing_directory_path);

                    gap_buffer_move_gap_to(*buffer.gb, 0);
                    contents := gap_buffer_make_view(buffer.gb, 0, buffer.gb.count, assert_no_allocations = true);
                    success := platform.write_file(document.backing_file_path, contents);
                    if success {
                        editor_log(editor, "Saved file %", document.backing_file_path);

                        document.flags &= ~.MODIFIED;
                        document.flags &= ~.READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT;

                        interpolation_start(*view.cursor_color,
                                            editor.theme.cursor_color_hot, editor.theme.cursor_color,
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
                    editor_log(editor, "(Already saved)");
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

                    original_cursor := view.cursors.c0;

                    view.cursors.c0 = { 0, 0 };
                    view.cursors.c1 = { 0, 0 };
                    text_buffer_reset(*document.buffer);

                    text_buffer_insert(*document.buffer, *view.cursors, file_contents, .OMIT);
                    text_buffer_move_to(document.buffer, *view.cursors, original_cursor, false);

                    document.flags &= ~.MODIFIED;
                    document.flags &= ~.READONLY_BECAUSE_OF_FILESYSTEM_CONFLICT;

                    interpolation_start(*view.cursor_color,
                                        editor.theme.cursor_color_hot, editor.theme.cursor_color,
                                        input.time, CURSOR_FLASH_DURATION);

                    update_scopes(document);
                    document_update_tokens(document);

                    editor_log(editor, "Reloaded file: %", document.backing_file_path);
                }
            }
        }

        case .SWAP_LINE_UP; {
            // TODO(jt): Implement version for moving selection.
            text_cursors_join(*view.cursors);
            if view.cursors.c0 == view.cursors.c1 && view.cursors.c0.y > 0 {
                original_cursor := view.cursors.c0;

                prev_start := text_buffer_get_start_of_line(document.buffer, view.cursors.c0.y - 1);
                prev_end   := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y - 1);
                prev       := text_buffer_make_view_for_interval(document.buffer, prev_start, prev_end, force_allocate = true,, temp);

                curr_start := text_buffer_get_start_of_line(document.buffer, view.cursors.c0.y);
                curr_end   := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y);
                curr       := text_buffer_make_view_for_interval(document.buffer, curr_start, curr_end, force_allocate = true,, temp);

                cursors := view.cursors;
                cursors.c0 = curr_start;
                cursors.c1 = curr_end;
                text_buffer_delete_selection(*document.buffer, *cursors, .NONE);

                cursors.c0 = prev_start;
                cursors.c1 = prev_end;
                text_buffer_delete_selection(*document.buffer, *cursors, .FUSE);
                text_buffer_insert(*document.buffer, *cursors, curr, .FUSE);

                cursors.c0 = curr_start;
                cursors.c1 = curr_start;
                text_buffer_insert(*document.buffer, *cursors, prev, .FUSE);

                // TODO(jt): Patch selection in undo so that we don't show it?

                original_cursor.y -= 1;

                view.cursors.c0 = original_cursor;
                view.cursors.c1 = original_cursor;

                buffer_changed = true;
            }
        }
        case .SWAP_LINE_DOWN; {
            // TODO(jt): Implement version for moving selection.
            text_cursors_join(*view.cursors);
            if view.cursors.c0.y < document.buffer.line_count - 1 {
                original_cursor := view.cursors.c0;

                curr_start := text_buffer_get_start_of_line(document.buffer, view.cursors.c0.y);
                curr_end   := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y);
                curr       := text_buffer_make_view_for_interval(document.buffer, curr_start, curr_end, force_allocate = true,, temp);

                next_start := text_buffer_get_start_of_line(document.buffer, view.cursors.c0.y + 1);
                next_end   := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y + 1);
                next       := text_buffer_make_view_for_interval(document.buffer, next_start, next_end, force_allocate = true,, temp);

                cursors := view.cursors;
                cursors.c0 = next_start;
                cursors.c1 = next_end;
                text_buffer_delete_selection(*document.buffer, *cursors, .NONE);

                cursors.c0 = curr_start;
                cursors.c1 = curr_end;
                text_buffer_delete_selection(*document.buffer, *cursors, .FUSE);
                text_buffer_insert(*document.buffer, *cursors, next, .FUSE);

                cursors.c0 = next_start;
                cursors.c1 = next_start;
                text_buffer_insert(*document.buffer, *cursors, curr, .FUSE);

                // TODO(jt): Patch selection in undo so that we don't show it?

                original_cursor.y += 1;

                view.cursors.c0 = original_cursor;
                view.cursors.c1 = original_cursor;

                buffer_changed = true;
            }
        }

        case .GO_TO_LINE;       open_modal_interaction(editor, platform, input, modal_interaction_go_to_line_procs);

        case .START_SELECTING;  view.selecting = true;  text_cursors_join(*view.cursors);
        case .STOP_SELECTING;   view.selecting = false; text_cursors_join(*view.cursors);

        case .DELETE_FORWARD; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                deleted := text_buffer_delete_forward(*document.buffer, *view.cursors, 1, .CAN_AUTOFUSE);
                buffer_changed |= deleted.count > 0;

                document.time_of_last_simple_edit = input.time;
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
                            deleted := text_buffer_delete_forward(*document.buffer, *view.cursors, 1, .NONE);
                            buffer_changed |= deleted.count > 0;
                            buffer_changed |= text_buffer_delete_backward(*document.buffer, *view.cursors, .FUSE);

                            handled = true;
                        }
                    }
                }

                if !handled {
                    view.selecting = false;
                    buffer_changed |= text_buffer_delete_backward(*document.buffer, *view.cursors, .CAN_AUTOFUSE);

                    document.time_of_last_simple_edit = input.time;
                }
            }
        }

        case .DELETE_FORWARD_WORD; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                deleted := text_buffer_delete_forward_word(*document.buffer, *view.cursors);
                if deleted.count {
                    buffer_changed = true;
                    platform.set_clipboard_text(deleted);
                }
            }
        }
        case .DELETE_BACKWARD_WORD; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                deleted := text_buffer_delete_backward_word(*document.buffer, *view.cursors);
                if deleted.count {
                    buffer_changed = true;
                    platform.set_clipboard_text(deleted);
                }
            }
        }

        case .DELETE_LINE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                deleted := text_buffer_delete_line(*document.buffer, *view.cursors);
                if deleted.count {
                    buffer_changed = true;
                    platform.set_clipboard_text(deleted);
                }
            }
        }
        case .JOIN_NEXT_LINE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                text_buffer_move_to_end_of_line(document.buffer, *view.cursors, false);

                deleted := text_buffer_delete_forward(*document.buffer, *view.cursors, 1, .NONE);
                cursors := view.cursors;

                if deleted.count {
                    text_buffer_insert(*document.buffer, *view.cursors, " ", .FUSE);
                    text_buffer_delete_indentation_forward(*document.buffer, *view.cursors, .FUSE);

                    view.cursors = cursors;
                    buffer_changed = true;
                }
            }
        }

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

                    cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors, -1, false);
                    if document.scopes.count {
                        update_scopes(document);

                        level := find_indentation_level_for_location(document, view.cursors.c0);
                        buffer_changed |= text_buffer_indent_line(*document.buffer, *view.cursors, level, .FUSE);
                    }
                    cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors, 1, false);
                }

                if document.scopes.count {
                    update_scopes(document);

                    level := find_indentation_level_for_location(document, view.cursors.c0);
                    buffer_changed |= text_buffer_indent_line(*document.buffer, *view.cursors, level, .FUSE);
                }

                if should_make_space_for_block {
                    cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors, -1, false);
                    cursor_moved |= text_buffer_move_to_end_of_line(document.buffer, *view.cursors, false);
                }
            }
        }
        case .INSERT_LINE_AFTER; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                // TODO(jt): Preserve CRLF in CRLF-only documents.
                view.selecting = false;
                buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, "\n", .NONE);
                cursor_moved   |= text_buffer_move_y(document.buffer, *view.cursors, -1, false);
                cursor_moved   |= text_buffer_move_to_end_of_line(document.buffer, *view.cursors, false);
            }
        }

        // TODO(jt): Preserve tabness in tab-only documents.
        case .INDENT_OR_AUTOCOMPLETE; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                if document.scopes.count {
                    view.selecting = false;

                    original_y0 := view.cursors.c0.y;
                    original_y1 := view.cursors.c1.y;
                    y0 := min(view.cursors.c0.y, view.cursors.c1.y);
                    y1 := max(view.cursors.c0.y, view.cursors.c1.y);

                    first := true;
                    for y0..y1 {
                        level := find_indentation_level_for_location(document, { 0, it });
                        text_buffer_move_to(document.buffer, *view.cursors, { 0, it }, false);
                        changed := text_buffer_indent_line(*document.buffer, *view.cursors, level, ifx first then .NONE else .FUSE);

                        if changed {
                            if it != y1 {
                                // Scopes will be updated at the bottom of this procedure anyway.
                                update_scopes(document);
                            }
                            first = false;
                        }

                        buffer_changed |= changed;
                    }

                    // Restore cursor's vertical position if the selection is backwards.
                    if original_y0 < original_y1 {
                        text_buffer_move_to(document.buffer, *view.cursors, view.cursors.c0.x, original_y0, false);
                    }
                } else {
                    if view.cursors.c0 == view.cursors.c1 {
                        spaces := temp_right_pad("", INDENTATION_STEP);
                        buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, spaces, .NONE);
                    }
                }
            }
        }

        // TODO(jt): @Bug This doesn't align the comment well across multiple lines.
        case .TOGGLE_COMMENT; {
            line_comment, block_comment_start, block_comment_end := document_get_comment_style(document);
            line_comment_length := count_utf8_chars(line_comment);

            line_comment_with_space := tprint("% ", line_comment);
            line_comment_with_space_length := line_comment_length + 1; // +1 okay, because space is ASCII.

            // TODO(jt): Preserve cursors and send them into the thing manually.
            if view.cursors.c0 == view.cursors.c1 || view.cursors.c0.x == 0 && view.cursors.c1.x == 0 {
                // 2 cases:
                // - Single line, and no selection on the line -> line comment
                // - Multi line, but both cursors have X at 0 -> multiple line comments
                if line_comment.count {
                    y0 := min(view.cursors.c0.y, view.cursors.c1.y);
                    y1 := max(view.cursors.c0.y, view.cursors.c1.y);

                    comments_action: enum { UNINITIALIZED; ADD; REMOVE; };
                    comments_add_at_level: s64;
                    {
                        // First line. Detect, whether we are adding or removing comments and do so for the first line.
                        // All operations pass .NONE undo modifier.
                        text_buffer_move_to(document.buffer, *view.cursors, 0, y0, false);
                        text_buffer_move_to_start_of_line(document.buffer, *view.cursors, false, .START_OF_TEXT);

                        line_end  := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y);
                        line_view := text_buffer_make_view_for_interval(document.buffer, view.cursors.c0, line_end,, temp);

                        if String.starts_with(line_view, line_comment_with_space) {
                            comments_action = .REMOVE;
                            text_buffer_delete_forward(*document.buffer, *view.cursors, line_comment_with_space_length, .NONE);
                        } else if String.starts_with(line_view, line_comment) {
                            comments_action = .REMOVE;
                            text_buffer_delete_forward(*document.buffer, *view.cursors, line_comment_length, .NONE);
                        } else  {
                            comments_action = .ADD;
                            comments_add_at_level = view.cursors.c0.x;
                            text_buffer_insert(*document.buffer, *view.cursors, line_comment_with_space, .NONE);
                        }
                    }

                    for y0 + 1..y1 {
                        // Subsequent lines. Do what we did ont the first line, but don't remove a comment if there is none.
                        // All operations pass .FUSE undo modifier.

                        text_buffer_move_to(document.buffer, *view.cursors, 0, it, false);
                        text_buffer_move_to_start_of_line(document.buffer, *view.cursors, false, .START_OF_TEXT);

                        if comments_action == .ADD {
                            if comments_add_at_level < view.cursors.c0.x {
                                text_buffer_move_to(document.buffer, *view.cursors, comments_add_at_level, it, false);
                            } else if comments_add_at_level > view.cursors.c0.x {
                                // We are before the comment level. If there is text on this line, tough luck.
                                // However, if the line is just short, we can indent it.
                                end := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y);
                                if view.cursors.c0 == end {
                                    // This should also move us to the right spot!
                                    text_buffer_indent_line(*document.buffer, *view.cursors, comments_add_at_level, .FUSE);
                                }
                            }

                            text_buffer_insert(*document.buffer, *view.cursors, line_comment_with_space, .FUSE);
                        } else if comments_action == .REMOVE {
                            line_end  := text_buffer_get_end_of_line(document.buffer, view.cursors.c0.y);
                            line_view := text_buffer_make_view_for_interval(document.buffer, view.cursors.c0, line_end,, temp);

                            if String.starts_with(line_view, line_comment_with_space) {
                                text_buffer_delete_forward(*document.buffer, *view.cursors, line_comment_with_space_length, .NONE);
                                comments_action = .REMOVE;
                            } else if String.starts_with(line_view, line_comment) {
                                text_buffer_delete_forward(*document.buffer, *view.cursors, line_comment_length, .NONE);
                                comments_action = .REMOVE;
                            }
                        }
                    }

                    if y0 == y1 {
                        moved := text_buffer_move_y(document.buffer, *view.cursors, 1, false);
                        if moved {
                            text_buffer_move_to_start_of_line(document.buffer, *view.cursors, false, .START_OF_TEXT);
                        }
                    } else {
                        text_buffer_move_to(document.buffer, *view.cursors, 0, y1, false);
                    }

                    buffer_changed = true;
                    view.selecting = false;
                } else {
                    editor_log(editor, "No line comment defined for language: %", get_document_lang(document));
                }
            } else if view.cursors.c0.y == view.cursors.c1.y {
                // TODO(jt): Add single line block comments (if we have a selection going)
            } else {
                // TODO(jt): Add multiline block comments.
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
            if text.count {
                platform.set_clipboard_text(text);
            }

            text_cursors_join(*view.cursors);
        }
        case .CUT; {
            document.flags |= .MODIFY_ATTEMPT_THIS_FRAME;
            if !(document.flags & .READONLY) {
                view.selecting = false;
                deleted := text_buffer_delete_selection(*document.buffer, *view.cursors, .NONE);
                if deleted.count {
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
                if text.count {
                    buffer_changed |= text_buffer_insert(*document.buffer, *view.cursors, text, .NONE);
                }
            }
        }

        // TODO(jt): @Bug Also traverse other panels to change the color, they can be visiting the same document.
        case .TOGGLE_READONLY; {
            if document.flags & .READONLY_BECAUSE_OF_MANUAL_LOCK {
                document.flags &= ~.READONLY_BECAUSE_OF_MANUAL_LOCK;
                if document.flags & .READONLY {
                    editor_log(editor, "% is now unlocked; however, it is still read-only for other reasons.", document.backing_file_path);
                } else {
                    interpolation_start(*view.cursor_color,
                                        editor.theme.cursor_color_hot, editor.theme.cursor_color,
                                        input.time, CURSOR_FLASH_DURATION);
                    editor_log(editor, "% is now unlocked", document.backing_file_path);
                }
            } else {
                document.flags |= .READONLY_BECAUSE_OF_MANUAL_LOCK;
                interpolation_start(*view.cursor_color,
                                    editor.theme.cursor_color_hot, editor.theme.cursor_color_readonly,
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

        case .LANGUAGE_TEXT;  document_change_lang(document, .TEXT);
        case .LANGUAGE_C;     document_change_lang(document, .C);
        case .LANGUAGE_JAI;   document_change_lang(document, .JAI);
        case .LANGUAGE_GLSL;  document_change_lang(document, .GLSL);

        case .DEBUG_PRINT_BYTE_AT_CURSOR; {
            if text_buffer_can_read_at_location(document.buffer, view.cursors.c0) {
                byte := text_buffer_get_byte_at_location(document.buffer, view.cursors.c0);
                editor_log(editor, "Byte at cursor: %", byte);
            } else {
                editor_log(editor, "Can't read at cursor");
            }
        }

        case .DEBUG_INSERT_BENCHMARK_TEXT; {
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
        view.flags |= .RECEIVED_DIRECT_KEYBOARD_INTERACTION;
        view.flags |= .CLAMP_SCROLL_TO_CURSOR;
    }

    if buffer_changed {
        document.flags |= .MODIFIED_THIS_FRAME;
        document.flags |= .MODIFIED;

        // We have to update these after every change, because the very next edit could be needing
        // this. We could start being smarter about this (e.g. by setting a specific dirty flag),
        // becuase not every subsequent action needs these up to date.  -jt, 22 July 2026.
        update_scopes(document);
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
            cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_DOWN; {
            cursor_moved |= text_buffer_move_y(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_BACKWARD; {
            cursor_moved |= text_buffer_move_x(document.buffer, *view.cursors, -1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }
        case .MOVE_FORWARD; {
            cursor_moved |= text_buffer_move_x(document.buffer, *view.cursors,  1, shift_selecting || view.selecting);
            view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            if shift_selecting {
                view.selecting = false;
            }
        }

        case .MOVE_TO_START_OF_LINE;        cursor_moved |= text_buffer_move_to_start_of_line(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END_OF_LINE;          cursor_moved |= text_buffer_move_to_end_of_line(document.buffer, *view.cursors, view.selecting);

        case .MOVE_TO_START;                cursor_moved |= text_buffer_move_to_start(document.buffer, *view.cursors, view.selecting);
        case .MOVE_TO_END;                  cursor_moved |= text_buffer_move_to_end(document.buffer, *view.cursors, view.selecting);

        case .MOVE_FORWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_to_next_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_START_OF_LINE;
            }
        }
        case .MOVE_BACKWARD_WORD; {
            cursor_moved=, cursor_y_moved := text_buffer_move_to_previous_word_boundary(document.buffer, *view.cursors, view.selecting);
            if cursor_y_moved {
                view.flags |= .CLAMP_SCROLL_TO_END_OF_LINE;
            }
        }

        case .MOVE_TO_PREVIOUS_ERROR; {
            if document.compilation_errors.count {
                document.compilation_error_index = clamp(document.compilation_error_index - 1, 0, document.compilation_errors.count - 1);
                ce := *document.compilation_errors[document.compilation_error_index];

                view.cursors.c0.x = ce.x0;
                view.cursors.c1.x = ce.x1;
                view.cursors.c0.y = ce.y;
                view.cursors.c1.y = ce.y;

                view.flags |= .CLAMP_SCROLL_TO_CURSOR;
            }
        }
        case .MOVE_TO_NEXT_ERROR; {
            if document.compilation_errors.count {
                document.compilation_error_index = clamp(document.compilation_error_index + 1, 0, document.compilation_errors.count - 1);

                ce := *document.compilation_errors[document.compilation_error_index];

                view.cursors.c0.x = ce.x0;
                view.cursors.c1.x = ce.x1;
                view.cursors.c0.y = ce.y;
                view.cursors.c1.y = ce.y;

                view.flags |= .CLAMP_SCROLL_TO_CURSOR;
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

        case .GO_TO_CURRENT_ERROR; {
            for document.compilation_errors {
                contains_y := it.y == view.cursors.c0.y;
                contains_x := it.x0 <= view.cursors.c0.x && it.x1 >= view.cursors.c0.x;
                if contains_y && contains_x {
                    open_in_panel := panel;
                    // TODO(jt): @Cleanup @Copypasta This is the same as OPEN_IN_OTHER_PANEL (also see cleanup comment there).
                    // Also, creating a compilation buffer also has its own sort of logic that looks similar. Let's make
                    // a shared system we can use to get a panel or make one if we need to.
                    if editor.active_view == .FULL {
                        assert(editor.panels.count == 1);

                        // The panel is not actually valid, until we set a view (a document or
                        // listing). We are going to do that soon after, in open_file.
                        open_in_panel = array_add(*editor.panels);
                        panel_init(open_in_panel, editor, platform);

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

                    open_file(editor, platform, input, it.path, open_in_panel);
                    if open_in_panel {
                        sanity_assert(open_in_panel.view.kind == .DOCUMENT);
                        if open_in_panel.view.kind == .DOCUMENT {
                            open_in_view := *open_in_panel.view._document;
                            open_in_document := open_in_view.document;

                            x := it.column_number - 1;
                            y := it.line_number - 1;

                            text_buffer_move_to(open_in_document.buffer, *open_in_view.cursors, x, y, false);
                            open_in_view.flags |= .CLAMP_SCROLL_TO_CURSOR;
                        }
                    }

                    break;
                }
            }
        }

        case .REFRESH;  run_compilation(editor, platform, panel);

        case .DEBUG_BYTE_AT_CURSOR; {
            if text_buffer_can_read_at_location(document.buffer, view.cursors.c0) {
                byte := text_buffer_get_byte_at_location(document.buffer, view.cursors.c0);
                editor_log(editor, "Byte at cursor: %", byte);
            } else {
                editor_log(editor, "Can't read at cursor");
            }
        }
    }

    if cursor_moved || buffer_changed {
        // The cursor position interpolation gets setup in a centralized place instead of here, because the
        // cursor can be moved from other places than this one (e.g. mouse, SEARCH mini
        // panel...).
        //
        // :CentralizedCursorInterpolationSetup
        view.flags |= .RECEIVED_DIRECT_KEYBOARD_INTERACTION;
        view.flags |= .CLAMP_SCROLL_TO_CURSOR;
    }

    if buffer_changed {
        document.flags |= .MODIFIED_THIS_FRAME;
        document.flags |= .MODIFIED;

        // We have to update these after every change, because the very next edit could be needing
        // this. We could start being smarter about this (e.g. by setting a specific dirty flag),
        // becuase not every subsequent action needs these up to date.  -jt, 22 July 2026.
        update_scopes(document);
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
                // TODO(jt): @Cleanup Maybe we should also have a make_or_get_panel_for_inactiv_view.
                if editor.active_view == .FULL {
                    assert(editor.panels.count == 1);

                    // The panel is not actually valid, until we set a view (a document or
                    // listing). We are going to do that soon after, in open_file.
                    open_in_panel = array_add(*editor.panels);
                    panel_init(open_in_panel, editor, platform);

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

        case .MARK_ITEM; {
            table_add(*listing.marked_items, view.item_index, null.*);
            view.item_index = clamp(view.item_index + 1, 0, listing.items.count - 1);
        }
        case .UNMARK_ITEM; {
            table_remove(*listing.marked_items, view.item_index);
            view.item_index = clamp(view.item_index + 1, 0, listing.items.count - 1);
        }

        case .DELETE_MARKED_ITEMS; {
            // TODO(jt): We should bring up a modal interaction to confirm.
            for listing.items {
                if table_find(*listing.marked_items, it_index) {
                    filename := String.path_join(listing.backing_directory_path, it.text, separator = "/",, temp);

                    success  := platform.delete_file(filename);
                    if !success {
                        editor_log(editor, "Failed to delete file: %", filename);
                    }
                }
            }

            refresh_directory_listing(platform, listing);
        }

        case .REFRESH;  refresh_directory_listing(platform, listing);

        case .ADD_PROJECT_DIRECTORY; {
            // TODO(jt): Also guard against one project directory being a prefix of another.
            if !array_find(editor.project_directories, listing.backing_directory_path) {
                // TODO(jt): @Leak Not a big problem, but still a leak.
                project_directory := arena_push_string(editor.perm_arena, listing.backing_directory_path);
                array_add(*editor.project_directories, project_directory);

                editor_log(editor, "Added project directory: %", project_directory);
            } else {
                editor_log(editor, "(Already a project directory)");
            }

        }
        case .REMOVE_PROJECT_DIRECTORY; {
            if array_unordered_remove_by_value(*editor.project_directories, listing.backing_directory_path) {
                editor_log(editor, "Removed project_directory", listing.backing_directory_path);
            } else {
                editor_log(editor, "(Wasn't a project directory)");
            }
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

            touch_panel(panel, input.time);
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
                        target.y = min(target.y, cell_h * cast(f64, document.buffer.line_count - 1));
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
                } else if row > document.buffer.line_count - 1 {
                    row = document.buffer.line_count - 1;
                    col = 1 + document.buffer.line_chars[row];
                } else if row == document.buffer.line_count - 1 {
                    line_view := text_buffer_make_view_for_line(document.buffer, row, include_newline = false,, temp);
                    col=, overflow := font_compute_char_index_on_line(editor.font, line_view, mouse.x - panel_content_rect.x0 + panel.scroll.value.x, binary = document.buffer.binary_mode);

                    // Include synthetic newline at the end of document.
                    if overflow {
                        col += 1;
                    }
                } else {
                    // Include newline, so that the cursor can go there.
                    line_view := text_buffer_make_view_for_line(document.buffer, row, include_newline = true,, temp);
                    col = font_compute_char_index_on_line(editor.font, line_view, mouse.x - panel_content_rect.x0 + panel.scroll.value.x, binary = document.buffer.binary_mode);
                }

                text_buffer_move_to(document.buffer, *view.cursors, col, row, !(editor.input_state.keys[Key.MB_LEFT] & .PRESSED));

                view.flags |= .RECEIVED_MOUSE_INTERACTION;
            }

            case .LISTING; {
                view := *panel.view._listing;
                listing := view.listing;

                row := cast(s64, floor((mouse.y + panel.scroll.value.y) / cell_h));
                if row >= 0 && row < listing.items.count {
                    view.item_index = row;
                    execute_listing_action(editor, platform, input, panel, view, listing, .OPEN);
                }
            }
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
    panel_content_h := rect_height(panel_content_rect);
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
                viewport_rect := drect_from_point_and_size(panel.scroll.target.x, panel.scroll.target.y, panel_content_w, panel_content_h);
                cursor_rect   := drect_from_point_and_size(cursor0_position.x, cursor0_position.y, cell_w, cell_h);

                cursor_position_dirty := false;
                if viewport_rect.y0 > cursor_rect.y1 {
                    // Move cursor down
                    delta := cast(s64, ceil((viewport_rect.y0 - cursor_rect.y1) / cell_h)) + PANEL_SCROLL_PADDING_CELLS_Y;
                    text_buffer_move_y(document.buffer, *view.cursors, delta, view.selecting);

                    cursor_position_dirty = true;
                } else if viewport_rect.y1 < cursor_rect.y0 {
                    // Move cursor up
                    delta := cast(s64, ceil((cursor_rect.y0 - viewport_rect.y1) / cell_h)) + PANEL_SCROLL_PADDING_CELLS_Y;
                    text_buffer_move_y(document.buffer, *view.cursors, -delta, view.selecting);

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

                viewport_rect := drect_from_point_and_size(panel.scroll.target.x + GUTTER_PIXELS, panel.scroll.target.y, panel_content_w, panel_content_h);
                scroll_to_rect: DRect;
                if view.flags & .CLAMP_SCROLL_TO_START_OF_LINE || cursor0_line_length < panel_content_w {
                    scroll_to_rect = drect_from_point_and_size(GUTTER_PIXELS, cursor0_position.y, cell_w, cell_h);
                } else if view.flags & .CLAMP_SCROLL_TO_END_OF_LINE {
                    scroll_to_rect = drect_from_point_and_size(GUTTER_PIXELS + cursor0_line_length, cursor0_position.y, cell_w, cell_h);
                } else if cursor0_line_length < panel_content_w {
                    // If text fits, clamp to start of line even if nobody asked us to, so that we automatically scroll back to x=0
                    // after being scrolled horizontally. This happens e.g. in minipanel search.
                    scroll_to_rect = drect_from_point_and_size(GUTTER_PIXELS, cursor0_position.y, cell_w, cell_h);
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
                document_update_tokens(document);
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
                    interpolation_start(*view.cursor_color, editor.theme.cursor_color_hot, color, input.time, CURSOR_FLASH_DURATION);
                }

                interpolation_running := false;
                interpolation_running |= interpolation_update(*view.cursor_position, input.time, dt);
                interpolation_running |= interpolation_update(*view.cursor_color, input.time, dt);
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
                viewport_rect := drect_from_point_and_size(panel.scroll.target.x, panel.scroll.target.y, panel_content_w, panel_content_h);
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

                viewport_rect := drect_from_point_and_size(panel.scroll.target.x + GUTTER_PIXELS, panel.scroll.target.y, panel_content_w, panel_content_h);
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
        interpolation_running := interpolation_update(*panel.scroll, input.time, dt);
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

            viewport_line0 := clamp(cast(s64, floor(viewport_y0 / cell_h)), 0, document.buffer.line_count - 1);
            viewport_line1 := clamp(cast(s64, ceil(viewport_y1 / cell_h)), 0, document.buffer.line_count - 1);

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

                scope := find_scope_for_location(document, view.cursors.c0);
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
            {
                set_scissor(render_commands, panel_rect);
                // So that thin cursors can be rendered at the edges of panel content without becoming even thinner!

                if panel_is_active {
                    cursor_position := view.cursor_position.value;

                    line_rect := rect_from_point_and_size(panel_content_x, cast(f32, cursor_position.y - panel.scroll.value.y),
                                                          panel_w, cell_h);
                    draw_rect(render_commands, line_rect, editor.theme.line_color);

                    cursor_w := cell_w;
                    if editor.theme.cursor_style == .THIN {
                        w  := round(THIN_CURSOR_WIDTH * editor.input_state.window_scale_factor);
                        hw := round(0.5 * w);

                        cursor_w = w;
                        cursor_position.x -= hw;
                    }

                    cursor_rect64   := drect_from_point_and_size(panel_content_x + cursor_position.x, cursor_position.y, cursor_w, cell_h) - panel.scroll.value;
                    cursor_rect     := drect_to_rect(cursor_rect64);

                    draw_rect(render_commands, cursor_rect, view.cursor_color.value);
                } else if editor.theme.cursor_style == .FULL {
                    cursor_position := view.cursor_position.value;

                    cursor_rect64   := drect_from_point_and_size(panel_content_x + cursor_position.x, cursor_position.y, cell_w, cell_h) - panel.scroll.value;
                    cursor_rect     := drect_to_rect(cursor_rect64);

                    left:   Rect = { cursor_rect.x0,     cursor_rect.y0,     cursor_rect.x0 + 1, cursor_rect.y1 };
                    right:  Rect = { cursor_rect.x1 - 1, cursor_rect.y0,     cursor_rect.x1,     cursor_rect.y1 };
                    top:    Rect = { cursor_rect.x0,     cursor_rect.y0,     cursor_rect.x1,     cursor_rect.y0 + 1 };
                    bottom: Rect = { cursor_rect.x0,     cursor_rect.y1 - 1, cursor_rect.x1,     cursor_rect.y1 };

                    draw_rect(render_commands, left, view.cursor_color.value);
                    draw_rect(render_commands, right, view.cursor_color.value);
                    draw_rect(render_commands, top, view.cursor_color.value);
                    draw_rect(render_commands, bottom, view.cursor_color.value);
                } else if editor.theme.cursor_style == .THIN {
                    w  := round(THIN_CURSOR_WIDTH_INACTIVE * editor.input_state.window_scale_factor);
                    hw := round(0.5 * w);

                    cursor_position := view.cursor_position.value;
                    cursor_position.x -= hw;

                    cursor_rect64   := drect_from_point_and_size(panel_content_x + cursor_position.x, cursor_position.y, w, cell_h) - panel.scroll.value;
                    cursor_rect     := drect_to_rect(cursor_rect64);

                    draw_rect(render_commands, cursor_rect, view.cursor_color.value);
                }

                set_scissor(render_commands, panel_content_rect);
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
                    for document.tokens {
                        if it.loc1.y < viewport_line0  continue; // TODO(jt): @Speed Binary search or skip ahead for the start instead?
                        if it.loc0.y > viewport_line1  break;

                        r: Font_Style_Range;
                        r.x0 = it.loc0.x;
                        r.y0 = it.loc0.y - viewport_line0;
                        r.x1 = it.loc1.x;
                        r.y1 = it.loc1.y - viewport_line0;

                        if #complete it.type == {
                            // These should not get here, but in case they do, we assign the defaults.
                            case .UNINITIALIZED;   r.color = editor.theme.text_color; r.variant = editor.theme.text_variant;
                            case .INVALID;         r.color = editor.theme.text_color; r.variant = editor.theme.text_variant;
                            case .END_OF_INPUT;    r.color = editor.theme.text_color; r.variant = editor.theme.text_variant;

                            // TODO(jt): @Cleanup While we sort of define color constants for things, we
                            // also can modify bold/italic, for which we have no way of customization
                            // yet. :Config
                            case .KEYWORD;         r.color = editor.theme.keyword_color; r.variant = editor.theme.keyword_variant;
                            case .NUMBER_LITERAL;  r.color = editor.theme.number_literal_color; r.variant = editor.theme.number_literal_variant;
                            case .STRING_LITERAL;  #through;
                            case .CHAR_LITERAL;    r.color = editor.theme.string_literal_color; r.variant = editor.theme.string_literal_variant;

                            // These should not get here, but in case they do, we assign the defaults.
                            case .PUNCTUATION;     r.color = editor.theme.text_color; r.variant = editor.theme.text_variant;
                            case .IDENTIFIER;      r.color = editor.theme.text_color; r.variant = editor.theme.text_variant;

                            case .ATTRIBUTE;       r.color = editor.theme.attribute_color; r.variant = editor.theme.attribute_variant;
                            case .DIRECTIVE;       r.color = editor.theme.directive_color; r.variant = editor.theme.directive_variant;

                            case .LINE_COMMENT;    #through;
                            case .BLOCK_COMMENT;   r.color = editor.theme.comment_color; r.variant = editor.theme.comment_variant;
                        }

                        array_add(*style_ranges, r);
                    }
                }

                invert_ranges: [..] Font_Invert_Range;
                invert_ranges.allocator = temp;
                if panel_is_active && editor.theme.invert_color_under_selection {
                    c0 := view.cursors.c0;
                    c1 := view.cursors.c1;

                    if c0 != c1 {
                        text_location_sort(*c0, *c1);

                        invert_range := array_add(*invert_ranges);
                        invert_range.x0 = c0.x;
                        invert_range.y0 = c0.y - viewport_line0;
                        invert_range.x1 = c1.x - 1; // -1, because font ranges are inclusive
                        invert_range.y1 = c1.y - viewport_line0;
                    }
                }

                scissor_rect := rect_from_point_and_size(panel_content_x, 0.0, panel_content_w, panel_h);
                font_layout_and_draw_text(*editor.font, cast(string, viewport_view),
                                          render_commands, atlas_update_regions,
                                          offset, scissor_rect,
                                          editor.theme.text_color, editor.theme.text_variant,
                                          style_ranges, invert_ranges,
                                          binary = document.buffer.binary_mode);
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
                percent := cast(s64, 100.0 * cast(f32, cursor.y) / cast(f32, document.buffer.line_count - 1));

                document_name := get_document_name(editor, document);
                document_lang := get_document_lang(document);

                left_part  := tprint("% %", temp_right_pad(document_lang, 10), document_name);
                right_part := tprint("%\% L% C%", percent, cursor.y + 1, temp_right_pad(tprint("%", cursor.x + 1), 4));

                padding := cast(s64, round(panel_w / cell_w)) - count_utf8_chars(left_part) - 10;
                s := tprint("     % %", left_part, temp_left_pad(right_part, padding));

                _font_layout_and_draw_text(*editor.font, s,
                                           render_commands, atlas_update_regions,
                                           modeline_offset, modeline_rect,
                                           editor.theme.system_text_color, .REGULAR,
                                           .[], .[],
                                           binary = false);
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

                invert_ranges: [..] Font_Invert_Range;
                invert_ranges.allocator = temp;

                if it == view.item_index {
                    if panel_is_active {
                        draw_rect(render_commands, line_rect_screen, editor.theme.listing_line_color);

                        if editor.theme.invert_color_under_selected_listing_line {
                            invert_range := array_add(*invert_ranges);
                            invert_range.x0 = 0;
                            invert_range.x1 = S64_MAX; // @Hack We want to invert the whole line anyway.
                        }
                    } else {
                        r := line_rect_screen;
                        left:   Rect = { r.x0,     r.y0,     r.x0 + 1, r.y1 };
                        right:  Rect = { r.x1 - 1, r.y0,     r.x1,     r.y1 };
                        top:    Rect = { r.x0,     r.y0,     r.x1,     r.y0 + 1 };
                        bottom: Rect = { r.x0,     r.y1 - 1, r.x1,     r.y1 };
                        draw_rect(render_commands, left, editor.theme.listing_line_color);
                        draw_rect(render_commands, right, editor.theme.listing_line_color);
                        draw_rect(render_commands, top, editor.theme.listing_line_color);
                        draw_rect(render_commands, bottom, editor.theme.listing_line_color);
                    }
                }

                // Because we start the layout just before the current viewport, the rendering scroll Y offset
                // is just the fractional part of the cell.
                offset: DVector2;
                offset.x = panel_content_x + -panel.scroll.value.x;
                offset.y = -viewport_y0 + cell_h * cast(f64, it);

                scissor_rect := rect_from_point_and_size(panel_content_x, 0.0, panel_content_w, panel_h);

                color   := editor.theme.listing_item_text_color;
                variant := editor.theme.listing_item_text_variant;
                if table_find(*listing.marked_items, it) {
                    color   = editor.theme.listing_item_text_color_marked;
                    variant = editor.theme.listing_item_text_variant_marked;
                }

                _font_layout_and_draw_text(*editor.font, item.text,
                                           render_commands, atlas_update_regions,
                                           offset, scissor_rect,
                                           color, variant,
                                           .[], invert_ranges,
                                           binary = false);
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
                percent := cast(s64, 100.0 * cast(f32, item_index) / cast(f32, listing.items.count - 1));

                listing_name := get_listing_name(editor, listing);

                left_part  := tprint("Directory  %", listing_name);
                right_part := tprint("%\% L%    ", percent, item_index + 1);

                padding := cast(s64, round(panel_w / cell_w)) - count_utf8_chars(left_part) - 10;
                s := tprint("     % %", left_part, temp_left_pad(right_part, padding));

                _font_layout_and_draw_text(*editor.font, s,
                                           render_commands, atlas_update_regions,
                                           modeline_offset, modeline_rect,
                                           editor.theme.system_text_color, .REGULAR,
                                           .[], .[],
                                           binary = false);
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

open_modal_interaction :: (editor: *Editor, platform: Platform, input: Input, procs: Modal_Interaction_Procs, params: *void = null) {
    modal_interaction := *editor.modal_interaction;

    assert(!modal_interaction.open);

    modal_interaction.procs = procs;
    modal_interaction.open = true;

    procs.init(editor, platform, input, params);
}

#scope_module

close_modal_interaction :: (editor: *Editor, platform: Platform, input: Input) {
    modal_interaction := *editor.modal_interaction;
    assert(modal_interaction.open);

    modal_interaction.cursors.c0 = { 0, 0 };
    modal_interaction.cursors.c1 = { 0, 0 };
    modal_interaction.selecting = false;

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

TEXT_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

TEXT_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

get_surround_pairs :: (document: Document) -> /* Static */ [] Paren_Pair {
    if #complete document.lang == {
        case .TEXT;  return TEXT_SURROUND_PAREN_PAIRS;
        case .C;     return LANG_C_SURROUND_PAREN_PAIRS;
        case .JAI;   return LANG_JAI_SURROUND_PAREN_PAIRS;
        case .GLSL;  return LANG_GLSL_SURROUND_PAREN_PAIRS;
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

load_config :: (editor: *Editor, platform: Platform, input: Input, fall_back_to_emergency_config: bool) {
    config_path := tprint("%/editor.config", input.config_path);

    success, config := platform.read_file(config_path,, temp);
    if success {
        success = parse_and_apply_config(editor, cast(string, config));
        if success {
            editor_log(editor, "Applied config");
        } else if fall_back_to_emergency_config {
            apply_emergency_config(editor);
            editor_log(editor, "Config at % corrupted. Applied emergency config", config_path);
        }
    } else {
        apply_emergency_config(editor);
        editor_log(editor, "Failed to read config file at %. Applied emergency config", config_path);
    }
}

// TODO(jt): @Cleanup maybe we should define a Theme enum and a way to get that from a string for config?
change_theme :: (editor: *Editor, theme: string) {
    theme_changed := false;

    if theme == {
        case "abulafia";             editor.theme = abulafia_theme(); theme_changed = true;
        case "naysayer";             editor.theme = naysayer_theme(); theme_changed = true;
        case "handmade";             editor.theme = handmade_theme(); theme_changed = true;
        case "stb";                  editor.theme = stb_theme(); theme_changed = true;
        case "zenburn";              editor.theme = zenburn_theme(); theme_changed = true;
        case "visual_studio_light";  editor.theme = visual_studio_light_theme(); theme_changed = true;
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

            // Refresh regardless of whether we already had the directory listed, so that we show new data.
            // TODO(jt): We should watch changes in the directory and periodically refresh its contents.
            refresh_directory_listing(platform, listing);

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
                        text_buffer_move_to(document.buffer, *document.cursors_cold, 0, 0, false);

                        update_scopes(document);
                        document_update_tokens(document);

                        watch_file(editor, platform, input, document.backing_file_path);
                        editor_log(editor, "Opened file: %", file_absolute_path);
                    } else {
                        editor_log(editor, "Failed to open file: %", file_absolute_path);
                    }
                } else {
                    editor_log(editor, "Opening new file: %", file_absolute_path);
                }
            }

            panel_set_document(panel, editor, document);
        }
    }

    return panel;
}

get_working_directory_for_active_view :: (editor: Editor, search_for_project: bool) -> success: bool, directory: string, directory_is_project: bool {
    // Search the current directory, unless it is part of a project, in which case search the (parent) project directory.

    working_directory: string;
    working_directory_is_project := false;

    panel := get_panel_for_active_view(editor);
    sanity_assert(panel != null);
    if !panel {
        return false, "", false;
    }

    if #complete panel.view.kind == {
        case .DOCUMENT;  working_directory = panel.view._document.document.backing_directory_path;
        case .LISTING;   working_directory = panel.view._listing.listing.backing_directory_path;
    }

    if working_directory.count == 0 {
        return false, "", false;
    }

    if search_for_project {
        success, project_directory := get_project_directory_for_path(editor, working_directory);
        if success {
            working_directory = project_directory;
            working_directory_is_project = true;
        }
    }

    return true, working_directory, working_directory_is_project;
}

get_project_directory_for_path :: (editor: Editor, path: string) -> success: bool, string {
    for editor.project_directories {
        if String.starts_with(path, it) {
            return true, it;
        }
    }

    return false, "";
}

ensure_directory :: (editor: *Editor, platform: Platform, _path: string) {
    path := _path;

    // So that the search below finds the last separator and checks the last path segment.
    if !String.ends_with(path, "/") {
        path = tprint("%/", path);
    }

    editor_log(editor, "Ensuring directory: %", path);

    index := String.find_index_from_left(path, #char "/", 0);
    while index != -1 {
        directory := String.slice(path, 0, index);

        if !platform.file_is_directory(directory) {
            if !platform.file_exists(directory) {
                platform.make_directory(directory);
                editor_log(editor, "Creating directory: %", directory);
            } else {
                editor_log(editor, "Can't create directory %, file already exists", directory);
                return;
            }
        }

        index = String.find_index_from_left(path, #char "/", index + 1);
    }
}

refresh_directory_listing :: (platform: Platform, listing: *Listing) {
    sanity_assert(listing.kind == .DIRECTORY);
    if listing.kind != .DIRECTORY {
        return;
    }

    array_reset(*listing.items);
    table_reset(*listing.marked_items);
    arena_pop_to_mark(listing.arena, listing.arena_base_data_mark);

    file_list := platform.list_directory(listing.backing_directory_path, recursive = false, files = true, directories = true,, temp);
    {
        self_dir := array_add(*listing.items);
        self_dir.text = ".";

        parent_dir := array_add(*listing.items);
        parent_dir.text = "..";
    }

    for file_list {
        s := "";
        if it.name.count {
            s = arena_push_string(listing.arena, it.name);

            item := array_add(*listing.items);
            item.text = s;
        }
    }
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

        it.time_of_last_activation = editor.input_state.time;

        return it, false;
    }

    debug_label_name: string;
    if #complete kind == {
        case .SCRATCH;      debug_label_name = "*scratch*";
        case .COMPILATION;  debug_label_name = "*compilation*";
        case .FILE;         debug_label_name = String.path_filename(backing_file_path);
    }

    // TODO(jt): @Leak The sprints below leak into perm.
    document_arena         := make_arena(editor, platform, .MEDIUM, sprint("% (Doc)", debug_label_name,, arena_allocator(editor.perm_arena)));
    buffer_arena           := make_arena(editor, platform, .LARGE,  sprint("% (Buffer)", debug_label_name,, arena_allocator(editor.perm_arena)));
    buffer_edit_text_arena := make_arena(editor, platform, .LARGE,  sprint("% (Edits)", debug_label_name,, arena_allocator(editor.perm_arena)));

    document: Document;
    document.kind = kind;
    document.lang = .TEXT;
    {
        ext, ext_found := String.path_extension(backing_file_path);
        if ext_found {
            if ext == {
                // We currently have a single lexer for both C and C-style C++.
                case "inl";   #through;
                case "hpp";   #through;
                case "cpp";   #through;
                case "h";     #through;
                case "c";     document.lang = .C;
                case "jai";   document.lang = .JAI;
                case "vert";  #through;
                case "frag";  #through;
                case "glsl";  document.lang = .GLSL;
            }
        }
    }

    document.flags = .NONE;
    document.time_of_last_activation = editor.input_state.time;

    text_buffer_init(*document.buffer, buffer_arena, buffer_edit_text_arena);

    document.arena = document_arena;
    if backing_directory_path.count {
        document.backing_directory_path = arena_push_string(document_arena, backing_directory_path);
    }

    if backing_file_path.count {
        document.backing_file_path = arena_push_string(document_arena, backing_file_path);
    }

    document.scopes.allocator = arena_allocator(document_arena);
    document.tokens.allocator = arena_allocator(document_arena);

    // If we find that we accidentally pass regular documents where compilation
    // documents are needed, we could set this to a fail_allocator or something.
    document.compilation_errors.allocator = arena_allocator(document_arena);

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

        it.time_of_last_activation = editor.input_state.time;

        return it, false;
    }

    debug_label_name: string;
    if #complete kind == {
        case .DIRECTORY;  debug_label_name = String.path_filename(backing_directory_path);
    }

    // TODO(jt): @Leak The sprint below leaks into perm.
    listing_arena := make_arena(editor, platform, .MEDIUM, sprint("% (Listing)", debug_label_name,, arena_allocator(editor.perm_arena)));

    listing: Listing;
    listing.kind = .DIRECTORY;
    listing.time_of_last_activation = editor.input_state.time;

    listing.arena = listing_arena;
    if backing_directory_path.count {
        listing.backing_directory_path = arena_push_string(listing_arena, backing_directory_path);
    }

    listing.arena_base_data_mark = arena_get_mark(listing_arena);

    listing.items.allocator = arena_allocator(listing_arena);

    listing.marked_items.allocator = arena_allocator(listing_arena);

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
        if it != document && it.time_of_last_activation > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .DOCUMENT;
            thing_to_show_time = it.time_of_last_activation;
        }
    }

    for * editor.listings {
        if it.time_of_last_activation > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .LISTING;
            thing_to_show_time = it.time_of_last_activation;
        }
    }

    // Find a document/listing with time_of_last_activation > 0. If we don't, we either have no
    // documents/listings (bad, becuase at least *scratch* shouldn't be closeable), or their
    // time_of_last_activation was not properly set everywhere it should be. We could do a fallback
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
    arena_deinit(document.arena);
    arena_deinit(document.buffer.arena);
    arena_deinit(document.buffer.edit_text_arena);

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
        if it.time_of_last_activation > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .DOCUMENT;
            thing_to_show_time = it.time_of_last_activation;
        }
    }

    for * editor.listings {
        if it != listing && it.time_of_last_activation > thing_to_show_time {
            thing_to_show = it;
            thing_to_show_kind = .LISTING;
            thing_to_show_time = it.time_of_last_activation;
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
    arena_deinit(listing.arena);

    locator := listing.locator;

    // Remove listing itself.
    bucket_array_remove(*editor.listings, locator);
}

document_get_comment_style :: (document: Document) -> /* Static */ line: string, block_start: string, block_end: string {
    if #complete document.lang == {
        case .TEXT;  return "", "", "";
        case .C;     return LANG_C_LINE_COMMENT, LANG_C_BLOCK_COMMENT_START, LANG_C_BLOCK_COMMENT_END;
        case .JAI;   return LANG_JAI_LINE_COMMENT, LANG_JAI_BLOCK_COMMENT_START, LANG_JAI_BLOCK_COMMENT_END;
        case .GLSL;  return LANG_GLSL_LINE_COMMENT, LANG_GLSL_BLOCK_COMMENT_START, LANG_GLSL_BLOCK_COMMENT_END;
    }
}

// TODO(jt): @Speed At sizes around ~10MB, even the fastest lexer we have (JAI_Lexer) takes 10 milliseconds to produce tokens.
// We need to make all lexers faster, so that we can increase the highlighting cutoff.
document_update_tokens :: (document: *Document) {
    if document.buffer.gb.count > HIGHLIGHT_CUTOFF_SIZE {
        array_reset_keeping_memory(*document.tokens);
        return;
    }

    if #complete document.lang == {
        case .TEXT;  // Nothing
        case .C;     lang_c_update_tokens(document);
        case .JAI;   lang_jai_update_tokens(document);
        case .GLSL;  lang_glsl_update_tokens(document);
    }
}

document_change_lang :: (document: *Document, lang: Document.Lang) {
    array_reset_keeping_memory(*document.tokens);
    array_reset_keeping_memory(*document.scopes);

    document.lang = lang;

    update_scopes(document);
    document_update_tokens(document);
}

// WARNING: At the moment, panels without views (documents/listings) are invalid, so only use this
// if you know you are going to set the view soon after.
panel_init :: (panel: *Panel, editor: *Editor, platform: Platform) {
    panel.highlights_arena = make_arena(editor, platform, .LARGE, "Panel"); // TODO(jt): Better debug_label.
    panel.highlights.allocator = arena_allocator(panel.highlights_arena);
    panel.highlight_index = -1;
}

panel_init_with_document :: (panel: *Panel, editor: *Editor, platform: Platform, document: *Document) {
    panel_init(panel, editor, platform);
    panel_set_document(panel, editor, document);
}

panel_init_with_listing :: (panel: *Panel, editor: *Editor, platform: Platform, listing: *Listing) {
    panel_init(panel, editor, platform);
    panel_set_listing(panel, editor, listing);
}

// Don't use the panel after calling this!
panel_deinit :: (panel: *Panel) {
    arena_deinit(panel.highlights_arena);
}

panel_set_document :: (panel: *Panel, editor: Editor, document: *Document) {
    // For now, each panel must have the underlying thing attached.
    // We may later relax this and show default background, or something.
    assert(document != null);

    panel_content_changed := true;

    // Save the view's cursors/item_index to the underlying thing.
    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;

            if view.document == document {
                // Don't reset scroll, cursors, etc, if we are setting the same document.
                panel_content_changed = false;
            }

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

    if panel_content_changed {
        panel.view.kind = .DOCUMENT;
        view := *panel.view._document;
        view.document = document;

        view.cursors = document.cursors_cold;
        text_buffer_clamp_cursors(document.buffer, *view.cursors);
        view.selecting = false;

        cursor_position := get_position_at_cursor(view, editor.font);

        view.old_cursor = view.cursors.c0;
        view.old_cursor_position = cursor_position;

        interpolation_init(*view.cursor_position, cursor_position);
        interpolation_init(*view.cursor_color, ifx document.flags & .READONLY then editor.theme.cursor_color_readonly else editor.theme.cursor_color);

        interpolation_init(*panel.scroll, { 0, 0 });
    }

    document.time_of_last_activation = editor.input_state.time;
}

panel_set_listing :: (panel: *Panel, editor: Editor, listing: *Listing) {
    // For now, each panel must have the underlying thing attached.
    // We may later relax this and show default background, or something.
    assert(listing != null);

    panel_content_changed := true;

    // Save the view's cursors/item_index to the underlying thing.
    if panel.view.kind == {
        case .DOCUMENT; {
            view := *panel.view._document;

            if view.document {
                view.document.cursors_cold = view.cursors;
            }
        }
        case .LISTING; {
            view := *panel.view._listing;

            if view.listing == listing {
                // Don't reset scroll, item_index, etc, if we are setting the same listing.
                panel_content_changed = false;
            }

            if view.listing {
                view.listing.item_index_cold = view.item_index;
            }
        }
    }

    if panel_content_changed {
        panel.view.kind = .LISTING;
        view := *panel.view._listing;
        view.listing = listing;

        view.item_index = clamp(listing.item_index_cold, 0, listing.items.count);

        interpolation_init(*panel.scroll, { 0, 0 });
    }

    listing.time_of_last_activation = editor.input_state.time;
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

    array_reset_keeping_memory(*document.compilation_errors);

    args := document.compilation_args;

    view.cursors.c0 = { 0, 0 };
    view.cursors.c1 = { 0, 0 };
    text_buffer_reset(*document.buffer);
    text_buffer_insert(*document.buffer, *view.cursors, "Compilation directory: ", .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, working_directory, .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, "\n", .OMIT );
    text_buffer_insert(*document.buffer, *view.cursors, "Compiling with args: ", .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, args, .OMIT);
    text_buffer_insert(*document.buffer, *view.cursors, "\n\n", .OMIT );

    // TODO(jt): @Bug On Windows, compilation returns CRLF output?

    time_before := platform.get_current_time_monotonic();
    exit_code, exit_type, output, error := platform.run_in_process(args, working_directory,, temp);
    time_after  := platform.get_current_time_monotonic();

    time_elapsed := time_after - time_before;

    // TODO(jt): Interleave stdout and stderr as the process writes to them.
    if error.count == 0 {
        text_buffer_insert(*document.buffer, *view.cursors, output, undo_modifier = .OMIT);
    } else if output.count == 0 {
        text_buffer_insert(*document.buffer, *view.cursors, error, undo_modifier = .OMIT);
    } else {
        text_buffer_insert(*document.buffer, *view.cursors, output, undo_modifier = .OMIT);
        text_buffer_insert(*document.buffer, *view.cursors, "\nCompilation also wrote to standard error (this will eventually be properly interleaved):\n\n", .OMIT);
        text_buffer_insert(*document.buffer, *view.cursors, error, undo_modifier = .OMIT);
    }

    text_buffer_insert(*document.buffer, *view.cursors, tprint("\nCompilation exited after % seconds with code: % (exit type: %)\n", to_float64_seconds(time_elapsed), exit_code, exit_type), undo_modifier = .OMIT);

    for :text_buffer_lines line_text, line_index: document.buffer {
        found, link := find_compilation_link(line_text);
        if found {
            ce := array_add(*document.compilation_errors);
            ce.x0 = count_utf8_chars(String.slice(line_text, 0, link.index));
            ce.x1 = ce.x0 + count_utf8_chars(String.slice(line_text, link.index, link.count));
            ce.y  = line_index;

            ce.line_number   = link.line_number;
            ce.column_number = link.column_number;

            if link.path_is_absolute {
                ce.path = arena_push_string(document.arena, link.path);
            } else {
                absolute_path := String.path_join(working_directory, link.path,, temp);
                ce.path = arena_push_string(document.arena, absolute_path);
            }
            String.path_overwrite_separators(ce.path, "/");
        }
    }
}

// TODO(jt): The user experience of this kind of sucks. The first C-l should always recenter. But
// then we need to remember if it is the first press.
recenter_panel :: (panel: *Panel, editor: Editor, input: Input, force_center := false, skip_interpolation := false) {
    is_near :: inline (a: f64, b: f64, epsilon: f64) -> bool {
        return a + epsilon >= b && a - epsilon <= b;
    }

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

    epsilon := editor.font.line_height_in_pixels;

    if force_center {
        target.y = center;
    } else if is_near(panel.scroll.target.y, center, epsilon) {
        target.y = top;
    } else if is_near(panel.scroll.target.y, top, epsilon) {
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
            text_buffer_move_y(view.document.buffer, *view.cursors, -delta, view.selecting);

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
            text_buffer_move_y(view.document.buffer, *view.cursors, delta, view.selecting);

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
        return 0;
    }

    line_length := get_line_length_for_line_index(document, font, view.cursors.c0.y);

    return line_length;
}

get_position_for_location :: (document: Document, font: Font, loc: Text_Location) -> DVector2 {
    if loc.y >= document.buffer.line_count {
        log_error("Tried to get position for a line out of document bounds. Line index is %. Document has % lines.", loc.y, document.buffer.line_count);
        return { 0, 0 };
    }

    line_view := text_buffer_make_view_for_line(document.buffer, loc.y,, temp);

    position: DVector2;
    position.x = font_compute_position_on_line(font, line_view, loc.x, binary = document.buffer.binary_mode);
    position.y = cast(f64, loc.y) * font.line_height_in_pixels;

    return position;
}

get_line_length_for_line_index :: (document: Document, font: Font, line_index: s64) -> f64 {
    if line_index >= document.buffer.line_count {
        log_error("Tried to get length for a line out of document bounds. Line index is %. Document has % lines.", line_index, document.buffer.line_count);
        return 0;
    }

    line_view   := text_buffer_make_view_for_line(document.buffer, line_index,, temp);
    line_length := font_compute_line_length(font, line_view, binary = document.buffer.binary_mode);

    return line_length;
}

canonicalize_path :: (path: *string) {
    String.path_overwrite_separators(path.*, "/");
    path.* = String.trim_right(path.*, "/");
}

Compilation_Link :: struct {
    index: s64;
    count: s64;
    path: string;
    path_is_absolute: bool;
    line_number: s64;
    column_number: s64;
}

// Heuristically find first occurence of a compilation link in a line.
//
// Currently detected:
//   <filename>:<line>:<col>
//   <filename>:<line>,<col>
//
// Known formats:
//
// jai:    C:/Users/yanchith/workspace/editor/src/editor/editor.jai:4801,5
// rustc:  game_platform_winit\src\main.rs:6:1
// clang:  sdl_asteroids.cpp:1:10 or .\asteroids.h:12:16
// tsc:    index.ts(2,5) or index.ts:2:5 (based on console feature detection?)
//
// TODO(jt): @Incomplete Detect alternative tsc format: "index.ts(2,5)"
find_compilation_link :: (line: string) -> found: bool, Compilation_Link {
    result: Compilation_Link;
    if !line.count {
        return false, result;
    }

    // We are looking for <path>:<line>:<col> or <path>:<line>,<col>.
    // We can't rely on the path containing a slash, so detect the line-col pair first.
    colon_index := String.find_index_from_left(line, #char ":");
    if colon_index == -1 {
        return false, result;
    }

    s := slice(line, colon_index + 1);

    success: bool;
    result.line_number, success, s = string_to_int(s, T = s64);
    if !success {
        return false, result;
    }

    if !s.count || (s[0] != ":" && s[0] != ",") {
        return false, result;
    }
    advance(*s);

    result.column_number, success, s = string_to_int(s, T = s64);
    if !success {
        return false, result;
    }

    // TODO(jt): @Incomplete Handle quoted paths.
    space_index := find_index_from_right(line, #char " ", colon_index);
    // Skip check for -1, as the path could be the first thing. Works out with the +1 below.

    path_index := space_index + 1;
    path_count := colon_index - path_index;
    if path_count == 0 {
        return false, result;
    }

    result.index = path_index;
    result.count = s.data - line.data - path_index;

    result.path = String.slice(line, path_index, path_count);
    result.path_is_absolute = String.is_absolute_path(result.path);

    return true, result;
}

#scope_file

draw_rect :: (render_commands: *[..] Render_Command, x0: f32, y0: f32, x1: f32, y1: f32, color: Vector4 = { 1, 1, 1, 1 }) {
    inline draw_rect(render_commands, { x0, y0, x1, y1 }, color);
}

draw_rect :: (render_commands: *[..] Render_Command, rect: Rect, color: Vector4 = { 1, 1, 1, 1 }) {
    command := array_add(render_commands);
    command.type = .DRAW_COLOR_RECT;
    command.rect = rect;
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
    LARGE  ::   8 << 30;
}

make_arena :: (editor: *Editor, platform: Platform, size: Arena_Size, label: string, attach_debug_procs := true) -> *Arena {
    procs: Arena_Procs;
    procs.page_size    = platform.page_size;
    procs.mem_reserve  = platform.mem_reserve;
    procs.mem_release  = platform.mem_release;
    procs.mem_commit   = platform.mem_commit;
    procs.mem_decommit = platform.mem_decommit;

    debug_procs: Arena_Debug_Procs;
    if attach_debug_procs {
        debug_procs = make_arena_debug_procs(editor);
    }

    arena := arena_new(procs, reserve_size = cast(s64, size), debug_procs = debug_procs, debug_label = label);

    return arena;
}

make_arena_debug_procs :: (editor: *Editor) -> Arena_Debug_Procs {
    debug_procs: Arena_Debug_Procs;
    debug_procs.on_init = (arena: *Arena, userdata: *void) {
        ed := cast(*Editor, userdata);
        array_add(*ed.arenas, arena);
    };
    debug_procs.on_deinit = (arena: *Arena, userdata: *void) {
        ed := cast(*Editor, userdata);
        array_unordered_remove_by_value(*ed.arenas, arena);
    }
    debug_procs.userdata = editor;

    return debug_procs;
}

mark_frame_profile :: (editor: *Editor, input: Input) {
    #assert is_power_of_two(editor.DEBUG_FRAME_PROFILE_COUNT); // So that we can use bit ops modulo.

    if editor.debug_view == .FRAME_PROFILE {
        state := *editor.debug_view_state._frame_profile;
        if state.paused {
            return;
        }
    }

    current := *editor.debug_frame_profiles.entries[editor.debug_frame_profile_index];
    array_copy(current.zones, input.previous_frame_profile_zones);
    array_copy(current.zone_labels, input.previous_frame_profile_zone_labels);
    current.time_scale = input.previous_frame_profile_time_scale;

    editor.debug_frame_profile_index += 1;
    editor.debug_frame_profile_index &= editor.DEBUG_FRAME_PROFILE_COUNT - 1;
}

mark_frame_timeline_point :: (editor: *Editor, platform: Platform, input: Input, marker: enum { START; RENDER; END; }) {
    if #complete marker == {
        case .START; {
            editor.debug_frame_timeline.entries[editor.debug_frame_timeline_index].time_start = input.time;
        }
        case .RENDER; {
            editor.debug_frame_timeline.entries[editor.debug_frame_timeline_index].time_render = platform.get_current_time_monotonic() - input.time_of_program_start;
        }
        case .END; {
            editor.debug_frame_timeline.entries[editor.debug_frame_timeline_index].time_end = platform.get_current_time_monotonic() - input.time_of_program_start;

            #assert is_power_of_two(editor.DEBUG_FRAME_TIMELINE_COUNT); // So that we can use bit ops modulo.
            editor.debug_frame_timeline_index += 1;
            editor.debug_frame_timeline_index &= editor.DEBUG_FRAME_TIMELINE_COUNT - 1;
        }
    }
}

toggle_debug_view :: (editor: *Editor, value: Editor.Debug_View) {
    editor.debug_view_state = {};

    if editor.debug_view == value {
        editor.debug_view = .NONE;
    } else {
        editor.debug_view = value;
    }
}

// TODO(jt): @Cleanup Remove this, if we do our own bucket array, or if it gets added to modules/Bucket_Array.
operator== :: (a: Bucket_Locator, b: Bucket_Locator) -> bool {
    return a.bucket_index == b.bucket_index && a.slot_index == b.slot_index;
}

// TODO(jt): Eventually replace this welcome message with something better:
// - OPEN_CONFIG_LOCATION command would certainly be helpful
// - remove disclaimers

WELCOME :: #run -> string {
    #if OS == .WINDOWS {
        CONFIG_TEMPLATE_LOCATION :: "next to the executable";
    } else #if OS == .MACOS {
        CONFIG_TEMPLATE_LOCATION :: "in ~/Library/Application Support/Editor";
    } else {
        CONFIG_TEMPLATE_LOCATION :: "";
    }

    return sprint(WELCOME_TEMPLATE, VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, BUILD_TIMESTAMP, CONFIG_TEMPLATE_LOCATION);
}

WELCOME_TEMPLATE :: #string DONE

Welcome to the untitled text editor! (Version %.%.%, built on %)

This is an alpha release, so expect minor bugs. I apologize for the inconvenience.

If you are coming from Emacs, most of the keyboard shortcuts will be familiar to you.
Otherwise, there are starter templates for the config files from other editors.
You can find the config %.

To list available commands and their bound shortcuts, type Alt-x or Ctrl-Shift-p.

DONE;
