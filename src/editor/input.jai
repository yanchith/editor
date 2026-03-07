Input :: struct {
    time:  Apollo_Time;
    dtime: Apollo_Time;

    window_size: IVector2;

    mouse_position:    Vector2;
    mouse_wheel_delta: s64;

    // TODO(jt): For now we can do what the input module gives us, but we'll have to grow beyond
    // that to be usable. We need a stream of pressed keys? Do we want to get Unicode codepoints?
    // What does Windows/Linux/macOS give us by default?
    //
    // What we need from this:
    //
    // - regular characters
    // - control keys: return, backspace, ...
    // - modifier keys: ctrl, alt, shift, meta
    // - combined keys: ˇ + s = š (ideally if we didn't have to do the combining?)
    //
    events: [] Input_Event;
}

Input_Event :: struct  {
    type: Type;
    flags: Flags;
    data: Data;

    Type :: enum u16 {
        KEY       :: 0;
        CODEPOINT :: 1;
    }

    Flags :: enum_flags u16 {
        NONE :: 0;

        KEY_PRESSED :: 0x01; // Whether the key is right now pressed. Absence of this flag means released.
        KEY_REPEAT  :: 0x02; // Whether the key is a synthetic OS repeat event.
    }


    // TODO(jt): This is not a discriminated union (yet?), because currently the tag is the first
    // member and we can't pack Keyboard_Event into 8 bytes because of padding this
    // introduces. Therefore the tag is stored outside.
    Data :: union {
        key: Key;
        codepoint: Codepoint;
    }
}

#assert size_of(Input_Event) == 8;


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

    MOUSE_BUTTON_LEFT;
    MOUSE_BUTTON_RIGHT;
    MOUSE_BUTTON_MIDDLE;
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
