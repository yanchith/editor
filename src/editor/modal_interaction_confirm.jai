//
// A generic confirm dialog. You supply the text and the proc, and it executes.
//

modal_interaction_confirm_procs: Modal_Interaction_Procs = {
    get_action_text,
    init,
    handle_event,
    advance,
    cancel,
};

Modal_Interaction_Confirm_Params :: struct {
    text: string;
    proc: (editor: *Editor, plaform: Platform, input: Input, userdata: *void);
    userdata: *void; // Will be passed to the proc.
}

#scope_file

Confirm_Userdata :: struct {
    params: *Modal_Interaction_Confirm_Params;
    key_map: Key_Map(Action);
    
    Action :: enum {
        NONE;
        
        CONFIRM;
        CANCEL;
    }
}

get_action_text :: (editor: *Editor, platform: Platform, input: Input) -> /* Temporary_Storage */ string {
    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return "";
    }

    userdata: *Confirm_Userdata = mi.userdata;
    
    return tprint("% (y: yes, n: no)", userdata.params.text);
}

init :: (editor: *Editor, platform: Platform, input: Input, params: *void) {
    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return;
    }
    
    userdata := arena_push(mi.arena, Confirm_Userdata);
    userdata.params = params;
    userdata.key_map.allocator = arena_allocator(mi.arena);
    key_map_reserve(*userdata.key_map, 8);
    
    key_map_add(*userdata.key_map, "y",   .CONFIRM);
    key_map_add(*userdata.key_map, "n",   .CANCEL);
    key_map_add(*userdata.key_map, "q",   .CANCEL);
    
    // Inherit confirm/cancel from modal interaction keymap
    for mi.key_map.registered {
        if it.action == {
            case .CONFIRM;                   key_map_add(*userdata.key_map, it.shortcut, .CONFIRM);
            case .CANCEL_OR_STOP_SELECTING;  key_map_add(*userdata.key_map, it.shortcut, .CANCEL);
        }
    }

    mi.userdata = userdata;
}

handle_event :: (editor: *Editor, event: Input_Event, platform: Platform, input: Input) -> handled: bool {
    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return false;
    }
    
    userdata: *Confirm_Userdata = mi.userdata;
    
    _, action := key_map_input(*userdata.key_map, event);
    if action == .CONFIRM {
        userdata.params.proc(editor, platform, input, userdata.params.userdata);
    }
    
    if action != .NONE {
        close_modal_interaction(editor, platform, input);
    }
    
    return true;
}

advance :: (editor: *Editor, platform: Platform, input: Input) {
    // Because handle_event almost unconditionally returns handled=true, we shouldn't normally
    // get here, but in case we do, we still do the right thing.

    mi := *editor.modal_interaction;
    sanity_assert(mi.open);
    if !mi.open {
        return;
    }
    
    userdata: *Confirm_Userdata = mi.userdata;
    
    userdata.params.proc(editor, platform, input, userdata.params.userdata);

    close_modal_interaction(editor, platform, input);
}

cancel :: (editor: *Editor, platform: Platform, input: Input) {
    close_modal_interaction(editor, platform, input);
}