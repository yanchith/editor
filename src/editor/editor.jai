/*

XXX: HERE Stuff to do:

- [ ] Implement Arena, or use Flat_Pool.
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

#load "math.jai";
#load "platform.jai";
#load "input.jai";
#load "render.jai";

Editor :: struct {
    perm_arena:  Arena;
    frame_arena: Arena;

    fonts: [..] Font;
}

init :: (editor: *Editor, platform: Platform) {
    procs := make_arena_procs(platform);

    editor.perm_arena.procs  = procs;
    editor.frame_arena.procs = procs;

    editor.fonts.allocator = { arena_allocator_proc, *editor.perm_arena };
}

update_and_render :: (editor: *Editor, platform: Platform, input: Input, render_lists: *Render_Lists) -> bool {
    arena_reset(*editor.frame_arena);

    foozle: [8000] u8;
    foozle_pointer := arena_push(*editor.frame_arena, foozle);
    foozle_pointer.*[0] = 42;

    return false;
}

#scope_file

Font :: struct {
    dummy: s32;
}

make_arena_procs :: (platform: Platform) -> Arena_Procs {
    return {
        platform.page_size,
        platform.mem_reserve,
        platform.mem_release,
        platform.mem_commit,
        platform.mem_decommit,
    };
}
