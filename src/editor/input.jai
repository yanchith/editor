Input :: struct {
    time:  Apollo_Time;
    dtime: Apollo_Time;

    frame_triggered_by_animation: bool;

    window_size: IVector2;
    window_scale_factor: f32;

    mouse_position:    Vector2;
    mouse_wheel_delta: s64;

    // Everything above 'events' is already integrated. If the OS sent us e.g. individual mouse
    // positions or window sizes as events (I am not sure if any actually do so), we don't have the
    // access to that information. Hopefully this won't be super important.

    events: [] Input_Event;
}

Input_Event :: struct  {
    type: Type;
    flags: Flags;

    data: u32;

    // Overlay instead of tagged union for more control over data data layout.
    #overlay (data) key: Key;
    #overlay (data) codepoint: Codepoint;

    Type :: enum u16 {
        KEY       :: 0;
        CODEPOINT :: 1;
    }

    Flags :: enum_flags u16 {
        NONE :: 0;

        PRESSED :: 0x01; // Whether the key is right now pressed. Absence of this flag means released.
        REPEAT  :: 0x02; // Whether the key is a synthetic OS repeat event. We currently don't use this?
    }
}

#assert size_of(Input_Event) == 8;

KEY_COUNT :: #run enum_highest_value(Key) + 1;
Key :: enum u32 {
    CTRL;
    ALT;
    SHIFT;
    META;

    ARROW_UP;
    ARROW_DOWN;
    ARROW_LEFT;
    ARROW_RIGHT;

    PAGE_UP;
    PAGE_DOWN;

    HOME;
    END;

    INSERT;
    // DELETE is a codepoint.

    F1;
    F2;
    F3;
    F4;
    F5;
    F6;
    F7;
    F8;
    F9;
    F10;
    F11;
    F12;

    PRINT_SCREEN;

    MB_LEFT;
    MB_RIGHT;
    MB_MIDDLE;
}

// A unicode codepoint.
Codepoint :: enum u32 {
    NULL :: 0;

    BACKSPACE   :: 8;
    TAB         :: 9;
    LINEFEED    :: 10; // TODO(jt): When exactly do we get linefeed? When we paste text? When we press enter, do we get ENTER? What about CR?
    ENTER       :: 13;
    ESCAPE      :: 27;
    SPACEBAR    :: 32;

    // The visible characters live in the interval [33, 126] and have their usual ascii values.

    DELETE :: 127;
}

Input_State :: struct {
    // TODO(jt): @Cleanup We are already selectively copying things from Input here. Consider
    // copying the whole input here, so any function that has access to editor also has access to
    // this frame's input, and we don't have to pass it manually.
    time: Apollo_Time;

    mouse_inside_window: bool;

    keys: [KEY_COUNT] Key_State;
    modifiers: Modifier_Flags;
}

Key_State :: enum_flags u8 {
    NONE     :: 0;

    DOWN     :: 0x01;
    PRESSED  :: 0x02;
    RELEASED :: 0x04;

    LAST_PRESS_WAS_WITH_MOUSE_INSIDE_WINDOW :: 0x10; // This stays set after the key has been released, until it is pressed again.
}

Modifier_Flags :: enum_flags u8 {
    NONE :: 0;

    CTRL  :: 0x01;
    ALT   :: 0x02;
    SHIFT :: 0x04;
    META  :: 0x08;
}

input_state_update_on_frame_start :: (input_state: *Input_State, input: Input) {
    input_state.time = input.time;

    window_rect := rect_from_point_and_size(0, 0, cast(f32, input.window_size.x), cast(f32, input.window_size.y));
    input_state.mouse_inside_window = rect_contains(window_rect, input.mouse_position);

    for * input_state.keys {
        it.* &= ~(.PRESSED | .RELEASED);
    }
}

input_state_update_with_event :: (input_state: *Input_State, event: Input_Event) {
    if event.type == .KEY {
        key := event.key;

        if event.flags & .PRESSED {
            input_state.keys[key] |= .DOWN | .PRESSED;
            if input_state.mouse_inside_window {
                input_state.keys[key] |= .LAST_PRESS_WAS_WITH_MOUSE_INSIDE_WINDOW;
            } else {
                input_state.keys[key] &= ~.LAST_PRESS_WAS_WITH_MOUSE_INSIDE_WINDOW;
            }
        } else {
            // Do not clear PRESSED. So that we can detect single-frame press and release.
            input_state.keys[key] &= ~.DOWN;
            input_state.keys[key] |= .RELEASED;
        }
    }

    modifiers: Modifier_Flags;
    if #complete event.type == {
        case .CODEPOINT; // Nothing
        case .KEY; {
            if event.key == {
                case .CTRL;   modifiers |= .CTRL;
                case .ALT;    modifiers |= .ALT;
                case .SHIFT;  modifiers |= .SHIFT;
                case .META;   modifiers |= .META;
            }
        }
    }

    if modifiers != .NONE {
        if event.flags & .PRESSED {
            input_state.modifiers |= modifiers;
        } else {
            input_state.modifiers &= ~modifiers;
        }
    }
}
