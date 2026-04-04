// TODO(jt): @Cleanup There is some overlap between key_map.jai and input.jai, for instance we
// consume some types from input here. Should we attempt to unify?

Action :: enum u32 {
    NONE;

    MINI_PANEL_MOVE_UP;
    MINI_PANEL_MOVE_DOWN;
    MINI_PANEL_MOVE_LEFT;
    MINI_PANEL_MOVE_RIGHT;

    MINI_PANEL_MOVE_FORWARD_WORD;
    MINI_PANEL_MOVE_BACKWARD_WORD;

    MINI_PANEL_MOVE_TO_START_OF_LINE;
    MINI_PANEL_MOVE_TO_END_OF_LINE;

    MINI_PANEL_DELETE_FORWARD;
    MINI_PANEL_DELETE_BACKWARD;

    MINI_PANEL_SCROLL_UP;
    MINI_PANEL_SCROLL_DOWN;

    MINI_PANEL_CONFIRM;
    MINI_PANEL_CANCEL;
}

Shortcut_Key :: struct {
    modifier_flags: Modifier_Flags;
    type: Input_Event.Type;
    data: Input_Event.Data;

    Modifier_Flags :: enum_flags u16 {
        NONE :: 0;

        CTRL  :: 0x01;
        ALT   :: 0x02;
        SHIFT :: 0x04;
        META  :: 0x08;
    }
}

#assert size_of(Shortcut_Key) == 8;

// TODO(jt): @Cleanup Because our platform layer is a mess, and we make up synthetic events for
// ctrl/alt + key, we sometimes (on Windows) and othertimes (on macOS) get the key in the wrong
// case. For this reason, we do the comparison case insensitively here, but maybe we should just fix
// that at the source, if at all possible. (If not possible, I guess we can live without case
// sensitive keyboard shortcuts.)

shortcut_key_equals_nocase :: (a: Shortcut_Key, b: Shortcut_Key) -> bool {
    if a.modifier_flags != b.modifier_flags  return false;
    if a.type != b.type                      return false;

    if a.type == {
        case .KEY; {
            // TODO(jt): should we also handle to_lower here?
            if a.data.key != b.data.key {
                return false;
            }
        }
        case .CODEPOINT; {
            if a.data.codepoint < 127 && b.data.codepoint < 127 {
                ascii_a := cast(u8, a.data.codepoint);
                ascii_b := cast(u8, b.data.codepoint);

                // TODO(jt): We need a Unicode version of to_lower here eventually.
                if to_lower(ascii_a) != to_lower(ascii_b) {
                    return false;
                }
            } else if a.data.codepoint != b.data.codepoint {
                return false;
            }
        }
    }

    return true;
}

SHORTCUT_COUNT_MAX :: 8;
Shortcut :: struct {
    // TODO(jt): Could use an inline array structure here?
    sequence:  [SHORTCUT_COUNT_MAX] Shortcut_Key;
    count:     s64;
}

shortcut_equals_nocase :: (a: Shortcut, b: Shortcut) -> bool {
    if a.count != b.count {
        return false;
    }

    for 0..a.count - 1 {
        key_a := a.sequence[it];
        key_b := b.sequence[it];

        if !shortcut_key_equals_nocase(key_a, key_b) {
            return false;
        }
    }

    return true;
}

// Parses stuff like "n" or "C-x" or "C-S-M <up>" into a shortcut sequence.
// Note that modifiers (C/M/S) can not stand on their own - they'll just be parsed as the literal letters C/M/S.
shortcut_parse :: (_s: string) -> Shortcut {
    assert(_s.count > 0);

    shortcut: Shortcut;

    s := _s;
    while s.count {
        _, left, right := String.split_from_left(s, #char " ");

        key: Shortcut_Key;

        dash_found, l, r := String.split_from_left(s, #char "-");
        while dash_found {
            if l == {
                case "C"; key.modifier_flags |= .CTRL;
                case "M"; key.modifier_flags |= .ALT;
                case "S"; key.modifier_flags |= .SHIFT;
            }

            dash_found, l, r = String.split_from_left(r, #char "-");
        }

        if l == {
            case "<up>";         key.type = .KEY; key.data.key = .ARROW_UP;
            case "<down>";       key.type = .KEY; key.data.key = .ARROW_DOWN;
            case "<left>";       key.type = .KEY; key.data.key = .ARROW_LEFT;
            case "<right>";      key.type = .KEY; key.data.key = .ARROW_RIGHT;

            case "<enter>";      key.type = .CODEPOINT; key.data.codepoint = .ENTER;
            case "<delete>";     key.type = .CODEPOINT; key.data.codepoint = .DELETE;
            case "<backspace>";  key.type = .CODEPOINT; key.data.codepoint = .BACKSPACE;

            case "<home>";       key.type = .KEY; key.data.key = .HOME;
            case "<end>";        key.type = .KEY; key.data.key = .END;

            case "<f1>";         key.type = .KEY; key.data.key = .F1;
            case "<f2>";         key.type = .KEY; key.data.key = .F2;
            case "<f3>";         key.type = .KEY; key.data.key = .F3;
            case "<f4>";         key.type = .KEY; key.data.key = .F4;
            case "<f5>";         key.type = .KEY; key.data.key = .F5;
            case "<f6>";         key.type = .KEY; key.data.key = .F6;
            case "<f7>";         key.type = .KEY; key.data.key = .F7;
            case "<f8>";         key.type = .KEY; key.data.key = .F8;
            case "<f9>";         key.type = .KEY; key.data.key = .F9;
            case "<f10>";        key.type = .KEY; key.data.key = .F10;
            case "<f11>";        key.type = .KEY; key.data.key = .F11;
            case "<f12>";        key.type = .KEY; key.data.key = .F12;
            case; {
                c := Unicode.character_utf8_to_utf32(l.data, l.count);
                key.type = .CODEPOINT;
                key.data.codepoint = cast(Codepoint, c);
            }
        }

        shortcut.sequence[shortcut.count] = key;
        shortcut.count += 1;

        s = right;
    }

    return shortcut;
}

shortcut_begins_with_nocase :: (shortcut: Shortcut, prefix: Shortcut) -> bool {
    if prefix.count > shortcut.count {
        return false;
    }

    for 0..prefix.count - 1 {
        key_a := shortcut.sequence[it];
        key_b := prefix.sequence[it];

        if !shortcut_key_equals_nocase(key_a, key_b) {
            return false;
        }
    }

    return true;
}

Key_Map :: struct {
    // XXX: Do this allocator spread thingu in text_buffer too, so we don't have to init?
    allocator: Allocator; // Will spread to all key map datastructures.
    registered_shortcuts: [..] Shortcut;
    registered_actions:   [..] Action;

    buffered_input: Shortcut;
    buffered_modifier_flags: Shortcut_Key.Modifier_Flags;
}

// You don't have to call init. It only pre-sizes the arrays. If you plan to set the allocator, do
// it before calling init.
key_map_init :: (key_map: *Key_Map, size: s64) {
    InitAllocators(key_map);
    array_reserve(*key_map.registered_shortcuts, size);
    array_reserve(*key_map.registered_actions, size);
}

key_map_register :: (key_map: *Key_Map, shortcut: Shortcut, action: Action) {
    InitAllocators(key_map);
    array_add(*key_map.registered_shortcuts, shortcut);
    array_add(*key_map.registered_actions, action);
}

key_map_flush :: (key_map: *Key_Map) {
    key_map.buffered_input = {};
}

key_map_input :: (key_map: *Key_Map, event: Input_Event) -> buffered: bool, action: Action {
    // Do nothing, if we haven't got shortcuts to compare against.
    if !key_map.registered_shortcuts.count {
        return false, .NONE;
    }

    modifier_flags := get_modifier_flags(event);
    if modifier_flags != .NONE {
        if event.flags & .PRESSED {
            key_map.buffered_modifier_flags |= modifier_flags;
        } else {
            key_map.buffered_modifier_flags &= ~modifier_flags;
        }

        return true, .NONE;
    }

    if event.flags & .PRESSED {
        if key_map.buffered_input.count == SHORTCUT_COUNT_MAX {
            // This should not happen, because if no action matched last time, we should have flushed.
            sanity_assert(false);
            key_map.buffered_input = {};
        }

        key: Shortcut_Key;
        key.modifier_flags = key_map.buffered_modifier_flags;
        key.type = event.type;
        key.data = event.data;

        key_map.buffered_input.sequence[key_map.buffered_input.count] = key;
        key_map.buffered_input.count += 1;

        has_candidates := false;
        for key_map.registered_shortcuts {
            if shortcut_begins_with_nocase(it, key_map.buffered_input) {
                has_candidates = true;
            }

            if shortcut_equals_nocase(it, key_map.buffered_input) {
                key_map.buffered_input = {};
                action := key_map.registered_actions[it_index];

                return false, action;
            }
        }

        if has_candidates {
            return true, .NONE;
        } else {
            key_map.buffered_input = {};
            return false, .NONE;
        }
    }

    return false, .NONE;
}

#scope_file

InitAllocators :: (key_map: *Key_Map) #expand {
    if !key_map.registered_shortcuts.count {
        if key_map.allocator.proc {
            key_map.registered_shortcuts.allocator = key_map.allocator;
            key_map.registered_actions.allocator = key_map.allocator;
        }
    }
}

get_modifier_flags :: inline (event: Input_Event) -> Shortcut_Key.Modifier_Flags {
    modifier_flags: Shortcut_Key.Modifier_Flags;
    if #complete event.type == {
        case .CODEPOINT; // Nothing
        case .KEY; {
            if event.data.key == {
                case .CTRL;   modifier_flags |= .CTRL;
                case .ALT;    modifier_flags |= .ALT;
                case .SHIFT;  modifier_flags |= .SHIFT;
                case .META;   modifier_flags |= .META;
            }
        }
    }

    return modifier_flags;
}
