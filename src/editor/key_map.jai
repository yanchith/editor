Shortcut_Key :: struct {
    modifier_flags: Modifier_Flags;
    type: Input_Event.Type;

    data: u32;
    #overlay (data) key: Key;
    #overlay (data) codepoint: Codepoint;
}

#assert size_of(Shortcut_Key) == 8;

// TODO(jt): @Cleanup Because our platform layer is a mess, and we make up synthetic events for
// ctrl/alt + key, we sometimes (on Windows) and othertimes (on macOS) get the key in the wrong
// case. For this reason, we do the comparison case insensitively here, but maybe we should just fix
// that at the source, if at all possible. (If not possible, I guess we can live without case
// sensitive keyboard shortcuts.)

shortcut_key_equals_nocase :: (a: Shortcut_Key, b: Shortcut_Key, allow_extra_shift_on_b: bool) -> bool {
    if allow_extra_shift_on_b {
        if a.modifier_flags != b.modifier_flags && a.modifier_flags | .SHIFT != b.modifier_flags {
            return false;
        }
    } else {
        if a.modifier_flags != b.modifier_flags {
            return false;
        }
    }

    if a.type != b.type {
        return false;
    }

    if a.type == {
        case .KEY; {
            // TODO(jt): should we also handle to_lower here?
            if a.key != b.key {
                return false;
            }
        }
        case .CODEPOINT; {
            if a.codepoint < 127 && b.codepoint < 127 {
                ascii_a := cast(u8, a.codepoint);
                ascii_b := cast(u8, b.codepoint);

                // TODO(jt): We need a Unicode version of to_lower here eventually.
                if to_lower(ascii_a) != to_lower(ascii_b) {
                    return false;
                }
            } else if a.codepoint != b.codepoint {
                return false;
            }
        }
    }

    return true;
}

SHORTCUT_COUNT_MAX :: 8;
Shortcut :: struct {
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

        // TODO(jt): @Cleanup @Hack The 'it == a.count - 1' is here to make M-< and M-> work. To
        // produce < and >, we need to press shift on en-us, but that's an additional modifier. We
        // should really think more carefully about this whole system.  -jt, 4 August 2026
        if !shortcut_key_equals_nocase(key_a, key_b, it == a.count - 1) {
            return false;
        }
    }

    return true;
}

// Parses stuff like "n" or "C-x" or "C-S-M <up>" into a shortcut sequence.
// Note that modifiers (C/M/S) can not stand on their own - they'll just be parsed as the literal letters C/M/S.
shortcut_parse :: (_s: string) -> success: bool, Shortcut {
    shortcut: Shortcut;

    s := _s;
    while s.count {
        _, left, right := String.split_from_left(s, #char " ");

        key: Shortcut_Key;

        dash_found, l, r := String.split_from_left(left, #char "-");
        while dash_found {
            if l == {
                case "Ctrl";   #through;
                case "C";      key.modifier_flags |= .CTRL;
                case "Alt";    #through;
                case "M";      key.modifier_flags |= .ALT;
                case "Shift";  #through;
                case "S";      key.modifier_flags |= .SHIFT;
                case "Meta";   #through;
                case "Cmd";    #through;
                case "X";      key.modifier_flags |= .META;

                case; return false, shortcut;
            }

            if r == "-" {
                // Allow things like "C--" where the last dash is not a separator.
                dash_found = false;
                l = r;
                r = "";
            } else {
                dash_found, l, r = String.split_from_left(r, #char "-");
            }
        }

        if l == {
            case "<up>";         key.type = .KEY; key.key = .ARROW_UP;
            case "<down>";       key.type = .KEY; key.key = .ARROW_DOWN;
            case "<left>";       key.type = .KEY; key.key = .ARROW_LEFT;
            case "<right>";      key.type = .KEY; key.key = .ARROW_RIGHT;

            case "<space>";      key.type = .CODEPOINT; key.codepoint = .SPACEBAR;
            case "<tab>";        key.type = .CODEPOINT; key.codepoint = .TAB;

            case "<backspace>";  key.type = .CODEPOINT; key.codepoint = .BACKSPACE;
            case "<enter>";      key.type = .CODEPOINT; key.codepoint = .ENTER;
            case "<escape>";     key.type = .CODEPOINT; key.codepoint = .ESCAPE;
            case "<delete>";     key.type = .CODEPOINT; key.codepoint = .DELETE;

            case "<home>";       key.type = .KEY; key.key = .HOME;
            case "<end>";        key.type = .KEY; key.key = .END;

            case "<prior>";      #through;
            case "<pageup>";     key.type = .KEY; key.key = .PAGE_UP;
            case "<next>";       #through;
            case "<pagedown>";   key.type = .KEY; key.key = .PAGE_DOWN;

            case "<f1>";         key.type = .KEY; key.key = .F1;
            case "<f2>";         key.type = .KEY; key.key = .F2;
            case "<f3>";         key.type = .KEY; key.key = .F3;
            case "<f4>";         key.type = .KEY; key.key = .F4;
            case "<f5>";         key.type = .KEY; key.key = .F5;
            case "<f6>";         key.type = .KEY; key.key = .F6;
            case "<f7>";         key.type = .KEY; key.key = .F7;
            case "<f8>";         key.type = .KEY; key.key = .F8;
            case "<f9>";         key.type = .KEY; key.key = .F9;
            case "<f10>";        key.type = .KEY; key.key = .F10;
            case "<f11>";        key.type = .KEY; key.key = .F11;
            case "<f12>";        key.type = .KEY; key.key = .F12;
            case; {
                c := Unicode.character_utf8_to_utf32(l.data, l.count);
                key.type = .CODEPOINT;
                key.codepoint = cast(Codepoint, c);
            }
        }

        shortcut.sequence[shortcut.count] = key;
        shortcut.count += 1;

        s = right;
    }

    return true, shortcut;
}

shortcut_begins_with_nocase :: (shortcut: Shortcut, prefix: Shortcut) -> bool {
    if prefix.count > shortcut.count {
        return false;
    }

    for 0..prefix.count - 1 {
        key_a := shortcut.sequence[it];
        key_b := prefix.sequence[it];

        if !shortcut_key_equals_nocase(key_a, key_b, it == prefix.count - 1) {
            return false;
        }
    }

    return true;
}

shortcut_print_to_builder :: (shortcut: Shortcut, sb: *String_Builder) {
    for 0..shortcut.count - 1 {
        key := shortcut.sequence[it];

        if key.modifier_flags & .CTRL   append(sb, "Ctrl-");
        if key.modifier_flags & .ALT    append(sb, "Alt-");
        if key.modifier_flags & .SHIFT  append(sb, "Shift-");
        if key.modifier_flags & .META   append(sb, "Meta-");

        if key.type == {
            case .KEY; {
                if key.key == {
                    case .ARROW_UP;      append(sb, "<up>");
                    case .ARROW_DOWN;    append(sb, "<down>");
                    case .ARROW_LEFT;    append(sb, "<left>");
                    case .ARROW_RIGHT;   append(sb, "<right>");

                    case .HOME;          append(sb, "<home>");
                    case .END;           append(sb, "<end>");

                    case .PAGE_UP;       append(sb, "<pageup>");
                    case .PAGE_DOWN;     append(sb, "<pagedown>");

                    case .F1;            append(sb, "<f1>");
                    case .F2;            append(sb, "<f2>");
                    case .F3;            append(sb, "<f3>");
                    case .F4;            append(sb, "<f4>");
                    case .F5;            append(sb, "<f5>");
                    case .F6;            append(sb, "<f6>");
                    case .F7;            append(sb, "<f7>");
                    case .F8;            append(sb, "<f8>");
                    case .F9;            append(sb, "<f9>");
                    case .F10;           append(sb, "<f10>");
                    case .F11;           append(sb, "<f11>");
                    case .F12;           append(sb, "<f12>");

                    case;                append(sb, "<unknown>");
                }
            }

            case .CODEPOINT; {
                if key.codepoint == {
                    case .SPACEBAR;      append(sb, "<space>");
                    case .TAB;           append(sb, "<tab>");

                    case .BACKSPACE;     append(sb, "<backspace>");
                    case .ENTER;         append(sb, "<enter>");
                    case .ESCAPE;        append(sb, "<escape>");
                    case .DELETE;        append(sb, "<delete>");

                    case; {
                        buf: [4] u8;
                        s: string;
                        s.data = buf.data;

                        Unicode.character_utf32_to_utf8(cast(u32, key.codepoint), *s);

                        append(sb, s);
                    }
                }
            }
        }

        if it < shortcut.count - 1 {
            append(sb, " ");
        }
    }
}

shortcut_sprint :: (shortcut: Shortcut) -> string {
    b: String_Builder;
    b.allocator = temp;

    shortcut_print_to_builder(shortcut, *b);

    s := builder_to_string(*b);

    return s;
}

// Note that key_map_input needs to return something even if it doesn't match an action. It will
// return the default value of T when nothing is matched. You can detect that by making sure the
// default value is not something you'd otherwise want to see, e.g. a .NONE value of an enum.
Key_Map :: struct (T: Type) {
    allocator: Allocator; // Set this before use if you don't want the default. Will propagate to underlying arrays.

    registered: [..] Pair;

    buffered_input: Shortcut;
    
    Pair :: struct {
        shortcut: Shortcut;
        action:   T;
    }
}

key_map_reserve :: (key_map: *Key_Map, size: s64) {
    InitAllocators(key_map);
    array_reserve(*key_map.registered, size);
}

key_map_reset_keeping_memory :: (key_map: *Key_Map) {
    array_reset_keeping_memory(*key_map.registered);
    key_map_flush(key_map);
}

key_map_find_shortcut :: (key_map: Key_Map($T), action: T) -> Shortcut {
    for key_map.registered {
        if it.action == action {
            return it.shortcut;
        }
    }

    return default_of(Shortcut);
}

key_map_add :: (key_map: *Key_Map($T), shortcut_string: string, action: T) {
    success, shortcut := shortcut_parse(shortcut_string);
    if success {
        key_map_add(key_map, shortcut, action);
    } else {
        log_error("Failed to parse and register shortcut % -> %", shortcut_string, action);
    }
}

// TODO(jt): We should validate against:
//
// - One keyboard shortcut being a prefix of another
// - One keyboard shortcut requiring a subset of the modifier keys of another in a branching
//   place, e.g.: 'C-M-x a' vs 'C-x a' or 'C-M-y' vs 'M-y'.
//
// The second one is only because of shift-selecting, and maybe we want to instead bind a
// different move action when shift is held:
//
// - C-S-n, S-<down>: MOVE_DOWN_KEEPING_SELECTION
// - C-n, <down>:     MOVE_DOWN
//
key_map_add :: (key_map: *Key_Map($T), shortcut: Shortcut, action: T) {
    InitAllocators(key_map);
    array_add(*key_map.registered, { shortcut, action });
}

key_map_sprint :: (key_map: Key_Map) -> string {
    b: String_Builder;
    b.allocator = temp;

    for key_map.registered {
        shortcut_print_to_builder(it.shortcut, *b);
        print(*b, "    %\n", it.action);
    }

    s := builder_to_string(*b);

    return s;
}

key_map_flush :: (key_map: *Key_Map) {
    key_map.buffered_input = {};
}

key_map_input :: (key_map: *Key_Map($T), event: Input_Event) -> buffered: bool, action: T {
    // Do nothing, if we haven't got shortcuts to compare against.
    if !key_map.registered.count {
        return false, default_of(T);
    }

    if is_modifier_key_event(event) {
        return true, default_of(T);
    }

    if event.flags & .PRESSED {
        if key_map.buffered_input.count == SHORTCUT_COUNT_MAX {
            // This should not happen, because if no action matched last time, we should have flushed.
            sanity_assert(false);
            key_map.buffered_input = {};
        }

        key: Shortcut_Key;
        key.modifier_flags = event.modifiers;
        key.type = event.type;
        key.data = event.data;

        key_map.buffered_input.sequence[key_map.buffered_input.count] = key;
        key_map.buffered_input.count += 1;

        has_candidates := false;
        for key_map.registered {
            if shortcut_begins_with_nocase(it.shortcut, key_map.buffered_input) {
                has_candidates = true;
            }

            if shortcut_equals_nocase(it.shortcut, key_map.buffered_input) {
                key_map.buffered_input = {};
                return false, it.action;
            }
        }

        if has_candidates {
            return true, default_of(T);
        } else {
            key_map.buffered_input = {};
            return false, default_of(T);
        }
    }

    return false, default_of(T);
}

#scope_file

InitAllocators :: (key_map: *Key_Map) #expand {
    if !key_map.allocator.proc {
        remember_allocators(key_map);
    }

    if !key_map.registered.allocator.proc {
        key_map.registered.allocator = key_map.allocator;
    }
}

is_modifier_key_event :: (event: Input_Event) -> bool {
    if event.type == {
        case .KEY; {
            if event.key == {
                case .CTRL;   return true;
                case .ALT;    return true;
                case .SHIFT;  return true;
                case .META;   return true;
            }
        }
    }

    return false;
}

// TODO(jt): @Cleanup default_of may become a JAI builtin and we can remove ours.
default_of :: ($T: Type) -> T #expand {
    value: T;
    return value;
}
