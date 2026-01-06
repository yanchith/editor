Render_Lists :: struct {
    buffer: [..] Render_Rect;
}

Render_Rect :: struct {
    rect: Rect;
    texture_rect: Rect;
    texture_id: u32;
    color := Vector4.{ 1, 1, 1, 1 };
}
