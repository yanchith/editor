Texture_ID :: #type,isa u32;

Render_Rect :: struct {
    rect: Rect;
    texture_rect: Rect;
    texture_id: Texture_ID;
    color := Vector4.{ 0, 0, 0, 1 };
}

Renderer :: struct {
    create_texture_r8unorm: (texture_id: Texture_ID, data: [] u8, width: s32, height: s32);
    update_texture_r8unorm: (texture_id: Texture_ID, data: [] u8, update_rect: IRect); // data is width*height*1 of the orignal texture.
    create_texture_rgba8unorm: (texture_id: Texture_ID, data: [] u8, width: s32, height: s32);
    update_texture_rgba8unorm: (texture_id: Texture_ID, data: [] u8, update_rect: IRect); // data is width*height*4 of the orignal texture.
    draw_rects: (render_rects: [] Render_Rect);
}
