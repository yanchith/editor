// Decodes SRGB color packed in an uint to linear-space, zero-to-one RGBA. The decoding only happens
// for the RGB channels, while alpha is remapped to zero-to-one range.
decode_srgb :: (srgb: u32) -> Vector4 {
    R255: f32 : 1.0 / 255;

    r_index := cast,trunc(u8, srgb >> 24);
    g_index := cast,trunc(u8, srgb >> 16);
    b_index := cast,trunc(u8, srgb >>  8);

    r := cast(*f32, *D3DX_SRGBTable[r_index]).*;
    g := cast(*f32, *D3DX_SRGBTable[g_index]).*;
    b := cast(*f32, *D3DX_SRGBTable[b_index]).*;

    a := cast(f32, cast,trunc(u8, srgb)) * R255;

    return { r, g, b, a };
}

// Like decode_srgb, but doesn't decode. It exists to support sRGB-space rendering pipelines
// (like Simp). Maybe we can remove this eventually?
unpack_srgb :: (packed: u32) -> Vector4 {
    R255: f32 : 1.0 / 255;

    r := cast(f32, cast,trunc(u8, packed >> 24)) * R255;
    g := cast(f32, cast,trunc(u8, packed >> 16)) * R255;
    b := cast(f32, cast,trunc(u8, packed >>  8)) * R255;

    a := cast(f32, cast,trunc(u8, packed)) * R255;

    return { r, g, b, a };
}

adjust_saturation_and_value :: (rgba: Vector4, saturation_multiplier: f32, value_multiplier: f32) -> Vector4 {
    hsv := rgb_to_hsv({ rgba.x, rgba.y, rgba.z });
    hsv.y = clamp(hsv.y * saturation_multiplier, 0, 1);
    hsv.z = clamp(hsv.z * value_multiplier, 0, 1);

    rgb := hsv_to_rgb(hsv);

    return { rgb.x, rgb.y, rgb.z, rgba.w };
}

adjust_saturation_and_value :: (rgba: Vector3, saturation_multiplier: f32, value_multiplier: f32) -> Vector3 {
    hsv := rgb_to_hsv({ rgba.x, rgba.y, rgba.z });
    hsv.y = clamp(hsv.y * saturation_multiplier, 0, 1);
    hsv.z = clamp(hsv.z * value_multiplier, 0, 1);

    return hsv_to_rgb(hsv);
}

adjust_saturation :: (rgba: Vector4, multiplier: f32) -> Vector4 {
    hsv := rgb_to_hsv({ rgba.x, rgba.y, rgba.z });
    hsv.y = clamp(hsv.y * multiplier, 0, 1);

    rgb := hsv_to_rgb(hsv);

    return { rgb.x, rgb.y, rgb.z, rgba.w };
}

adjust_saturation :: (rgb: Vector3, multiplier: f32) -> Vector4 {
    hsv := rgb_to_hsv(rgb);
    hsv.y = clamp(hsv.y * multiplier, 0, 1);

    return hsv_to_rgb(hsv);
}

adjust_value :: (rgba: Vector4, multiplier: f32) -> Vector4 {
    hsv := rgb_to_hsv({ rgba.x, rgba.y, rgba.z });
    hsv.z = clamp(hsv.z * multiplier, 0, 1);

    rgb := hsv_to_rgb(hsv);

    return { rgb.x, rgb.y, rgb.z, rgba.w };
}

adjust_value :: (rgb: Vector3, multiplier: f32) -> Vector4 {
    hsv := rgb_to_hsv(rgb);
    hsv.z = clamp(hsv.z * multiplier, 0, 1);

    return hsv_to_rgb(hsv);
}

// Takes RGB color (where each channel is [0, 1]) and produces HSV color (where hue, saturation and
// value are [0, 1]). Hue is in circle parameter space instead of degrees.
rgb_to_hsv :: (rgb: Vector3) -> Vector3 {
    R6: f32 : 1.0 / 6.0;

    // TODO(jt): log_error out of bounds in sanity builds?
    r := clamp(rgb.x, 0, 1);
    g := clamp(rgb.y, 0, 1);
    b := clamp(rgb.z, 0, 1);

    min_channel := min(r, g, b);
    max_channel := max(r, g, b);

    hue        := 0.0;
    saturation := 0.0;
    if min_channel != max_channel {
        distance := max_channel - min_channel;

        if r == max_channel {
            hue = 0 + (g - b) / distance;
        } else if g == max_channel {
            hue = 2 + (b - r) / distance;
        } else if b == max_channel {
            hue = 4 + (r - g) / distance;
        }

        hue *= R6;                     // Remap from [0, 6] to [0, 1]
        hue = fmod_cycling(hue, 1.0);  // Wrap

        saturation = distance / max_channel; // max_channel is not zero, as we clamp all channels and compare min/max.
    }

    return { hue, saturation, max_channel };
}

// Takes HSV color (where hue, saturation and value are all [0, 1]) and produces an RGB color (where
// each channel is [0, 1]). Hue is in circle parameter space instead of degrees.
hsv_to_rgb :: (hsv: Vector3) -> Vector3 {
    // TODO(jt): log_error out of bounds in sanity builds?
    hue        := clamp(hsv.x, 0, 1);
    saturation := clamp(hsv.y, 0, 1);
    value      := clamp(hsv.z, 0, 1);

    hi := cast(s32, round(hue * 6)) % 6;
    f  := hue * 6 - floor(hue * 6);

    v := value;
    p := value * (1 - saturation);
    q := value * (1 - f * saturation);
    t := value * (1 - (1 - f) * saturation);

    if      hi == 0  return { v, t, p };
    else if hi == 1  return { q, v, p };
    else if hi == 2  return { p, v, t };
    else if hi == 3  return { p, q, v };
    else if hi == 4  return { t, p, v };
    else             return { v, p, q };
}

#scope_file

// From D3DX_DXGIFormatConvert.inl.
//
// Also see:
// - https://medium.com/@tomforsyth/the-srgb-learning-curve-773b7f68cf7a
// - https://www.shadertoy.com/view/lsd3zN
D3DX_SRGBTable: [256] u32 : .[
    0x00000000,0x399f22b4,0x3a1f22b4,0x3a6eb40e,0x3a9f22b4,0x3ac6eb61,0x3aeeb40e,0x3b0b3e5d,
    0x3b1f22b4,0x3b33070b,0x3b46eb61,0x3b5b518d,0x3b70f18d,0x3b83e1c6,0x3b8fe616,0x3b9c87fd,
    0x3ba9c9b7,0x3bb7ad6f,0x3bc63549,0x3bd56361,0x3be539c1,0x3bf5ba70,0x3c0373b5,0x3c0c6152,
    0x3c15a703,0x3c1f45be,0x3c293e6b,0x3c3391f7,0x3c3e4149,0x3c494d43,0x3c54b6c7,0x3c607eb1,
    0x3c6ca5df,0x3c792d22,0x3c830aa8,0x3c89af9f,0x3c9085db,0x3c978dc5,0x3c9ec7c2,0x3ca63433,
    0x3cadd37d,0x3cb5a601,0x3cbdac20,0x3cc5e639,0x3cce54ab,0x3cd6f7d5,0x3cdfd010,0x3ce8ddb9,
    0x3cf2212c,0x3cfb9ac1,0x3d02a569,0x3d0798dc,0x3d0ca7e6,0x3d11d2af,0x3d171963,0x3d1c7c2e,
    0x3d21fb3c,0x3d2796b2,0x3d2d4ebb,0x3d332380,0x3d39152b,0x3d3f23e3,0x3d454fd1,0x3d4b991c,
    0x3d51ffef,0x3d58846a,0x3d5f26b7,0x3d65e6fe,0x3d6cc564,0x3d73c20f,0x3d7add29,0x3d810b67,
    0x3d84b795,0x3d887330,0x3d8c3e4a,0x3d9018f6,0x3d940345,0x3d97fd4a,0x3d9c0716,0x3da020bb,
    0x3da44a4b,0x3da883d7,0x3daccd70,0x3db12728,0x3db59112,0x3dba0b3b,0x3dbe95b5,0x3dc33092,
    0x3dc7dbe2,0x3dcc97b6,0x3dd1641f,0x3dd6412c,0x3ddb2eef,0x3de02d77,0x3de53cd5,0x3dea5d19,
    0x3def8e52,0x3df4d091,0x3dfa23e8,0x3dff8861,0x3e027f07,0x3e054280,0x3e080ea3,0x3e0ae378,
    0x3e0dc105,0x3e10a754,0x3e13966b,0x3e168e52,0x3e198f10,0x3e1c98ad,0x3e1fab30,0x3e22c6a3,
    0x3e25eb09,0x3e29186c,0x3e2c4ed0,0x3e2f8e41,0x3e32d6c4,0x3e362861,0x3e39831e,0x3e3ce703,
    0x3e405416,0x3e43ca5f,0x3e4749e4,0x3e4ad2ae,0x3e4e64c2,0x3e520027,0x3e55a4e6,0x3e595303,
    0x3e5d0a8b,0x3e60cb7c,0x3e6495e0,0x3e6869bf,0x3e6c4720,0x3e702e0c,0x3e741e84,0x3e781890,
    0x3e7c1c38,0x3e8014c2,0x3e82203c,0x3e84308d,0x3e8645ba,0x3e885fc5,0x3e8a7eb2,0x3e8ca283,
    0x3e8ecb3d,0x3e90f8e1,0x3e932b74,0x3e9562f8,0x3e979f71,0x3e99e0e2,0x3e9c274e,0x3e9e72b7,
    0x3ea0c322,0x3ea31892,0x3ea57308,0x3ea7d289,0x3eaa3718,0x3eaca0b7,0x3eaf0f69,0x3eb18333,
    0x3eb3fc18,0x3eb67a18,0x3eb8fd37,0x3ebb8579,0x3ebe12e1,0x3ec0a571,0x3ec33d2d,0x3ec5da17,
    0x3ec87c33,0x3ecb2383,0x3ecdd00b,0x3ed081cd,0x3ed338cc,0x3ed5f50b,0x3ed8b68d,0x3edb7d54,
    0x3ede4965,0x3ee11ac1,0x3ee3f16b,0x3ee6cd67,0x3ee9aeb6,0x3eec955d,0x3eef815d,0x3ef272ba,
    0x3ef56976,0x3ef86594,0x3efb6717,0x3efe6e02,0x3f00bd2d,0x3f02460e,0x3f03d1a7,0x3f055ff9,
    0x3f06f106,0x3f0884cf,0x3f0a1b56,0x3f0bb49b,0x3f0d50a0,0x3f0eef67,0x3f1090f1,0x3f12353e,
    0x3f13dc51,0x3f15862b,0x3f1732cd,0x3f18e239,0x3f1a946f,0x3f1c4971,0x3f1e0141,0x3f1fbbdf,
    0x3f21794e,0x3f23398e,0x3f24fca0,0x3f26c286,0x3f288b41,0x3f2a56d3,0x3f2c253d,0x3f2df680,
    0x3f2fca9e,0x3f31a197,0x3f337b6c,0x3f355820,0x3f3737b3,0x3f391a26,0x3f3aff7c,0x3f3ce7b5,
    0x3f3ed2d2,0x3f40c0d4,0x3f42b1be,0x3f44a590,0x3f469c4b,0x3f4895f1,0x3f4a9282,0x3f4c9201,
    0x3f4e946e,0x3f5099cb,0x3f52a218,0x3f54ad57,0x3f56bb8a,0x3f58ccb0,0x3f5ae0cd,0x3f5cf7e0,
    0x3f5f11ec,0x3f612eee,0x3f634eef,0x3f6571e9,0x3f6797e3,0x3f69c0d6,0x3f6beccd,0x3f6e1bbf,
    0x3f704db8,0x3f7282af,0x3f74baae,0x3f76f5ae,0x3f7933b9,0x3f7b74c6,0x3f7db8e0,0x3f800000
];
