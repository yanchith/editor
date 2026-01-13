Input :: struct {
    time:  Apollo_Time;
    dtime: Apollo_Time;

    window_size:    IVector2;
    mouse_position: Vector2;

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
    keyboard_events: [] Keyboard_Event;
}

Keyboard_Event :: struct  {
    type: Keyboard_Event_Type;
    flags: Keyboard_Event_Flags;
    data: Keyboard_Event_Data;
}

#assert size_of(Keyboard_Event) == 8;

Keyboard_Event_Type :: enum u16 {
    KEY       :: 0;
    CODEPOINT :: 1;
}

Keyboard_Event_Flags :: enum_flags u16 {
    NONE :: 0;

    PRESSED :: 0x01; // Whether the key is right now PRESSED. Absence of this flag means RELEASED.
    REPEAT  :: 0x02; // Whether the key is a synthetic OS repeat event.
}

// TODO(jt): This is not a discriminated union (yet?), because currently the tag is the first member
// and we can't pack Keyboard_Event into 8 bytes because of padding this introduces. Therefore the
// tag is stored outside.
Keyboard_Event_Data :: union {
    key: Key;
    codepoint: Codepoint;

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
    }

    // A unicode codepoint.
    Codepoint :: enum u32 {
        NULL :: 0;

        BACKSPACE   :: 8;
        TAB         :: 9;
        LINEFEED    :: 10;
        ENTER       :: 13;
        ESCAPE      :: 27;
        SPACEBAR    :: 32;

        // The visible characters live in the interval [33, 126] and have their usual ascii values.

        DELETE :: 127;
    }
}
