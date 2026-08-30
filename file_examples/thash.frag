#version 450

layout(set = 0, binding = 0, std140) uniform Draw3DCameraUniforms {
    mat4 u_projection_matrix;
    mat4 u_view_matrix;
};

layout(set = 1, binding = 0, std140) uniform Draw3DThashLineUniforms {
    uint u_screen_width;
    uint u_screen_height;
    uint _pad0;
    uint _pad1;
};

layout(location = 0) in vec2 v_line_start_screen_pos;
layout(location = 1) in float v_width;
layout(location = 2) in vec4 v_color;
layout(location = 3) flat in uint v_pattern_bits_and_length;    // 0xPPPP_PPLL

layout(location = 0) out vec4 f_color;

void main() {
    // gl_FragCoord starts from upper left here, hence the flipped Y
    vec2 screen_pos = vec2(gl_FragCoord.x, u_screen_height - gl_FragCoord.y);

    // v_pattern_bits_and_length bit-packs both the pattern and its bit length like so: 0xPPPP_PPLL.
    // We clamp the 8-bit length to [1, 24], i.e. the min/max pattern length in bits.
    uint pattern_length_bits = clamp(v_pattern_bits_and_length & 0xff, 1u, 24u);
    float pattern_length_px = v_width * pattern_length_bits;
    float line_position_px = length(screen_pos - v_line_start_screen_pos);

    // Line always starts and ends on a 1, otherwise check the pattern
    float pattern_position_px = line_position_px % pattern_length_px;
    uint pattern_position_bits = uint(floor(pattern_position_px / v_width));

    // Pattern bits are ordered from least to most significant, starting
    // from the 9th least significant bit, skipping the 8 length bits at the end
    bool pattern_bit_set = (v_pattern_bits_and_length & (1 << pattern_position_bits + 8)) != 0;

    float alpha = v_color.a * float(pattern_bit_set);    // casts bool to 1/0

    f_color = vec4(v_color.rgb, alpha);
}
