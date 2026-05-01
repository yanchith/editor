Action :: enum u32 {
    NONE;

    //
    // Mini panel stuff
    //

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

    MINI_PANEL_AUTOCOMPLETE;

    MINI_PANEL_CONFIRM;
    MINI_PANEL_CANCEL;

    //
    // Modal interaction stuff
    //

    MODAL_INTERACTION_CANCEL;

    //
    // Mega panel stuff
    //

    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;

    SEARCH;
    SEARCH_AND_REPLACE;

    OPEN_FILE;
    SAVE_FILE;

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

    INSERT_TAB;

    UNDO_EDIT;
    REDO_EDIT;

    COPY;
    CUT;
    PASTE;
}

Action_Kind :: enum {
    OTHER :: 0;
    MOVE  :: 1;
    EDIT  :: 2;
}

action_classify :: (action: Action) -> Action_Kind {
    if #complete action == {
        case .NONE;                              return .OTHER;

        //
        // Mini panel stuff
        //

        case .MINI_PANEL_MOVE_UP;                return .MOVE;
        case .MINI_PANEL_MOVE_DOWN;              return .MOVE;
        case .MINI_PANEL_MOVE_LEFT;              return .MOVE;
        case .MINI_PANEL_MOVE_RIGHT;             return .MOVE;

        case .MINI_PANEL_MOVE_FORWARD_WORD;      return .MOVE;
        case .MINI_PANEL_MOVE_BACKWARD_WORD;     return .MOVE;

        case .MINI_PANEL_MOVE_TO_START_OF_LINE;  return .MOVE;
        case .MINI_PANEL_MOVE_TO_END_OF_LINE;    return .MOVE;

        case .MINI_PANEL_DELETE_FORWARD;         return .EDIT;
        case .MINI_PANEL_DELETE_BACKWARD;        return .EDIT;

        case .MINI_PANEL_SCROLL_UP;              return .MOVE;
        case .MINI_PANEL_SCROLL_DOWN;            return .MOVE;

        case .MINI_PANEL_AUTOCOMPLETE;           return .EDIT;

        case .MINI_PANEL_CONFIRM;                return .OTHER;
        case .MINI_PANEL_CANCEL;                 return .OTHER;

        //
        // Modal interaction stuff
        //
        // TODO(jt): @Cleanup None of the modal interaction stuff makes sense to classify. Should we
        // break this up into multiple enums somehow?

        case .MODAL_INTERACTION_CANCEL;          return .OTHER;

        //
        // Mega panel stuff
        //

        case .MOVE_UP;                           return .MOVE;
        case .MOVE_DOWN;                         return .MOVE;
        case .MOVE_LEFT;                         return .MOVE;
        case .MOVE_RIGHT;                        return .MOVE;

        case .SEARCH;                            return .OTHER;
        case .SEARCH_AND_REPLACE;                return .OTHER;

        case .OPEN_FILE;                         return .OTHER;
        case .SAVE_FILE;                         return .OTHER;

        case .SWITCH_TO_DOCUMENT;                return .OTHER;
        case .CLOSE_DOCUMENT;                    return .OTHER;

        case .SWAP_LINE_UP;                      return .EDIT;
        case .SWAP_LINE_DOWN;                    return .EDIT;

        case .MOVE_TO_START_OF_LINE;             return .MOVE;
        case .MOVE_TO_END_OF_LINE;               return .MOVE;

        case .MOVE_TO_START_OF_DOCUMENT;         return .MOVE;
        case .MOVE_TO_END_OF_DOCUMENT;           return .MOVE;

        case .MOVE_TO_PREVIOUS_BLANK_LINE;       return .MOVE;
        case .MOVE_TO_NEXT_BLANK_LINE;           return .MOVE;

        case .MOVE_FORWARD_WORD;                 return .MOVE;
        case .MOVE_BACKWARD_WORD;                return .MOVE;

        case .RECENTER;                          return .MOVE;
        case .SCROLL_UP;                         return .MOVE;
        case .SCROLL_DOWN;                       return .MOVE;

        case .START_SELECTING;                   return .OTHER;
        case .STOP_SELECTING;                    return .OTHER;

        case .DELETE_LINE;                       return .EDIT;
        case .DELETE_FORWARD;                    return .EDIT;
        case .DELETE_BACKWARD;                   return .EDIT;

        case .DELETE_FORWARD_WORD;               return .EDIT;
        case .DELETE_BACKWARD_WORD;              return .EDIT;

        case .INSERT_LINE_BEFORE;                return .EDIT;
        case .INSERT_LINE_AFTER;                 return .EDIT;

        case .INSERT_TAB;                        return .EDIT;

        case .UNDO_EDIT;                         return .EDIT;
        case .REDO_EDIT;                         return .EDIT;

        case .COPY;                              return .OTHER;
        case .CUT;                               return .EDIT;
        case .PASTE;                             return .EDIT;
    }
}

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

shortcut_key_equals_nocase :: (a: Shortcut_Key, b: Shortcut_Key, allow_superset_b_modifiers: bool) -> bool {
    if allow_superset_b_modifiers {
        MODIFIERS :: Modifier_Flags.[.CTRL, .ALT, .SHIFT, .META];
        for MODIFIERS {
            a_has := a.modifier_flags & it;
            b_has := b.modifier_flags & it;

            if a_has && !b_has {
                return false;
            }
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
                case "C"; key.modifier_flags |= .CTRL;
                case "M"; key.modifier_flags |= .ALT;
                case "S"; key.modifier_flags |= .SHIFT;
                case "X"; key.modifier_flags |= .META;

                case; return false, shortcut;
            }

            dash_found, l, r = String.split_from_left(r, #char "-");
        }

        if l == {
            case "<up>";         key.type = .KEY; key.key = .ARROW_UP;
            case "<down>";       key.type = .KEY; key.key = .ARROW_DOWN;
            case "<left>";       key.type = .KEY; key.key = .ARROW_LEFT;
            case "<right>";      key.type = .KEY; key.key = .ARROW_RIGHT;

            case "<space>";      key.type = .CODEPOINT; key.codepoint = .SPACEBAR;
            case "<tab>";        key.type = .CODEPOINT; key.codepoint = .TAB;

            case "<enter>";      key.type = .CODEPOINT; key.codepoint = .ENTER;
            case "<delete>";     key.type = .CODEPOINT; key.codepoint = .DELETE;
            case "<backspace>";  key.type = .CODEPOINT; key.codepoint = .BACKSPACE;

            case "<home>";       key.type = .KEY; key.key = .HOME;
            case "<end>";        key.type = .KEY; key.key = .END;

            case "<prior>";     #through;
            case "<pageup>";    key.type = .KEY; key.key = .PAGE_UP;
            case "<next>";      #through;
            case "<pagedown>";  key.type = .KEY; key.key = .PAGE_DOWN;

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

shortcut_print_to_builder :: (shortcut: Shortcut, b: *String_Builder) {
    for 0..shortcut.count - 1 {
        key := shortcut.sequence[it];

        if key.modifier_flags & .CTRL  print(b, "C-");
        if key.modifier_flags & .ALT   print(b, "M-");
        if key.modifier_flags & .SHIFT print(b, "S-");
        if key.modifier_flags & .META  print(b, "X-");

        if key.type == {
            case .KEY; {
                if key.key == {
                    case .ARROW_UP;      print(b, "<up>");
                    case .ARROW_DOWN;    print(b, "<down>");
                    case .ARROW_LEFT;    print(b, "<left>");
                    case .ARROW_RIGHT;   print(b, "<right>");

                    case .HOME;          print(b, "<home>");
                    case .END;           print(b, "<end>");

                    case .PAGE_UP;       print(b, "<pageup>");
                    case .PAGE_DOWN;     print(b, "<pagedown>");

                    case .F1;            print(b, "<f1>");
                    case .F2;            print(b, "<f2>");
                    case .F3;            print(b, "<f3>");
                    case .F4;            print(b, "<f4>");
                    case .F5;            print(b, "<f5>");
                    case .F6;            print(b, "<f6>");
                    case .F7;            print(b, "<f7>");
                    case .F8;            print(b, "<f8>");
                    case .F9;            print(b, "<f9>");
                    case .F10;           print(b, "<f10>");
                    case .F11;           print(b, "<f11>");
                    case .F12;           print(b, "<f12>");

                    case;                print(b, "<unknown>");
                }
            }

            case .CODEPOINT; {
                if key.codepoint == {
                    case .SPACEBAR;      print(b, "<space>");
                    case .TAB;           print(b, "<tab>");

                    case .ENTER;         print(b, "<enter>");
                    case .DELETE;        print(b, "<delete>");
                    case .BACKSPACE;     print(b, "<backspace>");

                    case; {
                        buf: [4] u8;
                        s: string;
                        s.data = buf.data;

                        Unicode.character_utf32_to_utf8(cast(u32, key.codepoint), *s);

                        print(b, s);
                    }
                }
            }
        }

        print(b, " ");
    }
}

shortcut_sprint :: (shortcut: Shortcut) -> string {
    b: String_Builder;
    b.allocator = temp;

    shortcut_print_to_builder(shortcut, *b);

    s := builder_to_string(*b);

    return s;
}

Key_Map :: struct {
    allocator: Allocator; // Will spread to all key map datastructures.

    registered_shortcuts: [..] Shortcut;
    registered_actions:   [..] Action;

    buffered_input: Shortcut;
}

key_map_reserve :: (key_map: *Key_Map, size: s64) {
    InitAllocators(key_map);
    array_reserve(*key_map.registered_shortcuts, size);
    array_reserve(*key_map.registered_actions, size);
}

key_map_reset_keeping_memory :: (key_map: *Key_Map) {
    array_reset_keeping_memory(*key_map.registered_shortcuts);
    array_reset_keeping_memory(*key_map.registered_actions);

    key_map_flush(key_map);
}

key_map_add :: (key_map: *Key_Map, shortcut_string: string, action: Action) {
    success, shortcut := shortcut_parse(shortcut_string);
    if success {
        key_map_add(key_map, shortcut, action);
    } else {
        log_error("Failed to parse and register shortcut % -> %", shortcut_string, action);
    }
}

key_map_add :: (key_map: *Key_Map, shortcut: Shortcut, action: Action) {
    InitAllocators(key_map);

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

    array_add(*key_map.registered_shortcuts, shortcut);
    array_add(*key_map.registered_actions, action);
}

key_map_sprint :: (key_map: Key_Map) -> string {
    b: String_Builder;
    b.allocator = temp;

    for 0..key_map.registered_shortcuts.count - 1 {
        shortcut := key_map.registered_shortcuts[it];
        action   := key_map.registered_actions[it];

        shortcut_print_to_builder(shortcut, *b);
        print(*b, "    %\n", action);
    }

    s := builder_to_string(*b);

    return s;
}

key_map_flush :: (key_map: *Key_Map) {
    key_map.buffered_input = {};
}

key_map_input :: (key_map: *Key_Map, event: Input_Event, modifier_flags: Modifier_Flags) -> buffered: bool, action: Action {
    // Do nothing, if we haven't got shortcuts to compare against.
    if !key_map.registered_shortcuts.count {
        return false, .NONE;
    }

    if is_modifier_key_event(event) {
        return true, .NONE;
    }

    if event.flags & .PRESSED {
        if key_map.buffered_input.count == SHORTCUT_COUNT_MAX {
            // This should not happen, because if no action matched last time, we should have flushed.
            sanity_assert(false);
            key_map.buffered_input = {};
        }

        key: Shortcut_Key;
        key.modifier_flags = modifier_flags;
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
