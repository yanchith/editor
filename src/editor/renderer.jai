Texture_ID :: #type,isa u32;

Render_Command :: struct {
    type: Render_Command_Type;
    rect: Rect;
    texture_rect: Rect;              // Unused for SET_SCISSOR
    texture_id: Texture_ID;          // Unused for SET_SCISSOR
    color := Vector4.{ 0, 0, 0, 1 }; // Unused for SET_SCISSOR
}

Render_Command_Type :: enum u32 {
    DRAW_RECT   :: 0;
    SET_SCISSOR :: 1;
}

Texture_Filter :: enum {
    NEAREST :: 0;
    LINEAR  :: 1;
}

Renderer :: struct {
    create_texture_r8unorm: (texture_id: Texture_ID, data: [] u8, width: s32, height: s32, filter: Texture_Filter);
    update_texture_r8unorm: (texture_id: Texture_ID, data: [] u8, update_rect: IRect); // data is width*height*1 of the orignal texture.
    create_texture_rgba8unorm: (texture_id: Texture_ID, data: [] u8, width: s32, height: s32, filter: Texture_Filter);
    update_texture_rgba8unorm: (texture_id: Texture_ID, data: [] u8, update_rect: IRect); // data is width*height*4 of the orignal texture.

    begin_frame:  (clear_color: Vector4);
    submit_frame: ();

    //
    // Things that should be called in between begin_frame and submit_frame.
    // (This is less strict for Simp/OpenGL/D3D11, but probably still a good idea.)
    //

    draw: (render_commands: [] Render_Command);
}
