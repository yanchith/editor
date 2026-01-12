/*

TODO(jt): Stuff to do:

- [X] Implement Arena, or use Flat_Pool.
- [X] Display text on screen
- [ ] Font Kerning

- [ ] Gap Buffer (or other text datastructure)

- [ ] Load file/Save file
- [ ] Basic file navigation
- [ ] Basic file editing

- [ ] Sytax Highlighting
- [ ] Indentation

- [ ] Customization and plugins

*/

f32 :: float32;
f64 :: float64;

#import "Basic";
#import "Arena";
#import "Hash_Table";

Math    :: #import "Math";
Unicode :: #import "Unicode";

Vector2 :: Math.Vector2;
Vector4 :: Math.Vector4;
ceil    :: Math.ceil;

#load "math.jai";
#load "platform.jai";
#load "renderer.jai";
#load "input.jai";
#load "font.jai";
#load "gap_buffer.jai";

TEXTURE_ID_GLYPH_ATLAS: Texture_ID = 0;

Editor :: struct {
    perm_arena: *Arena;
    font: Font;
    gb: Gap_Buffer;
}

init :: (editor: *Editor, platform: Platform, renderer: Renderer) {
    arena_procs := make_arena_procs(platform);
    editor.perm_arena = arena_allocate(arena_procs);


    font_arena := arena_allocate(arena_procs);

    success, ttf_buffer := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, arena_allocator(font_arena));
    assert(success);

    editor.font = make_font(font_arena, ttf_buffer, TEXTURE_ID_GLYPH_ATLAS);


    gb_arena := arena_allocate(arena_procs);
    editor.gb.buffer.allocator = arena_allocator(gb_arena);

    gap_buffer_insert(*editor.gb, TEXT);

    renderer.create_texture_r8unorm(
        TEXTURE_ID_GLYPH_ATLAS,
        editor.font.glyph_atlas_width,
        editor.font.glyph_atlas_height,
        editor.font.glyph_atlas,
    );
}

update_and_render :: (editor: *Editor, platform: Platform, renderer: Renderer, input: Input) -> bool {
    render_rects: [..] Render_Rect;
    render_rects.allocator = temp;
    update_regions: [..] IRect;
    update_regions.allocator = temp;

    text := gap_buffer_make_contiguous_view(editor.gb, 0, editor.gb.count);
    hits, misses := layout_and_draw_text(*editor.font, cast(string, text), *render_rects, *update_regions, is_new_frame = true);

    renderer.update_texture_regions_r8unorm(TEXTURE_ID_GLYPH_ATLAS, update_regions, editor.font.glyph_atlas);
    renderer.draw_rects(render_rects);

    return false;
}

#scope_file

make_arena_procs :: (platform: Platform) -> Arena_Procs {
    return {
        platform.page_size,
        platform.mem_reserve,
        platform.mem_release,
        platform.mem_commit,
        platform.mem_decommit,
    };
}

TEXT :: #string DONE
But I must explain to you how all this mistaken idea of denouncing pleasure
and praising pain was born and I will give you a complete account of the system,
and expound the actual teachings of the great explorer of the truth,
the master-builder of human happiness.

Hello, Sailor!
DONE
