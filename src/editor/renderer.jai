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

    begin_frame:  (clear_color: Vector4);
    submit_frame: ();

    // Things that should be called in between begin frame and submit_frame. (Not necessarilly true
    // for the Simp/OpenGL backend, but it will be true for most others.)

    draw_rects: (render_rects: [] Render_Rect);
}
