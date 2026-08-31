renderer_init :: (window: WT.Window_Type) {
    Simp.set_render_target(window, .LEFT_HANDED);

    // :WindowsVSync
    //
    // We don't currently enable VSync, because it didn't do anything and
    // we still burned CPU inside the driver.
    /*
    #if OS == .WINDOWS {
        // Enable VSync if we can.
        _wglSwapIntervalEXT : (interval: s32) -> BOOL #foreign;
        _wglSwapIntervalEXT = xx wglGetProcAddress("wglSwapIntervalEXT");
        if _wglSwapIntervalEXT {
            success := _wglSwapIntervalEXT(1);
            if success {
                log("VSync enabled");
            } else {
                log_error("Failed to enable VSync");
            }
        } else {
            log_error("Failed to load wglSwapIntervalEXT; Can't enable VSync");
        }
    }
    */

    renderer_state.window = window;

    renderer_state.text_shader.gl_handle   = Simp.get_shader_program(TEXT_SHADER);
    renderer_state.text_shader.alpha_blend = true;
    renderer_state.text_shader_subpixel.gl_handle   = Simp.get_shader_program(TEXT_SHADER_SUBPIXEL);
    renderer_state.text_shader_subpixel.alpha_blend = true;

    renderer_update(window);
}

renderer_update :: (window: WT.Window_Type) {
    Simp.update_window(window);
}

renderer_create_texture_r8unorm :: (texture_id: Editor.Texture_ID, data: [] u8, width: s32, height: s32, filter: Editor.Texture_Filter) {
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

renderer_create_texture_rgba8unorm :: (texture_id: Editor.Texture_ID, data: [] u8, width: s32, height: s32, filter: Editor.Texture_Filter) {
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

renderer_update_texture_r8unorm :: (texture_id: Editor.Texture_ID, data: [] u8, update_rect: IRect) {
    ProfileZone("renderer_update_texture_r8unorm");

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

renderer_update_texture_rgba8unorm :: (texture_id: Editor.Texture_ID, data: [] u8, update_rect: IRect) {
    ProfileZone("renderer_update_texture_rgba8unorm");

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

renderer_begin_frame :: (clear_color: Vector4) {
    ProfileZone("renderer_begin_frame");

    // TODO(jt): @Bug On Windows, when a window is resized, we clear the the old surface here.
    Simp.clear_render_target(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
}

renderer_submit_frame :: () {
    ProfileZone("renderer_submit_frame");
    Simp.swap_buffers(renderer_state.window);

    // :WindowVSync
    //
    // wglSwapInterval unfortunately does nothing (at least on my computer/drivers).
    // This seems to help and I noticed no bad side effects yet.
    #if OS == .WINDOWS {
        hresult := DwmFlush();
        if hresult != S_OK {
            log_error("Call to DwmFlush failed: %", hresult);
        }
    }
}

renderer_draw :: (render_commands: [] Editor.Render_Command) {
    ProfileZone("renderer_draw");

    // TODO(jt): @Speed Realistically, they all point to the same texture, so maybe we want
    // to shape the API such that there is only one texture binding followed by an instanced
    // draw command instead of looping and binding per iteration, or something like that.
    for render_commands {
        if #complete it.type == {
            case .DRAW_COLOR_RECT; {
                if renderer_state.pipeline != .COLOR {
                    renderer_state.pipeline = .COLOR;
                    Simp.set_shader_for_color(enable_blend = true);
                }

                Simp.immediate_quad(
                    { it.rect.x0, it.rect.y0 },
                    { it.rect.x0, it.rect.y1 },
                    { it.rect.x1, it.rect.y1 },
                    { it.rect.x1, it.rect.y0 },
                    it.color,
                );
            }

            case .DRAW_TEXT; {
                texture := table_find_pointer(*renderer_state.textures, it.texture_id);
                if !texture {
                    continue;
                }

                if renderer_state.pipeline != .TEXT {
                    renderer_state.pipeline = .TEXT;
                    // This is where we'd normally call Simp.set_shader_for_images(texture), but
                    // we instead pass in our modified shader, so we have to do a little bit
                    // more work.
                    Simp.immediate_flush();

                    target_shader := *renderer_state.text_shader;
                    if context.simp.current_shader != target_shader {
                        Simp.immediate_set_shader(target_shader);
                        Simp.set_projection();
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

            case .DRAW_TEXT_SUBPIXEL; {
                texture := table_find_pointer(*renderer_state.textures, it.texture_id);
                if !texture {
                    continue;
                }

                if renderer_state.pipeline != .TEXT_SUBPIXEL {
                    renderer_state.pipeline = .TEXT_SUBPIXEL;
                    // This is where we'd normally call Simp.set_shader_for_images(texture), but
                    // we instead pass in our modified shader, so we have to do a little bit
                    // more work.
                    Simp.immediate_flush();

                    target_shader := *renderer_state.text_shader_subpixel;
                    if context.simp.current_shader != target_shader {
                        Simp.immediate_set_shader(target_shader);

                        // immediate_set_shader enables GL_BLEND for us, but sets up the default blend func:
                        //
                        //   SRC * src_alpha, DST * (1 - dst_alpha)
                        //
                        // For subpixel rendering, we override that to use the per-channel blend weights from the shader.
                        // (Note the 1 in SRC1, which referes to index 1 of the shader output.)
                        glBlendFunc(GL_SRC1_COLOR, GL_ONE_MINUS_SRC1_COLOR);

                        Simp.set_projection();
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
                Simp.set_scissor(it.rect.p0, it.rect.p1);
            }
        }
    }
}


#scope_file

WT     :: #import "Window_Type";
Simp   :: #import "Simp";
Dwmapi :: #library,system "Dwmapi";

DwmFlush :: () -> HRESULT #foreign Dwmapi;

renderer_state: Renderer_State;
Renderer_State :: struct {
    window: *void;

    textures: Table(Editor.Texture_ID, Simp.Texture); // We currently aren't careful about allocating textures, but there aren't many. :Malloc

    text_shader: Simp.Shader;
    text_shader_subpixel: Simp.Shader;

    pipeline: Pipeline = .NONE; // To prevent immediate_flush when pipeline is the same.

    Pipeline :: enum {
        NONE;
        COLOR;
        TEXT;
        TEXT_SUBPIXEL;
    }
}

// This is a modified version of SHADER_SPRITE_LEFT_HANDED from Simp, so that we can pass in a
// single-channel texture and have the colors map the way we want.
TEXT_SHADER :: #string END
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

TEXT_SHADER_SUBPIXEL :: #string END
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

const float COVERAGE_ADJUSTMENT = 0.1; // TODO(jt): Make this configurable? :Config

void main () {
    vec3 coverage = texture(diffuse_texture, v_tex_coords).rgb;

    // Coverage adjustment taken from:
    // https://arkanis.de/weblog/2023-08-14-simple-good-quality-subpixel-text-rendering-in-opengl-with-stb-truetype-and-dual-source-blending/
    if (COVERAGE_ADJUSTMENT > 0.0) {
        coverage = min(coverage * (1.0 + COVERAGE_ADJUSTMENT), 1.0);
    } else if (COVERAGE_ADJUSTMENT < 0.0) {
        coverage = max((1.0 - (1.0 - coverage) * (1.0 - COVERAGE_ADJUSTMENT)), 0.0);
    }

    f_color = v_color;
    f_blend = vec4(coverage, 1.0);
}
#endif
END
