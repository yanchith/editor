Texture_ID :: #type,isa u32;

Render_Rect :: struct {
    rect: Rect;
    texture_rect: Rect;
    texture_id: Texture_ID;
    color := Vector4.{ 1, 1, 1, 1 };
}

Renderer :: struct {
    create_texture_r8unorm: (texture_id: Texture_ID, width: s32, height: s32, data: [] u8);
    update_texture_regions_r8norm: (texture_id: Texture_ID, regions: [] IRect, data: [] u8);
    draw_rects: (render_rects: [] Render_Rect);
}
