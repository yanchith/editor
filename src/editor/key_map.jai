// TODO(jt): @Cleanup There is some overlap between key_map.jai and input.jai, for instance we
// consume some types from input here. Should we attempt to unify?

Action :: enum u32 {
    NONE;

    MOVE_UP;
    MOVE_DOWN;
    MOVE_LEFT;
    MOVE_RIGHT;
}

SHORTCUT_COUNT_MAX :: 8;
Shortcut :: struct {
    // TODO(jt): Could use an inline array structure here?
    sequence:  [SHORTCUT_COUNT_MAX] Key;
    count:     s64;

    Key :: struct {
        modifier_flags: Modifier_Flags;
        type: Input_Event.Type;
        data: Input_Event.Data;
    }

    #assert size_of(Key) == 8;

    Modifier_Flags :: enum_flags u16 {
        NONE :: 0;

        CTRL  :: 0x01;
        ALT   :: 0x02;
        SHIFT :: 0x04;
        META  :: 0x08;
    }
}

Key_Map :: struct {
    // XXX: Do this allocator spread thingu in text_buffer too, so we don't have to init?
    allocator: Allocator; // Will spread to all key map datastructures.
    registered_shortcuts: [..] Shortcut;
    registered_actions:   [..] Action;

    buffered_input: Shortcut;
    buffered_modifier_flags: Shortcut.Modifier_Flags;
}

// You don't have to call init. It only pre-sizes the arrays. If you plan to set the allocator, do
// it before calling init.
key_map_init :: (key_map: *Key_Map, size: s64) {
    InitAllocators(key_map);
    array_reserve(key_map.registered_shortcuts, size);
    array_reserve(key_map.registered_actions, size);
}

key_map_register :: (key_map: *Key_Map, shortcut: Shortcut, action: Action) {
    InitAllocators(key_map);
    array_add(*key_map.registered_shortcuts, shortcut);
    array_add(*key_map.registered_actions, action);
}

key_map_input :: (key_map: *Key, event: Input_Event) -> buffered: bool, action: Action {
    // Do nothing, if we haven't got shortcuts to compare against.
    if !key_map.registered_shortcuts.count {
        return false, .NONE;
    }

    modifier_flags := get_modifier_flags(event);
    if modifier_flags != .NONE {
        if event.flags & .KEY_PRESSED {
            key_map.buffered_modifier_flags |= modifier_flags;
        } else {
            key_map.buffered_modifier_flags &= ~modifier_flags;
        }
    } else {
        if key_map.buffered_input.count == SHORTCUT_MAX_COUNT {
            // This should not happen, because if no action matched last time, we should have flushed.
            sanity_assert(false);
            key_map.buffered_input = {};
        }

        key: Key;
        key.modifier_flags = buffered_modifier_flags;
        key.type = event.type;
        key.data = event.data;

        key_map.buffered_input.sequence[key_map.buffered_input.count] = key;
        key_map.buffered_input.count += 1;

        has_candidates := false;
        for key_map.registered_shortcuts {
            if shortcut_begins_with(it, key_map.buffered_input) {
                has_candidates = true;
            }

            if it == key_map.buffered_input {
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

get_modifier_flags :: inline (event: Input_Event) -> Shortcut.Modifier_Flags {
    modifiers_flags: Modifier_Flags;
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
