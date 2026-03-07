#import "X11";
#import "String";  // @Cleanup: Remove this dependency on String?

set_custom_cursor_handling :: (is_custom: bool) {
    // @Incomplete: Implement this.
    // Use this if you are doing immediate-mode API stuff that sets cursors and want to prevent cursors from flickering. Windows is annoying to interface with.
}

get_key_code :: (key: KeySym) -> Key_Code {
    // Modified get_key_code() by Vladislav Morozov,
    // subject to CC0 1.0 Universal.

    using Key_Code;
    // non-ascii ordered as in ./module.jai/Key_Code
    if key == XK_BackSpace
        return BACKSPACE;
    if key == XK_Tab || key == XK_KP_Tab || key == XK_ISO_Left_Tab
        return TAB;
    if key == XK_Return
        return ENTER;
    if key == XK_Escape
        return ESCAPE;

    if key == 32 || key == XK_KP_Space return SPACEBAR;


    if key == XK_Delete || key == XK_KP_Delete
        return DELETE;


    if key == XK_Up || key == XK_KP_Up
        return ARROW_UP;
    if key == XK_Down || key == XK_KP_Down
        return ARROW_DOWN;
    if key == XK_Left || key == XK_KP_Left
        return ARROW_LEFT;
    if key == XK_Right || key == XK_KP_Right
        return ARROW_RIGHT;


    if key == XK_Page_Up || key == XK_KP_Page_Up
        return PAGE_UP;
    if key == XK_Page_Down || key == XK_KP_Page_Down
        return PAGE_DOWN;


    if key == XK_Home || key == XK_KP_Home
        return HOME;
    if key == XK_End || key == XK_KP_End
        return END;

    if key == XK_Insert || key == XK_KP_Insert
        return INSERT;


    if key == XK_Pause
        return PAUSE;
    if key == XK_Scroll_Lock
        return SCROLL_LOCK;

    if (key == XK_Alt_L) || (key == XK_Alt_R) || (key == XK_ISO_Level3_Shift) 
        return ALT;
    if (key == XK_Control_L) || (key == XK_Control_R)
        return CTRL;
    if (key == XK_Shift_L) || (key == XK_Shift_R)
        return SHIFT;
    if     (key == XK_Meta_L)  || (key == XK_Meta_R)
        || (key == XK_Super_L) || (key == XK_Super_R)
        || (key == XK_Hyper_L) || (key == XK_Hyper_R)
        return META;


    if key >= XK_F1 && key <= XK_F24
        return (cast(Key_Code) (key - XK_F1))+F1;


    if key == XK_Print
        return PRINT_SCREEN;


    if key == XK_Menu
        return UNKNOWN;

    key = key & 0xFF; // @Cleanup Why is this here? (It mapped Menu to "G". What else?)
    if (key >= #char "a") && (key <= #char "z") return cast(Key_Code) (key - 0x20);
    if key > 32 && key < 127 return cast(Key_Code) key;

    return UNKNOWN;
}

#scope_file

// Xdnd support by Jens Frederich. Send questions his way. Licensed under the MIT license; see copyright at the end of the file.

get_position_root_x :: inline (xevent: *XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] >> 16;
}

get_position_root_y :: inline (xevent: *XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] & 0xffff;
}

apply_position :: (dnd: *Xdnd_Context, widget: Window, from: Window, action: Atom, x: s32, y: s32, time: Time, typelist: [] Atom, want_position: *bool, supported_action_return: *Atom, desired_type: *Atom, rectangle: *XRectangle) -> bool {
    supported_type: Atom;
    supported_action: Atom;

    dropper_typelist  := drop_info.user_typelist;
    supported_actions := drop_info.user_actions;

    if dropper_typelist.count > 0 {
        // find a correlation:
        for j: dropper_typelist {
            for i: typelist {
                if i == j {
                    supported_type = i;
                    break;
                }
            }
        }
    } else {
        // user did not specify, so return first type
        supported_type = typelist[0];
    }

    // not supported, so return false
    if !supported_type  return false;

    if supported_actions.count > 0 {
        for supported_actions {
            if action == it {
                supported_action = action;
                break;
            }
        }
    } else {
        // user did not specify
        if action == XdndActionCopy  supported_action = action;
    }

    if !supported_action  return false;

    want_position.* = true;
    rectangle.x = 0;
    rectangle.y = 0;
    rectangle.width = 0;
    rectangle.height = 0;

    drop_info.return_action   = supported_action;
    supported_action_return.* = supported_action;
    drop_info.return_type = supported_type;
    desired_type.* = supported_type;
    drop_info.x = x;
    drop_info.y = y;

    return true;
}

send_finished :: (display: *Display, window: Window, from: Window) {
    xevent: XEvent;
    xevent.xany.type = ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = XdndFinished;
    xevent.xclient.format = 32;

    // target window
    xevent.xclient.data.l[0] = cast(s64) from;

    XSendEvent(display, window, 0, 0, *xevent);
}

send_status :: (display: *Display, window: Window, from: Window, will_accept: bool, want_position: bool, x: int, y: int, w: int, h: int, action: Atom) {
    xevent: XEvent;
    xevent.xany.type = ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = XdndStatus;
    xevent.xclient.format = 32;

    // Our window
    xevent.xclient.data.l[0] = cast(s64) from;

    // will accept yes no
    xevent.xclient.data.l[1] = (xevent.xclient.data.l[1] & ~0x1) | ifx will_accept then 1 else 0;

    // want position?
    if will_accept  xevent.xclient.data.l[1] = (xevent.xclient.data.l[1] & ~0x2) | ifx want_position then 2 else 0;

    if want_position {
        xevent.xclient.data.l[2] = (x << 16) | (y & 0xffff);
        xevent.xclient.data.l[3] = (w << 16) | (h & 0xffff);
    }

    if will_accept  xevent.xclient.data.l[4] = cast(s64) action;

    XSendEvent(display, window, 0, 0, *xevent);
}

paste_property :: (display: *Display, from: Window, insert: Window, prop: u64, delete_prop: s64) -> bool {
    nread: s64;
    data_count: s64;
    bytes_after: s64;
    error: bool;

    array_reset(*drop_info.data);
    while true {
        actual_type: Atom;
        actual_fmt: s32;
        data: *u8;

        x := nread / 4;

        if XGetWindowProperty(display, insert, prop, xx x , 65536, xx delete_prop, AnyPropertyType, *actual_type, *actual_fmt, xx *data_count, xx *bytes_after, *data) != Success {
            XFree(data);
            return false;
        }

        nread += data_count;

        if (drop_info.data.count == 0) {
            array_reserve(*drop_info.data, data_count + bytes_after);
        }
        memcpy(drop_info.data.data + drop_info.data.count, data, data_count);
        drop_info.data.count += data_count;

        XFree(data);

        if bytes_after == 0  break;
    }

    if !nread  return false;

    return true;
}

get_selection :: (display: *Display, from: Window, prop: Atom, insert: Window) -> bool {
    if prop == None  return false;

    actual_type: Atom;
    actual_fmt: s32;
    nitems: u64;
    bytes_after: u64;
    s: *u8;
    if (XGetWindowProperty(display, insert, prop, 0, 8, False, AnyPropertyType, *actual_type, *actual_fmt, *nitems, *bytes_after, *s) != Success) {
        XFree(s);
        return false;
    }

    XFree(s);
    if actual_type != XInternAtom(display, "INCR", False) {
        return paste_property(display, from, insert, prop, True);
    }

    XDeleteProperty(display, insert, prop);

    /* @Cleanup: Get rid of fd_set stuff.
    time_start := seconds_since_init();
    while true {
        r: fd_set;
        xe: XEvent;
        if XCheckMaskEvent(display, PropertyChangeMask, *xe) {
            if xe.type == PropertyNotify && xe.xproperty.state == PropertyNewValue {
                // time between arrivals of data
                time_start = seconds_since_init();
                if paste_property(display, from, insert, prop, True)  break;
            }
        } else {
            FD_ZERO(*r);
            FD_SET(ConnectionNumber(display), *r);
            select(ConnectionNumber(display) + 1, *r, 0, 0, *tv);

            if FD_ISSET(ConnectionNumber(display), *r)  continue;
        }
        end := seconds_since_init();

        // no data for five seconds, so quit
        if end - start > 5000000  return false;
    }
    */
    return true;
}

maybe_handle_xdnd_drop_events :: (display: *Display, xevent: *XEvent, drop_info: *Drop_Info) -> bool {
    assert(xevent.type == ClientMessage);
    assert(xevent.xclient.message_type == XdndEnter);

    dnd := x_global_xdnd_context;
    dnd.root_window = DefaultRootWindow(display);

    while true {
        if xevent.type == ClientMessage {
            if xevent.xclient.message_type == XdndEnter {
                version := xevent.xclient.data.l[1] >> 24;
                if version < 3  return false;

                xdnd_context_reset(*dnd);
                dnd.dragger_window = cast(Window) xevent.xclient.data.l[0];
                dnd.dropper_toplevel = xevent.xany.window;
                dnd.dropper_window = 0;  // Enter goes to the top level window only, so we don't really know what the sub window is yet.

                support_more_than_three_types := xevent.xclient.data.l[1] & 0x1;
                if !support_more_than_three_types {
                    for 0..2 {
                        atom := cast(Atom) xevent.xclient.data.l[2 + it];
                        array_add(*dnd.dragger_typelist, atom);
                    }
                } else {
                    array_reset(*dnd.dragger_typelist);

                    type: Atom;
                    format: s32;
                    count, remaining: u64;
                    data: *u8 = null;
                    XGetWindowProperty(display, dnd.dragger_window, XdndTypeList, 0, 0x8000000, False, XA_ATOM, *type, *format, *count, *remaining, *data);

                    if type != XA_ATOM || format != 32 || count == 0 || data == null {
                        print("XGetWindowProperty failed in get type list\n");
                    }

                    atom_data: *Atom = cast(*Atom)data;
                    for 0..count {
                        array_add(*dnd.dragger_typelist, atom_data[it]);
                    }

                    XFree(data);
                }

                if dnd.dragger_typelist {
                    dnd.stage = Xdnd_Stage.DROP_ENTERED;
                } else {
                    print("      typelist returned as zero!\n");
                }
            } else if xevent.xclient.message_type == XdndLeave {
                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    dnd.stage = Xdnd_Stage.DROP_IDLE;
                    array_reset(*dnd.dragger_typelist);
                    dnd.dropper_toplevel = 0;
                    dnd.dropper_window = 0;
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == XdndPosition {
                action: Atom;
                rectangle: XRectangle;
                want_position: bool;
                last_window: Window;

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    last_window = dnd.dropper_window;

                    if xevent.xany.window != dnd.dropper_toplevel || !dnd.dropper_window {
                        dnd.dropper_toplevel = xevent.xany.window;
                        parent := dnd.root_window;
                        child := dnd.dropper_toplevel;
                        root_x := get_position_root_x(xevent);
                        root_y := get_position_root_y(xevent);

                        while true {
                            xd: s32;
                            yd: s32;
                            new_child: Window;
                            if !XTranslateCoordinates(display, parent, child, root_x, root_y, *xd, *yd, *new_child)  break;
                            if !new_child  break;

                            child = new_child;
                        }

                        dnd.dropper_window = child;
                        xevent.xany.window = child;
                    } else if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                        xevent.xany.window = dnd.dropper_window;
                    }

                    action := XdndActionCopy;
                    dnd.supported_action = XdndActionCopy;
                    dnd.x = get_position_root_x(xevent);
                    dnd.y = get_position_root_y(xevent);
                    dnd.time = CurrentTime;

                    dnd.will_accept = apply_position(*dnd, xevent.xany.window, dnd.dragger_window, action, dnd.x, dnd.y, dnd.time, dnd.dragger_typelist, *want_position, *dnd.supported_action, *dnd.desired_type, *rectangle);
                    send_status(display, dnd.dragger_window, dnd.dropper_toplevel, dnd.will_accept, want_position, rectangle.x, rectangle.y, rectangle.width, rectangle.height, dnd.supported_action);
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == XdndDrop {
                if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                    xevent.xany.window = dnd.dropper_window;
                }

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    dnd.time = CurrentTime;
                    if dnd.will_accept {
                        // convert selection
                        {
                            dnd.dragger_window = XGetSelectionOwner(display, XdndSelection);
                            if !dnd.dragger_window {
                                print(" XGetSelectionOwner failed\n");
                            } else {
                                XConvertSelection(display, XdndSelection, dnd.desired_type, x_global_non_protocol_atom, dnd.dropper_window, CurrentTime);
                            }
                        }

                        dnd.stage = Xdnd_Stage.DROP_CONVERTING;
                    } else {
                        print("    will_accept is false - sending finished\n");
                        send_finished(display, dnd.dragger_window, dnd.dropper_toplevel);

                        array_reset(*dnd.dragger_typelist);
                        xdnd_context_reset(*dnd);
                        dnd.stage = Xdnd_Stage.DROP_IDLE;
                    }
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            }
        } else if xevent.type == SelectionNotify {
            if xevent.xselection.property == x_global_non_protocol_atom && dnd.stage == Xdnd_Stage.DROP_CONVERTING {
                error := get_selection(display, dnd.dragger_window, xevent.xselection.property, xevent.xany.window);
                // Error is not actually used, I think future versions of the protocol maybe should return an error status to the calling window with the XdndFinished client message.

                send_finished(display, dnd.dragger_window, dnd.dropper_toplevel);

                array_reset(*dnd.dragger_typelist);
                xdnd_context_reset(*dnd);
                dnd.stage = Xdnd_Stage.DROP_IDLE;
            } else {
                print("  property is not Xdnd_NON_PROTOCOL_ATOM - ignoring\n");
            }
        }

        if dnd.stage == Xdnd_Stage.DROP_IDLE  break;

        XNextEvent(x_global_display, xevent);
    }

    if drop_info.data.count > 0 {
        files: [..] string;

        p: string = ---;
        p.data  = drop_info.data.data;
        p.count = drop_info.data.count;
        while true {
            uri_length := find_index_from_left(p, "\r\n");
            if uri_length == -1  break;

            // X gives URI like "file://[host]/path/to/file" instead of just path
            URI_PREFIX :: "file://";
            assert(begins_with(p, URI_PREFIX));
            // let's ignore this "file://" prefix
            file_name := slice(p, URI_PREFIX.count, uri_length - URI_PREFIX.count);
            assert(file_name.count > 0);

            advance(*p, uri_length + 2);

            if (file_name[0] != #char "/") {
                // URI seems to start with a hostname.
                log_error("Drag & drop for file URIs with hostnames is not yet supported. Ignoring \"%\".", slice(p, 0, uri_length));
                continue;
            }

            // Heap allocated like on Windows.
            array_add(*files, copy_string(file_name));
        }

        event: Event;
        event.type = .DRAG_AND_DROP_FILES;
        event.files = files;
        array_add(*events_this_frame, event);

        array_reset(*drop_info.data);
        return true;
    }

    return false;
}


update_x11_window_events :: () {
    using Key_Code;

    #if X11_ENABLE_TOUCH_INPUT  touch_init(); // We need to register for touch events to receive any, so this init can't just be done on receiving a touch event...

    input_per_frame_event_and_flag_update();

    display := x_global_display;
    XLockDisplay(display);

    key_press_repeat := false;
    while XPending(display) {
        xev: XEvent;
        XNextEvent(display, *xev);

        if XFilterEvent(*xev, None) continue;


        if xev.type == {
          case ClientMessage;
            message_type := xev.xclient.message_type;
            if message_type == XdndEnter {
                drop_handled := maybe_handle_xdnd_drop_events(display, *xev, *drop_info);
		        if drop_handled  continue;
            } else if message_type == x_global_wm_protocols {
                message0 := cast(Atom) xev.xclient.data.l[0];

                // This can't be a switch, because the values are not constant!
                // Except come on guys, every single implementation of X11 in the universe
                // is going to agree on these values. Why are we pretending they are not constant?
                // How about if we just look them up once and then hardcode them into this program?
                // We'd save startup time...

                if message0 == x_global_wm_delete_window {
                    event: Event;
                    event.type = .QUIT;
                    array_add(*events_this_frame, event);
                }
            }
        case KeyPress;
            event: Event;

            shift: u32;
            if xev.xkey.state & ShiftMask
                shift = 1;
            if xev.xkey.state & ControlMask
                event.ctrl_pressed = true;
            if xev.xkey.state & Mod1Mask
                event.alt_pressed = true;

            status: Status;
            keysym: KeySym;
            text: [16]u32;
            lookup_count := XwcLookupString(x_global_input_context, *xev.xkey, xx text.data, xx text.count, *keysym, *status);

            has_keysym := (status == XLookupKeySym || status == XLookupBoth);
            has_text := (status == XLookupChars || status == XLookupBoth);

            if has_keysym {
                if xev.xkey.state & ShiftMask   event.shift_pressed = true;
                if xev.xkey.state & ControlMask event.ctrl_pressed = true;
                if xev.xkey.state & Mod1Mask    event.alt_pressed = true;
                if xev.xkey.state & Mod4Mask    event.cmd_meta_pressed = true;

                event.type = .KEYBOARD;
                event.key_pressed = 1;
                event.key_code = get_key_code(keysym);

                for 0..lookup_count - 1 {
                    utf32 := text[it];
                    if utf32 >= 32 && utf32 != 127 event.text_input_count += 1;
                }
                
                if event.key_code == {
                    case .SHIFT; event.shift_pressed = true;
                    case .CTRL;  event.ctrl_pressed = true;
                    case .ALT;   event.alt_pressed = true;
                    case .META;  event.cmd_meta_pressed = true;
                }

                event.repeat = key_press_repeat;
                key_press_repeat = false;
                
                array_add(*events_this_frame, event);
                input_button_states[event.key_code] = .START | .DOWN;
            }

            event.shift_pressed = cast(bool) shift;

            if has_text {
                for 0..lookup_count - 1 {
                    utf32 := text[it];
                    if utf32 < 32 || utf32 == 127 continue;

                    char_event: Event;
                    char_event.type = .TEXT_INPUT;
                    char_event.key_pressed = 1;
                    char_event.key_code = get_key_code(keysym);
                    char_event.utf32 = utf32;

                    array_add(*events_this_frame, char_event);
                }
            }
        case KeyRelease;
            // For some odd reason X11 generates KeyRelease followed by a near identical KeyPress to simulate repeat events so we have to filter that out
            if XEventsQueued(display, QueuedAfterReading) {
                nev: XEvent;
                XPeekEvent(display, *nev);

                if nev.type == KeyPress
                    && nev.xkey.time == xev.xkey.time
                    && nev.xkey.keycode == xev.xkey.keycode {

                        // This is a repeat, so we ignore the KeyRelease and set the repeat flag.
                    key_press_repeat = true;
                    continue;
                }
            }

            event: Event;

            shift: u32;
            if xev.xkey.state & ShiftMask
                shift = 1;
            if xev.xkey.state & ControlMask
                event.ctrl_pressed = true;
            if xev.xkey.state & Mod1Mask
                event.alt_pressed = true;

            keysym := XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, 0 /* English lowercase group*/);
            event.type = .KEYBOARD;
            event.key_pressed = 0;
            event.shift_pressed = cast(bool) shift;
            event.key_code = get_key_code(keysym);
            
            input_button_states[event.key_code] = .END;

            array_add(*events_this_frame, event);
        case ButtonPress;
            event: Event;
            event.type = .KEYBOARD;

            event.key_pressed = 1;
            button := xev.xbutton.button;

            // 6/7 is horizontal/secondary wheel, don't handle it
            if (button == 6) || (button == 7) continue;

            // button 4/5 is mwheel up/down
            if (button == 4) || (button == 5) {
                event.type = .MOUSE_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = event.typical_wheel_delta * ifx button & 1 then cast(s32) - 1 else 1;
                array_add(*events_this_frame, event);
                mouse_delta_z += event.wheel_delta;
                continue;
            }
            
            if button == Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            input_button_states[event.key_code] = .START | .DOWN;

            array_add(*events_this_frame, event);
        case ButtonRelease;
            // it seems that mouse input doesnt generate repeat events so we dont have to peek the queue
            event: Event;
            event.type = .KEYBOARD;

            event.key_pressed = 0;
            button := xev.xbutton.button;

            if (button >= 4) && (button <= 7) continue;  // No action on button release of mouse wheels.
            
            if button == Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            input_button_states[event.key_code] = .END;

            array_add(*events_this_frame, event);
        case SelectionRequest;
            selreq := cast(*XSelectionRequestEvent) *xev;

            out: XEvent;
            selnot := cast(*XSelectionEvent) *out;
            selnot.type = SelectionNotify;
            selnot.requestor = selreq.requestor;
            selnot.selection = selreq.selection;
            selnot.target = selreq.target;
            selnot.time = selreq.time;
            selnot.property = None;

            if x_window_is_ours(x_global_display, selreq.owner) {
                if selreq.target == x_global_xa_utf8 {
                    selnot.property = selreq.property;

                    text_data := x_global_clipboard_buffer.text_data;
                    XChangeProperty(selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
                                    text_data.data, cast(s32) text_data.count);
                } else if selreq.target == x_global_xa_targets {

                    selnot.property = selreq.property;

                    atoms: [..] Atom;
                    array_add(*atoms, x_global_xa_utf8);
                    array_add(*atoms, x_global_xa_targets);
                    array_add(*atoms, x_global_xa_multiple);
                    if x_global_clipboard_buffer.rgb_data {
                        array_add(*atoms, x_global_image_bmp);
                    }
                    XChangeProperty(selreq.display, selreq.requestor, selreq.property, x_global_xa_atom, 32, PropModeReplace,
                                    xx atoms.data, cast(s32) atoms.count);

                    array_reset(*atoms);
                } else if selreq.target == x_global_image_bmp {
                    #import "stb_image_write";

                    Data :: struct {
                        _context: *#Context;
                        data: [..] u8;
                    }

                    write_func :: (data_pointer: *void, _data: *void, size: s32) #c_call {
                        data := cast(*Data) data_pointer;
                        push_context data._context.* {
                            data8 := cast(*u8) _data;
                            for 0..size-1 {
                                array_add(*data.data, data8[it]);
                            }
                        }
                    }

                    data: Data;
                    data._context = *context;
                    w := x_global_clipboard_buffer.width;
                    h := x_global_clipboard_buffer.height;
                    comp: s32 = 3;
                    stride := x_global_clipboard_buffer.pitch;
                    stbi_write_bmp_to_func(write_func, *data, w, h, comp, x_global_clipboard_buffer.rgb_data);

                    selnot.property = selreq.property;
                    XChangeProperty(selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
                                    xx data.data.data, cast(s32) data.data.count);

                    array_reset(*data.data);
                } else {
                    // print("GOT REQ: %\n", to_string(XGetAtomName(x_global_display, selreq.target)));
                }
            }

            XSendEvent(selreq.display, selreq.requestor, True, 0, *out);
        case ConfigureNotify;
            config := cast(*XConfigureEvent) *xev;
            add_resize_record(config.window, config.width, config.height);
        case FocusIn;
            input_application_has_focus = true;
        case FocusOut;
            input_application_has_focus = false;
        case GenericEvent;
            assert(xev.xcookie.type == GenericEvent);
            
            #if X11_ENABLE_TOUCH_INPUT {
                if !touch_supported  continue;

                if xev.xcookie.extension == touch_input_extension_opcode {
                    XGetEventData(display, *xev.xcookie);
                    defer XFreeEventData(display, *xev.xcookie);
                    if xev.xcookie.evtype == XI_TouchBegin || xev.xcookie.evtype == XI_TouchUpdate || xev.xcookie.evtype == XI_TouchEnd {
                        // print("Touch event recieved!\n");
                        
                        event := cast(*XIDeviceEvent) xev.xcookie.data;
                        if event.evtype == {
                            case XI_TouchBegin;
                            // print("Touch Begin: ID % at (%, %)\n", event.detail, event.event_x, event.event_y);
                            touch_event: Event;
                            touch_event.type = .TOUCH;
                            touch_event.touch_index = 0;
                            touch_event.touch_type = .PRESSED;
                            array_add(*events_this_frame, touch_event);

                            case XI_TouchUpdate;
                            // print("Touch Update: ID % at (%, %)\n", event.detail, event.event_x, event.event_y);
                            
                            case XI_TouchEnd;
                            // print("Touch End: ID %\n", event.detail);
                            touch_event: Event;
                            touch_event.type = .TOUCH;
                            touch_event.touch_index = 0;
                            touch_event.touch_type = .RELEASED;
                            array_add(*events_this_frame, touch_event);
                        }
                    }
                }
            }
        }
    }
    XUnlockDisplay(display);
}


#scope_export

WHEEL_DELTA :: 120;

update_window_events :: () {
    update_x11_window_events();
}

// @CopyPasta from Input/windows.jai
add_resize_record :: (hwnd: Window, width: s32, height: s32) {
    record: *Window_Resize_Record;
    for * pending_resizes {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_resizes);
    }

    record.window = hwnd;
    record.width = width;
    record.height = height;
}

#scope_file

#if X11_ENABLE_TOUCH_INPUT {
    touch_initted := false;
    touch_supported := false;
    touch_input_extension_opcode: s32;

    touch_init :: () {
        if touch_initted  return;
        touch_initted = true;
        
        print("touch_init()\n");

        display := x_global_display;
        assert(display != null);
        
        // Check for XInput2 support
        opcode, event, error: s32;
        if XQueryExtension(display, "XInputExtension", *opcode, *event, *error) {
            print("XInputExtension found with opcode %\n", opcode);
            // Check for XInput2 version
            major := cast(s32) 2;
            minor := cast(s32) 2;
            if XIQueryVersion(display, *major, *minor) == BadRequest {
                log_error("XInputExtension was available but not XI2. We need at least version 2.2 for touch input.");
            } else {
                print("XIQueryVersion succeeded with v%.%\n", major, minor);
                touch_supported = true;
                touch_input_extension_opcode = opcode;

                display := x_global_display;
                
                // Select input events for touch devices
                // This code is maybe analagous to the RegisterTouchWindow needed on windows?
                root := DefaultRootWindow(display);
                
                event_mask: XIEventMask;
                mask: [(XI_LASTEVENT + 7)/8] u8;
                event_mask.deviceid = XIAllDevices;
                event_mask.mask_len = size_of(type_of(mask));
                event_mask.mask = mask.data;
                XISetMask(mask.data, XI_TouchBegin);
                XISetMask(mask.data, XI_TouchUpdate);
                XISetMask(mask.data, XI_TouchEnd);
                XISelectEvents(display, root, *event_mask, 1);
            }
        } else {
            log_error("XInputExtension not available, touch input disabled.\n");
        }
    }

    // Bindings required to use XInput2 extension. They are here insetad of in modules/X11 for now because they require
    // libxi to be installed, so we are behind X11_ENABLE_TOUCH_INPUT here. If they were in X11 module we would need a
    // module  paramter on the X11 module as well! :X11TouchInput
    //
    // These definitions are contained in the headers X11/extensions/XInput2.h and X11/extensions/XI2.h. They have been hand
    // converted, but it may be sensible to use the Bindings_Generator both for them and for the other X11 bindings.

    XIQueryVersion :: (display: *Display, major_version_inout: *s32, minor_version_inout: *s32) -> Status #foreign libXi;

    XIEventMask :: struct {
        deviceid: s32;
        mask_len: s32;
        mask: *u8;
    }

    XISelectEvents :: (dpy: *Display, win: Window, masks: *XIEventMask, num_masks: s32) -> s32 #foreign libXi;

    // NOTE(Charles): XIEventMask is an array of bytes so you have these macros to actually set the bits you want of the correct
    // byte for the flag you want (Even though there are only 32 events...). For now I have just converted the one I needed.

    /* XI2 event mask macros */

    // #define XISetMask(ptr, event)   (((unsigned char*)(ptr))[(event)>>3] |=  (1 << ((event) & 7)))
    XISetMask :: (mask: *u8, event: int) #expand {
        // mask[event / 8] |= 1 << ((event) % 8));
        mask[event >> 3] |= 1 << (event & 7);
    }
    // #define XIClearMask(ptr, event) (((unsigned char*)(ptr))[(event)>>3] &= ~(1 << ((event) & 7)))
    // #define XIMaskIsSet(ptr, event) (((unsigned char*)(ptr))[(event)>>3] &   (1 << ((event) & 7)))
    // #define XIMaskLen(event)        (((event) >> 3) + 1)

    /* Fake device ID's for event selection */
    XIAllDevices       : s32 : 0;
    XIAllMasterDevices : s32 : 1;

    /* Event types */
    XI_DeviceChanged      :: 1;
    XI_KeyPress           :: 2;
    XI_KeyRelease         :: 3;
    XI_ButtonPress        :: 4;
    XI_ButtonRelease      :: 5;
    XI_Motion             :: 6;
    XI_Enter              :: 7;
    XI_Leave              :: 8;
    XI_FocusIn            :: 9;
    XI_FocusOut           :: 10;
    XI_HierarchyChanged   :: 11;
    XI_PropertyEvent      :: 12;
    XI_RawKeyPress        :: 13;
    XI_RawKeyRelease      :: 14;
    XI_RawButtonPress     :: 15;
    XI_RawButtonRelease   :: 16;
    XI_RawMotion          :: 17;
    XI_TouchBegin         :: 18; /* XI 2.2 */
    XI_TouchUpdate        :: 19;
    XI_TouchEnd           :: 20;
    XI_TouchOwnership     :: 21;
    XI_RawTouchBegin      :: 22;
    XI_RawTouchUpdate     :: 23;
    XI_RawTouchEnd        :: 24;
    XI_BarrierHit         :: 25; /* XI 2.3 */
    XI_BarrierLeave       :: 26;
    XI_GesturePinchBegin  :: 27; /* XI 2.4 */
    XI_GesturePinchUpdate :: 28;
    XI_GesturePinchEnd    :: 29;
    XI_GestureSwipeBegin  :: 30;
    XI_GestureSwipeUpdate :: 31;
    XI_GestureSwipeEnd    :: 32;
    XI_LASTEVENT          :: XI_GestureSwipeEnd;

    XIDeviceEvent :: struct {
        type:       s32;         /* GenericEvent */
        serial:     u64;       /* # of last request processed by server */
        send_event: Bool;   /* true if this came from a SendEvent request */
        display:    *Display;     /* Display the event was read from */
        extension:  s32;    /* XI extension offset */
        evtype:     s32;
        time:       Time;
        deviceid:   s32;
        sourceid:   s32;
        detail:     s32;
        root:       Window;
        event:      Window;
        child:      Window;
        root_x:     float64;
        root_y:     float64;
        event_x:    float64;
        event_y:    float64;
        flags:      s32;
        buttons:    XIButtonState;
        valuators:  XIValuatorState;
        mods:       XIModifierState;
        group:      XIGroupState;
    }

    XIButtonState :: struct {
        mask_len: s32;
        mask: *u8;
    }

    XIValuatorState :: struct {
        mask_len: s32;
        mask: *u8;
        values: *float64;
    }

    XIModifierState :: struct {
        base:      s32;
        latched:   s32;
        locked:    s32;
        effective: s32;
    }
    XIGroupState :: XIModifierState; // ?

    libXi :: #library,system "libXi";
}

/*

Copyright 2021, Thekla, Inc (portions of this code, dealing with Xdnd, are copyright Jens Frederich).

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/
