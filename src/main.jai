f32 :: float32;
f64 :: float64;

// SANITY enables additional costly asserts for operations.
#if #exists(__SANITY) {
    SANITY :: __SANITY;
} else {
    SANITY :: false;
}

// SUBPIXEL enables subpixel font rendering.
#if #exists(__SUBPIXEL) {
    SUBPIXEL :: __SUBPIXEL;
} else {
    SUBPIXEL :: false;
}

#if OS == .WINDOWS {
    #import "Windows";
    #import "Windows_Utf8";

    // TODO(jt): @Cleanup We define a few functions that are either not present in modules/Windows,
    // or are commented out there. Eventually remove our version? Or eventually have just our
    // version of modules/Windows?
    user32 :: #library,system "user32";

    TRUE:  s32 : 1;
    FALSE: s32 : 0;

    UINT :: u32;

    // TODO(jt): GetDpiForWindow is relatively new (Windows 10, version 1607), but we could switch
    // to GetDpiForMonitor (Windows 8.1) in Shcore.dll, or the venerable GetDeviceCaps(LOGPIXELSX)
    // (Windows 2000) in Gdi32.dll.
    GetDpiForWindow :: (hWnd: HWND) -> UINT #foreign user32;
    WaitMessage     :: () -> BOOL #foreign user32;
} else #if OS == .MACOS {
    #import "POSIX";
    #import "macOS";
    #import "Objective_C";
    #import "Objective_C/AppKit";
} else {
    // TODO(jt): Linux, I guess.
    #assert(false, "Unsupported OS");
}

#import "Basic";
#import "Hash_Table";
#import "GL";
#import "Profiler"()(IMPORT_MODE = .RUNTIME);

String         :: #import "String";
System         :: #import "System";
File           :: #import "File";
File_Utilities :: #import "File_Utilities";
Process        :: #import "Process";
Window         :: #import "Window_Creation";
Input          :: #import "Input"; // This is our modified version. See :ModifiedInputModule.
Clipboard      :: #import "Clipboard";
Simp           :: #import "Simp";
Editor         :: #import,file "editor/editor.jai"()(SANITY = SANITY, SUBPIXEL = SUBPIXEL);

Vector4 :: Editor.Vector4;
IRect   :: Editor.IRect;

// The slow frame is more than 16.66, because it includes waiting for V-sync. Maybe we can do
// something smart to exclude that once we switch away from OpenGL. We definitely want to do less
// laggy present modes, if possible.
SLOW_FRAME_THRESHOLD_MILLIS :: 18;
SLOW_INIT_THRESHOLD_MILLIS  :: 200;

// :OperatingSystemSpecificHacks
//
// TODO(jt): @Cleanup @Hack For file watching, we have a #c_call callback, but we know it is called
// from the main thread, and we want it to use the main thread's temporary storage. Maybe we should
// just have an arena for that?
#if OS == .MACOS {
    main_thread_temporary_storage: *Temporary_Storage;
}

main :: () {
    time_of_program_start := current_time_monotonic();

    profiler_init();
    profiler_start_frame("init");

    context_logger_data: Context_Logger_Data = { time_of_program_start };

    editor_context := context;
    editor_context.logger      = context_logger;
    editor_context.logger_data = *context_logger_data;

    push_context editor_context {
        #if OS == .WINDOWS {
            // :OperatingSystemSpecificHacks
            //
            // Unless you call this, GetClientRect reports sizes in scaled pixels, which is not
            // okay, if you do your own text rendering. We could further improve this with
            // per-monitor awareness: SetProcessDpiAwarenessContext.
            SetProcessDPIAware();
        } else #if OS == .MACOS {
            // :OperatingSystemSpecificHacks
            //
            // Save main thread's temporary storage, so we can set it for event_stream_callback
            // later. We know the callback runs on the main thread.
            main_thread_temporary_storage = context.temporary_storage;

            // :OperatingSystemSpecificHacks
            //
            // Working directory on macOS is weird. If you start from console, it respects the
            // current console working directory. If you click on the executable, it starts in the
            // user's HOME. We make it behave more like Windows, where the working directory
            // defaults to the current executable path, unless overridden from console.
            //
            // We detect this situation by looking for asset files that should be distributed with
            // the executable. If we can't find them, we are most likely not running from console.
            see_data := File_Utilities.is_directory("data/fonts");
            if !see_data {
                exe_file := System.get_path_of_running_executable();
                exe_dir  := String.path_strip_filename(exe_file);

                log("We are on macOS and we don't see our data. Attempting to set working directory to the executable path: %", exe_dir);

                set_working_directory(exe_dir);
            }
        }

        window := Window.create_window(1920, 1200, "editor");
        Simp.set_render_target(window, .LEFT_HANDED);

        platform: Editor.Platform;
        #if OS == .WINDOWS {
            // :VirtualMemoryProcs
            info: SYSTEM_INFO;
            GetSystemInfo(*info);

            platform.page_size = info.dwPageSize;
            platform.mem_reserve = (size: s64) -> *void {
                return VirtualAlloc(null, cast(u64, size), MEM_RESERVE, PAGE_READWRITE);
            };
            platform.mem_release = (pointer: *void, size: s64) {
                VirtualFree(pointer, 0, MEM_RELEASE);
            }
            platform.mem_commit = (pointer: *void, size: s64) -> bool {
                result := VirtualAlloc(pointer, cast(u64, size), MEM_COMMIT, PAGE_READWRITE);
                return result != null;
            }
            platform.mem_decommit = (pointer: *void, size: s64) {
                VirtualFree(pointer, cast(u64, size), MEM_DECOMMIT);
            };
        } else #if OS_IS_UNIX {
            // :VirtualMemoryProcs
            platform.page_size = sysconf(_SC_PAGE_SIZE);
            platform.mem_reserve = (size: s64) -> *void {
                result := mmap(null, cast(u64, size), PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, 0, 0);
                if result == MAP_FAILED {
                    result = null;
                }

                return result;
            }
            platform.mem_release = (pointer: *void, size: s64) {
                munmap(pointer, cast(u64, size));
            }
            platform.mem_commit = (pointer: *void, size: s64) -> bool {
                result := mprotect(pointer, cast(u64, size), PROT_READ | PROT_WRITE);
                return result == 0;
            }
            platform.mem_decommit = (pointer: *void, size: s64) {
                madvise(pointer, cast(u64, size), MADV_DONTNEED);
                mprotect(pointer, cast(u64, size), PROT_NONE);
            }
        }

        platform.run_in_process = (args: string, working_directory: string) -> exit_code: s32, output: string, error: string {
            // break_command_into_string always puts the thing in temp, so our context override is
            // just futureproofing...
            arguments := Process.break_command_into_strings(args,, temp);

            result, output, error := Process.run_command(..arguments, working_directory = working_directory, capture_and_return_output = true);
            if result.type != .EXITED {
                log_error("Process result is %, exit code: %. Command was: %", result.type, result.exit_code, args);
            }

            return result.exit_code, output, error;
        }

        platform.get_absolute_path = (path: string) -> success: bool, string {
            // TODO(jt): @Cleanup File.get_absolute_path allocates in temp regardless of context allocator,
            // but I suspect it will start respecting context eventually, so we pass in temp for future
            // proofing. We should probably submit a fix for that.
            //
            // If the caller really wanted temp, we just return the thing. Otherwise, we copy the stuff to
            // context allocator - see postamble.
            //
            _absolute_path, success := File.get_absolute_path(path,, temp);

            #if OS_IS_UNIX {
                // realpath on unix doesn't work for non-existing files, so we go one step further and
                // try it on the directory, appending the file name back.
                //
                // TODO(jt): Eventually we'll need to do this for arbitrarily deep nonexistent suffixes, because
                // we'll want to create files in nonexistent directories.
                if !success {
                    dir_path, _, _, filename := String.path_decomp(path);
                    dir_absolute_path:, success = File.get_absolute_path(dir_path,, temp);

                    if success {
                        _absolute_path = String.join(dir_absolute_path, filename, separator = "/");
                    }
                }
            }

            absolute_path: string;
            if context.allocator.proc == temp.proc && context.allocator.data == temp.data {
                absolute_path = _absolute_path;
            } else {
                absolute_path = copy_string(_absolute_path);
            }

            return success, absolute_path;
        }

        platform.file_exists = (path: string) -> bool {
            return File_Utilities.file_exists(path);
        }
        platform.file_is_directory = (path: string) -> bool {
            is_directory, success := File_Utilities.is_directory(path);
            return success && is_directory;
        }
        platform.file_modification_time_and_size = (path: string) -> bool, Apollo_Time, s64 {
            modtime, size, exists := File_Utilities.file_modtime_and_size(path);
            return exists, modtime, size;
        }
        platform.read_file = (path: string) -> success: bool, [] u8 {
            data, success := File.read_entire_file(path);
            return success, cast([] u8, data);
        }
        platform.write_file = (path: string, data: [] u8) -> success: bool {
            return File.write_entire_file(path, cast(string, data));
        }
        platform.delete_file = (path: string) -> success: bool {
            return File.file_delete(path);
        }

        // TODO(jt): platform.make_directory
        // TODO(jt): platform.delete_directory
        platform.list_directory = (path: string) -> [] Editor.File_Info /* Allocated with context.allocator */ {
            file_infos: [..] Editor.File_Info; // context.allocator

            visitor :: (visit_info: *File_Utilities.File_Visit_Info, userdata: *[..] Editor.File_Info) {
                file_info := array_add(userdata);
                file_info.name = copy_string(visit_info.full_name); // context.allocator
                file_info.size = visit_info.size;

                file_info.modification_time = visit_info.modification_time;

                file_info.is_symlink   = visit_info.is_symlink;
                file_info.is_directory = visit_info.is_directory;
            }

            File_Utilities.visit_files(path, false, *file_infos, visitor, visit_files = true, visit_directories = true, visit_symlinks = true, follow_directory_symlinks = true);

            return file_infos;
        }
        // WARNING: Do not override context allocator here when calling. Resources for watching are
        // allocated with a general-purpose allocator here for now.
        //
        // TODO(jt): @Cleanup It would be better if we had a arena/pool for these so that we would be resistant to changes to context?
        platform.watch_directory = (_path: string) -> success: bool {
            path := String.trim_right(_path, "/");

            #if OS == .WINDOWS {
                for platform_state.watched_directories {
                    if it.info.path == path {
                        log("Reusing handles for watching path: %", path);
                        return true;
                    }
                }

                log("Creating resources for watching path: %", path);

                event_handle := CreateEventW(null, FALSE, FALSE, null);
                if event_handle == null {
                    return false;
                }

                directory_handle := CreateFileW(utf8_to_wide(path,, temp), FILE_LIST_DIRECTORY,
                                                FILE_SHARE_READ | FILE_SHARE_DELETE | FILE_SHARE_WRITE,
                                                null,
                                                OPEN_EXISTING,
                                                FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
                                                null);

                if directory_handle == INVALID_HANDLE_VALUE {
                    error_code, description := System.get_error_value_and_string();
                    log_error("watch_directory encountered an error in CreateFileW: %, %", error_code, description);

                    CloseHandle(event_handle);
                    return false;
                }

                info := New(Platform_State.Watched_Directory_Info); // :Malloc
                info.path = copy_string(path);                      // :Malloc
                info.directory_handle = directory_handle;
                info.overlapped.hEvent = event_handle;
                info.overlapped.Offset = 0;

                String.path_overwrite_separators(info.path, #char "/");

                watched_directory := array_add(*platform_state.watched_directories);
                watched_directory.info = info;

                issue_one_read(watched_directory.info);
            } else #if OS == .MACOS {
                for platform_state.watched_directories {
                    if it.path == path {
                        log("Reusing event stream for path: %", path);
                        return true;
                    }
                }

                log("Creating and starting event stream for path: %", path);

                paths_to_watch: CFArrayRef;
                {
                    cfstring_path: CFStringRef = CFStringCreateWithBytes(null, path.data, path.count, .UTF8, false);
                    cfarray_paths: CFArrayRef  = CFArrayCreate(null, cast(**void, *cfstring_path), 1, *kCFTypeArrayCallBacks);

                    paths_to_watch = cfarray_paths;
                }

                event_stream := FSEventStreamCreate(null, event_stream_callback, null, paths_to_watch,
                                                    kFSEventStreamEventIdSinceNow,
                                                    to_float64_seconds(Editor.FILE_WATCH_BLIND_WINDOW),
                                                    kFSEventStreamCreateFlagFileEvents);

                FSEventStreamScheduleWithRunLoop(event_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                FSEventStreamStart(event_stream);

                watched_directory := array_add(*platform_state.watched_directories);
                watched_directory.path = copy_string(path); // :Malloc
                watched_directory.event_stream = event_stream;

                return true;
            }

            return false;
        }
        // WARNING: Do not override context allocator here when calling. Resources for watching are
        // allocated with a general-purpose allocator here for now.
        platform.unwatch_directory = (path: string) {
            #if OS == .WINDOWS {
                for platform_state.watched_directories {
                    log("Cancelling overlapped IO and releasing resources for watching path: %", path);

                    CancelIo(it.info.directory_handle);
                    CloseHandle(it.info.overlapped.hEvent);
                    CloseHandle(it.info.directory_handle);

                    free(it.info.path);
                    free(it.info);

                    remove it;
                }
            } else #if OS == .MACOS {
                for platform_state.watched_directories {
                    if it.path == path {
                        log("Stopping and releasing event stream for watching path: %", path);

                        FSEventStreamStop(it.event_stream);
                        FSEventStreamInvalidate(it.event_stream); // Remove stream from all run loops
                        FSEventStreamRelease(it.event_stream);

                        free(it.path);
                        remove it;
                    }
                }
            }
        }

        platform.get_clipboard_text = () -> string {
            return Clipboard.os_clipboard_get_text();
        }
        platform.set_clipboard_text = (text: string) {
            Clipboard.os_clipboard_set_text(text);
        }

        renderer_state.window = window;

        shader := #ifx SUBPIXEL then SHADER_TEXT_SUBPIXEL else SHADER_TEXT;
        renderer_state.text_shader.gl_handle = Simp.get_shader_program(shader);
        renderer_state.text_shader.alpha_blend = true;

        renderer: Editor.Renderer;
        renderer.create_texture_r8unorm = (texture_id: Editor.Texture_ID, data: [] u8, width: s32, height: s32, filter: Editor.Texture_Filter) {
            bitmap: Simp.Bitmap;
            Simp.bitmap_alloc(*bitmap, width, height, .R8,, temp);
            bitmap.flags &= ~.FREE_DATA_ON_DEINIT; // The bitmap is allocated in temporary storage, so no need.

            assert(bitmap.data.count == data.count);
            memcpy(bitmap.data.data, data.data, data.count);

            texture: Simp.Texture;
            Simp.texture_load_from_bitmap(*texture, *bitmap);

            // Simp sets LINEAR filtering on the texture in backend_realloc_texture, override that here.
            if filter == .NEAREST {
                gl_texture := texture.gl_handle;
                glBindTexture(GL_TEXTURE_2D, gl_texture);

                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            }

            table_add(*renderer_state.textures, texture_id, texture);
        }
        renderer.create_texture_rgba8unorm = (texture_id: Editor.Texture_ID, data: [] u8, width: s32, height: s32, filter: Editor.Texture_Filter) {
            bitmap: Simp.Bitmap;
            Simp.bitmap_alloc(*bitmap, width, height, .RGBA8,, temp);
            bitmap.flags &= ~.FREE_DATA_ON_DEINIT; // The bitmap is allocated in temporary storage, so no need.

            assert(bitmap.data.count == data.count);
            memcpy(bitmap.data.data, data.data, data.count);

            texture: Simp.Texture;
            Simp.texture_load_from_bitmap(*texture, *bitmap);

            // Simp sets LINEAR filtering on the texture in backend_realloc_texture, override that here.
            if filter == .NEAREST {
                gl_texture := texture.gl_handle;

                glBindTexture(GL_TEXTURE_2D, gl_texture);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            }

            table_add(*renderer_state.textures, texture_id, texture);
        }
        renderer.update_texture_r8unorm = (texture_id: Editor.Texture_ID, data: [] u8, update_rect: IRect) {
            ProfileZone("renderer.update_texture_r8unorm");

            texture := table_find_pointer(*renderer_state.textures, texture_id);
            if !texture {
                log_error("Can't update nonexistent texture: %", texture_id);
                return;
            }

            update_xoffset := update_rect.x0;
            update_yoffset := update_rect.y0;
            update_width   := update_rect.x1 - update_rect.x0;
            update_height  := update_rect.y1 - update_rect.y0;

            if update_width == 0 || update_height == 0 {
                return;
            }

            gl_texture := texture.gl_handle;
            glBindTexture(GL_TEXTURE_2D, gl_texture);

            // TODO(jt): @Speed We could do glTexSubImage2D and copy just the updated region, but it
            // makes no difference on my machine. Maybe it makes a difference somewhere else? Maybe
            // if we use something better than OpenGL?
            glTexImage2D(GL_TEXTURE_2D, 0,
                         GL_R8,
                         cast(u32, texture.width), cast(u32, texture.height), 0,
                         GL_RED, GL_UNSIGNED_BYTE,
                         data.data);
        }
        renderer.update_texture_rgba8unorm = (texture_id: Editor.Texture_ID, data: [] u8, update_rect: IRect) {
            ProfileZone("renderer.update_texture_rgba8unorm");

            texture := table_find_pointer(*renderer_state.textures, texture_id);
            if !texture {
                log_error("Can't update nonexistent texture: %", texture_id);
                return;
            }

            update_xoffset := update_rect.x0;
            update_yoffset := update_rect.y0;
            update_width   := update_rect.x1 - update_rect.x0;
            update_height  := update_rect.y1 - update_rect.y0;

            if update_width == 0 || update_height == 0 {
                return;
            }

            gl_texture := texture.gl_handle;
            glBindTexture(GL_TEXTURE_2D, gl_texture);

            // TODO(jt): @Speed We could do glTexSubImage2D and copy just the updated region, but it
            // makes no difference on my machine. Maybe it makes a difference somewhere else? Maybe
            // if we use something better than OpenGL?
            glTexImage2D(GL_TEXTURE_2D, 0,
                         GL_RGBA,
                         cast(u32, texture.width), cast(u32, texture.height), 0,
                         GL_RGBA, GL_UNSIGNED_BYTE,
                         data.data);
        }

        renderer.begin_frame = (clear_color: Vector4) {
            ProfileZone("renderer.begin_frame");
            Simp.clear_render_target(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        }
        renderer.submit_frame = () {
            Simp.swap_buffers(renderer_state.window);
        }

        renderer.draw = (render_commands: [] Editor.Render_Command) {
            ProfileZone("renderer.draw");

            // TODO(jt): @Speed Realistically, they all point to the same texture, so maybe we want
            // to shape the API such that there is only one texture binding followed by an instanced
            // draw command instead of looping and binding per iteration. If they for some reason
            // don't fit into one texture, we'd flush thhe pipeline.
            for render_commands {
                if #complete it.type == {
                    case .DRAW_RECT; {
                        texture := table_find_pointer(*renderer_state.textures, it.texture_id);
                        if texture {
                            if renderer_state.current_pipeline != .TEXT {
                                renderer_state.current_pipeline = .TEXT;
                                // This is where we'd normally call Simp.set_shader_for_images(texture), but
                                // we instead pass in our modified shader, so we have to do a little bit
                                // more work.
                                Simp.immediate_flush();

                                target_shader := *renderer_state.text_shader;
                                if context.simp.current_shader != target_shader {
                                    Simp.immediate_set_shader(target_shader);

                                    // immediate_set_shader enables GL_BLEND for us, but sets up the default blend func:
                                    //
                                    //   SRC * src_alpha, DST * (1 - dst_alpha)
                                    //
                                    // For subpixel rendering, we override that to use the per-channel blend weights from the shader.
                                    // (Note the 1 in SRC1, which referes to index 1 of the shader output.)
                                    #if SUBPIXEL {
                                        glBlendFunc(GL_SRC1_COLOR, GL_ONE_MINUS_SRC1_COLOR);
                                    }

                                    Simp.set_projection();
                                }

                                Simp.immediate_set_texture(texture);
                            }
                        } else {
                            if renderer_state.current_pipeline != .COLOR {
                                renderer_state.current_pipeline = .COLOR;
                                Simp.set_shader_for_color(enable_blend = true);
                            }
                        }

                        Simp.immediate_quad(
                            { it.rect.x0, it.rect.y0 },
                            { it.rect.x0, it.rect.y1 },
                            { it.rect.x1, it.rect.y1 },
                            { it.rect.x1, it.rect.y0 },
                            it.color,
                            { it.texture_rect.x0, it.texture_rect.y0 },
                            { it.texture_rect.x0, it.texture_rect.y1 },
                            { it.texture_rect.x1, it.texture_rect.y1 },
                            { it.texture_rect.x1, it.texture_rect.y0 },
                        );
                    }
                    case .SET_SCISSOR; {
                        Simp.immediate_flush();
                        Simp.set_scissor(it.rect.p0, it.rect.p1);
                    }
                }
            }
        }

        window_width, window_height := Simp.get_render_dimensions(window);

        input: Editor.Input;
        // input.time and input.dtime are zeroed.
        // input.frame_requested_by_editor is zeroed.
        input.window_size = { window_width, window_height };
        input.window_scale_factor = platform_get_window_scale_factor(window);

        mouse_x, mouse_y, success := Window.get_mouse_pointer_position();
        if success {
            input.mouse_position = { cast(f32, mouse_x), cast(f32, mouse_y) };
        }
        // input.mouse_wheel_delta is zeroed.
        // input.watched_directory_changes is zeroed.
        // input.events is zeroed.

        editor: Editor.Editor;
        Editor.init(*editor, platform, renderer, input);
        {
            time_scale := profiler_end_frame();
            print_profile_for_slow_frames(SLOW_INIT_THRESHOLD_MILLIS, time_scale);
        }

        time_of_last_frame_start := time_of_program_start;

        should_run  := true;
        while should_run {
            profiler_start_frame("frame");

            time_of_frame_start := current_time_monotonic();
            time_since_program_start := time_of_frame_start - time_of_program_start;

            dtime := time_of_frame_start - time_of_last_frame_start;
            time_of_last_frame_start = time_of_frame_start;

            input.time = time_since_program_start;
            input.dtime = dtime;

            input_events: [..] Editor.Input_Event;
            input_events.allocator = temp;

            Input.update_window_events();
            for Input.get_window_resizes() {
                Simp.update_window(it.window);

                if it.window == window {
                    input.window_size = { it.width, it.height };
                }
            }

            scale_factor := platform_get_window_scale_factor(window);
            // TODO(jt): @Cleanup The way the Windows Input module handles the .QUIT event (WM_QUIT)
            // causes the window to be destroyed before we are done with our last frame, and thus
            // the scale_factor becomes 0. This confuses the font system inside the editor. (And, in
            // general, the platform layer should give good information to the app, so the app
            // doesn't need to hack around stuff like this.)
            #if OS == .WINDOWS {
                if scale_factor != 0.0 {
                    input.window_scale_factor = scale_factor;
                }
            }

            for Input.events_this_frame {
                if it.type == {
                    case .QUIT; {
                        should_run = false;
                    }

                    // TODO(jt): On macOS at least, we are missing combined accented characters, like 'e -> = é
                    case .KEYBOARD; {
                        #if OS == .WINDOWS {
                            if it.alt_pressed && it.key_code == .F4 {
                                should_run = false;
                                continue;
                            }
                        }

                        flags: Editor.Input_Event.Flags;
                        if it.key_pressed flags |= .PRESSED;
                        if it.repeat      flags |= .REPEAT;

                        // The Input module's key_codes mirror ASCII in that range. However, for
                        // control characters outside of the ASCII range we use our own enum.
                        if it.key_code == {
                            // keycodes that are also in ASCII
                            case .BACKSPACE;            array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = .BACKSPACE });
                            case .TAB;                  array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = .TAB });
                            case .LINEFEED;             array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = .LINEFEED });
                            case .ENTER;                array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = .ENTER });
                            case .ESCAPE;               array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = .ESCAPE });
                            // SPACEBAR also gets sent as a text event, so we capture it there.
                            case .DELETE;               array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = .DELETE });

                            // keycodes that are not in ASCII
                            case .CTRL;                 array_add(*input_events, { type = .KEY, flags = flags, key = .CTRL });
                            case .ALT;                  array_add(*input_events, { type = .KEY, flags = flags, key = .ALT });
                            case .SHIFT;                array_add(*input_events, { type = .KEY, flags = flags, key = .SHIFT });
                            case .META;                 array_add(*input_events, { type = .KEY, flags = flags, key = .META });

                            case .ARROW_UP;             array_add(*input_events, { type = .KEY, flags = flags, key = .ARROW_UP });
                            case .ARROW_DOWN;           array_add(*input_events, { type = .KEY, flags = flags, key = .ARROW_DOWN });
                            case .ARROW_LEFT;           array_add(*input_events, { type = .KEY, flags = flags, key = .ARROW_LEFT });
                            case .ARROW_RIGHT;          array_add(*input_events, { type = .KEY, flags = flags, key = .ARROW_RIGHT });

                            case .PAGE_UP;              array_add(*input_events, { type = .KEY, flags = flags, key = .PAGE_UP });
                            case .PAGE_DOWN;            array_add(*input_events, { type = .KEY, flags = flags, key = .PAGE_DOWN });

                            case .HOME;                 array_add(*input_events, { type = .KEY, flags = flags, key = .HOME });
                            case .END;                  array_add(*input_events, { type = .KEY, flags = flags, key = .END });

                            case .INSERT;               array_add(*input_events, { type = .KEY, flags = flags, key = .INSERT });

                            case .F1;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F1 });
                            case .F2;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F2 });
                            case .F3;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F3 });
                            case .F4;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F4 });
                            case .F5;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F5 });
                            case .F6;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F6 });
                            case .F7;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F7 });
                            case .F8;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F8 });
                            case .F9;                   array_add(*input_events, { type = .KEY, flags = flags, key = .F9 });
                            case .F10;                  array_add(*input_events, { type = .KEY, flags = flags, key = .F10 });
                            case .F11;                  array_add(*input_events, { type = .KEY, flags = flags, key = .F11 });
                            case .F12;                  array_add(*input_events, { type = .KEY, flags = flags, key = .F12 });

                            case .PRINT_SCREEN;         array_add(*input_events, { type = .KEY, flags = flags, key = .PRINT_SCREEN });

                            case .MOUSE_BUTTON_LEFT;    array_add(*input_events, { type = .KEY, flags = flags, key = .MB_LEFT });
                            case .MOUSE_BUTTON_RIGHT;   array_add(*input_events, { type = .KEY, flags = flags, key = .MB_RIGHT });
                            case .MOUSE_BUTTON_MIDDLE;  array_add(*input_events, { type = .KEY, flags = flags, key = .MB_MIDDLE });

                            case; {
                                // TODO(jt): @Cleanup @Hack Both Windows and macOS have their quirks
                                // with translating keyboard events to text events.
                                //
                                // On macOS, Alt + key usually remaps the codepoint in the text
                                // event into an exotic character, but for us it is important to
                                // have Alt be part of keyboard shortcuts. For this reason, we
                                // modified modules/Input to ignore modifiers when extracting the
                                // text event characters. See :ModifiedInputModule.
                                //
                                // On Windows (and macOS sometimes?), holding down control
                                // suppresses the text event, so we emit it here.
                                //
                                // This is a temporary hack. We should eventually rewrite the
                                // platform layers for both and do the minimal necessary hacks
                                // there.

                                if it.ctrl_pressed && it.text_input_count == 0 {
                                    array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = cast(Editor.Codepoint, it.key_code) });
                                }
                            }
                        }
                    }

                    case .TEXT_INPUT; {
                        flags: Editor.Input_Event.Flags;
                        flags |= .PRESSED; // TEXT_INPUT implies key_pressed.

                        array_add(*input_events, { type = .CODEPOINT, flags = flags, codepoint = cast(Editor.Codepoint, it.utf32) });
                    }
                }
            }

            mouse_x, mouse_y, success := Window.get_mouse_pointer_position();
            if success {
                input.mouse_position = { cast(f32, mouse_x), cast(f32, mouse_y) };
            }
            input.mouse_wheel_delta = Input.mouse_delta_z;

            platform_process_watched_directory_changes();

            input.watched_directory_changes = platform_state.watched_directory_changes;
            input.events = input_events;

            wants_next_frame := Editor.update_and_render(*editor, platform, renderer, input);

            input.frame_requested_by_editor = wants_next_frame;

            time_scale := profiler_end_frame();
            print_profile_for_slow_frames(SLOW_FRAME_THRESHOLD_MILLIS, time_scale);

            array_reset_keeping_memory(*platform_state.watched_directory_changes);
            reset_temporary_storage();

            if should_run && !wants_next_frame {
                platform_wait_for_events();
            }
        }
    }
}

//
// Platform
//

Platform_State :: struct {
    watched_directory_changes: [..] Editor.Watched_Directory_Change; // :Malloc
    watched_directories:       [..] Watched_Directory;               // :Malloc

    #if OS == .WINDOWS {
        Watched_Directory :: struct {
            // The actual data is behind a pointer so that the overlapped structure and the notify
            // buffer are pointer stable and safe against resizes of the watched_directories array.
            info: *Watched_Directory_Info; // :Malloc
        }

        Watched_Directory_Info :: struct {
            path: string; // :Malloc
            directory_handle: HANDLE;
            overlapped: OVERLAPPED;

            read_issue_failed: bool;

            // Unlike modules/File_Watcher, the buffer is inline, so we must be careful about it being pointer-stable!
            // Additionally, we must make sure to align it manually, otherwise ReadDirectoryChangesW fails silently.
            notify_buffer: [NOTIFY_BUFFER_SIZE] u8  #align 16;

            NOTIFY_BUFFER_SIZE :: 4096;
        }
    } else #if OS == .MACOS {
        Watched_Directory :: struct {
            path: string; // :Malloc
            event_stream: FSEventStreamRef;
        }
    }
}

platform_state: Platform_State;

platform_wait_for_events :: () {
    #if OS == .WINDOWS {
        // On Windows (TM), we wait for new events with WaitMessage.
        //
        // TODO(jt): WaitMessage does not wake us for overlapped IO completion. We could signal
        // ourselves by posting onto our message queue from a callback, but we can also use
        // MsgWaitForMultipleObjectsEx().
        WaitMessage();
    } else #if OS == .MACOS {
        // On macOS, we wait for events by checking the queue with nextEventMatchingMask
        // (with NO as the last parameter so that we don't dequeue).
        NSApplication.nextEventMatchingMask(NSApp, NSEventMaskAny, NSDate.distantFuture(), NSDefaultRunLoopMode, NO);
    }
}

platform_get_window_scale_factor :: (window: Window.Window_Type) -> f32 {
    #if OS == .WINDOWS {
        return cast(f32, GetDpiForWindow(window)) / 96.0;
    } else #if OS == .MACOS {
        // backingScaleFactor is only tells us, if we are on a Retina display (by returning 2.0),
        // but it doesn't tell us what scaling the user has picked. Still, we can use it to
        // approximate how large we want things to be. Maybe there is a better solution, but winit
        // also does backingScaleFactor.
        return cast(f32, window.backingScaleFactor(window));
    }

    return 1.0;
}

platform_process_watched_directory_changes :: () {
    #if OS == .WINDOWS {
        advance_notify_info :: (info: *FILE_NOTIFY_INFORMATION) -> *FILE_NOTIFY_INFORMATION {
            if info.NextEntryOffset == 0 {
                return null;
            }

            return cast(*FILE_NOTIFY_INFORMATION, cast(*u8, info) + info.NextEntryOffset);
        }

        for * platform_state.watched_directories {
            if it.info.read_issue_failed {
                it.info.read_issue_failed = false;
                issue_one_read(it.info);

                // If the read failed again immediately, we'll try again next time.
                if it.info.read_issue_failed {
                    continue;
                }
            }

            if !HasOverlappedIoCompleted(it.info.overlapped) {
                continue;
            }

            bytes_transferred: s32;
            success := GetOverlappedResult(it.info.directory_handle, *it.info.overlapped, *bytes_transferred, FALSE);
            if success {
                log("% bytes transferred into notify buffer for watching directory %", bytes_transferred, it.info.path);
            }

            defer issue_one_read(it.info); // Note that we can miss events until the overlapped read gets set up again. It is fine.

            if !success {
                continue;
            }

            if bytes_transferred == 0 {
                // The changes buffer overflowed. Add full rescan event for the whole directory.
                change := array_add(*platform_state.watched_directory_changes);
                change.path = copy_string(it.info.path,, temp);
                change.flags |= .MODIFIED | .NEED_FULL_CHILDREN_SCAN;

                continue;
            }

            notify_info := cast(*FILE_NOTIFY_INFORMATION, it.info.notify_buffer.data);
            while notify_info != null {
                defer notify_info = advance_notify_info(notify_info);

                flags: Editor.Watched_Directory_Change.Flags;
                if notify_info.Action == {
                    case FILE_ACTION_ADDED;             flags = .ADDED;
                    case FILE_ACTION_REMOVED;           flags = .REMOVED;
                    case FILE_ACTION_MODIFIED;          flags = .MODIFIED;
                    case FILE_ACTION_RENAMED_OLD_NAME;  flags = .MOVED | .MOVED_FROM;
                    case FILE_ACTION_RENAMED_NEW_NAME;  flags = .MOVED | .MOVED_TO;
                    case;                               continue;
                }

                filename_data  := cast(*u16, notify_info.FileName.data);
                filename_count := notify_info.FileNameLength / 2; // FileNameLength is in bytes.

                path, success := wide_to_utf8(filename_data, filename_count,, temp);
                if !success {
                    continue;
                }

                String.path_overwrite_separators(path, #char "/");
                full_path := tprint("%/%", it.info.path, path);

                if flags & .MODIFIED && File_Utilities.is_directory(full_path) {
                    // TODO(jt): @Audit From modules/File_Watcher:
                    //
                    // Window's doesn't seem to issue the right events when things are renamed or moved.
                    // Instead it issues a "MODIFIED" event for the parent directory that the change occurred in.
                    flags |= .NEED_FULL_CHILDREN_SCAN;
                }

                change := array_add(*platform_state.watched_directory_changes);
                change.path = full_path;
                change.flags |= flags;
            }
        }
    } else #if OS == .MACOS {
        // TODO(jt): @Audit Unlike modules/File_Watcher, we actually don't need to call this,
        // because (presumably) AppKit calls this for us, which in turn calls event_stream_callback.
        // I wish I understood the Apple ecosystem more.
        //
        // CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
    }
}

#if OS == .WINDOWS {
    issue_one_read :: (info: *Platform_State.Watched_Directory_Info) {
        NOTIFY_FILTER: s32 : FILE_NOTIFY_CHANGE_FILE_NAME
            | FILE_NOTIFY_CHANGE_DIR_NAME
            | FILE_NOTIFY_CHANGE_CREATION
            | FILE_NOTIFY_CHANGE_SIZE
            | FILE_NOTIFY_CHANGE_LAST_WRITE
            | FILE_NOTIFY_CHANGE_SECURITY
            | FILE_NOTIFY_CHANGE_ATTRIBUTES;

        success := ReadDirectoryChangesW(info.directory_handle,
                                         info.notify_buffer.data, info.notify_buffer.count,
                                         /* bWatchSubtree could also be FALSE */ TRUE, NOTIFY_FILTER,
                                         null, *info.overlapped, null);

        if !success {
            info.read_issue_failed = true;

            error_code, description := System.get_error_value_and_string();
            log_error("ReadDirectoryChangesW failed for directory %: %, %", info.path, error_code, description);
        }
    }
} else #if OS == .MACOS {
    event_stream_callback :: (streamRef: FSEventStreamRef, clientCallBackInfo: *void, numEvents: u64, eventPaths: *void, eventFlags: *FSEventStreamEventFlags, eventIds: *FSEventStreamEventId) #c_call {
        FS_ATTRIBUTE_CHANGES :: kFSEventStreamEventFlagChangeOwner | kFSEventStreamEventFlagItemInodeMetaMod | kFSEventStreamEventFlagItemFinderInfoMod;

        // push_context and set temporary storage, because we copy_string with temp below.
        // This callback *should* run on the main thread. You can verify this with:
        //
        // assert(main_thread == pthread_self()); // Get main_thread at the start of the program.
        push_context {
            context.temporary_storage = main_thread_temporary_storage;

            event_paths := cast(**u8, eventPaths);
            for 0..numEvents - 1 {
                event_flags := eventFlags[it];
                event_id    := eventIds[it];
                event_path  := to_string(event_paths[it]);

                flags: Editor.Watched_Directory_Change.Flags;
                if event_flags & kFSEventStreamEventFlagItemCreated      flags |= .ADDED;
                if event_flags & kFSEventStreamEventFlagItemRemoved      flags |= .REMOVED;
                if event_flags & kFSEventStreamEventFlagItemModified     flags |= .MODIFIED;
                if event_flags & FS_ATTRIBUTE_CHANGES                    flags |= .ATTRIBUTES_CHANGED;

                if event_flags & kFSEventStreamEventFlagItemRenamed      flags |= .MOVED;
                if event_flags & kFSEventStreamEventFlagMustScanSubDirs  flags |= .NEED_FULL_CHILDREN_SCAN;

                if !flags {
                    continue;
                }

                if event_flags & kFSEventStreamEventFlagItemIsDir && event_flags & (kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRenamed) {
                    flags |= .NEED_FULL_CHILDREN_SCAN;
                }

                change := array_add(*platform_state.watched_directory_changes);
                change.path = copy_string(event_path,, temp); // event_path will be deallocated by the kernel once the callback returns, so we want our own copy.
                change.flags = flags;
            }
        }
    }
}

//
// Renderer
//

Renderer_State :: struct {
    window: *void;

    textures: Table(Editor.Texture_ID, Simp.Texture); // We currently aren't careful about allocating textures, but there aren't many. :Malloc
    text_shader: Simp.Shader;
    current_pipeline: Pipeline = .NONE; // To prevent immediate_flush when pipeline is the same.

    Pipeline :: enum {
        NONE;
        TEXT;
        COLOR;
    }
}

renderer_state: Renderer_State;

// This is a modified version of SHADER_SPRITE_LEFT_HANDED from Simp, so that we can pass in a
// single-channel texture and have the colors map the way we want.
SHADER_TEXT :: #string END
OUT_IN vec2 v_tex_coords;
OUT_IN vec4 v_color;

#ifdef VERTEX_SHADER
// These have to be named vert_xyz, because Simp is looking for those idents.
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    v_tex_coords = vert_uv0.xy;
    v_color = vert_color;
    gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
}
#endif

#ifdef FRAGMENT_SHADER
out vec4 f_color;

uniform sampler2D diffuse_texture;

void main () {
    float a = texture(diffuse_texture, v_tex_coords).r;
    f_color = v_color * vec4(1, 1, 1, a);
}
#endif
END

SHADER_TEXT_SUBPIXEL :: #string END
OUT_IN vec2 v_tex_coords;
OUT_IN vec4 v_color;

#ifdef VERTEX_SHADER
// These have to be named vert_xyz, because Simp is looking for those idents.
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    v_tex_coords = vert_uv0.xy;
    v_color = vert_color;
    gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
}
#endif

#ifdef FRAGMENT_SHADER
layout(location = 0, index = 0) out vec4 f_color;
layout(location = 0, index = 1) out vec4 f_blend;

uniform sampler2D diffuse_texture;

void main () {
    vec3 coverage = texture(diffuse_texture, v_tex_coords).rgb;

    f_color = v_color;
    f_blend = vec4(coverage, 1.0);
}
#endif
END

//
// Logger
//

Context_Logger_Data :: struct {
    time_of_program_start: Apollo_Time;
}

context_logger :: (message: string, data: *void, info: Log_Info) {
    if !message {
        return;
    }

    context_logger_data := cast(*Context_Logger_Data, data);

    // Add time since launch. Pad to up to 4 leading digits and 6 decimal digits.
    time_start           := context_logger_data.time_of_program_start;
    time_now             := current_time_monotonic();
    time_since_start     := time_now - time_start;
    time_since_start_str := tprint("% ", formatFloat(to_float64_seconds(time_since_start), trailing_width = 6, zero_removal = .NO));
    time_prefix          := temp_left_pad(time_since_start_str, 12);

    // Add log level.
    log_level_prefix := " INFO ";
    if info.common_flags & .WARNING  log_level_prefix = " WARN ";
    if info.common_flags & .ERROR    log_level_prefix = "ERROR ";

    // Add source file.
    source_prefix: string;
    {
        PAD_LENGTH :: 30;
        MODULES :: "modules/";

        path := info.location.fully_pathed_filename;
        index := String.find_index_from_left(path, MODULES);
        if index != -1 {
            source_prefix = advance(path, index + MODULES.count);
        } else {
            filename := String.path_filename(path);
            source_prefix = filename;
        }

        source_prefix = temp_right_pad(source_prefix, PAD_LENGTH);
    }

    write_strings(time_prefix, log_level_prefix, source_prefix, " ", message, "\n", to_standard_error = (info.common_flags & .ERROR) != 0);
}

//
// Misc helpers
//

print_profile_for_slow_frames :: (threshold_millis: f64, time_scale: f64) {
    zones, zone_labels := profiler_get_zones(.INCLUSIVE_TIME,, temp);
    if zones.count {
        frame_time := 1000.0 * time_scale * zones[0].elapsed_inclusive;
        if frame_time >= threshold_millis {
            print("\nFrame took more than % millis. Printing profiling info for % zones:\n\n", threshold_millis, zones.count);

            print("      zone                                                               hits    inclusive millis    exclusive millis\n");
            print("---------------------------------------------------------------------------------------------------------------------\n");
            for zones {
                print(
                    "% %      %     %     %\n",
                    temp_right_pad(tprint("[%]", it_index), 5),
                    temp_right_pad(zone_labels[it_index], 50),
                    formatInt(it.hits, minimum_digits = 15, padding = #char " "),
                    formatFloat(1000 * time_scale * it.elapsed_inclusive, width = 15, trailing_width = 3),
                    formatFloat(1000 * time_scale * it.elapsed_exclusive, width = 15, trailing_width = 3),
                );
            }
        }
    }
}

// These are copypaste from src/string.jai, but it isn't worth it #load-ing all of that code just for these two.

temp_left_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    for s.count..length - 1 {
        append(*builder, " ");
    }

    append(*builder, s);

    return builder_to_string(*builder,, temp);
}

temp_right_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, s);

    for s.count..length - 1 {
        append(*builder, " ");
    }

    return builder_to_string(*builder,, temp);
}
