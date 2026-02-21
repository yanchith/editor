f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Hash_Table";

Memory :: #import "Memory";
Random :: #import "Random";
String :: #import "String";
File   :: #import "File";
Window :: #import "Window_Creation";
Input  :: #import "Input";
Simp   :: #import "Simp"; // TODO(jt): Make our own simple renderer on Vulkan and Metal? SGPU? WGPU? Something.
Editor :: #import,file "editor/editor.jai";

Random_State           :: Random.Random_State;
random_seed            :: Random.random_seed;
random_get             :: Random.random_get;
random_get_zero_to_one :: Random.random_get_zero_to_one;

IRect :: Editor.IRect;

// TODO(jt): These globals are fine for now, but maybe we want to pass userdata through the renderer API?
renderer_textures: Table(Editor.Texture_ID, Simp.Texture);
renderer_shader: Simp.Shader;

main :: () {
    time_program_start := current_time_monotonic();

    context_logger_data := Context_Logger_Data.{ time_program_start };

    editor_context := context;
    editor_context.logger      = context_logger;
    editor_context.logger_data = *context_logger_data;

    fuzz_rng: Random_State;
    random_seed(*fuzz_rng, 1);

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


        renderer_shader.gl_handle = Simp.get_shader_program(SHADER_SPRITE_LEFT_HANDED_SINGLE_CHANNEL);
        renderer_shader.alpha_blend = true;

        renderer: Editor.Renderer;
        renderer.create_texture_r8unorm = (texture_id: Editor.Texture_ID, width: s32, height: s32, data: [] u8) {
            bitmap: Simp.Bitmap;
            Simp.bitmap_alloc(*bitmap, width, height, .R8,, temp);
            bitmap.flags &= ~.FREE_DATA_ON_DEINIT; // The bitmap is allocated in temporary storage, so no need.


            assert(bitmap.data.count == data.count);
            Memory.copy(bitmap.data.data, data.data, data.count);

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
            Memory.copy(bitmap.data.data, data.data, data.count);

            Simp.texture_load_from_bitmap(texture, *bitmap);
        }
        renderer.draw_rects = (render_rects: [] Editor.Render_Rect) {
            // TODO(jt): @Speed Realistically, they all point to the same texture, so maybe we want
            // to shape the API such that there is only one texture binding followed by an instanced
            // draw command instead of looping and binding per iteration. If they for some reason
            // don't fit into one texture, we'd flush thhe pipeline.
            for render_rects {
                texture := table_find_pointer(*renderer_textures, it.texture_id);

                // NOTE(jt): This is where we'd normally call Simp.set_shader_for_images(texture),
                // but we instead pass in our modified shader, so we have to do a little bit more
                // work.
                {
                    Simp.immediate_flush();

                    target_shader := *renderer_shader;
                    if context.simp.current_shader != target_shader {
                        Simp.immediate_set_shader(target_shader);
                        Simp.set_projection();
                    }

                    Simp.immediate_set_texture(texture);
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
        }

        input: Editor.Input;
        input.window_size = { window_width, window_height };

        editor: Editor.Editor;
        Editor.init(*editor, platform, renderer);

        should_run  := true;
        should_fuzz := false;

        // TODO(jt): Change this to wake up and run only if there are events (but still v-sync the render).
        while should_run {
            reset_temporary_storage();

            time_frame_start := current_time_monotonic();
            time_since_program_start := time_frame_start - time_program_start;

            dtime := time_frame_start - time_last_frame_start;
            time_last_frame_start = time_frame_start;

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

            for Input.events_this_frame {
                if it.type == {
                    case .QUIT; {
                        should_run = false;
                    }

                    // XXX: On macOS at least, we are missing combined accented characters, like 'e -> = é
                    case .KEYBOARD; {
                        #if OS == .WINDOWS {
                            if it.alt_pressed && it.key_code == .F4 {
                                should_run = false;
                            }
                        }

                        // TODO(jt): Send down repeats.
                        flags: Editor.Input_Event.Flags;
                        if it.key_pressed {
                            flags |= .KEY_PRESSED;
                        }

                        // The Input module's key_codes mirror ASCII in that range. However, for
                        // control characters outside of the ASCII range we use our own enum.
                        if it.key_code == {
                            // keycodes that are also in ASCII
                            case .BACKSPACE;               array_add(*input_events, { .CODEPOINT, flags, { codepoint = .BACKSPACE } });
                            case .TAB;                     array_add(*input_events, { .CODEPOINT, flags, { codepoint = .TAB } });
                            case .LINEFEED;                array_add(*input_events, { .CODEPOINT, flags, { codepoint = .LINEFEED } });
                            case .ENTER;                   array_add(*input_events, { .CODEPOINT, flags, { codepoint = .ENTER } });
                            case .ESCAPE;                  array_add(*input_events, { .CODEPOINT, flags, { codepoint = .ESCAPE } });
                            // SPACEBAR also gets sent as a text event, so we capture it there.
                            case .DELETE;                  array_add(*input_events, { .CODEPOINT, flags, { codepoint = .DELETE } });

                            // keycodes that are not in ASCII
                            case .CTRL;                    array_add(*input_events, { .KEY, flags, { key = .CTRL} });
                            case .ALT;                     array_add(*input_events, { .KEY, flags, { key = .ALT } });
                            case .SHIFT;                   array_add(*input_events, { .KEY, flags, { key = .SHIFT } });
                            case .META;                    array_add(*input_events, { .KEY, flags, { key = .META } });

                            case .ARROW_UP;                array_add(*input_events, { .KEY, flags, { key = .ARROW_UP } });
                            case .ARROW_DOWN;              array_add(*input_events, { .KEY, flags, { key = .ARROW_DOWN } });
                            case .ARROW_LEFT;              array_add(*input_events, { .KEY, flags, { key = .ARROW_LEFT } });
                            case .ARROW_RIGHT;             array_add(*input_events, { .KEY, flags, { key = .ARROW_RIGHT } });

                            case .PAGE_UP;                 array_add(*input_events, { .KEY, flags, { key = .PAGE_UP } });
                            case .PAGE_DOWN;               array_add(*input_events, { .KEY, flags, { key = .PAGE_DOWN } });

                            case .HOME;                    array_add(*input_events, { .KEY, flags, { key = .HOME } });
                            case .END;                     array_add(*input_events, { .KEY, flags, { key = .END } });

                            case .INSERT;                  array_add(*input_events, { .KEY, flags, { key = .INSERT } });

                            case .F1;                      array_add(*input_events, { .KEY, flags, { key = .F1 } });
                            case .F2;                      array_add(*input_events, { .KEY, flags, { key = .F2 } });
                            case .F3;                      array_add(*input_events, { .KEY, flags, { key = .F3 } });
                            case .F4;                      array_add(*input_events, { .KEY, flags, { key = .F4 } });
                            case .F5;                      array_add(*input_events, { .KEY, flags, { key = .F5 } });
                            case .F6;                      array_add(*input_events, { .KEY, flags, { key = .F6 } });
                            case .F7;                      array_add(*input_events, { .KEY, flags, { key = .F7 } });
                            case .F8;                      array_add(*input_events, { .KEY, flags, { key = .F8 } });
                            case .F9;                      array_add(*input_events, { .KEY, flags, { key = .F9 } });
                            case .F10;                     array_add(*input_events, { .KEY, flags, { key = .F10 } });
                            case .F11;                     array_add(*input_events, { .KEY, flags, { key = .F11 } });
                            case .F12;                     array_add(*input_events, { .KEY, flags, { key = .F12 } }); if it.key_pressed then should_fuzz = !should_fuzz;

                            case .PRINT_SCREEN;            array_add(*input_events, { .KEY, flags, { key = .PRINT_SCREEN } });

                            case .MOUSE_BUTTON_LEFT;       array_add(*input_events, { .KEY, flags, { key = .MOUSE_BUTTON_LEFT } });
                            case .MOUSE_BUTTON_RIGHT;      array_add(*input_events, { .KEY, flags, { key = .MOUSE_BUTTON_RIGHT } });
                            case .MOUSE_BUTTON_MIDDLE;     array_add(*input_events, { .KEY, flags, { key = .MOUSE_BUTTON_MIDDLE } });

                            case; {
                                #if OS == .MACOS {
                                    // @Hack macOS doesn't send these as TEXT_INPUT, if ctrl is held
                                    // down, so we listen for them here. More accurately,
                                    // text_input_count is nonzero and it sends weird control
                                    // characters, but they get filtered out. Probably there is a
                                    // better way of doing this, but for now we are hacking around
                                    // modules/Input.
                                    //
                                    // Between SPACE and DELETE
                                    if it.ctrl_pressed && it.key_code >= 32 && it.key_code <= 127 {
                                        array_add(*input_events, { .CODEPOINT, flags, { codepoint = cast(Editor.Codepoint, it.key_code) } });
                                    }
                                }
                            }
                        }
                    }

                    case .TEXT_INPUT; {
                        flags: Editor.Input_Event.Flags;
                        flags |= .KEY_PRESSED; // TEXT_INPUT implies key_pressed.

                        data: Editor.Input_Event.Data;
                        data.codepoint = cast(Editor.Codepoint, it.utf32);

                        array_add(*input_events, { .CODEPOINT, flags, data });
                    }
                }
            }

            if should_fuzz {
                MOVES   :: Editor.Key.[.ARROW_UP, .ARROW_DOWN, .ARROW_LEFT, .ARROW_RIGHT];
                ADDS    :: Editor.Codepoint.[.ENTER, .SPACEBAR, .TAB, #char "A", #char "B", #char "C", #char "D", #char "E", #char "F", #char "š", #char "č", #char "ť", #char "か", #char "わ", #char "い", #char "可", #char "愛"];
                DELETES :: Editor.Codepoint.[.BACKSPACE, .DELETE];

                for 0..1000 {
                    r := random_get_zero_to_one(*fuzz_rng);

                    if r < 0.2 {
                        e := array_add(*input_events);
                        e.type = .KEY;
                        e.flags |= .KEY_PRESSED;

                        index := random_get(*fuzz_rng) % MOVES.count;
                        e.data.key = MOVES[index];
                    } else if r < 0.8 {
                        e := array_add(*input_events);
                        e.type = .CODEPOINT;
                        e.flags |= .KEY_PRESSED;

                        index := random_get(*fuzz_rng) % ADDS.count;
                        e.data.codepoint = ADDS[index];
                    } else if r < 0.99 {
                        e := array_add(*input_events);
                        e.type = .CODEPOINT;
                        e.flags |= .KEY_PRESSED;

                        index := random_get(*fuzz_rng) % DELETES.count;
                        e.data.codepoint = DELETES[index];
                    } else if r < 0.995 {
                        for 0..100 {
                            e := array_add(*input_events);
                            e.type = .KEY;
                            e.flags |= .KEY_PRESSED;

                            e.data.key = .ARROW_RIGHT;
                        }

                        for 0..100 {
                            e := array_add(*input_events);
                            e.type = .CODEPOINT;
                            e.flags |= .KEY_PRESSED;

                            e.data.codepoint = .BACKSPACE;
                        }
                    } else {
                        for 0..100 {
                            e := array_add(*input_events);
                            e.type = .KEY;
                            e.flags |= .KEY_PRESSED;

                            e.data.key = .ARROW_LEFT;
                        }

                        for 0..100 {
                            e := array_add(*input_events);
                            e.type = .CODEPOINT;
                            e.flags |= .KEY_PRESSED;

                            e.data.codepoint = .DELETE;
                        }
                    }
                }
            }

            mouse_x, mouse_y, success := Window.get_mouse_pointer_position();
            if success {
                input.mouse_position = .{ cast(f32, mouse_x), cast(f32, mouse_y) };
            }

            input.events = input_events;

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

        // TODO(jt): @Speed resize + memset?
        for s.count..length - 1 {
            append(*builder, " ");
        }

        append(*builder, s);

        return builder_to_string(*builder,, temp);
    }

    right_pad :: (s: string, length: s64) -> string {
        builder: String_Builder;
        builder.allocator = temp;

        append(*builder, s);

        // TODO(jt): @Speed resize + memset?
        for s.count..length - 1 {
            append(*builder, " ");
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

// This is a modified version of SHADER_SPRITE_LEFT_HANDED from Simp, so that we can pass in a
// single-channel texture and have the colors map the way we want.
SHADER_SPRITE_LEFT_HANDED_SINGLE_CHANNEL :: #string END
OUT_IN vec2 TexCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
in vec4 vert_position;
in vec4 vert_color;
in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    TexCoords = vert_uv0.xy;
    gl_Position = projection * vec4(vert_position.xy, 0.0, 1.0);
    iterated_color = vert_color;
}
#endif

#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D diffuse_texture;

void main () {
    // This is the modified part. The single texture channel will become our alpha. We also got rid
    // of the discard.
    color = iterated_color * vec4(1, 1, 1, texture(diffuse_texture, TexCoords));
}
#endif
END
