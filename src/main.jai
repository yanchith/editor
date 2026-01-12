f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Hash_Table";

String :: #import "String";
File   :: #import "File";
Window :: #import "Window_Creation";
Input  :: #import "Input";
Simp   :: #import "Simp"; // TODO(jt): Make our own simple renderer on Vulkan and Metal? SGPU? WGPU? Something.
Editor :: #import,file "editor/editor.jai";

IRect :: Editor.IRect;

// TODO(jt): This global is fine for now, but maybe we want to pass userdata through the renderer
// API that the caller has to pass back?
renderer_textures: Table(Editor.Texture_ID, Simp.Texture);

main :: () {
    time_program_start := current_time_monotonic();

    context_logger_data := Context_Logger_Data.{ time_program_start };

    editor_context := context;
    editor_context.logger      = context_logger;
    editor_context.logger_data = *context_logger_data;

    push_context editor_context {
        #if OS == .MACOS {
            System         :: #import "System";
            File_Utilities :: #import "File_Utilities";

            see_data := true;
            see_data &&= File_Utilities.is_directory("data/fonts");

            if !see_data {
                exe_file := System.get_path_of_running_executable();
                exe_dir  := String.path_strip_filename(exe_file);

                log("We are on macOS and we don't see our data. Attempting to set working directory to the executable path: %", exe_dir);

                set_working_directory(exe_dir);
            }
        }

        time_last_frame_start := time_program_start;

        window_width:  s32 = 1600;
        window_height: s32 = 900;
        window := Window.create_window(window_width, window_height, "editor");

        Simp.set_render_target(window, .LEFT_HANDED);

        platform: Editor.Platform;
        #if OS == .WINDOWS {
            W :: #import "Windows";

            info: W.SYSTEM_INFO;
            W.GetSystemInfo(*info);

            platform.page_size = info.dwPageSize;
            platform.mem_reserve = (size: s64) -> *void {
                return W.VirtualAlloc(null, cast(u64, size), W.MEM_RESERVE, W.PAGE_READWRITE);
            };
            platform.mem_release = (pointer: *void, size: s64) {
                W.VirtualFree(pointer, 0, W.MEM_RELEASE);
            }
            platform.mem_commit = (pointer: *void, size: s64) -> bool {
                result := W.VirtualAlloc(pointer, cast(u64, size), W.MEM_COMMIT, W.PAGE_READWRITE);
                return result != null;
            }
            platform.mem_decommit = (pointer: *void, size: s64) {
                W.VirtualFree(pointer, cast(u64, size), W.MEM_DECOMMIT);
            };
        } else #if OS_IS_UNIX {
            P :: #import "POSIX";

            platform.page_size = P.sysconf(P._SC_PAGE_SIZE);
            platform.mem_reserve = (size: s64) -> *void {
                result := P.mmap(null, cast(u64, size), P.PROT_NONE, P.MAP_PRIVATE | P.MAP_ANONYMOUS, 0, 0);
                if result == P.MAP_FAILED {
                    result = null;
                }

                return result;
            }
            platform.mem_release = (pointer: *void, size: s64) {
                P.munmap(pointer, cast(u64, size));
            }
            platform.mem_commit = (pointer: *void, size: s64) -> bool {
                result := P.mprotect(pointer, cast(u64, size), P.PROT_READ | P.PROT_WRITE);
                return result == 0;
            }
            platform.mem_decommit = (pointer: *void, size: s64) {
                P.madvise(pointer, cast(u64, size), P.MADV_DONTNEED);
                P.mprotect(pointer, cast(u64, size), P.PROT_NONE);
            }
        }

        platform.read_file = (path: string) -> success: bool, data: [] u8 {
            // NOTE(jt): get_absolute_path goes to Temporary_Storage all the time, but I suspect it
            // will start respecting context.allocator eventually, so we pass in temp there as well.
            absolute_path := File.get_absolute_path(path,, temp);
            data, success := File.read_entire_file(absolute_path);

            return success, cast([] u8, data);
        }

        renderer: Editor.Renderer;
        renderer.create_texture_r8unorm = (texture_id: Editor.Texture_ID, width: s32, height: s32, data: [] u8) {
            bitmap: Simp.Bitmap;
            Simp.bitmap_alloc(*bitmap, width, height, .R8,, temp);
            bitmap.flags &= ~.FREE_DATA_ON_DEINIT; // The bitmap is allocated in temporary storage, so no need.


            assert(bitmap.data.count == data.count);
            memcpy(bitmap.data.data, data.data, data.count);

            texture: Simp.Texture;
            Simp.texture_load_from_bitmap(*texture, *bitmap);

            table_add(*renderer_textures, texture_id, texture);
        }
        renderer.update_texture_regions_r8unorm = (texture_id: Editor.Texture_ID, regions: [] IRect, data: [] u8) {
            texture := table_find_pointer(*renderer_textures, texture_id);
            if !texture {
                log_error("Can't update nonexistent texture: %", texture_id);
            }

            // TODO(jt): @Correctness @Speed This function re-uploads everything, because Simp does
            // glTexImage2D. Whatever backend we end up using, we want to limit the upload to just
            // the subregions. This may also end up being a correctness issue, but at the moment it
            // is fine.

            bitmap: Simp.Bitmap;
            Simp.bitmap_alloc(*bitmap, texture.width, texture.height, .R8,, temp);
            bitmap.flags &= ~.FREE_DATA_ON_DEINIT; // The bitmap is allocated in temporary storage, so no need.

            assert(bitmap.data.count == data.count);
            memcpy(bitmap.data.data, data.data, data.count);

            Simp.texture_load_from_bitmap(texture, *bitmap);
        }
        renderer.draw_rects = (render_rects: [] Editor.Render_Rect) {
            // TODO(jt): @Speed Realistically, they all point to the same texture, so maybe we want
            // to shape the API such that there is only one texture binding followed by an instanced
            // draw command instead of looping and binding per iteration.
            for render_rects {
                texture := table_find_pointer(*renderer_textures, it.texture_id);
                Simp.set_shader_for_images(texture);

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
        }

        editor: Editor.Editor;
        Editor.init(*editor, platform, renderer);

        should_run := true;

        // TODO(jt): Change this to wake up and run only if there are events (but still v-sync the render).
        while should_run {
            reset_temporary_storage();

            time_frame_start := current_time_monotonic();
            time_since_program_start := time_frame_start - time_program_start;

            dtime := time_frame_start - time_last_frame_start;
            time_last_frame_start = time_frame_start;

            input: Editor.Input;
            // TODO(jt): Fill in input.

            Input.update_window_events();
            for Input.get_window_resizes() {
                Simp.update_window(it.window);

                if it.window == window {
                    input.window_size = { it.width, it.height };
                }
            }

            for Input.events_this_frame {
                if it.type == {
                    case .QUIT; {
                        should_run = false;
                    }

                    case .KEYBOARD; {
                        #if OS == .WINDOWS {
                            if it.alt_pressed && it.key_code == .F4 {
                                should_run = false;
                            }
                        }
                    }
                }
            }

            mouse_x, mouse_y, success := Window.get_mouse_pointer_position();
            if success {
                input.mouse_position = .{ cast(f32, mouse_x), cast(f32, mouse_y) };
            }

            Simp.clear_render_target(1, 1, 1, 1);

            wants_quit := Editor.update_and_render(*editor, platform, renderer, input);
            if wants_quit {
                should_run = false;
            }

            Simp.swap_buffers(window);

        }
    }
}

Context_Logger_Data :: struct {
    time_program_start: Apollo_Time;
}

context_logger :: (message: string, data: *void, info: Log_Info) {
    left_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        // TODO(jt): @Speed memset?
        for s.count..length - 1 {
            append(*builder, #char " ");
        }

        append(*builder, s);

        return builder_to_string(*builder,, temp);
    }

    right_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        append(*builder, s);

        // TODO(jt): @Speed memset?
        for s.count..length - 1 {
            append(*builder, #char " ");
        }

        return builder_to_string(*builder,, temp);
    }

    if !message {
        return;
    }

    context_logger_data := cast(*Context_Logger_Data, data);

    // Add time since launch. Pad to up to 4 leading digits and 6 decimal digits.
    time_start           := context_logger_data.time_program_start;
    time_now             := current_time_monotonic();
    time_since_start     := time_now - time_start;
    time_since_start_str := tprint("% ", formatFloat(to_float64_seconds(time_since_start), trailing_width = 6, zero_removal = .NO));
    time_prefix          := left_pad(time_since_start_str, 12);

    // Add log level.
    log_level_prefix := " INFO ";
    if info.common_flags & .WARNING  log_level_prefix = " WARN ";
    if info.common_flags & .ERROR    log_level_prefix = "ERROR ";

    // Add source file.
    source_prefix: string;
    {
        LENGTH :: 30;
        MODULES :: "modules/";

        path := info.location.fully_pathed_filename;
        index := String.find_index_from_left(path, MODULES);
        if index != -1 {
            source_prefix = advance(path, index + MODULES.count);
        } else {
            _, _, _, basename_with_extension := String.path_decomp(path);
            source_prefix = basename_with_extension;
        }

        source_prefix = right_pad(source_prefix, LENGTH + 1);
    }

    write_strings(time_prefix, log_level_prefix, source_prefix, message, "\n", to_standard_error = (info.common_flags & .ERROR) != 0);
}
