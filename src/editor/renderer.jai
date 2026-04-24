Texture_ID :: #type,isa u32;

Render_Rect :: struct {
    rect: Rect;
    texture_rect: Rect;
    texture_id: Texture_ID;
    color := Vector4.{ 0, 0, 0, 1 };
}

Renderer :: struct {
    create_texture_r8unorm: (texture_id: Texture_ID, data: [] u8, width: s32, height: s32);
    update_texture_r8unorm: (texture_id: Texture_ID, data: [] u8, update_rect: IRect); // data is width*height of the orignal texture, in case the implementation ignores update_rect.
    draw_rects: (render_rects: [] Render_Rect);
}
