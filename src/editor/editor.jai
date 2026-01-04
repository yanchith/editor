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

Math :: #import "Math";

Vector2 :: Math.Vector2;

#load "math.jai";
#load "platform.jai";
#load "input.jai";
#load "render.jai";

Editor :: struct {
    dummy: s64;
}

init :: (editor: *Editor, platform: Platform) {
    log("Editor init");
}

update_and_render :: (editor: *Editor, platform: Platform, input: Input, render_lists: *Render_Lists) -> bool {
    log("Editor update and render");
    return false;
}
