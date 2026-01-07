//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



// private structure
stbtt__buf :: struct {
    data:   *u8;
    cursor: s32;
    size:   s32;
}

//////////////////////////////////////////////////////////////////////////////
//
// TEXTURE BAKING API
//
// If you use this API, you only have to call two functions ever.
//
stbtt_bakedchar :: struct {
    x0:       u16; // coordinates of bbox in bitmap
    y0:       u16; // coordinates of bbox in bitmap
    x1:       u16; // coordinates of bbox in bitmap
    y1:       u16; // coordinates of bbox in bitmap
    xoff:     float;
    yoff:     float;
    xadvance: float;
}

stbtt_BakeFontBitmap :: (data: *u8, offset: s32, pixel_height: float, pixels: *u8, pw: s32, ph: s32, first_char: s32, num_chars: s32, chardata: *stbtt_bakedchar) -> s32 #foreign stb_truetype;

// if return is positive, the first unused row of the bitmap
// if return is negative, returns the negative of the number of characters that fit
// if return is 0, no characters fit and no rows were used
// This uses a very crappy packing.
stbtt_aligned_quad :: struct {
    x0: float; // top-left
    y0: float; // top-left
    s0: float; // top-left
    t0: float; // top-left
    x1: float; // bottom-right
    y1: float; // bottom-right
    s1: float; // bottom-right
    t1: float; // bottom-right
}

stbtt_GetBakedQuad :: (chardata: *stbtt_bakedchar, pw: s32, ph: s32, char_index: s32, xpos: *float, ypos: *float, q: *stbtt_aligned_quad, opengl_fillrule: s32) -> void #foreign stb_truetype;

// Call GetBakedQuad with char_index = 'character - first_char', and it
// creates the quad you need to draw and advances the current position.
//
// The coordinate system used assumes y increases downwards.
//
// Characters will extend both above and below the current position;
// see discussion of "BASELINE" above.
//
// It's inefficient; you might want to c&p it and optimize it.
stbtt_GetScaledFontVMetrics :: (fontdata: *u8, index: s32, size: float, ascent: *float, descent: *float, lineGap: *float) -> void #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// NEW TEXTURE BAKING API
//
// This provides options for packing multiple fonts into one atlas, not
// perfectly but better than nothing.
stbtt_packedchar :: struct {
    x0:       u16; // coordinates of bbox in bitmap
    y0:       u16; // coordinates of bbox in bitmap
    x1:       u16; // coordinates of bbox in bitmap
    y1:       u16; // coordinates of bbox in bitmap
    xoff:     float;
    yoff:     float;
    xadvance: float;
    xoff2:    float;
    yoff2:    float;
}

//////////////////////////////////////////////////////////////////////////////
//
// bitmap baking
//
// This is SUPER-AWESOME (tm Ryan Gordon) packing using stb_rect_pack.h. If
// stb_rect_pack.h isn't available, it uses the BakeFontBitmap strategy.
stbtt_PackBegin :: (spc: *stbtt_pack_context, pixels: *u8, width: s32, height: s32, stride_in_bytes: s32, padding: s32, alloc_context: *void) -> s32 #foreign stb_truetype;

// Initializes a packing context stored in the passed-in stbtt_pack_context.
// Future calls using this context will pack characters into the bitmap passed
// in here: a 1-channel bitmap that is width * height. stride_in_bytes is
// the distance from one row to the next (or 0 to mean they are packed tightly
// together). "padding" is the amount of padding to leave between each
// character (normally you want '1' for bitmaps you'll use as textures with
// bilinear filtering).
//
// Returns 0 on failure, 1 on success.
stbtt_PackEnd :: (spc: *stbtt_pack_context) -> void #foreign stb_truetype;

stbtt_PackFontRange :: (spc: *stbtt_pack_context, fontdata: *u8, font_index: s32, font_size: float, first_unicode_char_in_range: s32, num_chars_in_range: s32, chardata_for_range: *stbtt_packedchar) -> s32 #foreign stb_truetype;

// Creates character bitmaps from the font_index'th font found in fontdata (use
// font_index=0 if you don't know what that is). It creates num_chars_in_range
// bitmaps for characters with unicode values starting at first_unicode_char_in_range
// and increasing. Data for how to render them is stored in chardata_for_range;
// pass these to stbtt_GetPackedQuad to get back renderable quads.
//
// font_size is the full height of the character from ascender to descender,
// as computed by stbtt_ScaleForPixelHeight. To use a point size as computed
// by stbtt_ScaleForMappingEmToPixels, wrap the point size in STBTT_POINT_SIZE()
// and pass that result as 'font_size':
//       ...,                  20 , ... // font max minus min y is 20 pixels tall
//       ..., STBTT_POINT_SIZE(20), ... // 'M' is 20 pixels tall
stbtt_pack_range :: struct {
    font_size:                        float;
    first_unicode_codepoint_in_range: s32; // if non-zero, then the chars are continuous, and this is the first codepoint
    array_of_unicode_codepoints:      *s32; // if non-zero, then this is an array of unicode codepoints
    num_chars:                        s32;
    chardata_for_range:               *stbtt_packedchar; // output
    h_oversample:                     u8; // don't set these, they're used internally
    v_oversample:                     u8; // don't set these, they're used internally
}

stbtt_PackFontRanges :: (spc: *stbtt_pack_context, fontdata: *u8, font_index: s32, ranges: *stbtt_pack_range, num_ranges: s32) -> s32 #foreign stb_truetype;

// Creates character bitmaps from multiple ranges of characters stored in
// ranges. This will usually create a better-packed bitmap than multiple
// calls to stbtt_PackFontRange. Note that you can call this multiple
// times within a single PackBegin/PackEnd.
stbtt_PackSetOversampling :: (spc: *stbtt_pack_context, h_oversample: u32, v_oversample: u32) -> void #foreign stb_truetype;

// Oversampling a font increases the quality by allowing higher-quality subpixel
// positioning, and is especially valuable at smaller text sizes.
//
// This function sets the amount of oversampling for all following calls to
// stbtt_PackFontRange(s) or stbtt_PackFontRangesGatherRects for a given
// pack context. The default (no oversampling) is achieved by h_oversample=1
// and v_oversample=1. The total number of pixels required is
// h_oversample*v_oversample larger than the default; for example, 2x2
// oversampling requires 4x the storage of 1x1. For best results, render
// oversampled textures with bilinear filtering. Look at the readme in
// stb/tests/oversample for information about oversampled fonts
//
// To use with PackFontRangesGather etc., you must set it before calls
// call to PackFontRangesGatherRects.
stbtt_PackSetSkipMissingCodepoints :: (spc: *stbtt_pack_context, skip: s32) -> void #foreign stb_truetype;

// If skip != 0, this tells stb_truetype to skip any codepoints for which
// there is no corresponding glyph. If skip=0, which is the default, then
// codepoints without a glyph recived the font's "missing character" glyph,
// typically an empty box by convention.
stbtt_GetPackedQuad :: (chardata: *stbtt_packedchar, pw: s32, ph: s32, char_index: s32, xpos: *float, ypos: *float, q: *stbtt_aligned_quad, align_to_integer: s32) -> void #foreign stb_truetype;

// rects array must be big enough to accommodate all characters in the given ranges
stbtt_PackFontRangesGatherRects :: (spc: *stbtt_pack_context, info: *stbtt_fontinfo, ranges: *stbtt_pack_range, num_ranges: s32, rects: *stbrp_rect) -> s32 #foreign stb_truetype;

stbtt_PackFontRangesPackRects :: (spc: *stbtt_pack_context, rects: *stbrp_rect, num_rects: s32) -> void #foreign stb_truetype;

// rects array must be big enough to accommodate all characters in the given ranges
stbtt_PackFontRangesRenderIntoRects :: (spc: *stbtt_pack_context, info: *stbtt_fontinfo, ranges: *stbtt_pack_range, num_ranges: s32, rects: *stbrp_rect) -> s32 #foreign stb_truetype;

// this is an opaque structure that you shouldn't mess with which holds
// all the context needed from PackBegin to PackEnd.
stbtt_pack_context :: struct {
    user_allocator_context: *void;
    pack_info:              *void;
    width:                  s32;
    height:                 s32;
    stride_in_bytes:        s32;
    padding:                s32;
    skip_missing:           s32;
    h_oversample:           u32;
    v_oversample:           u32;
    pixels:                 *u8;
    nodes:                  *void;
}

//////////////////////////////////////////////////////////////////////////////
//
// FONT LOADING
//
//
stbtt_GetNumberOfFonts :: (data: *u8) -> s32 #foreign stb_truetype;

// This function will determine the number of fonts in a font file.  TrueType
// collection (.ttc) files may contain multiple fonts, while TrueType font
// (.ttf) files only contain one font. The number of fonts can be used for
// indexing with the previous function where the index is between zero and one
// less than the total fonts. If an error occurs, -1 is returned.
stbtt_GetFontOffsetForIndex :: (data: *u8, index: s32) -> s32 #foreign stb_truetype;

// The following structure is defined publicly so you can declare one on
// the stack or as a global or etc, but you should treat it as opaque.
stbtt_fontinfo :: struct {
    userdata:         *void;
    data:             *u8; // pointer to .ttf file
    fontstart:        s32; // offset of start of font

    numGlyphs:        s32; // number of glyphs, needed for range checking

    loca:             s32; // table locations as offset from start of .ttf
    head:             s32; // table locations as offset from start of .ttf
    glyf:             s32; // table locations as offset from start of .ttf
    hhea:             s32; // table locations as offset from start of .ttf
    hmtx:             s32; // table locations as offset from start of .ttf
    kern:             s32; // table locations as offset from start of .ttf
    gpos:             s32; // table locations as offset from start of .ttf
    svg:              s32; // table locations as offset from start of .ttf
    index_map:        s32; // a cmap mapping for our chosen character encoding
    indexToLocFormat: s32; // format needed to map from glyph index to glyph

    cff:              stbtt__buf; // cff font data
    charstrings:      stbtt__buf; // the charstring index
    gsubrs:           stbtt__buf; // global charstring subroutines index
    subrs:            stbtt__buf; // private charstring subroutines index
    fontdicts:        stbtt__buf; // array of font dicts
    fdselect:         stbtt__buf; // map from glyph to fontdict
}

stbtt_InitFont :: (info: *stbtt_fontinfo, data: *u8, offset: s32) -> s32 #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER TO GLYPH-INDEX CONVERSIOn
stbtt_FindGlyphIndex :: (info: *stbtt_fontinfo, unicode_codepoint: s32) -> s32 #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// CHARACTER PROPERTIES
//
stbtt_ScaleForPixelHeight :: (info: *stbtt_fontinfo, pixels: float) -> float #foreign stb_truetype;

// computes a scale factor to produce a font whose "height" is 'pixels' tall.
// Height is measured as the distance from the highest ascender to the lowest
// descender; in other words, it's equivalent to calling stbtt_GetFontVMetrics
// and computing:
//       scale = pixels / (ascent - descent)
// so if you prefer to measure height by the ascent only, use a similar calculation.
stbtt_ScaleForMappingEmToPixels :: (info: *stbtt_fontinfo, pixels: float) -> float #foreign stb_truetype;

// computes a scale factor to produce a font whose EM size is mapped to
// 'pixels' tall. This is probably what traditional APIs compute, but
// I'm not positive.
stbtt_GetFontVMetrics :: (info: *stbtt_fontinfo, ascent: *s32, descent: *s32, lineGap: *s32) -> void #foreign stb_truetype;

// ascent is the coordinate above the baseline the font extends; descent
// is the coordinate below the baseline the font extends (i.e. it is typically negative)
// lineGap is the spacing between one row's descent and the next row's ascent...
// so you should advance the vertical position by "*ascent - *descent + *lineGap"
//   these are expressed in unscaled coordinates, so you must multiply by
//   the scale factor for a given size
stbtt_GetFontVMetricsOS2 :: (info: *stbtt_fontinfo, typoAscent: *s32, typoDescent: *s32, typoLineGap: *s32) -> s32 #foreign stb_truetype;

// analogous to GetFontVMetrics, but returns the "typographic" values from the OS/2
// table (specific to MS/Windows TTF files).
//
// Returns 1 on success (table present), 0 on failure.
stbtt_GetFontBoundingBox :: (info: *stbtt_fontinfo, x0: *s32, y0: *s32, x1: *s32, y1: *s32) -> void #foreign stb_truetype;

// the bounding box around all possible characters
stbtt_GetCodepointHMetrics :: (info: *stbtt_fontinfo, codepoint: s32, advanceWidth: *s32, leftSideBearing: *s32) -> void #foreign stb_truetype;

// leftSideBearing is the offset from the current horizontal position to the left edge of the character
// advanceWidth is the offset from the current horizontal position to the next horizontal position
//   these are expressed in unscaled coordinates
stbtt_GetCodepointKernAdvance :: (info: *stbtt_fontinfo, ch1: s32, ch2: s32) -> s32 #foreign stb_truetype;

// an additional amount to add to the 'advance' value between ch1 and ch2
stbtt_GetCodepointBox :: (info: *stbtt_fontinfo, codepoint: s32, x0: *s32, y0: *s32, x1: *s32, y1: *s32) -> s32 #foreign stb_truetype;

// Gets the bounding box of the visible part of the glyph, in unscaled coordinates
stbtt_GetGlyphHMetrics :: (info: *stbtt_fontinfo, glyph_index: s32, advanceWidth: *s32, leftSideBearing: *s32) -> void #foreign stb_truetype;

stbtt_GetGlyphKernAdvance :: (info: *stbtt_fontinfo, glyph1: s32, glyph2: s32) -> s32 #foreign stb_truetype;

stbtt_GetGlyphBox :: (info: *stbtt_fontinfo, glyph_index: s32, x0: *s32, y0: *s32, x1: *s32, y1: *s32) -> s32 #foreign stb_truetype;

// as above, but takes one or more glyph indices for greater efficiency
stbtt_kerningentry :: struct {
    glyph1:  s32; // use stbtt_FindGlyphIndex
    glyph2:  s32;
    advance: s32;
}

stbtt_GetKerningTableLength :: (info: *stbtt_fontinfo) -> s32 #foreign stb_truetype;

stbtt_GetKerningTable :: (info: *stbtt_fontinfo, table: *stbtt_kerningentry, table_length: s32) -> s32 #foreign stb_truetype;

STBTT :: enum s32 {
    vmove  :: 1;
    vline  :: 2;
    vcurve :: 3;
    vcubic :: 4;

    STBTT_vmove  :: vmove;
    STBTT_vline  :: vline;
    STBTT_vcurve :: vcurve;
    STBTT_vcubic :: vcubic;
}

stbtt_vertex :: struct {
    x:       s16;
    y:       s16;
    cx:      s16;
    cy:      s16;
    cx1:     s16;
    cy1:     s16;
    type:    u8;
    padding: u8;
}

stbtt_IsGlyphEmpty :: (info: *stbtt_fontinfo, glyph_index: s32) -> s32 #foreign stb_truetype;

// returns non-zero if nothing is drawn for this glyph
stbtt_GetCodepointShape :: (info: *stbtt_fontinfo, unicode_codepoint: s32, vertices: **stbtt_vertex) -> s32 #foreign stb_truetype;

stbtt_GetGlyphShape :: (info: *stbtt_fontinfo, glyph_index: s32, vertices: **stbtt_vertex) -> s32 #foreign stb_truetype;

// returns # of vertices and fills *vertices with the pointer to them
//   these are expressed in "unscaled" coordinates
//
// The shape is a series of contours. Each one starts with
// a STBTT_moveto, then consists of a series of mixed
// STBTT_lineto and STBTT_curveto segments. A lineto
// draws a line from previous endpoint to its x,y; a curveto
// draws a quadratic bezier from previous endpoint to
// its x,y, using cx,cy as the bezier control point.
stbtt_FreeShape :: (info: *stbtt_fontinfo, vertices: *stbtt_vertex) -> void #foreign stb_truetype;

// frees the data allocated above
stbtt_FindSVGDoc :: (info: *stbtt_fontinfo, gl: s32) -> *u8 #foreign stb_truetype;

stbtt_GetCodepointSVG :: (info: *stbtt_fontinfo, unicode_codepoint: s32, svg: **u8) -> s32 #foreign stb_truetype;

stbtt_GetGlyphSVG :: (info: *stbtt_fontinfo, gl: s32, svg: **u8) -> s32 #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// BITMAP RENDERING
//
stbtt_FreeBitmap :: (bitmap: *u8, userdata: *void) -> void #foreign stb_truetype;

// frees the bitmap allocated below
stbtt_GetCodepointBitmap :: (info: *stbtt_fontinfo, scale_x: float, scale_y: float, codepoint: s32, width: *s32, height: *s32, xoff: *s32, yoff: *s32) -> *u8 #foreign stb_truetype;

// allocates a large-enough single-channel 8bpp bitmap and renders the
// specified character/glyph at the specified scale into it, with
// antialiasing. 0 is no coverage (transparent), 255 is fully covered (opaque).
// *width & *height are filled out with the width & height of the bitmap,
// which is stored left-to-right, top-to-bottom.
//
// xoff/yoff are the offset it pixel space from the glyph origin to the top-left of the bitmap
stbtt_GetCodepointBitmapSubpixel :: (info: *stbtt_fontinfo, scale_x: float, scale_y: float, shift_x: float, shift_y: float, codepoint: s32, width: *s32, height: *s32, xoff: *s32, yoff: *s32) -> *u8 #foreign stb_truetype;

// the same as stbtt_GetCodepoitnBitmap, but you can specify a subpixel
// shift for the character
stbtt_MakeCodepointBitmap :: (info: *stbtt_fontinfo, output: *u8, out_w: s32, out_h: s32, out_stride: s32, scale_x: float, scale_y: float, codepoint: s32) -> void #foreign stb_truetype;

// the same as stbtt_GetCodepointBitmap, but you pass in storage for the bitmap
// in the form of 'output', with row spacing of 'out_stride' bytes. the bitmap
// is clipped to out_w/out_h bytes. Call stbtt_GetCodepointBitmapBox to get the
// width and height and positioning info for it first.
stbtt_MakeCodepointBitmapSubpixel :: (info: *stbtt_fontinfo, output: *u8, out_w: s32, out_h: s32, out_stride: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, codepoint: s32) -> void #foreign stb_truetype;

// same as stbtt_MakeCodepointBitmap, but you can specify a subpixel
// shift for the character
stbtt_MakeCodepointBitmapSubpixelPrefilter :: (info: *stbtt_fontinfo, output: *u8, out_w: s32, out_h: s32, out_stride: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, oversample_x: s32, oversample_y: s32, sub_x: *float, sub_y: *float, codepoint: s32) -> void #foreign stb_truetype;

// same as stbtt_MakeCodepointBitmapSubpixel, but prefiltering
// is performed (see stbtt_PackSetOversampling)
stbtt_GetCodepointBitmapBox :: (font: *stbtt_fontinfo, codepoint: s32, scale_x: float, scale_y: float, ix0: *s32, iy0: *s32, ix1: *s32, iy1: *s32) -> void #foreign stb_truetype;

// get the bbox of the bitmap centered around the glyph origin; so the
// bitmap width is ix1-ix0, height is iy1-iy0, and location to place
// the bitmap top left is (leftSideBearing*scale,iy0).
// (Note that the bitmap uses y-increases-down, but the shape uses
// y-increases-up, so CodepointBitmapBox and CodepointBox are inverted.)
stbtt_GetCodepointBitmapBoxSubpixel :: (font: *stbtt_fontinfo, codepoint: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, ix0: *s32, iy0: *s32, ix1: *s32, iy1: *s32) -> void #foreign stb_truetype;

// the following functions are equivalent to the above functions, but operate
// on glyph indices instead of Unicode codepoints (for efficiency)
stbtt_GetGlyphBitmap :: (info: *stbtt_fontinfo, scale_x: float, scale_y: float, glyph: s32, width: *s32, height: *s32, xoff: *s32, yoff: *s32) -> *u8 #foreign stb_truetype;

stbtt_GetGlyphBitmapSubpixel :: (info: *stbtt_fontinfo, scale_x: float, scale_y: float, shift_x: float, shift_y: float, glyph: s32, width: *s32, height: *s32, xoff: *s32, yoff: *s32) -> *u8 #foreign stb_truetype;

stbtt_MakeGlyphBitmap :: (info: *stbtt_fontinfo, output: *u8, out_w: s32, out_h: s32, out_stride: s32, scale_x: float, scale_y: float, glyph: s32) -> void #foreign stb_truetype;

stbtt_MakeGlyphBitmapSubpixel :: (info: *stbtt_fontinfo, output: *u8, out_w: s32, out_h: s32, out_stride: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, glyph: s32) -> void #foreign stb_truetype;

stbtt_MakeGlyphBitmapSubpixelPrefilter :: (info: *stbtt_fontinfo, output: *u8, out_w: s32, out_h: s32, out_stride: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, oversample_x: s32, oversample_y: s32, sub_x: *float, sub_y: *float, glyph: s32) -> void #foreign stb_truetype;

stbtt_GetGlyphBitmapBox :: (font: *stbtt_fontinfo, glyph: s32, scale_x: float, scale_y: float, ix0: *s32, iy0: *s32, ix1: *s32, iy1: *s32) -> void #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// antialiasing software rasterizer
//
stbtt_GetGlyphBitmapBoxSubpixel :: (font: *stbtt_fontinfo, glyph: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, ix0: *s32, iy0: *s32, ix1: *s32, iy1: *s32) -> void #foreign stb_truetype;

// @TODO: don't expose this structure
stbtt__bitmap :: struct {
    w:      s32;
    h:      s32;
    stride: s32;
    pixels: *u8;
}

// rasterize a shape with quadratic beziers into a bitmap
stbtt_Rasterize :: (result: *stbtt__bitmap, flatness_in_pixels: float, vertices: *stbtt_vertex, num_verts: s32, scale_x: float, scale_y: float, shift_x: float, shift_y: float, x_off: s32, y_off: s32, invert: s32, userdata: *void) -> void #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// Signed Distance Function (or Field) rendering
stbtt_FreeSDF :: (bitmap: *u8, userdata: *void) -> void #foreign stb_truetype;

// frees the SDF bitmap allocated below
stbtt_GetGlyphSDF :: (info: *stbtt_fontinfo, scale: float, glyph: s32, padding: s32, onedge_value: u8, pixel_dist_scale: float, width: *s32, height: *s32, xoff: *s32, yoff: *s32) -> *u8 #foreign stb_truetype;

stbtt_GetCodepointSDF :: (info: *stbtt_fontinfo, scale: float, codepoint: s32, padding: s32, onedge_value: u8, pixel_dist_scale: float, width: *s32, height: *s32, xoff: *s32, yoff: *s32) -> *u8 #foreign stb_truetype;

//////////////////////////////////////////////////////////////////////////////
//
// Finding the right font...
//
// You should really just solve this offline, keep your own tables
// of what font is what, and don't try to get it out of the .ttf file.
// That's because getting it out of the .ttf file is really hard, because
// the names in the file can appear in many possible encodings, in many
// possible languages, and e.g. if you need a case-insensitive comparison,
// the details of that depend on the encoding & language in a complex way
// (actually underspecified in truetype, but also gigantic).
//
// But you can use the provided functions in two possible ways:
//     stbtt_FindMatchingFont() will use *case-sensitive* comparisons on
//             unicode-encoded names to try to find the font you want;
//             you can run this before calling stbtt_InitFont()
//
//     stbtt_GetFontNameString() lets you get any of the various strings
//             from the file yourself and do your own comparisons on them.
//             You have to have called stbtt_InitFont() first.
stbtt_FindMatchingFont :: (fontdata: *u8, name: *u8, flags: s32) -> s32 #foreign stb_truetype;

stbtt_CompareUTF8toUTF16_bigendian :: (s1: *u8, len1: s32, s2: *u8, len2: s32) -> s32 #foreign stb_truetype;

// returns 1/0 whether the first string interpreted as utf8 is identical to
// the second string interpreted as big-endian utf16... useful for strings from next func
stbtt_GetFontNameString :: (font: *stbtt_fontinfo, length: *s32, platformID: s32, encodingID: s32, languageID: s32, nameID: s32) -> *u8 #foreign stb_truetype;

// returns the string (which may be big-endian double byte, e.g. for unicode)
// and puts the length in bytes in *length.
//
// some of the values for the IDs are below; for more see the truetype spec:
//     http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6name.html
//     http://www.microsoft.com/typography/otspec/name.htm
STBTT_PLATFORM_ID :: enum s32 {
    UNICODE   :: 0;
    MAC       :: 1;
    ISO       :: 2;
    MICROSOFT :: 3;

    STBTT_PLATFORM_ID_UNICODE   :: UNICODE;
    STBTT_PLATFORM_ID_MAC       :: MAC;
    STBTT_PLATFORM_ID_ISO       :: ISO;
    STBTT_PLATFORM_ID_MICROSOFT :: MICROSOFT;
}

STBTT_UNICODE_EID :: enum s32 {
    UNICODE_1_0      :: 0;
    UNICODE_1_1      :: 1;
    ISO_10646        :: 2;
    UNICODE_2_0_BMP  :: 3;
    UNICODE_2_0_FULL :: 4;

    STBTT_UNICODE_EID_UNICODE_1_0      :: UNICODE_1_0;
    STBTT_UNICODE_EID_UNICODE_1_1      :: UNICODE_1_1;
    STBTT_UNICODE_EID_ISO_10646        :: ISO_10646;
    STBTT_UNICODE_EID_UNICODE_2_0_BMP  :: UNICODE_2_0_BMP;
    STBTT_UNICODE_EID_UNICODE_2_0_FULL :: UNICODE_2_0_FULL;
}

STBTT_MS_EID :: enum s32 {
    SYMBOL       :: 0;
    UNICODE_BMP  :: 1;
    SHIFTJIS     :: 2;
    UNICODE_FULL :: 10;

    STBTT_MS_EID_SYMBOL       :: SYMBOL;
    STBTT_MS_EID_UNICODE_BMP  :: UNICODE_BMP;
    STBTT_MS_EID_SHIFTJIS     :: SHIFTJIS;
    STBTT_MS_EID_UNICODE_FULL :: UNICODE_FULL;
}

STBTT_MAC_EID :: enum s32 {
    ROMAN        :: 0;
    ARABIC       :: 4;
    JAPANESE     :: 1;
    HEBREW       :: 5;
    CHINESE_TRAD :: 2;
    GREEK        :: 6;
    KOREAN       :: 3;
    RUSSIAN      :: 7;

    STBTT_MAC_EID_ROMAN        :: ROMAN;
    STBTT_MAC_EID_ARABIC       :: ARABIC;
    STBTT_MAC_EID_JAPANESE     :: JAPANESE;
    STBTT_MAC_EID_HEBREW       :: HEBREW;
    STBTT_MAC_EID_CHINESE_TRAD :: CHINESE_TRAD;
    STBTT_MAC_EID_GREEK        :: GREEK;
    STBTT_MAC_EID_KOREAN       :: KOREAN;
    STBTT_MAC_EID_RUSSIAN      :: RUSSIAN;
}

STBTT_MS_LANG :: enum s32 {
    ENGLISH  :: 1033;
    ITALIAN  :: 1040;
    CHINESE  :: 2052;
    JAPANESE :: 1041;
    DUTCH    :: 1043;
    KOREAN   :: 1042;
    FRENCH   :: 1036;
    RUSSIAN  :: 1049;
    GERMAN   :: 1031;
    SPANISH  :: 1033;
    HEBREW   :: 1037;
    SWEDISH  :: 1053;

    STBTT_MS_LANG_ENGLISH  :: ENGLISH;
    STBTT_MS_LANG_ITALIAN  :: ITALIAN;
    STBTT_MS_LANG_CHINESE  :: CHINESE;
    STBTT_MS_LANG_JAPANESE :: JAPANESE;
    STBTT_MS_LANG_DUTCH    :: DUTCH;
    STBTT_MS_LANG_KOREAN   :: KOREAN;
    STBTT_MS_LANG_FRENCH   :: FRENCH;
    STBTT_MS_LANG_RUSSIAN  :: RUSSIAN;
    STBTT_MS_LANG_GERMAN   :: GERMAN;
    STBTT_MS_LANG_SPANISH  :: SPANISH;
    STBTT_MS_LANG_HEBREW   :: HEBREW;
    STBTT_MS_LANG_SWEDISH  :: SWEDISH;
}

STBTT_MAC_LANG :: enum s32 {
    ENGLISH            :: 0;
    JAPANESE           :: 11;
    ARABIC             :: 12;
    KOREAN             :: 23;
    DUTCH              :: 4;
    RUSSIAN            :: 32;
    FRENCH             :: 1;
    SPANISH            :: 6;
    GERMAN             :: 2;
    SWEDISH            :: 5;
    HEBREW             :: 10;
    CHINESE_SIMPLIFIED :: 33;
    ITALIAN            :: 3;
    CHINESE_TRAD       :: 19;

    STBTT_MAC_LANG_ENGLISH            :: ENGLISH;
    STBTT_MAC_LANG_JAPANESE           :: JAPANESE;
    STBTT_MAC_LANG_ARABIC             :: ARABIC;
    STBTT_MAC_LANG_KOREAN             :: KOREAN;
    STBTT_MAC_LANG_DUTCH              :: DUTCH;
    STBTT_MAC_LANG_RUSSIAN            :: RUSSIAN;
    STBTT_MAC_LANG_FRENCH             :: FRENCH;
    STBTT_MAC_LANG_SPANISH            :: SPANISH;
    STBTT_MAC_LANG_GERMAN             :: GERMAN;
    STBTT_MAC_LANG_SWEDISH            :: SWEDISH;
    STBTT_MAC_LANG_HEBREW             :: HEBREW;
    STBTT_MAC_LANG_CHINESE_SIMPLIFIED :: CHINESE_SIMPLIFIED;
    STBTT_MAC_LANG_ITALIAN            :: ITALIAN;
    STBTT_MAC_LANG_CHINESE_TRAD       :: CHINESE_TRAD;
}

stbtt__csctx :: struct {
    bounds:       s32;
    started:      s32;
    first_x:      float;
    first_y:      float;
    x:            float;
    y:            float;
    min_x:        s32;
    max_x:        s32;
    min_y:        s32;
    max_y:        s32;

    pvertices:    *stbtt_vertex;
    num_vertices: s32;
}

//////////////////////////////////////////////////////////////////////////////
//
//  Rasterizer
stbtt__hheap_chunk :: struct {
    next: *stbtt__hheap_chunk;
}

stbtt__hheap :: struct {
    head:                        *stbtt__hheap_chunk;
    first_free:                  *void;
    num_remaining_in_head_chunk: s32;
}

stbtt__edge :: struct {
    x0:     float;
    y0:     float;
    x1:     float;
    y1:     float;
    invert: s32;
}

stbtt__active_edge :: struct {
    next:      *stbtt__active_edge;

    fx:        float;
    fdx:       float;
    fdy:       float;
    direction: float;
    sy:        float;
    ey:        float;
}

stbtt__point :: struct {
    x: float;
    y: float;
}

stbrp_coord :: s32;

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                                                                                //
// COMPILER WARNING ?!?!?                                                         //
//                                                                                //
//                                                                                //
// if you get a compile warning due to these symbols being defined more than      //
// once, move #include "stb_rect_pack.h" before #include "stb_truetype.h"         //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////
stbrp_context :: struct {
    width:    s32;
    height:   s32;
    x:        s32;
    y:        s32;
    bottom_y: s32;
}

stbrp_node :: struct {
    x: u8;
}

stbrp_rect :: struct {
    x:          stbrp_coord;
    y:          stbrp_coord;
    id:         s32;
    w:          s32;
    h:          s32;
    was_packed: s32;
}

#scope_file


#if OS == .WINDOWS {
    stb_truetype :: #library "windows/stb_truetype";
} else #if OS == .LINUX {
    stb_truetype :: #library "linux/stb_truetype";
} else #if OS == .MACOS {
    stb_truetype :: #library "macos/stb_truetype";
} else {
    #assert false;
}

