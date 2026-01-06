// TODO(jt): Features:
//
// - [ ] glyphs
// - [ ] glyph metrics
// - [ ] codepoints
// - [ ] basic layout
// - [ ] kerning
// - [ ] ligatures
//
// Nonfeatures:
//
// - hinting
// - shaping
// - right to left
// - vertical fonts
//

Font :: struct {
    line_height: f32;
}

Glyph :: struct {
    advance: f32;
}

Glyph_Cache :: struct {
    arena: Arena;
}

// TODO(jt): context.allocator vs Temporary_Storage vs explicit arena.
layout_text :: (font: *Font, font_size: f32, text: string) -> [..] Render_Rect {

}
