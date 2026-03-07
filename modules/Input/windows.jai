#import "String";
#import "Windows";
#import "Windows_Utf8";
#import "Hash_Table";

Gamepad_Lib :: #import "Gamepad";


//
// @Incomplete @Robustness: We should check whichever flags Windows gives us automatically
// in the event data (e.g. is control held, is shift held, etc)... rather than maintaining
// our own per-frame state... the "is ctrl held down" variables should just be informational
// to the outside user.
//

window_minimized := false; // @@ Hack.

set_custom_cursor_handling :: (is_custom: bool) {
    // Use this if you are doing immediate-mode API stuff that sets cursors and want to prevent cursors from flickering. Windows is annoying to interface with.
    windows_ignore_setcursor_messages = is_custom;
}

//#scope_export

get_key_code :: (wParam: WPARAM) -> Key_Code {
    found, value := table_find(*vk_to_key_code, wParam);

    if found return value;
    return UNKNOWN;
}

get_vk :: (key: Key_Code) -> VK: u64 {
    found, value := table_find(*key_code_to_vk, key);

    if found return value;
    return 0;
}

//
// If you're on Microsoft Windows (TM), the way events work is, you create a Window of a certain
// Window Class, and that Window Class designates the WindowProc that handles input.
// So for this module to see events, the window must be created with that WindowProc
// as an argument. We could make it a requirement that any module that opens windows
// on any operating system takes a handle to the input module, but that would be
// imposing a constraint on all programs everywhere just because Microsoft Windows
// is being dumb. And if you follow that philosophy for everything, you make people
// deal with the superset of all constraints on all operating systems, which is a disaster.
// So we insulate the complication to Windows only.
// We put MyWindowProc in the Context, and anyone who wants to open windows, on
// the Microsoft Windows operating system, can look in the context and see if this is there.
// If not they can use a default proc. If you want to replace the WindowProc with your own,
// you can set context.window_proc before calling create_window....
//
#add_context input_handler: struct {
    window_proc := MyWindowProc;
    window_proc_allocator: Allocator;
};

MyWindowProc :: (hwnd: HWND, message: u32,
                 wParam: WPARAM, lParam: LPARAM) -> s64 #c_call {
    push_context {
        using Key_Code;

        if message == {
          case WM_SYSCOMMAND;
            return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_ACTIVATEAPP;
            if wParam {  // We are being activated.

                    // We do our best to provide the application with reliable key states without brute force sampling every key.
                    // The intended rules are that a key down event will be sent when a key is depressed and will be followed
                    // by zero or more key down events with the repeat flag set as long as the key remains down.  A key up event
                    // will be sent when the key is released.
                    // In practice:
                    // 1. An application will always be notified when it has or gains focus if a key is up.
                // 2. An application will always be notified when it has focus if a key is down.
                // 3. An application will *usually* be notified when it gains focus if a key is down.
                // So the one thing you can't rely on is being notified if a key is pressed while the application is out of
                // focus and then the application gains focus.  In the rare cases where that doesn't happen, the key will
                // have to be released and re-pressed for the application to get a key down event.
                for key_down, vkey: key_down_table {
                    state := GetAsyncKeyState(cast,trunc(s32) vkey);
                    if !(state & 0x8000) {
                        send_key_event(get_key_code(vkey), false);
                        remove;
                    }
                }
            }
            
	        return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_SYSKEYDOWN; #through;
          case WM_KEYDOWN;

            repeat := ((cast (s32) lParam) & 0x40000000) != 0;
            maybe_send_vkey_event(wParam, true, repeat);

          case WM_SYSKEYUP; #through;
          case WM_KEYUP;

            maybe_send_vkey_event(wParam, false);

          case WM_SYSCHAR;
              // This is here to prevent beeps when a Alt key combo is pressed. If we don't return 0, windows helpfully emits a beep sound to
              // indicate the user that the key wasn't handled.

          case WM_CHAR;
            keycode := wParam;

            if keycode > 31 {
                // Control characters generate key codes < 32, but these are redundant
                // with KEYDOWN events and are also ambiguous (ctrl-m generates 13, but
                // so does RETURN.)
                event: Event;
                event.type = .TEXT_INPUT;
                event.utf32 = xx keycode;

                array_add(*events_this_frame, event);
            }

          case WM_SETFOCUS;
            input_application_has_focus = true;
          case WM_KILLFOCUS;
            input_application_has_focus = false;
          case WM_PAINT;
		    ValidateRect(hwnd, null);
	        return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_LBUTTONDOWN; #through;
          case WM_LBUTTONUP;
            maybe_send_vkey_event(VK_LBUTTON, message == WM_LBUTTONDOWN);

            if message == WM_LBUTTONDOWN SetCapture(hwnd);
            else ReleaseCapture();

          case WM_RBUTTONDOWN; #through;
          case WM_RBUTTONUP;
            maybe_send_vkey_event(VK_RBUTTON, message == WM_RBUTTONDOWN);

         case WM_MBUTTONDOWN; #through;
         case WM_MBUTTONUP;
            maybe_send_vkey_event(VK_MBUTTON, message == WM_MBUTTONDOWN);

          case WM_MOUSEMOVE;
            // We don't have mouse move events yet, but we'll record the delta.


            // We use Raw Input for mouse position stuff now.
/*
            x := (lParam & 0xffff);
            y := (lParam >> 16) & 0xffff;
            mouse_delta_x += x - last_mouse_event_x;
            mouse_delta_y += y - last_mouse_event_y;

            last_mouse_event_x = x;
            last_mouse_event_y = y;
*/
          case WM_MOUSEWHEEL;
            event: Event;
            event.type = .MOUSE_WHEEL;
            event.typical_wheel_delta = WHEEL_DELTA;
            event.wheel_delta = xx cast,trunc(s16)(wParam >> 16);
            array_add(*events_this_frame, event);

            mouse_delta_z += event.wheel_delta;

          case WM_XBUTTONUP; #through;
          case WM_XBUTTONDOWN;
            // Handle mouse "thumb" buttons. 
            //
            // NOTE(Charles): These buttons are typically used for a programs "forward" and "backward" operations. There is also
            // the WM_APPCOMMAND message that will give us APPCOMMAND_BROWSER_BACKWARD/FORWARD, maybe they are better to use?

            // low/high word of lParam contains the x/y coord of mouse.
            XBUTTON1 :: 0x0001;
            XBUTTON2 :: 0x0002;

            // hi has what button was pressed.
            // lo has flags for whether control, shift, or other mouse buttons are prssed (MK_*), but we already handle modifier keys.
            double_world := cast,no_check(u32, wParam);
            hi := (double_world >> 16) & 0xffff;
            lo := (double_world >>  0) & 0xffff;

            key_down := message == WM_XBUTTONDOWN;
            if hi == XBUTTON1 {
                send_key_event(.MOUSE_BUTTON_EXTRA_1, key_down);
            } else {
                assert(hi == XBUTTON2, "Unexpected hi word during WM_XBUTTONDOWN message. Expected XBUTTON1/2 but got %. wParam was %", hi, wParam);

                send_key_event(.MOUSE_BUTTON_EXTRA_2, key_down);
            }

            return 1;

          case WM_CLOSE; #through;
          case WM_QUIT;
            event: Event;
            event.type = .QUIT;
            array_add(*events_this_frame, event);
	        return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_INPUT;
            extra := GetMessageExtraInfo();

            if (extra & 0x82) == 0x82 {
                // @Hack: Ignore touch input! There is no documentation of this
                // that I can see. This is just what I needed to do to filter
                // out fake mouse input generated by WM_TOUCH. I would regard
                // this as extremely fragile and could-break-at-any-time.
            } else {
                process_raw_input(cast(HRAWINPUT)lParam);
            }

            DefWindowProcW(hwnd, message, wParam, lParam);  // This is required for some reason.    // @@ Why?
          case WM_SIZE;
            if wParam == {
              case SIZE_MAXIMIZED;
                window_minimized = false;
                add_resize_record(hwnd);
              case SIZE_RESTORED;
                  if window_minimized window_minimized = false;
                  else add_resize_record(hwnd);
              case SIZE_MINIMIZED;
                  window_minimized = true;
            }
            return 0;
          case WM_MOVE;
            add_move_record(hwnd);
            return 0;
          case WM_EXITSIZEMOVE;
            add_resize_record(hwnd);
            return 0;
          case WM_DPICHANGED;
            y_dpi := (wParam >> 16) & 0xFFFF;
            x_dpi := (wParam)       & 0xFFFF;

            rect := cast(*RECT) lParam;

            w := rect.right - rect.left;
            h := rect.bottom - rect.top;

            SetWindowPos(hwnd, HWND_TOPMOST, rect.left, rect.top, w, h, SWP_NOACTIVATE|SWP_NOZORDER);
            return 0;
          case WM_DROPFILES;
 	  	    drop := cast(HDROP) wParam;
 	 	    // If "0xFFFFFFFF" as the second parameter: return the count of files dropped.
 	 	    file_paths_count := DragQueryFileW(drop, 0xFFFFFFFF, null, 0);
            assert(file_paths_count > 0);

            allocator := context.input_handler.window_proc_allocator;
            if !allocator.proc  allocator = context.default_allocator;
            
            files: [..] string;
            files.allocator = allocator;
            array_reserve(*files, file_paths_count);

 	 	    for i: 0..file_paths_count-1 {
 	 	        // If null as the third parameter: return the length of the path, not counting the trailing '\0'.
 	 	        file_name_wide_count := DragQueryFileW(drop, i, null, 0) + 2;
 	 	        assert(file_name_wide_count > 0);

                file_name_wide := cast(*u16) alloc(file_name_wide_count * size_of(u16),, temp);
 	 	        ok := DragQueryFileW(drop, i, file_name_wide, file_name_wide_count);
 	 	        assert(ok > 0); // means success

 	  	        file_name := wide_to_utf8(file_name_wide,, allocator);
 	 	        array_add(*files, file_name);
 	 	    }

 	 	    DragFinish(drop);

 	  	    event: Event;
 	 	    event.type  = .DRAG_AND_DROP_FILES;
            event.files = files;
 	 	    array_add(*events_this_frame, event);
            return 0;

          case WM_SETCURSOR;
            if windows_ignore_setcursor_messages return 0;
	        else return DefWindowProcW(hwnd, message, wParam, lParam);

          // WM_TOUCH is currently used for touch input. There is a newer POINTER api, eg WM_POINTERDOWN that combines
          // pen, touch, mouse together that might be worth considering in the future.
          case WM_TOUCH;
            // There doesn't appear to be a way to know what the max number of points we might get is.
            touch_points_count := wParam & 0xFFFF;
            touch_points := NewArray(xx touch_points_count, TOUCHINPUT,, temp);

            touch_input_handle := cast(HTOUCHINPUT) lParam;

            if GetTouchInputInfo(touch_input_handle, xx touch_points.count, touch_points.data, size_of(TOUCHINPUT)) {
                defer CloseTouchInputHandle(touch_input_handle);

                for touch_points {
                    // TOUCHINPUT.x/y are in hundredths of a pixel
                    x := TOUCH_COORD_TO_PIXEL(it.x);
                    y := TOUCH_COORD_TO_PIXEL(it.y);

                    // Just create events for the "primary" touch for now. Primary is the first to touch, not necessarily
                    // the last
                    if it.dwFlags & TOUCHEVENTF_PRIMARY {
                        if it.dwFlags & TOUCHEVENTF_DOWN {
                            touch_event: Event;
                            touch_event.type = .TOUCH;
                            touch_event.touch_index = 0;
                            touch_event.touch_type = .PRESSED;
                            array_add(*events_this_frame, touch_event);
                        } else if it.dwFlags & TOUCHEVENTF_UP {
                            touch_event: Event;
                            touch_event.type = .TOUCH;
                            touch_event.touch_index = 0;
                            touch_event.touch_type = .RELEASED;
                            array_add(*events_this_frame, touch_event);
                        }
                    }
                }

                return 0;

            } else {
                System :: #import "System";
                code, s := System.get_error_value_and_string();
                log_error("GetTouchInputInfo() failed with error %: %", code, s);
            }

            return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_CREATE;
            // Look for already-existing xbox controllers
            dev := SetupDiGetClassDevsW(*XBOX_GUID, null, null, DIGCF_DEVICEINTERFACE | DIGCF_PRESENT);
            if dev == INVALID_HANDLE_VALUE return DefWindowProcW(hwnd, message, wParam, lParam);
            idata: SP_DEVICE_INTERFACE_DATA;
            idata.cbSize = size_of(SP_DEVICE_INTERFACE_DATA);

            index: u32 = 0;
            while SetupDiEnumDeviceInterfaces(dev, null, *XBOX_GUID, index, *idata) {
                size: u32;
                SetupDiGetDeviceInterfaceDetailW(dev, *idata, null, 0, *size, null);
                detail := cast(*SP_DEVICE_INTERFACE_DETAIL_DATA_W)alloc(size,, temp);
                detail.cbSize = size_of(SP_DEVICE_INTERFACE_DETAIL_DATA_W); // yes, sizeof of structure, not allocated memory

                data: SP_DEVINFO_DATA;
                data.cbSize = size_of(SP_DEVINFO_DATA);

                if SetupDiGetDeviceInterfaceDetailW(dev, *idata, detail, size, *size, *data) {
                    xbox_connect(detail.DevicePath.data);
                }
                index += 1;
            }

            SetupDiDestroyDeviceInfoList(dev);


        
          case WM_DEVICECHANGE;
            hdr := cast(*DEV_BROADCAST_HDR)lParam;
            if !hdr || hdr.dbch_devicetype != DBT_DEVTYP_DEVICEINTERFACE return DefWindowProcW(hwnd, message, wParam, lParam);
            dif := cast(*DEV_BROADCAST_DEVICEINTERFACE_W)hdr;
            if wParam == {
                case DBT_DEVICEARRIVAL;
                    xbox_connect(dif.dbcc_name.data);
                case DBT_DEVICEREMOVECOMPLETE;
                    xbox_disconnect(dif.dbcc_name.data);
                case;
                    return DefWindowProcW(hwnd, message, wParam, lParam);
            }

          case;
	        return DefWindowProcW(hwnd, message, wParam, lParam);
	    }

        return 0;
    }
}

update_window_events :: () {
    if !initted {
        init_key_code_tables();
        init_input_system();
        initted = true;
    }

    input_per_frame_event_and_flag_update();

    // @Robustness: Maybe do this for all keystrokes that are down? Sigh...
    if alt_state || (input_button_states[Key_Code.ALT] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_MENU);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            alt_state = false;
            input_button_states[Key_Code.ALT] |= .END;
        }
    }

    if ctrl_state || (input_button_states[Key_Code.CTRL] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_CONTROL);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            ctrl_state = false;
            input_button_states[Key_Code.CTRL] |= .END;
        }
    }

    if shift_state || (input_button_states[Key_Code.SHIFT] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_SHIFT);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            shift_state = false;
            input_button_states[Key_Code.SHIFT] |= .END;
        }
    }

    while true {
        msg: MSG;

        result := PeekMessageW(*msg, null, 0, 0, PM_REMOVE);
        if !result break;

        // This is how we used to handle Alt+Enter on The Witness:
        // Alt+Enter is not delivered through WM_INPUT, so the combination was handled through WM_(SYS)KEYDOWN messages.
        /*if msg.message == WM_SYSKEYDOWN {
            if msg.wParam == VK_RETURN {

                // Toggle full screen upon alt-enter
                dwMask :: (1 << 29);
                if (msg.lParam & dwMask) != 0 { // Alt is down also
                    //display->toggle_fullscreen();

                    event: Event;
                    event.type = .KEYBOARD;
                    event.key_pressed = 1;
                    event.key_code = get_key_code(msg.wParam);
                    event.packed = 0;  // @Temporary: Unions not currently initialized.
                    event.shift_pressed = shift_state;
                    event.ctrl_pressed = ctrl_state;
                    event.alt_pressed = true;

                    array_add(*events_this_frame, event);

                    // Do not send this message to the window proc, because that produces beep sound.
                    continue;
                }
            }
        }*/

        // Doing that was also useful to avoid the beeping sound when pressing Alt+key combinations. However, to avoid that
        // we only need to avoid TranslateMessage. Turns out TranslateMessage enqueues a WM_SYSCHAR message which is the actual
        // culprit of the beeping sound. Handling WM_SYSCHAR in the message handler and returning 0 prevents the default handling
        // of the message and avoids the beep.

        TranslateMessage(*msg);
        DispatchMessageW(*msg);
    }
}

xbox_devices: [8] struct { handle: HANDLE; path: string; };
the_rawinput_handler: (product_id: u16, device_id: u16, handle: HANDLE, data: *u8, length: int);

#scope_file

xbox_connect :: (wide_path: *u16) {
    path := wide_to_utf8(wide_path); 
    // SetupDi* and WM_DEVICECHANGE use different case paths.
    // The example code I saw used _wcsicmp, a wide char case-insensitive comparison function in the crt.
    // However, that depends on the locale of the program, so I don't want to do this.
    // The path I am seeing on my computer has only ascii characters. I will do this for now.
    to_lower_in_place(path);

    for xbox_devices {
        if !it.handle || it.path != path continue;
        free(path);
        return;
    }

    handle := CreateFileW(wide_path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if handle == INVALID_HANDLE_VALUE return;

    for * xbox_devices {
        if it.handle continue;
        it.* = .{ handle = handle, path = path };
        break;
    }
}

xbox_disconnect :: (wide_path: *u16) {
    path := wide_to_utf8(wide_path,, temp); 
    to_lower_in_place(path);

    for * xbox_devices {
        if !it.handle || it.path != path continue;
        free(it.path);
        it.* = {};
        break;
    }
}


shift_state := false;
ctrl_state  := false;
alt_state   := false;


// Nice tutorial about using raw input for games:
// http://www.toymaker.info/Games/html/raw_input.html

// About Raw Input:
// http://msdn.microsoft.com/en-us/library/ms645543(v=vs.85).aspx#_win32_Registration_for_Raw_Input

// Taking Advantage of High-Definition Mouse Movement:
// http://msdn.microsoft.com/en-us/library/ee418864(v=vs.85).aspx

// Using Raw Input Examples:
// http://msdn.microsoft.com/en-us/library/ms645546(v=vs.85).aspx#standard_read

raw_input_buffer: [..] u8;
process_raw_input :: (handle: HRAWINPUT) {
    //
    // We currently use Raw Input for mouse events, so that we can get deltas
    // while doing things like tightly constraining the mouse pointer.
    //
    // In The Witness we also used Raw Input for keyboard events, but I am
    // not sure what benefit we got from this. Maybe it's better, I don't know!
    // But for now I am leaving keyboard out of this code.
    //
    //          -jblow, 31 March 2017.

    // IC: We are using raw input, because there are no WM events for some special keys such as PrintScreen.

    if !raw_input_buffer.allocated {
        // Pre-season the Raw Input Buffer to prevent spammy growing
        // in the beginning.
        array_resize(*raw_input_buffer, 8000);
    }

    dwSize: u32;
    GetRawInputData(handle, RID_INPUT, null, *dwSize, size_of(RAWINPUTHEADER));

    set_array_count(*raw_input_buffer, dwSize);
	written_bytes := GetRawInputData(handle, RID_INPUT, raw_input_buffer.data, *dwSize, size_of(RAWINPUTHEADER));
    if written_bytes == 0xffff_ffff return; // Error. Steam Input causes this to happen sometimes.
    assert(written_bytes <= dwSize);        // note that GetRawInputData() is allowed to request a buffer size and then write less bytes than the size

    raw := cast(*RAWINPUT) raw_input_buffer.data;

    handled := false;
    if raw.header.dwType == RIM_TYPEMOUSE {
        mouse := *raw.data.mouse;

        // The docs say to check this flag, but MOUSE_MOVE_RELATIVE
        // is defined as 0? wtf?
        if (mouse.usFlags & MOUSE_MOVE_ABSOLUTE) {
            // @@ What to do if we only receive absolute coordinates? To do proper motions we need to know when the pen touches the tablet and when is it lifted.
            //mouse_delta_x += cast(int)((mouse.lLastX - mouse_abs_x) * 0.01);
            //mouse_delta_y += cast(int)((mouse.lLastY - mouse_abs_y) * 0.01);
            //mouse_abs_x = mouse.lLastX;
            //mouse_abs_y = mouse.lLastY;
        } else {
            mouse_delta_x += mouse.lLastX;
            mouse_delta_y += mouse.lLastY;
        }
    } else if raw.header.dwType == RIM_TYPEKEYBOARD {
        is_left  := (raw.data.keyboard.Flags & RI_KEY_E0)    != 0;
        is_right := (raw.data.keyboard.Flags & RI_KEY_E1)    != 0;
        is_down  := (raw.data.keyboard.Flags & RI_KEY_BREAK) == 0;

        vkey    := raw.data.keyboard.VKey;
        raw_key := raw.data.keyboard.MakeCode;

        handle_keyboard_event(is_left, is_right, is_down, vkey, raw_key);
    } else if raw.header.dwType == RIM_TYPEHID {
        RID_DEVICE_INFO_MOUSE :: struct {
            dwId: u32;
            dwNumberOfButtons: u32;
            dwSampleRate: u32;
            fHasHorizontalWheel: BOOL;
        }

        RID_DEVICE_INFO_KEYBOARD :: struct {
            dwType: u32;
            dwSubType: u32;
            dwKeyboardMode: u32;
            dwNumberOfFunctionKeys: u32;
            dwNumberOfIndicators: u32;
            dwNumberOfKeysTotal: u32;
        }

        RID_DEVICE_INFO_HID :: struct {
            dwVendorId: u32;
            dwProductId: u32;
            dwVersionNumber: u32;
            usUsagePage: u16;
            usUsage: u16;
        }

        RID_DEVICE_INFO :: struct {
            cbSize: u32;
            dwType: u32;

            union {
                mouse:    RID_DEVICE_INFO_MOUSE;
                keyboard: RID_DEVICE_INFO_KEYBOARD;
                hid:      RID_DEVICE_INFO_HID;
            }
        }
        
        RIDI_DEVICEINFO :: 0x2000000b;

        device_info: RID_DEVICE_INFO;
        device_info_size := cast(u32)size_of(RID_DEVICE_INFO);
        if GetRawInputDeviceInfoA(raw.header.hDevice, RIDI_DEVICEINFO, *device_info, *device_info_size) == -1 return;
        if device_info.dwType != RIM_TYPEHID return;
        if the_rawinput_handler the_rawinput_handler(xx device_info.hid.dwVendorId, xx device_info.hid.dwProductId, raw.header.hDevice, raw.data.hid.bRawData.data, raw.data.hid.dwSizeHid);
    }
}


handle_keyboard_event :: (is_left: bool, is_right: bool, is_down: bool, vkey: u16, raw_key: u16) -> handled:bool {
    // @@ IC: Here we only care about the PRINT SCREEN key, because there's no WM message for it.
    if vkey != VK_SNAPSHOT return false;

    key_code := get_key_code(vkey);
    repeat := is_down && (input_button_states[key_code] & .DOWN) != 0;
    maybe_send_vkey_event(vkey, is_down, repeat);

    return true;
}


init_input_system :: () {
    rid := RAWINPUTDEVICE.[
        .{ usUsagePage = HID_USAGE_PAGE_GENERIC,
           usUsage     = HID_USAGE_GENERIC_MOUSE
         },

        // IC: We are not using the RIDEV_NOHOTKEYS flag anymore, because it interferes with the Alt-Tab dialog.
        // This means that we are not blocking the windows logo key and that pressing it will cause the app to lose the focus.
        .{ usUsagePage = HID_USAGE_PAGE_GENERIC,
           usUsage     = HID_USAGE_GENERIC_KEYBOARD
         },
        .{ usUsagePage = HID_USAGE_PAGE_GENERIC,
           usUsage     = HID_USAGE_GENERIC_JOYSTICK
         },
        .{ usUsagePage = HID_USAGE_PAGE_GENERIC,
           usUsage     = HID_USAGE_GENERIC_GAMEPAD
         }
    ];
    
    if RegisterRawInputDevices(rid.data, rid.count, size_of(RAWINPUTDEVICE)) == 1 {
        // Do nothing.
    } else {
        log_error("Failed to initialize Raw Input.\n");
        assert(false);
    }

    // @@ Enable/Disable shortcut keys?

    // Disable StickyKeys/etc shortcuts but if the accessibility feature is on,
    // then leave the settings alone as its probably being usefully used

    sk: STICKYKEYS;
    SystemParametersInfoW(SPI_GETSTICKYKEYS, size_of(STICKYKEYS), *sk, 0);

    tk: TOGGLEKEYS;
    SystemParametersInfoW(SPI_GETTOGGLEKEYS, size_of(TOGGLEKEYS), *tk, 0);

    fk: FILTERKEYS;
    SystemParametersInfoW(SPI_GETFILTERKEYS, size_of(FILTERKEYS), *fk, 0);

    // Disable shortcuts:
    {
        skOff := sk;
        if (skOff.dwFlags & SKF_STICKYKEYSON) == 0 {
            // Disable the hotkey and the confirmation
            skOff.dwFlags &= ~SKF_HOTKEYACTIVE;
            skOff.dwFlags &= ~SKF_CONFIRMHOTKEY;
            skOff.dwFlags &= ~SKF_HOTKEYSOUND;

            result := SystemParametersInfoW(SPI_SETSTICKYKEYS, size_of(STICKYKEYS), *skOff, 0);
            k := result;
        }

        tkOff := tk;
        if (tkOff.dwFlags & TKF_TOGGLEKEYSON) == 0 {
            // Disable the hotkey and the confirmation
            tkOff.dwFlags &= ~TKF_HOTKEYACTIVE;
            tkOff.dwFlags &= ~TKF_CONFIRMHOTKEY;
            tkOff.dwFlags &= ~TKF_HOTKEYSOUND;

            result := SystemParametersInfoW(SPI_SETTOGGLEKEYS, size_of(TOGGLEKEYS), *tkOff, 0);
            k := result;
        }

        fkOff := fk;
        if (fkOff.dwFlags & FKF_FILTERKEYSON) == 0 {
            // Disable the hotkey and the confirmation
            fkOff.dwFlags &= ~FKF_HOTKEYACTIVE;
            fkOff.dwFlags &= ~FKF_CONFIRMHOTKEY;
            fkOff.dwFlags &= ~FKF_HOTKEYSOUND;

            result := SystemParametersInfoW(SPI_SETFILTERKEYS, size_of(FILTERKEYS), *fkOff, 0);
            k := result;
        }
    }
}


initted := false;

WHEEL_DELTA :: 120;

using Key_Current_State;

add_resize_record :: (hwnd: HWND) {
    record: *Window_Resize_Record;
    for * pending_resizes {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_resizes);
        this_allocation_is_not_a_leak(pending_resizes.data); // :ScanGlobalData
    }

    client_rect: RECT;
    GetClientRect(hwnd, *client_rect);

    record.window = hwnd;
    record.width  = client_rect.right;
    record.height = client_rect.bottom;
}

add_move_record :: (hwnd: HWND) {
    client_rect: RECT;
    GetWindowRect(hwnd, *client_rect);

    record: *Window_Move_Record;
    for * pending_moves {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_moves);
        this_allocation_is_not_a_leak(pending_moves.data); // :ScanGlobalData:  We could just scan the global data of the program and automatically consider anything there as not a leak. (Do we do this recursively though?)
    }

    record.window = hwnd;
    record.x = client_rect.left;
    record.y = client_rect.top;
}




#scope_file
windows_ignore_setcursor_messages := false;

key_down_table: Table(WPARAM, bool);

set_key_down_state :: (vkey: WPARAM, is_down: bool) -> was_down:bool {
    was_down := table_find_pointer(*key_down_table, vkey) != null;
    if is_down && !was_down {
        table_add(*key_down_table, vkey, true);
    } else if was_down && !is_down {
        table_remove(*key_down_table, vkey);
    }

    return was_down;
}

maybe_send_vkey_event :: (vkey: u64, key_down: bool, repeat := false) {
    was_down := set_key_down_state(cast,trunc(u32) vkey, key_down);
    if !key_down && !was_down {
        // redundant key_up event
        return;
    }

    if key_down && repeat && !was_down {
        // key was pressed while we didn't have focus so the first
        // event we see is incorrectly labeled as a repeat.
        repeat = false;
    }

    send_key_event(get_key_code(vkey), key_down, repeat);
}

send_key_event :: (key_code: Key_Code, key_down: bool, repeat := false) {
    if key_code == .ALT     alt_state   = key_down;
    if key_code == .SHIFT   shift_state = key_down;
    if key_code == .CTRL    ctrl_state  = key_down;  // @Cleanup: Look at what I do in the Braid code because this is bananas.

    event: Event;
    event.type = .KEYBOARD;
    event.key_pressed = xx key_down;
    event.key_code = key_code;
    event.packed = 0;
    event.shift_pressed = shift_state;
    event.ctrl_pressed  = ctrl_state;
    event.alt_pressed   = alt_state;
    event.repeat = repeat;
    array_add(*events_this_frame, event);

    input_button_states[key_code] |= ifx key_down then (Key_Current_State.DOWN | .START) else .END;
}

#scope_file;
HID_USAGE_GENERIC_MOUSE    :: 2;
HID_USAGE_GENERIC_JOYSTICK :: 4;
HID_USAGE_GENERIC_GAMEPAD  :: 5;
HID_USAGE_GENERIC_KEYBOARD :: 6;

HID_USAGE_PAGE_GENERIC :: 1;
HID_USAGE_PAGE_GAME    :: 5;

set_array_count :: (array: *[..] $T, count: s64) {
    if array.allocated >= count {
        array.count = count;
        return;
    }

    array_resize(array, count);
    this_allocation_is_not_a_leak(array.data); // :ScanGlobalData
}

vk_to_key_code: Table(WPARAM, Key_Code);
key_code_to_vk: Table(Key_Code, WPARAM);

add_code :: (vk: WPARAM, key_code: Key_Code) {
    // Add this code to both tables, so we can
    // look it up in either direction.

    table_add(*vk_to_key_code, vk, key_code);
    table_add(*key_code_to_vk, key_code, vk);
}

init_key_code_tables :: () {
    // Make tables for fast forward and inverse lookup of key codes.

    // Make the tables at least kind of big so we don't flail.
    INITIAL_TABLE_SIZE :: 512;
    init(*vk_to_key_code, INITIAL_TABLE_SIZE);
    init(*key_code_to_vk, INITIAL_TABLE_SIZE);

    // ASCII characters:
    for i: 48..cast(u32)90 {
        add_code(i, cast(Key_Code) i);
    }

    // Function keys:
    for i: VK_F1..VK_F16 {
        delta := i - VK_F1;
        add_code(cast(WPARAM) i, F1 + cast(Key_Code) delta);
    }

    // Numeric keypad:
    for i: VK_NUMPAD0..VK_NUMPAD9 {
        // We just treat these like normal numbers for the purposes
        // of button events.
        delta := i - VK_NUMPAD0;
        add_code(xx i, xx (#char "0" + delta));
    }
    
    // Entries defined by the array in this file:
    for vk_to_key_code_array {
        add_code(it.vk, it.key_code);
    }
}

// We make a static table, and just
// iterate over it to set the values...
// Let's put it in global scope so people can
// use it if they want.
Vk_To_Key_Code :: struct {
    vk: u32;
    key_code: Key_Code;
}

vk_to_key_code_array :: Vk_To_Key_Code.[
    .{ VK_LBUTTON,  MOUSE_BUTTON_LEFT },
    .{ VK_MBUTTON,  MOUSE_BUTTON_MIDDLE },
    .{ VK_RBUTTON,  MOUSE_BUTTON_RIGHT },
    .{ VK_SPACE,    xx 32 },
    .{ VK_HOME,     HOME },
    .{ VK_END,      Key_Code.END },
    .{ VK_PRIOR,    PAGE_UP },
    .{ VK_NEXT,     PAGE_DOWN },
    .{ VK_LEFT,     ARROW_LEFT },
    .{ VK_RIGHT,    ARROW_RIGHT },
    .{ VK_UP,       ARROW_UP},
    .{ VK_DOWN,     ARROW_DOWN },
    .{ VK_MENU,     ALT },
    .{ VK_SHIFT,    SHIFT },
    .{ VK_CONTROL,  CTRL },
    .{ VK_BACK,     BACKSPACE },
    .{ VK_DELETE,   DELETE },
    .{ VK_INSERT,   INSERT },
    .{ VK_ESCAPE,   ESCAPE },
    .{ VK_RETURN,   ENTER },
    .{ VK_TAB,      TAB },
    .{ VK_OEM_1,       xx #char ";"},
    .{ VK_OEM_2,       xx #char "/"},
    .{ VK_OEM_3,       xx #char "`"},
    .{ VK_OEM_4,       xx #char "["},
    .{ VK_OEM_5,       xx #char "\\"},
    .{ VK_OEM_6,       xx #char "]"},
    .{ VK_OEM_7,       xx #char "'"},
    .{ VK_OEM_PLUS,    xx #char "+" },
    .{ VK_OEM_MINUS,   xx #char "-"    },
    .{ VK_OEM_PERIOD,  xx #char "."     },
    .{ VK_OEM_COMMA,   xx #char ","    },
    .{ VK_SNAPSHOT,   PRINT_SCREEN },
    .{ VK_PAUSE,      PAUSE },
    .{ VK_SCROLL,     SCROLL_LOCK },
];

#scope_file;
using,except(END) Key_Code; // Key_Current_State.END would conflict with this. Sigh.


#import "Hash_Table";
