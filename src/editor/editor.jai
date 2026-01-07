/*

XXX: HERE Stuff to do:

- [X] Implement Arena, or use Flat_Pool.
- [ ] Load Font
- [ ] Rasterize Font
- [ ] Display Font
- [ ] Kerning
- [ ] Ligatures

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

Math  :: #import "Math";

Vector2 :: Math.Vector2;
Vector4 :: Math.Vector4;

#load "math.jai";
#load "platform.jai";
#load "input.jai";
#load "render.jai";
#load "font.jai";

Editor :: struct {
    perm_arena:  Arena;

    fonts: [..] Font;
}

init :: (editor: *Editor, platform: Platform) {
    procs := make_arena_procs(platform);
    editor.perm_arena.procs = procs;

    editor.fonts.allocator = { arena_allocator_proc, *editor.perm_arena };

    {
        success, ttf_buffer := platform.read_file("./data/fonts/LiberationMono/LiberationMono-Regular.ttf",, temp);
        assert(success);

        font_arena: Arena;
        font_arena.procs = procs;
        default_font : Font = make_font(font_arena, ttf_buffer);

        array_add(*editor.fonts, default_font);
    }

    xxx_foozle := arena_push(*editor.perm_arena, [8000] u8);
    xxx_foozle.*[0] = 42;
}

update_and_render :: (editor: *Editor, platform: Platform, input: Input, render_lists: *Render_Lists) -> bool {
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
