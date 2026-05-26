//
// This file was auto-generated using the following command:
//
// jai modules/freetype/generate.jai
//



FT_RENDER_POOL_SIZE :: 16384;

FT_MAX_MODULES :: 32;

TT_CONFIG_OPTION_MAX_RUNNABLE_OPCODES :: 1000000;

T1_MAX_DICT_DEPTH :: 5;

T1_MAX_SUBRS_CALLS :: 16;

T1_MAX_CHARSTRINGS_OPERANDS :: 256;

CFF_CONFIG_OPTION_DARKENING_PARAMETER_X1 :: 500;
CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y1 :: 400;

CFF_CONFIG_OPTION_DARKENING_PARAMETER_X2 :: 1000;
CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y2 :: 275;

CFF_CONFIG_OPTION_DARKENING_PARAMETER_X3 :: 1667;
CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y3 :: 275;

CFF_CONFIG_OPTION_DARKENING_PARAMETER_X4 :: 2333;
CFF_CONFIG_OPTION_DARKENING_PARAMETER_Y4 :: 0;

FT_INT64_ZERO :: 0;

FT_OUTLINE_NONE :: 0x0;
FT_OUTLINE_OWNER :: 0x1;
FT_OUTLINE_EVEN_ODD_FILL :: 0x2;
FT_OUTLINE_REVERSE_FILL :: 0x4;
FT_OUTLINE_IGNORE_DROPOUTS :: 0x8;
FT_OUTLINE_SMART_DROPOUTS :: 0x10;
FT_OUTLINE_INCLUDE_STUBS :: 0x20;
FT_OUTLINE_OVERLAP :: 0x40;

FT_OUTLINE_HIGH_PRECISION :: 0x100;
FT_OUTLINE_SINGLE_PASS :: 0x200;

ft_outline_none :: FT_OUTLINE_NONE;
ft_outline_owner :: FT_OUTLINE_OWNER;
ft_outline_even_odd_fill :: FT_OUTLINE_EVEN_ODD_FILL;
ft_outline_reverse_fill :: FT_OUTLINE_REVERSE_FILL;
ft_outline_ignore_dropouts :: FT_OUTLINE_IGNORE_DROPOUTS;
ft_outline_high_precision :: FT_OUTLINE_HIGH_PRECISION;
ft_outline_single_pass :: FT_OUTLINE_SINGLE_PASS;

FT_CURVE_TAG_ON :: 0x01;
FT_CURVE_TAG_CONIC :: 0x00;
FT_CURVE_TAG_CUBIC :: 0x02;

FT_CURVE_TAG_HAS_SCANMODE :: 0x04;

FT_CURVE_TAG_TOUCH_X :: 0x08;
FT_CURVE_TAG_TOUCH_Y :: 0x10;

FT_CURVE_TAG_TOUCH_BOTH :: FT_CURVE_TAG_TOUCH_X | FT_CURVE_TAG_TOUCH_Y;

FT_Curve_Tag_On :: FT_CURVE_TAG_ON;
FT_Curve_Tag_Conic :: FT_CURVE_TAG_CONIC;
FT_Curve_Tag_Cubic :: FT_CURVE_TAG_CUBIC;
FT_Curve_Tag_Touch_X :: FT_CURVE_TAG_TOUCH_X;
FT_Curve_Tag_Touch_Y :: FT_CURVE_TAG_TOUCH_Y;

FT_Outline_MoveTo_Func :: FT_Outline_MoveToFunc;

FT_Outline_LineTo_Func :: FT_Outline_LineToFunc;

FT_Outline_ConicTo_Func :: FT_Outline_ConicToFunc;

FT_Outline_CubicTo_Func :: FT_Outline_CubicToFunc;

FT_Raster_Span_Func :: FT_SpanFunc;

FT_RASTER_FLAG_DEFAULT :: 0x0;
FT_RASTER_FLAG_AA :: 0x1;
FT_RASTER_FLAG_DIRECT :: 0x2;
FT_RASTER_FLAG_CLIP :: 0x4;
FT_RASTER_FLAG_SDF :: 0x8;

ft_raster_flag_default :: FT_RASTER_FLAG_DEFAULT;
ft_raster_flag_aa :: FT_RASTER_FLAG_AA;
ft_raster_flag_direct :: FT_RASTER_FLAG_DIRECT;
ft_raster_flag_clip :: FT_RASTER_FLAG_CLIP;

FT_Raster_New_Func :: FT_Raster_NewFunc;

FT_Raster_Done_Func :: FT_Raster_DoneFunc;

FT_Raster_Reset_Func :: FT_Raster_ResetFunc;

FT_Raster_Set_Mode_Func :: FT_Raster_SetModeFunc;

FT_Raster_Render_Func :: FT_Raster_RenderFunc;

FT_ERR_BASE :: 0;

FT_FACE_FLAG_SCALABLE :: 1 << 0;
FT_FACE_FLAG_FIXED_SIZES :: 1 << 1;
FT_FACE_FLAG_FIXED_WIDTH :: 1 << 2;
FT_FACE_FLAG_SFNT :: 1 << 3;
FT_FACE_FLAG_HORIZONTAL :: 1 << 4;
FT_FACE_FLAG_VERTICAL :: 1 << 5;
FT_FACE_FLAG_KERNING :: 1 << 6;
FT_FACE_FLAG_FAST_GLYPHS :: 1 << 7;
FT_FACE_FLAG_MULTIPLE_MASTERS :: 1 << 8;
FT_FACE_FLAG_GLYPH_NAMES :: 1 << 9;
FT_FACE_FLAG_EXTERNAL_STREAM :: 1 << 10;
FT_FACE_FLAG_HINTER :: 1 << 11;
FT_FACE_FLAG_CID_KEYED :: 1 << 12;
FT_FACE_FLAG_TRICKY :: 1 << 13;
FT_FACE_FLAG_COLOR :: 1 << 14;
FT_FACE_FLAG_VARIATION :: 1 << 15;
FT_FACE_FLAG_SVG :: 1 << 16;
FT_FACE_FLAG_SBIX :: 1 << 17;
FT_FACE_FLAG_SBIX_OVERLAY :: 1 << 18;

FT_STYLE_FLAG_ITALIC :: 1 << 0;
FT_STYLE_FLAG_BOLD :: 1 << 1;

FT_OPEN_MEMORY :: 0x1;
FT_OPEN_STREAM :: 0x2;
FT_OPEN_PATHNAME :: 0x4;
FT_OPEN_DRIVER :: 0x8;
FT_OPEN_PARAMS :: 0x10;

ft_open_memory :: FT_OPEN_MEMORY;
ft_open_stream :: FT_OPEN_STREAM;
ft_open_pathname :: FT_OPEN_PATHNAME;
ft_open_driver :: FT_OPEN_DRIVER;
ft_open_params :: FT_OPEN_PARAMS;

FT_LOAD_DEFAULT :: 0x0;
FT_LOAD_NO_SCALE :: 1 << 0;
FT_LOAD_NO_HINTING :: 1 << 1;
FT_LOAD_RENDER :: 1 << 2;
FT_LOAD_NO_BITMAP :: 1 << 3;
FT_LOAD_VERTICAL_LAYOUT :: 1 << 4;
FT_LOAD_FORCE_AUTOHINT :: 1 << 5;
FT_LOAD_CROP_BITMAP :: 1 << 6;
FT_LOAD_PEDANTIC :: 1 << 7;
FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH :: 1 << 9;
FT_LOAD_NO_RECURSE :: 1 << 10;
FT_LOAD_IGNORE_TRANSFORM :: 1 << 11;
FT_LOAD_MONOCHROME :: 1 << 12;
FT_LOAD_LINEAR_DESIGN :: 1 << 13;
FT_LOAD_SBITS_ONLY :: 1 << 14;
FT_LOAD_NO_AUTOHINT :: 1 << 15;

FT_LOAD_COLOR :: 1 << 20;
FT_LOAD_COMPUTE_METRICS :: 1 << 21;
FT_LOAD_BITMAP_METRICS_ONLY :: 1 << 22;
FT_LOAD_NO_SVG :: 1 << 24;

FT_LOAD_ADVANCE_ONLY :: 1 << 8;
FT_LOAD_SVG_ONLY :: 1 << 23;

FT_SUBGLYPH_FLAG_ARGS_ARE_WORDS :: 1;
FT_SUBGLYPH_FLAG_ARGS_ARE_XY_VALUES :: 2;
FT_SUBGLYPH_FLAG_ROUND_XY_TO_GRID :: 4;
FT_SUBGLYPH_FLAG_SCALE :: 8;
FT_SUBGLYPH_FLAG_XY_SCALE :: 0x40;
FT_SUBGLYPH_FLAG_2X2 :: 0x80;
FT_SUBGLYPH_FLAG_USE_MY_METRICS :: 0x200;

FT_FSTYPE_INSTALLABLE_EMBEDDING :: 0x0000;
FT_FSTYPE_RESTRICTED_LICENSE_EMBEDDING :: 0x0002;
FT_FSTYPE_PREVIEW_AND_PRINT_EMBEDDING :: 0x0004;
FT_FSTYPE_EDITABLE_EMBEDDING :: 0x0008;
FT_FSTYPE_NO_SUBSETTING :: 0x0100;
FT_FSTYPE_BITMAP_EMBEDDING_ONLY :: 0x0200;

FREETYPE_MAJOR :: 2;
FREETYPE_MINOR :: 14;
FREETYPE_PATCH :: 3;

/**************************************************************************
*
* @type:
*   FT_Int16
*
* @description:
*   A typedef for a 16bit signed integer type.
*/
FT_Int16 :: s16;

/**************************************************************************
*
* @type:
*   FT_UInt16
*
* @description:
*   A typedef for a 16bit unsigned integer type.
*/
FT_UInt16 :: u16;

FT_Int32 :: s32;
FT_UInt32 :: u32;

FT_Fast :: s32;
FT_UFast :: u32;

FT_Int64 :: s64;
FT_UInt64 :: u64;

/**************************************************************************
*
* @type:
*   FT_Memory
*
* @description:
*   A handle to a given memory manager object, defined with an
*   @FT_MemoryRec structure.
*
*/
FT_Memory :: *FT_MemoryRec_;

/**************************************************************************
*
* @functype:
*   FT_Alloc_Func
*
* @description:
*   A function used to allocate `size` bytes from `memory`.
*
* @input:
*   memory ::
*     A handle to the source memory manager.
*
*   size ::
*     The size in bytes to allocate.
*
* @return:
*   Address of new memory block.  0~in case of failure.
*
*/
FT_Alloc_Func :: #type (memory: FT_Memory, size: s32) -> *void #c_call;

/**************************************************************************
*
* @functype:
*   FT_Free_Func
*
* @description:
*   A function used to release a given block of memory.
*
* @input:
*   memory ::
*     A handle to the source memory manager.
*
*   block ::
*     The address of the target memory block.
*
*/
FT_Free_Func :: #type (memory: FT_Memory, block: *void) -> void #c_call;

/**************************************************************************
*
* @functype:
*   FT_Realloc_Func
*
* @description:
*   A function used to re-allocate a given block of memory.
*
* @input:
*   memory ::
*     A handle to the source memory manager.
*
*   cur_size ::
*     The block's current size in bytes.
*
*   new_size ::
*     The block's requested new size.
*
*   block ::
*     The block's current address.
*
* @return:
*   New block address.  0~in case of memory shortage.
*
* @note:
*   In case of error, the old block must still be available.
*
*/
FT_Realloc_Func :: #type (memory: FT_Memory, cur_size: s32, new_size: s32, block: *void) -> *void #c_call;

/**************************************************************************
*
* @struct:
*   FT_MemoryRec
*
* @description:
*   A structure used to describe a given memory manager to FreeType~2.
*
* @fields:
*   user ::
*     A generic typeless pointer for user data.
*
*   alloc ::
*     A pointer type to an allocation function.
*
*   free ::
*     A pointer type to an memory freeing function.
*
*   realloc ::
*     A pointer type to a reallocation function.
*
*/
FT_MemoryRec_ :: struct {
    user:    *void;
    alloc:   FT_Alloc_Func;
    free:    FT_Free_Func;
    realloc: FT_Realloc_Func;
}

/**************************************************************************
*
* @type:
*   FT_Stream
*
* @description:
*   A handle to an input stream.
*
* @also:
*   See @FT_StreamRec for the publicly accessible fields of a given stream
*   object.
*
*/
FT_Stream :: *FT_StreamRec_;

/**************************************************************************
*
* @struct:
*   FT_StreamDesc
*
* @description:
*   A union type used to store either a long or a pointer.  This is used
*   to store a file descriptor or a `FILE*` in an input stream.
*
*/
FT_StreamDesc_ :: union {
    value:   s32;
    pointer: *void;
}

/**************************************************************************
*
* @struct:
*   FT_StreamDesc
*
* @description:
*   A union type used to store either a long or a pointer.  This is used
*   to store a file descriptor or a `FILE*` in an input stream.
*
*/
FT_StreamDesc :: FT_StreamDesc_;

/**************************************************************************
*
* @functype:
*   FT_Stream_IoFunc
*
* @description:
*   A function used to seek and read data from a given input stream.
*
* @input:
*   stream ::
*     A handle to the source stream.
*
*   offset ::
*     The offset from the start of the stream to seek to.
*
*   buffer ::
*     The address of the read buffer.
*
*   count ::
*     The number of bytes to read from the stream.
*
* @return:
*   If count >~0, return the number of bytes effectively read by the
*   stream (after seeking to `offset`).  If count ==~0, return the status
*   of the seek operation (non-zero indicates an error).
*
*/
FT_Stream_IoFunc :: #type (stream: FT_Stream, offset: u32, buffer: *u8, count: u32) -> u32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Stream_CloseFunc
*
* @description:
*   A function used to close a given input stream.
*
* @input:
*  stream ::
*    A handle to the target stream.
*
*/
FT_Stream_CloseFunc :: #type (stream: FT_Stream) -> void #c_call;

/**************************************************************************
*
* @struct:
*   FT_StreamRec
*
* @description:
*   A structure used to describe an input stream.
*
* @input:
*   base ::
*     For memory-based streams, this is the address of the first stream
*     byte in memory.  This field should always be set to `NULL` for
*     disk-based streams.
*
*   size ::
*     The stream size in bytes.
*
*     In case of compressed streams where the size is unknown before
*     actually doing the decompression, the value is set to 0x7FFFFFFF.
*     (Note that this size value can occur for normal streams also; it is
*     thus just a hint.)
*
*   pos ::
*     The current position within the stream.
*
*   descriptor ::
*     This field is a union that can hold an integer or a pointer.  It is
*     used by stream implementations to store file descriptors or `FILE*`
*     pointers.
*
*   pathname ::
*     This field is completely ignored by FreeType.  However, it is often
*     useful during debugging to use it to store the stream's filename
*     (where available).
*
*   read ::
*     The stream's input function.
*
*   close ::
*     The stream's close function.
*
*   memory ::
*     The memory manager to use to preload frames.  This is set internally
*     by FreeType and shouldn't be touched by stream implementations.
*
*   cursor ::
*     This field is set and used internally by FreeType when parsing
*     frames.  In particular, the `FT_GET_XXX` macros use this instead of
*     the `pos` field.
*
*   limit ::
*     This field is set and used internally by FreeType when parsing
*     frames.
*
*/
FT_StreamRec_ :: struct {
    base:       *u8;
    size:       u32;
    pos:        u32;

    descriptor: FT_StreamDesc;
    pathname:   FT_StreamDesc;
    read:       FT_Stream_IoFunc;
    close:      FT_Stream_CloseFunc;

    memory:     FT_Memory;
    cursor:     *u8;
    limit:      *u8;
}

/**************************************************************************
*
* @struct:
*   FT_StreamRec
*
* @description:
*   A structure used to describe an input stream.
*
* @input:
*   base ::
*     For memory-based streams, this is the address of the first stream
*     byte in memory.  This field should always be set to `NULL` for
*     disk-based streams.
*
*   size ::
*     The stream size in bytes.
*
*     In case of compressed streams where the size is unknown before
*     actually doing the decompression, the value is set to 0x7FFFFFFF.
*     (Note that this size value can occur for normal streams also; it is
*     thus just a hint.)
*
*   pos ::
*     The current position within the stream.
*
*   descriptor ::
*     This field is a union that can hold an integer or a pointer.  It is
*     used by stream implementations to store file descriptors or `FILE*`
*     pointers.
*
*   pathname ::
*     This field is completely ignored by FreeType.  However, it is often
*     useful during debugging to use it to store the stream's filename
*     (where available).
*
*   read ::
*     The stream's input function.
*
*   close ::
*     The stream's close function.
*
*   memory ::
*     The memory manager to use to preload frames.  This is set internally
*     by FreeType and shouldn't be touched by stream implementations.
*
*   cursor ::
*     This field is set and used internally by FreeType when parsing
*     frames.  In particular, the `FT_GET_XXX` macros use this instead of
*     the `pos` field.
*
*   limit ::
*     This field is set and used internally by FreeType when parsing
*     frames.
*
*/
FT_StreamRec :: FT_StreamRec_;

/**************************************************************************
*
* @type:
*   FT_Pos
*
* @description:
*   The type FT_Pos is used to store vectorial coordinates.  Depending on
*   the context, these can represent distances in integer font units, or
*   16.16, or 26.6 fixed-point pixel coordinates.
*/
FT_Pos :: s32;

/**************************************************************************
*
* @struct:
*   FT_Vector
*
* @description:
*   A simple structure used to store a 2D vector; coordinates are of the
*   FT_Pos type.
*
* @fields:
*   x ::
*     The horizontal coordinate.
*   y ::
*     The vertical coordinate.
*/
FT_Vector_ :: struct {
    x: FT_Pos;
    y: FT_Pos;
}

/**************************************************************************
*
* @struct:
*   FT_Vector
*
* @description:
*   A simple structure used to store a 2D vector; coordinates are of the
*   FT_Pos type.
*
* @fields:
*   x ::
*     The horizontal coordinate.
*   y ::
*     The vertical coordinate.
*/
FT_Vector :: FT_Vector_;

/**************************************************************************
*
* @struct:
*   FT_BBox
*
* @description:
*   A structure used to hold an outline's bounding box, i.e., the
*   coordinates of its extrema in the horizontal and vertical directions.
*
* @fields:
*   xMin ::
*     The horizontal minimum (left-most).
*
*   yMin ::
*     The vertical minimum (bottom-most).
*
*   xMax ::
*     The horizontal maximum (right-most).
*
*   yMax ::
*     The vertical maximum (top-most).
*
* @note:
*   The bounding box is specified with the coordinates of the lower left
*   and the upper right corner.  In PostScript, those values are often
*   called (llx,lly) and (urx,ury), respectively.
*
*   If `yMin` is negative, this value gives the glyph's descender.
*   Otherwise, the glyph doesn't descend below the baseline.  Similarly,
*   if `ymax` is positive, this value gives the glyph's ascender.
*
*   `xMin` gives the horizontal distance from the glyph's origin to the
*   left edge of the glyph's bounding box.  If `xMin` is negative, the
*   glyph extends to the left of the origin.
*/
FT_BBox_ :: struct {
    xMin: FT_Pos;
    yMin: FT_Pos;
    xMax: FT_Pos;
    yMax: FT_Pos;
}

/**************************************************************************
*
* @struct:
*   FT_BBox
*
* @description:
*   A structure used to hold an outline's bounding box, i.e., the
*   coordinates of its extrema in the horizontal and vertical directions.
*
* @fields:
*   xMin ::
*     The horizontal minimum (left-most).
*
*   yMin ::
*     The vertical minimum (bottom-most).
*
*   xMax ::
*     The horizontal maximum (right-most).
*
*   yMax ::
*     The vertical maximum (top-most).
*
* @note:
*   The bounding box is specified with the coordinates of the lower left
*   and the upper right corner.  In PostScript, those values are often
*   called (llx,lly) and (urx,ury), respectively.
*
*   If `yMin` is negative, this value gives the glyph's descender.
*   Otherwise, the glyph doesn't descend below the baseline.  Similarly,
*   if `ymax` is positive, this value gives the glyph's ascender.
*
*   `xMin` gives the horizontal distance from the glyph's origin to the
*   left edge of the glyph's bounding box.  If `xMin` is negative, the
*   glyph extends to the left of the origin.
*/
FT_BBox :: FT_BBox_;

/**************************************************************************
*
* @enum:
*   FT_Pixel_Mode
*
* @description:
*   An enumeration type used to describe the format of pixels in a given
*   bitmap.  Note that additional formats may be added in the future.
*
* @values:
*   FT_PIXEL_MODE_NONE ::
*     Value~0 is reserved.
*
*   FT_PIXEL_MODE_MONO ::
*     A monochrome bitmap, using 1~bit per pixel.  Note that pixels are
*     stored in most-significant order (MSB), which means that the
*     left-most pixel in a byte has value 128.
*
*   FT_PIXEL_MODE_GRAY ::
*     An 8-bit bitmap, generally used to represent anti-aliased glyph
*     images.  Each pixel is stored in one byte.  Note that the number of
*     'gray' levels is stored in the `num_grays` field of the @FT_Bitmap
*     structure (it generally is 256).
*
*   FT_PIXEL_MODE_GRAY2 ::
*     A 2-bit per pixel bitmap, used to represent embedded anti-aliased
*     bitmaps in font files according to the OpenType specification.  We
*     haven't found a single font using this format, however.
*
*   FT_PIXEL_MODE_GRAY4 ::
*     A 4-bit per pixel bitmap, representing embedded anti-aliased bitmaps
*     in font files according to the OpenType specification.  We haven't
*     found a single font using this format, however.
*
*   FT_PIXEL_MODE_LCD ::
*     An 8-bit bitmap, representing RGB or BGR decimated glyph images used
*     for display on LCD displays; the bitmap is three times wider than
*     the original glyph image.  See also @FT_RENDER_MODE_LCD.
*
*   FT_PIXEL_MODE_LCD_V ::
*     An 8-bit bitmap, representing RGB or BGR decimated glyph images used
*     for display on rotated LCD displays; the bitmap is three times
*     taller than the original glyph image.  See also
*     @FT_RENDER_MODE_LCD_V.
*
*   FT_PIXEL_MODE_BGRA ::
*     [Since 2.5] An image with four 8-bit channels per pixel,
*     representing a color image (such as emoticons) with alpha channel.
*     For each pixel, the format is BGRA, which means, the blue channel
*     comes first in memory.  The color channels are pre-multiplied and in
*     the sRGB colorspace.  For example, full red at half-translucent
*     opacity will be represented as '00,00,80,80', not '00,00,FF,80'.
*     See also @FT_LOAD_COLOR.
*/
FT_Pixel_Mode_ :: enum s32 {
    NONE  :: 0;
    MONO  :: 1;
    GRAY  :: 2;
    GRAY2 :: 3;
    GRAY4 :: 4;
    LCD   :: 5;
    LCD_V :: 6;
    BGRA  :: 7;

    MAX   :: 8;

    FT_PIXEL_MODE_NONE  :: NONE;
    FT_PIXEL_MODE_MONO  :: MONO;
    FT_PIXEL_MODE_GRAY  :: GRAY;
    FT_PIXEL_MODE_GRAY2 :: GRAY2;
    FT_PIXEL_MODE_GRAY4 :: GRAY4;
    FT_PIXEL_MODE_LCD   :: LCD;
    FT_PIXEL_MODE_LCD_V :: LCD_V;
    FT_PIXEL_MODE_BGRA  :: BGRA;

    FT_PIXEL_MODE_MAX   :: MAX;
}

/**************************************************************************
*
* @enum:
*   FT_Pixel_Mode
*
* @description:
*   An enumeration type used to describe the format of pixels in a given
*   bitmap.  Note that additional formats may be added in the future.
*
* @values:
*   FT_PIXEL_MODE_NONE ::
*     Value~0 is reserved.
*
*   FT_PIXEL_MODE_MONO ::
*     A monochrome bitmap, using 1~bit per pixel.  Note that pixels are
*     stored in most-significant order (MSB), which means that the
*     left-most pixel in a byte has value 128.
*
*   FT_PIXEL_MODE_GRAY ::
*     An 8-bit bitmap, generally used to represent anti-aliased glyph
*     images.  Each pixel is stored in one byte.  Note that the number of
*     'gray' levels is stored in the `num_grays` field of the @FT_Bitmap
*     structure (it generally is 256).
*
*   FT_PIXEL_MODE_GRAY2 ::
*     A 2-bit per pixel bitmap, used to represent embedded anti-aliased
*     bitmaps in font files according to the OpenType specification.  We
*     haven't found a single font using this format, however.
*
*   FT_PIXEL_MODE_GRAY4 ::
*     A 4-bit per pixel bitmap, representing embedded anti-aliased bitmaps
*     in font files according to the OpenType specification.  We haven't
*     found a single font using this format, however.
*
*   FT_PIXEL_MODE_LCD ::
*     An 8-bit bitmap, representing RGB or BGR decimated glyph images used
*     for display on LCD displays; the bitmap is three times wider than
*     the original glyph image.  See also @FT_RENDER_MODE_LCD.
*
*   FT_PIXEL_MODE_LCD_V ::
*     An 8-bit bitmap, representing RGB or BGR decimated glyph images used
*     for display on rotated LCD displays; the bitmap is three times
*     taller than the original glyph image.  See also
*     @FT_RENDER_MODE_LCD_V.
*
*   FT_PIXEL_MODE_BGRA ::
*     [Since 2.5] An image with four 8-bit channels per pixel,
*     representing a color image (such as emoticons) with alpha channel.
*     For each pixel, the format is BGRA, which means, the blue channel
*     comes first in memory.  The color channels are pre-multiplied and in
*     the sRGB colorspace.  For example, full red at half-translucent
*     opacity will be represented as '00,00,80,80', not '00,00,FF,80'.
*     See also @FT_LOAD_COLOR.
*/
FT_Pixel_Mode :: FT_Pixel_Mode_;

/**************************************************************************
*
* @struct:
*   FT_Bitmap
*
* @description:
*   A structure used to describe a bitmap or pixmap to the raster.  Note
*   that we now manage pixmaps of various depths through the `pixel_mode`
*   field.
*
* @fields:
*   rows ::
*     The number of bitmap rows.
*
*   width ::
*     The number of pixels in bitmap row.
*
*   pitch ::
*     The pitch's absolute value is the number of bytes taken by one
*     bitmap row, including padding.  However, the pitch is positive when
*     the bitmap has a 'down' flow, and negative when it has an 'up' flow.
*     In all cases, the pitch is an offset to add to a bitmap pointer in
*     order to go down one row.
*
*     Note that 'padding' means the alignment of a bitmap to a byte
*     border, and FreeType functions normally align to the smallest
*     possible integer value.
*
*     For the B/W rasterizer, `pitch` is always an even number.
*
*     To change the pitch of a bitmap (say, to make it a multiple of 4),
*     use @FT_Bitmap_Convert.  Alternatively, you might use callback
*     functions to directly render to the application's surface; see the
*     file `example2.cpp` in the tutorial for a demonstration.
*
*   buffer ::
*     A typeless pointer to the bitmap buffer.  This value should be
*     aligned on 32-bit boundaries in most cases.
*
*   num_grays ::
*     This field is only used with @FT_PIXEL_MODE_GRAY; it gives the
*     number of gray levels used in the bitmap.
*
*   pixel_mode ::
*     The pixel mode, i.e., how pixel bits are stored.  See @FT_Pixel_Mode
*     for possible values.
*
*   palette_mode ::
*     This field is intended for paletted pixel modes; it indicates how
*     the palette is stored.  Not used currently.
*
*   palette ::
*     A typeless pointer to the bitmap palette; this field is intended for
*     paletted pixel modes.  Not used currently.
*
* @note:
*   `width` and `rows` refer to the *physical* size of the bitmap, not the
*   *logical* one.  For example, if @FT_Pixel_Mode is set to
*   `FT_PIXEL_MODE_LCD`, the logical width is a just a third of the
*   physical one.
*
*   An empty bitmap with a NULL `buffer` is valid, with `rows` and/or
*   `pitch` also set to 0.  Such bitmaps might be produced while rendering
*   empty or degenerate outlines.
*/
FT_Bitmap_ :: struct {
    rows:         u32;
    width:        u32;
    pitch:        s32;
    buffer:       *u8;
    num_grays:    u16;
    pixel_mode:   u8;
    palette_mode: u8;
    palette:      *void;
}

/**************************************************************************
*
* @struct:
*   FT_Bitmap
*
* @description:
*   A structure used to describe a bitmap or pixmap to the raster.  Note
*   that we now manage pixmaps of various depths through the `pixel_mode`
*   field.
*
* @fields:
*   rows ::
*     The number of bitmap rows.
*
*   width ::
*     The number of pixels in bitmap row.
*
*   pitch ::
*     The pitch's absolute value is the number of bytes taken by one
*     bitmap row, including padding.  However, the pitch is positive when
*     the bitmap has a 'down' flow, and negative when it has an 'up' flow.
*     In all cases, the pitch is an offset to add to a bitmap pointer in
*     order to go down one row.
*
*     Note that 'padding' means the alignment of a bitmap to a byte
*     border, and FreeType functions normally align to the smallest
*     possible integer value.
*
*     For the B/W rasterizer, `pitch` is always an even number.
*
*     To change the pitch of a bitmap (say, to make it a multiple of 4),
*     use @FT_Bitmap_Convert.  Alternatively, you might use callback
*     functions to directly render to the application's surface; see the
*     file `example2.cpp` in the tutorial for a demonstration.
*
*   buffer ::
*     A typeless pointer to the bitmap buffer.  This value should be
*     aligned on 32-bit boundaries in most cases.
*
*   num_grays ::
*     This field is only used with @FT_PIXEL_MODE_GRAY; it gives the
*     number of gray levels used in the bitmap.
*
*   pixel_mode ::
*     The pixel mode, i.e., how pixel bits are stored.  See @FT_Pixel_Mode
*     for possible values.
*
*   palette_mode ::
*     This field is intended for paletted pixel modes; it indicates how
*     the palette is stored.  Not used currently.
*
*   palette ::
*     A typeless pointer to the bitmap palette; this field is intended for
*     paletted pixel modes.  Not used currently.
*
* @note:
*   `width` and `rows` refer to the *physical* size of the bitmap, not the
*   *logical* one.  For example, if @FT_Pixel_Mode is set to
*   `FT_PIXEL_MODE_LCD`, the logical width is a just a third of the
*   physical one.
*
*   An empty bitmap with a NULL `buffer` is valid, with `rows` and/or
*   `pitch` also set to 0.  Such bitmaps might be produced while rendering
*   empty or degenerate outlines.
*/
FT_Bitmap :: FT_Bitmap_;

/**************************************************************************
*
* @struct:
*   FT_Outline
*
* @description:
*   This structure is used to describe an outline to the scan-line
*   converter.
*
* @fields:
*   n_contours ::
*     The number of contours in the outline.
*
*   n_points ::
*     The number of points in the outline.
*
*   points ::
*     A pointer to an array of `n_points` @FT_Vector elements, giving the
*     outline's point coordinates.
*
*   tags ::
*     A pointer to an array of `n_points` chars, giving each outline
*     point's type.
*
*     If bit~0 is unset, the point is 'off' the curve, i.e., a Bezier
*     control point, while it is 'on' if set.
*
*     Bit~1 is meaningful for 'off' points only.  If set, it indicates a
*     third-order Bezier arc control point; and a second-order control
*     point if unset.
*
*     If bit~2 is set, bits 5-7 contain the drop-out mode (as defined in
*     the OpenType specification; the value is the same as the argument to
*     the 'SCANTYPE' instruction).
*
*     Bits 3 and~4 are reserved for internal purposes.
*
*   contours ::
*     An array of `n_contours` shorts, giving the end point of each
*     contour within the outline.  For example, the first contour is
*     defined by the points '0' to `contours[0]`, the second one is
*     defined by the points `contours[0]+1` to `contours[1]`, etc.
*
*   flags ::
*     A set of bit flags used to characterize the outline and give hints
*     to the scan-converter and hinter on how to convert/grid-fit it.  See
*     @FT_OUTLINE_XXX.
*
* @note:
*   The B/W rasterizer only checks bit~2 in the `tags` array for the first
*   point of each contour.  The drop-out mode as given with
*   @FT_OUTLINE_IGNORE_DROPOUTS, @FT_OUTLINE_SMART_DROPOUTS, and
*   @FT_OUTLINE_INCLUDE_STUBS in `flags` is then overridden.
*/
FT_Outline_ :: struct {
    n_contours: u16; /* number of contours in glyph        */
    n_points:   u16; /* number of points in the glyph      */

    points:     *FT_Vector; /* the outline's points               */
    tags:       *u8; /* the points flags                   */
    contours:   *u16; /* the contour end points             */

    flags:      s32; /* outline masks                      */
}

/**************************************************************************
*
* @struct:
*   FT_Outline
*
* @description:
*   This structure is used to describe an outline to the scan-line
*   converter.
*
* @fields:
*   n_contours ::
*     The number of contours in the outline.
*
*   n_points ::
*     The number of points in the outline.
*
*   points ::
*     A pointer to an array of `n_points` @FT_Vector elements, giving the
*     outline's point coordinates.
*
*   tags ::
*     A pointer to an array of `n_points` chars, giving each outline
*     point's type.
*
*     If bit~0 is unset, the point is 'off' the curve, i.e., a Bezier
*     control point, while it is 'on' if set.
*
*     Bit~1 is meaningful for 'off' points only.  If set, it indicates a
*     third-order Bezier arc control point; and a second-order control
*     point if unset.
*
*     If bit~2 is set, bits 5-7 contain the drop-out mode (as defined in
*     the OpenType specification; the value is the same as the argument to
*     the 'SCANTYPE' instruction).
*
*     Bits 3 and~4 are reserved for internal purposes.
*
*   contours ::
*     An array of `n_contours` shorts, giving the end point of each
*     contour within the outline.  For example, the first contour is
*     defined by the points '0' to `contours[0]`, the second one is
*     defined by the points `contours[0]+1` to `contours[1]`, etc.
*
*   flags ::
*     A set of bit flags used to characterize the outline and give hints
*     to the scan-converter and hinter on how to convert/grid-fit it.  See
*     @FT_OUTLINE_XXX.
*
* @note:
*   The B/W rasterizer only checks bit~2 in the `tags` array for the first
*   point of each contour.  The drop-out mode as given with
*   @FT_OUTLINE_IGNORE_DROPOUTS, @FT_OUTLINE_SMART_DROPOUTS, and
*   @FT_OUTLINE_INCLUDE_STUBS in `flags` is then overridden.
*/
FT_Outline :: FT_Outline_;

/**************************************************************************
*
* @functype:
*   FT_Outline_MoveToFunc
*
* @description:
*   A function pointer type used to describe the signature of a 'move to'
*   function during outline walking/decomposition.
*
*   A 'move to' is emitted to start a new contour in an outline.
*
* @input:
*   to ::
*     A pointer to the target point of the 'move to'.
*
*   user ::
*     A typeless pointer, which is passed from the caller of the
*     decomposition function.
*
* @return:
*   Error code.  0~means success.
*/
FT_Outline_MoveToFunc :: #type (to: *FT_Vector, user: *void) -> s32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Outline_LineToFunc
*
* @description:
*   A function pointer type used to describe the signature of a 'line to'
*   function during outline walking/decomposition.
*
*   A 'line to' is emitted to indicate a segment in the outline.
*
* @input:
*   to ::
*     A pointer to the target point of the 'line to'.
*
*   user ::
*     A typeless pointer, which is passed from the caller of the
*     decomposition function.
*
* @return:
*   Error code.  0~means success.
*/
FT_Outline_LineToFunc :: #type (to: *FT_Vector, user: *void) -> s32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Outline_ConicToFunc
*
* @description:
*   A function pointer type used to describe the signature of a 'conic to'
*   function during outline walking or decomposition.
*
*   A 'conic to' is emitted to indicate a second-order Bezier arc in the
*   outline.
*
* @input:
*   control ::
*     An intermediate control point between the last position and the new
*     target in `to`.
*
*   to ::
*     A pointer to the target end point of the conic arc.
*
*   user ::
*     A typeless pointer, which is passed from the caller of the
*     decomposition function.
*
* @return:
*   Error code.  0~means success.
*/
FT_Outline_ConicToFunc :: #type (control: *FT_Vector, to: *FT_Vector, user: *void) -> s32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Outline_CubicToFunc
*
* @description:
*   A function pointer type used to describe the signature of a 'cubic to'
*   function during outline walking or decomposition.
*
*   A 'cubic to' is emitted to indicate a third-order Bezier arc.
*
* @input:
*   control1 ::
*     A pointer to the first Bezier control point.
*
*   control2 ::
*     A pointer to the second Bezier control point.
*
*   to ::
*     A pointer to the target end point.
*
*   user ::
*     A typeless pointer, which is passed from the caller of the
*     decomposition function.
*
* @return:
*   Error code.  0~means success.
*/
FT_Outline_CubicToFunc :: #type (control1: *FT_Vector, control2: *FT_Vector, to: *FT_Vector, user: *void) -> s32 #c_call;

/**************************************************************************
*
* @struct:
*   FT_Outline_Funcs
*
* @description:
*   A structure to hold various function pointers used during outline
*   decomposition in order to emit segments, conic, and cubic Beziers.
*
* @fields:
*   move_to ::
*     The 'move to' emitter.
*
*   line_to ::
*     The segment emitter.
*
*   conic_to ::
*     The second-order Bezier arc emitter.
*
*   cubic_to ::
*     The third-order Bezier arc emitter.
*
*   shift ::
*     The shift that is applied to coordinates before they are sent to the
*     emitter.
*
*   delta ::
*     The delta that is applied to coordinates before they are sent to the
*     emitter, but after the shift.
*
* @note:
*   The point coordinates sent to the emitters are the transformed version
*   of the original coordinates (this is important for high accuracy
*   during scan-conversion).  The transformation is simple:
*
*   ```
*     x' = (x << shift) - delta
*     y' = (y << shift) - delta
*   ```
*
*   Set the values of `shift` and `delta` to~0 to get the original point
*   coordinates.
*/
FT_Outline_Funcs_ :: struct {
    move_to:  FT_Outline_MoveToFunc;
    line_to:  FT_Outline_LineToFunc;
    conic_to: FT_Outline_ConicToFunc;
    cubic_to: FT_Outline_CubicToFunc;

    shift:    s32;
    delta:    FT_Pos;
}

/**************************************************************************
*
* @struct:
*   FT_Outline_Funcs
*
* @description:
*   A structure to hold various function pointers used during outline
*   decomposition in order to emit segments, conic, and cubic Beziers.
*
* @fields:
*   move_to ::
*     The 'move to' emitter.
*
*   line_to ::
*     The segment emitter.
*
*   conic_to ::
*     The second-order Bezier arc emitter.
*
*   cubic_to ::
*     The third-order Bezier arc emitter.
*
*   shift ::
*     The shift that is applied to coordinates before they are sent to the
*     emitter.
*
*   delta ::
*     The delta that is applied to coordinates before they are sent to the
*     emitter, but after the shift.
*
* @note:
*   The point coordinates sent to the emitters are the transformed version
*   of the original coordinates (this is important for high accuracy
*   during scan-conversion).  The transformation is simple:
*
*   ```
*     x' = (x << shift) - delta
*     y' = (y << shift) - delta
*   ```
*
*   Set the values of `shift` and `delta` to~0 to get the original point
*   coordinates.
*/
FT_Outline_Funcs :: FT_Outline_Funcs_;

/**************************************************************************
*
* @enum:
*   FT_Glyph_Format
*
* @description:
*   An enumeration type used to describe the format of a given glyph
*   image.  Note that this version of FreeType only supports two image
*   formats, even though future font drivers will be able to register
*   their own format.
*
* @values:
*   FT_GLYPH_FORMAT_NONE ::
*     The value~0 is reserved.
*
*   FT_GLYPH_FORMAT_COMPOSITE ::
*     The glyph image is a composite of several other images.  This format
*     is _only_ used with @FT_LOAD_NO_RECURSE, and is used to report
*     compound glyphs (like accented characters).
*
*   FT_GLYPH_FORMAT_BITMAP ::
*     The glyph image is a bitmap, and can be described as an @FT_Bitmap.
*     You generally need to access the `bitmap` field of the
*     @FT_GlyphSlotRec structure to read it.
*
*   FT_GLYPH_FORMAT_OUTLINE ::
*     The glyph image is a vectorial outline made of line segments and
*     Bezier arcs; it can be described as an @FT_Outline; you generally
*     want to access the `outline` field of the @FT_GlyphSlotRec structure
*     to read it.
*
*   FT_GLYPH_FORMAT_PLOTTER ::
*     The glyph image is a vectorial path with no inside and outside
*     contours.  Some Type~1 fonts, like those in the Hershey family,
*     contain glyphs in this format.  These are described as @FT_Outline,
*     but FreeType isn't currently capable of rendering them correctly.
*
*   FT_GLYPH_FORMAT_SVG ::
*     [Since 2.12] The glyph is represented by an SVG document in the
*     'SVG~' table.
*/
FT_Glyph_Format_ :: enum s32 {
    NONE      :: 0;

    COMPOSITE :: 1668246896;
    BITMAP    :: 1651078259;
    OUTLINE   :: 1869968492;
    PLOTTER   :: 1886154612;
    SVG       :: 1398163232;

    FT_GLYPH_FORMAT_NONE      :: NONE;

    FT_GLYPH_FORMAT_COMPOSITE :: COMPOSITE;
    FT_GLYPH_FORMAT_BITMAP    :: BITMAP;
    FT_GLYPH_FORMAT_OUTLINE   :: OUTLINE;
    FT_GLYPH_FORMAT_PLOTTER   :: PLOTTER;
    FT_GLYPH_FORMAT_SVG       :: SVG;
}

/**************************************************************************
*
* @enum:
*   FT_Glyph_Format
*
* @description:
*   An enumeration type used to describe the format of a given glyph
*   image.  Note that this version of FreeType only supports two image
*   formats, even though future font drivers will be able to register
*   their own format.
*
* @values:
*   FT_GLYPH_FORMAT_NONE ::
*     The value~0 is reserved.
*
*   FT_GLYPH_FORMAT_COMPOSITE ::
*     The glyph image is a composite of several other images.  This format
*     is _only_ used with @FT_LOAD_NO_RECURSE, and is used to report
*     compound glyphs (like accented characters).
*
*   FT_GLYPH_FORMAT_BITMAP ::
*     The glyph image is a bitmap, and can be described as an @FT_Bitmap.
*     You generally need to access the `bitmap` field of the
*     @FT_GlyphSlotRec structure to read it.
*
*   FT_GLYPH_FORMAT_OUTLINE ::
*     The glyph image is a vectorial outline made of line segments and
*     Bezier arcs; it can be described as an @FT_Outline; you generally
*     want to access the `outline` field of the @FT_GlyphSlotRec structure
*     to read it.
*
*   FT_GLYPH_FORMAT_PLOTTER ::
*     The glyph image is a vectorial path with no inside and outside
*     contours.  Some Type~1 fonts, like those in the Hershey family,
*     contain glyphs in this format.  These are described as @FT_Outline,
*     but FreeType isn't currently capable of rendering them correctly.
*
*   FT_GLYPH_FORMAT_SVG ::
*     [Since 2.12] The glyph is represented by an SVG document in the
*     'SVG~' table.
*/
FT_Glyph_Format :: FT_Glyph_Format_;

/**************************************************************************
*
* @struct:
*   FT_Span
*
* @description:
*   A structure to model a single span of consecutive pixels when
*   rendering an anti-aliased bitmap.
*
* @fields:
*   x ::
*     The span's horizontal start position.
*
*   len ::
*     The span's length in pixels.
*
*   coverage ::
*     The span color/coverage, ranging from 0 (background) to 255
*     (foreground).
*
* @note:
*   This structure is used by the span drawing callback type named
*   @FT_SpanFunc that takes the y~coordinate of the span as a parameter.
*
*   The anti-aliased rasterizer produces coverage values from 0 to 255,
*   that is, from completely transparent to completely opaque.
*/
FT_Span_ :: struct {
    x:        u16;
    len:      u16;
    coverage: u8;
}

/**************************************************************************
*
* @struct:
*   FT_Span
*
* @description:
*   A structure to model a single span of consecutive pixels when
*   rendering an anti-aliased bitmap.
*
* @fields:
*   x ::
*     The span's horizontal start position.
*
*   len ::
*     The span's length in pixels.
*
*   coverage ::
*     The span color/coverage, ranging from 0 (background) to 255
*     (foreground).
*
* @note:
*   This structure is used by the span drawing callback type named
*   @FT_SpanFunc that takes the y~coordinate of the span as a parameter.
*
*   The anti-aliased rasterizer produces coverage values from 0 to 255,
*   that is, from completely transparent to completely opaque.
*/
FT_Span :: FT_Span_;

/**************************************************************************
*
* @functype:
*   FT_SpanFunc
*
* @description:
*   A function used as a call-back by the anti-aliased renderer in order
*   to let client applications draw themselves the pixel spans on each
*   scan line.
*
* @input:
*   y ::
*     The scanline's upward y~coordinate.
*
*   count ::
*     The number of spans to draw on this scanline.
*
*   spans ::
*     A table of `count` spans to draw on the scanline.
*
*   user ::
*     User-supplied data that is passed to the callback.
*
* @note:
*   This callback allows client applications to directly render the spans
*   of the anti-aliased bitmap to any kind of surfaces.
*
*   This can be used to write anti-aliased outlines directly to a given
*   background bitmap using alpha compositing.  It can also be used for
*   oversampling and averaging.
*/
FT_SpanFunc :: #type (y: s32, count: s32, spans: *FT_Span, user: *void) -> void #c_call;

/**************************************************************************
*
* @functype:
*   FT_Raster_BitTest_Func
*
* @description:
*   Deprecated, unimplemented.
*/
FT_Raster_BitTest_Func :: #type (y: s32, x: s32, user: *void) -> s32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Raster_BitSet_Func
*
* @description:
*   Deprecated, unimplemented.
*/
FT_Raster_BitSet_Func :: #type (y: s32, x: s32, user: *void) -> void #c_call;

/**************************************************************************
*
* @struct:
*   FT_Raster_Params
*
* @description:
*   A structure to hold the parameters used by a raster's render function,
*   passed as an argument to @FT_Outline_Render.
*
* @fields:
*   target ::
*     The target bitmap.
*
*   source ::
*     A pointer to the source glyph image (e.g., an @FT_Outline).
*
*   flags ::
*     The rendering flags.
*
*   gray_spans ::
*     The gray span drawing callback.
*
*   black_spans ::
*     Unused.
*
*   bit_test ::
*     Unused.
*
*   bit_set ::
*     Unused.
*
*   user ::
*     User-supplied data that is passed to each drawing callback.
*
*   clip_box ::
*     An optional span clipping box expressed in _integer_ pixels
*     (not in 26.6 fixed-point units).
*
* @note:
*   The @FT_RASTER_FLAG_AA bit flag must be set in the `flags` to
*   generate an anti-aliased glyph bitmap, otherwise a monochrome bitmap
*   is generated.  The `target` should have appropriate pixel mode and its
*   dimensions define the clipping region.
*
*   If both @FT_RASTER_FLAG_AA and @FT_RASTER_FLAG_DIRECT bit flags
*   are set in `flags`, the raster calls an @FT_SpanFunc callback
*   `gray_spans` with `user` data as an argument ignoring `target`.  This
*   allows direct composition over a pre-existing user surface to perform
*   the span drawing and composition.  To optionally clip the spans, set
*   the @FT_RASTER_FLAG_CLIP flag and `clip_box`.  The monochrome raster
*   does not support the direct mode.
*
*   The gray-level rasterizer always uses 256 gray levels.  If you want
*   fewer gray levels, you have to use @FT_RASTER_FLAG_DIRECT and reduce
*   the levels in the callback function.
*/
FT_Raster_Params_ :: struct {
    target:      *FT_Bitmap;
    source:      *void;
    flags:       s32;
    gray_spans:  FT_SpanFunc;
    black_spans: FT_SpanFunc; /* unused */
    bit_test:    FT_Raster_BitTest_Func; /* unused */
    bit_set:     FT_Raster_BitSet_Func; /* unused */
    user:        *void;
    clip_box:    FT_BBox;
}

/**************************************************************************
*
* @struct:
*   FT_Raster_Params
*
* @description:
*   A structure to hold the parameters used by a raster's render function,
*   passed as an argument to @FT_Outline_Render.
*
* @fields:
*   target ::
*     The target bitmap.
*
*   source ::
*     A pointer to the source glyph image (e.g., an @FT_Outline).
*
*   flags ::
*     The rendering flags.
*
*   gray_spans ::
*     The gray span drawing callback.
*
*   black_spans ::
*     Unused.
*
*   bit_test ::
*     Unused.
*
*   bit_set ::
*     Unused.
*
*   user ::
*     User-supplied data that is passed to each drawing callback.
*
*   clip_box ::
*     An optional span clipping box expressed in _integer_ pixels
*     (not in 26.6 fixed-point units).
*
* @note:
*   The @FT_RASTER_FLAG_AA bit flag must be set in the `flags` to
*   generate an anti-aliased glyph bitmap, otherwise a monochrome bitmap
*   is generated.  The `target` should have appropriate pixel mode and its
*   dimensions define the clipping region.
*
*   If both @FT_RASTER_FLAG_AA and @FT_RASTER_FLAG_DIRECT bit flags
*   are set in `flags`, the raster calls an @FT_SpanFunc callback
*   `gray_spans` with `user` data as an argument ignoring `target`.  This
*   allows direct composition over a pre-existing user surface to perform
*   the span drawing and composition.  To optionally clip the spans, set
*   the @FT_RASTER_FLAG_CLIP flag and `clip_box`.  The monochrome raster
*   does not support the direct mode.
*
*   The gray-level rasterizer always uses 256 gray levels.  If you want
*   fewer gray levels, you have to use @FT_RASTER_FLAG_DIRECT and reduce
*   the levels in the callback function.
*/
FT_Raster_Params :: FT_Raster_Params_;

FT_RasterRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Raster
*
* @description:
*   An opaque handle (pointer) to a raster object.  Each object can be
*   used independently to convert an outline into a bitmap or pixmap.
*
* @note:
*   In FreeType 2, all rasters are now encapsulated within specific
*   @FT_Renderer modules and only used in their context.
*
*/
FT_Raster :: *FT_RasterRec_;

/**************************************************************************
*
* @functype:
*   FT_Raster_NewFunc
*
* @description:
*   A function used to create a new raster object.
*
* @input:
*   memory ::
*     A handle to the memory allocator.
*
* @output:
*   raster ::
*     A handle to the new raster object.
*
* @return:
*   Error code.  0~means success.
*
* @note:
*   The `memory` parameter is a typeless pointer in order to avoid
*   un-wanted dependencies on the rest of the FreeType code.  In practice,
*   it is an @FT_Memory object, i.e., a handle to the standard FreeType
*   memory allocator.  However, this field can be completely ignored by a
*   given raster implementation.
*/
FT_Raster_NewFunc :: #type (memory: *void, raster: *FT_Raster) -> s32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Raster_DoneFunc
*
* @description:
*   A function used to destroy a given raster object.
*
* @input:
*   raster ::
*     A handle to the raster object.
*/
FT_Raster_DoneFunc :: #type (raster: FT_Raster) -> void #c_call;

/**************************************************************************
*
* @functype:
*   FT_Raster_ResetFunc
*
* @description:
*   FreeType used to provide an area of memory called the 'render pool'
*   available to all registered rasterizers.  This was not thread safe,
*   however, and now FreeType never allocates this pool.
*
*   This function is called after a new raster object is created.
*
* @input:
*   raster ::
*     A handle to the new raster object.
*
*   pool_base ::
*     Previously, the address in memory of the render pool.  Set this to
*     `NULL`.
*
*   pool_size ::
*     Previously, the size in bytes of the render pool.  Set this to 0.
*
* @note:
*   Rasterizers should rely on dynamic or stack allocation if they want to
*   (a handle to the memory allocator is passed to the rasterizer
*   constructor).
*/
FT_Raster_ResetFunc :: #type (raster: FT_Raster, pool_base: *u8, pool_size: u32) -> void #c_call;

/**************************************************************************
*
* @functype:
*   FT_Raster_SetModeFunc
*
* @description:
*   This function is a generic facility to change modes or attributes in a
*   given raster.  This can be used for debugging purposes, or simply to
*   allow implementation-specific 'features' in a given raster module.
*
* @input:
*   raster ::
*     A handle to the new raster object.
*
*   mode ::
*     A 4-byte tag used to name the mode or property.
*
*   args ::
*     A pointer to the new mode/property to use.
*/
FT_Raster_SetModeFunc :: #type (raster: FT_Raster, mode: u32, args: *void) -> s32 #c_call;

/**************************************************************************
*
* @functype:
*   FT_Raster_RenderFunc
*
* @description:
*   Invoke a given raster to scan-convert a given glyph image into a
*   target bitmap.
*
* @input:
*   raster ::
*     A handle to the raster object.
*
*   params ::
*     A pointer to an @FT_Raster_Params structure used to store the
*     rendering parameters.
*
* @return:
*   Error code.  0~means success.
*
* @note:
*   The exact format of the source image depends on the raster's glyph
*   format defined in its @FT_Raster_Funcs structure.  It can be an
*   @FT_Outline or anything else in order to support a large array of
*   glyph formats.
*
*   Note also that the render function can fail and return a
*   `FT_Err_Unimplemented_Feature` error code if the raster used does not
*   support direct composition.
*/
FT_Raster_RenderFunc :: #type (raster: FT_Raster, params: *FT_Raster_Params) -> s32 #c_call;

/**************************************************************************
*
* @struct:
*   FT_Raster_Funcs
*
* @description:
*  A structure used to describe a given raster class to the library.
*
* @fields:
*   glyph_format ::
*     The supported glyph format for this raster.
*
*   raster_new ::
*     The raster constructor.
*
*   raster_reset ::
*     Used to reset the render pool within the raster.
*
*   raster_render ::
*     A function to render a glyph into a given bitmap.
*
*   raster_done ::
*     The raster destructor.
*/
FT_Raster_Funcs_ :: struct {
    glyph_format:    FT_Glyph_Format;

    raster_new:      FT_Raster_NewFunc;
    raster_reset:    FT_Raster_ResetFunc;
    raster_set_mode: FT_Raster_SetModeFunc;
    raster_render:   FT_Raster_RenderFunc;
    raster_done:     FT_Raster_DoneFunc;
}

/**************************************************************************
*
* @struct:
*   FT_Raster_Funcs
*
* @description:
*  A structure used to describe a given raster class to the library.
*
* @fields:
*   glyph_format ::
*     The supported glyph format for this raster.
*
*   raster_new ::
*     The raster constructor.
*
*   raster_reset ::
*     Used to reset the render pool within the raster.
*
*   raster_render ::
*     A function to render a glyph into a given bitmap.
*
*   raster_done ::
*     The raster destructor.
*/
FT_Raster_Funcs :: FT_Raster_Funcs_;

/**************************************************************************
*
* @type:
*   FT_Bool
*
* @description:
*   A typedef of unsigned char, used for simple booleans.  As usual,
*   values 1 and~0 represent true and false, respectively.
*/
FT_Bool :: u8;

/**************************************************************************
*
* @type:
*   FT_FWord
*
* @description:
*   A signed 16-bit integer used to store a distance in original font
*   units.
*/
FT_FWord :: s16;

/**************************************************************************
*
* @type:
*   FT_UFWord
*
* @description:
*   An unsigned 16-bit integer used to store a distance in original font
*   units.
*/
FT_UFWord :: u16;

/**************************************************************************
*
* @type:
*   FT_Char
*
* @description:
*   A simple typedef for the _signed_ char type.
*/
FT_Char :: s8;

/**************************************************************************
*
* @type:
*   FT_Byte
*
* @description:
*   A simple typedef for the _unsigned_ char type.
*/
FT_Byte :: u8;

/**************************************************************************
*
* @type:
*   FT_Bytes
*
* @description:
*   A typedef for constant memory areas.
*/
FT_Bytes :: *FT_Byte;

/**************************************************************************
*
* @type:
*   FT_Tag
*
* @description:
*   A typedef for 32-bit tags (as used in the SFNT format).
*/
FT_Tag :: FT_UInt32;

/**************************************************************************
*
* @type:
*   FT_String
*
* @description:
*   A simple typedef for the char type, usually used for strings.
*/
FT_String :: u8;

/**************************************************************************
*
* @type:
*   FT_Short
*
* @description:
*   A typedef for signed short.
*/
FT_Short :: s16;

/**************************************************************************
*
* @type:
*   FT_UShort
*
* @description:
*   A typedef for unsigned short.
*/
FT_UShort :: u16;

/**************************************************************************
*
* @type:
*   FT_Int
*
* @description:
*   A typedef for the int type.
*/
FT_Int :: s32;

/**************************************************************************
*
* @type:
*   FT_UInt
*
* @description:
*   A typedef for the unsigned int type.
*/
FT_UInt :: u32;

/**************************************************************************
*
* @type:
*   FT_Long
*
* @description:
*   A typedef for signed long.
*/
FT_Long :: s32;

/**************************************************************************
*
* @type:
*   FT_ULong
*
* @description:
*   A typedef for unsigned long.
*/
FT_ULong :: u32;

/**************************************************************************
*
* @type:
*   FT_F2Dot14
*
* @description:
*   A signed 2.14 fixed-point type used for unit vectors.
*/
FT_F2Dot14 :: s16;

/**************************************************************************
*
* @type:
*   FT_F26Dot6
*
* @description:
*   A signed 26.6 fixed-point type used for vectorial pixel coordinates.
*/
FT_F26Dot6 :: s32;

/**************************************************************************
*
* @type:
*   FT_Fixed
*
* @description:
*   This type is used to store 16.16 fixed-point values, like scaling
*   values or matrix coefficients.
*/
FT_Fixed :: s32;

/**************************************************************************
*
* @type:
*   FT_Error
*
* @description:
*   The FreeType error code type.  A value of~0 is always interpreted as a
*   successful operation.
*/
FT_Error :: s32;

/**************************************************************************
*
* @type:
*   FT_Pointer
*
* @description:
*   A simple typedef for a typeless pointer.
*/
FT_Pointer :: *void;

/**************************************************************************
*
* @type:
*   FT_Offset
*
* @description:
*   This is equivalent to the ANSI~C `size_t` type, i.e., the largest
*   _unsigned_ integer type used to express a file size or position, or a
*   memory block size.
*/
FT_Offset :: u64;

/**************************************************************************
*
* @type:
*   FT_PtrDist
*
* @description:
*   This is equivalent to the ANSI~C `ptrdiff_t` type, i.e., the largest
*   _signed_ integer type used to express the distance between two
*   pointers.
*/
FT_PtrDist :: ptrdiff_t;

/**************************************************************************
*
* @struct:
*   FT_UnitVector
*
* @description:
*   A simple structure used to store a 2D vector unit vector.  Uses
*   FT_F2Dot14 types.
*
* @fields:
*   x ::
*     Horizontal coordinate.
*
*   y ::
*     Vertical coordinate.
*/
FT_UnitVector_ :: struct {
    x: FT_F2Dot14;
    y: FT_F2Dot14;
}

/**************************************************************************
*
* @struct:
*   FT_UnitVector
*
* @description:
*   A simple structure used to store a 2D vector unit vector.  Uses
*   FT_F2Dot14 types.
*
* @fields:
*   x ::
*     Horizontal coordinate.
*
*   y ::
*     Vertical coordinate.
*/
FT_UnitVector :: FT_UnitVector_;

/**************************************************************************
*
* @struct:
*   FT_Matrix
*
* @description:
*   A simple structure used to store a 2x2 matrix.  Coefficients are in
*   16.16 fixed-point format.  The computation performed is:
*
*   ```
*     x' = x*xx + y*xy
*     y' = x*yx + y*yy
*   ```
*
* @fields:
*   xx ::
*     Matrix coefficient.
*
*   xy ::
*     Matrix coefficient.
*
*   yx ::
*     Matrix coefficient.
*
*   yy ::
*     Matrix coefficient.
*/
FT_Matrix_ :: struct {
    _xx: FT_Fixed;
    xy:  FT_Fixed;
    yx:  FT_Fixed;
    yy:  FT_Fixed;
}

/**************************************************************************
*
* @struct:
*   FT_Matrix
*
* @description:
*   A simple structure used to store a 2x2 matrix.  Coefficients are in
*   16.16 fixed-point format.  The computation performed is:
*
*   ```
*     x' = x*xx + y*xy
*     y' = x*yx + y*yy
*   ```
*
* @fields:
*   xx ::
*     Matrix coefficient.
*
*   xy ::
*     Matrix coefficient.
*
*   yx ::
*     Matrix coefficient.
*
*   yy ::
*     Matrix coefficient.
*/
FT_Matrix :: FT_Matrix_;

/**************************************************************************
*
* @struct:
*   FT_Data
*
* @description:
*   Read-only binary data represented as a pointer and a length.
*
* @fields:
*   pointer ::
*     The data.
*
*   length ::
*     The length of the data in bytes.
*/
FT_Data_ :: struct {
    pointer: *FT_Byte;
    length:  FT_UInt;
}

/**************************************************************************
*
* @struct:
*   FT_Data
*
* @description:
*   Read-only binary data represented as a pointer and a length.
*
* @fields:
*   pointer ::
*     The data.
*
*   length ::
*     The length of the data in bytes.
*/
FT_Data :: FT_Data_;

/**************************************************************************
*
* @functype:
*   FT_Generic_Finalizer
*
* @description:
*   Describe a function used to destroy the 'client' data of any FreeType
*   object.  See the description of the @FT_Generic type for details of
*   usage.
*
* @input:
*   The address of the FreeType object that is under finalization.  Its
*   client data is accessed through its `generic` field.
*/
FT_Generic_Finalizer :: #type (object: *void) -> void #c_call;

/**************************************************************************
*
* @struct:
*   FT_Generic
*
* @description:
*   Client applications often need to associate their own data to a
*   variety of FreeType core objects.  For example, a text layout API
*   might want to associate a glyph cache to a given size object.
*
*   Some FreeType object contains a `generic` field, of type `FT_Generic`,
*   which usage is left to client applications and font servers.
*
*   It can be used to store a pointer to client-specific data, as well as
*   the address of a 'finalizer' function, which will be called by
*   FreeType when the object is destroyed (for example, the previous
*   client example would put the address of the glyph cache destructor in
*   the `finalizer` field).
*
* @fields:
*   data ::
*     A typeless pointer to any client-specified data. This field is
*     completely ignored by the FreeType library.
*
*   finalizer ::
*     A pointer to a 'generic finalizer' function, which will be called
*     when the object is destroyed.  If this field is set to `NULL`, no
*     code will be called.
*/
FT_Generic_ :: struct {
    data:      *void;
    finalizer: FT_Generic_Finalizer;
}

/**************************************************************************
*
* @struct:
*   FT_Generic
*
* @description:
*   Client applications often need to associate their own data to a
*   variety of FreeType core objects.  For example, a text layout API
*   might want to associate a glyph cache to a given size object.
*
*   Some FreeType object contains a `generic` field, of type `FT_Generic`,
*   which usage is left to client applications and font servers.
*
*   It can be used to store a pointer to client-specific data, as well as
*   the address of a 'finalizer' function, which will be called by
*   FreeType when the object is destroyed (for example, the previous
*   client example would put the address of the glyph cache destructor in
*   the `finalizer` field).
*
* @fields:
*   data ::
*     A typeless pointer to any client-specified data. This field is
*     completely ignored by the FreeType library.
*
*   finalizer ::
*     A pointer to a 'generic finalizer' function, which will be called
*     when the object is destroyed.  If this field is set to `NULL`, no
*     code will be called.
*/
FT_Generic :: FT_Generic_;

/**************************************************************************
*
* @type:
*   FT_ListNode
*
* @description:
*    Many elements and objects in FreeType are listed through an @FT_List
*    record (see @FT_ListRec).  As its name suggests, an FT_ListNode is a
*    handle to a single list element.
*/
FT_ListNode :: *FT_ListNodeRec_;

/**************************************************************************
*
* @type:
*   FT_List
*
* @description:
*   A handle to a list record (see @FT_ListRec).
*/
FT_List :: *FT_ListRec_;

/**************************************************************************
*
* @struct:
*   FT_ListNodeRec
*
* @description:
*   A structure used to hold a single list element.
*
* @fields:
*   prev ::
*     The previous element in the list.  `NULL` if first.
*
*   next ::
*     The next element in the list.  `NULL` if last.
*
*   data ::
*     A typeless pointer to the listed object.
*/
FT_ListNodeRec_ :: struct {
    prev: FT_ListNode;
    next: FT_ListNode;
    data: *void;
}

/**************************************************************************
*
* @struct:
*   FT_ListNodeRec
*
* @description:
*   A structure used to hold a single list element.
*
* @fields:
*   prev ::
*     The previous element in the list.  `NULL` if first.
*
*   next ::
*     The next element in the list.  `NULL` if last.
*
*   data ::
*     A typeless pointer to the listed object.
*/
FT_ListNodeRec :: FT_ListNodeRec_;

/**************************************************************************
*
* @struct:
*   FT_ListRec
*
* @description:
*   A structure used to hold a simple doubly-linked list.  These are used
*   in many parts of FreeType.
*
* @fields:
*   head ::
*     The head (first element) of doubly-linked list.
*
*   tail ::
*     The tail (last element) of doubly-linked list.
*/
FT_ListRec_ :: struct {
    head: FT_ListNode;
    tail: FT_ListNode;
}

/**************************************************************************
*
* @struct:
*   FT_ListRec
*
* @description:
*   A structure used to hold a simple doubly-linked list.  These are used
*   in many parts of FreeType.
*
* @fields:
*   head ::
*     The head (first element) of doubly-linked list.
*
*   tail ::
*     The tail (last element) of doubly-linked list.
*/
FT_ListRec :: FT_ListRec_;

FT_Mod_Err :: enum s32 {
    Base     :: 0;
    Autofit  :: 0;
    BDF      :: 0;
    Bzip2    :: 0;
    Cache    :: 0;
    CFF      :: 0;
    CID      :: 0;
    Gzip     :: 0;
    LZW      :: 0;
    OTvalid  :: 0;
    PCF      :: 0;
    PFR      :: 0;
    PSaux    :: 0;
    PShinter :: 0;
    PSnames  :: 0;
    Raster   :: 0;
    SFNT     :: 0;
    Smooth   :: 0;
    TrueType :: 0;
    Type1    :: 0;
    Type42   :: 0;
    Winfonts :: 0;
    GXvalid  :: 0;
    Sdf      :: 0;

    Max      :: 1;

    FT_Mod_Err_Base     :: Base;
    FT_Mod_Err_Autofit  :: Autofit;
    FT_Mod_Err_BDF      :: BDF;
    FT_Mod_Err_Bzip2    :: Bzip2;
    FT_Mod_Err_Cache    :: Cache;
    FT_Mod_Err_CFF      :: CFF;
    FT_Mod_Err_CID      :: CID;
    FT_Mod_Err_Gzip     :: Gzip;
    FT_Mod_Err_LZW      :: LZW;
    FT_Mod_Err_OTvalid  :: OTvalid;
    FT_Mod_Err_PCF      :: PCF;
    FT_Mod_Err_PFR      :: PFR;
    FT_Mod_Err_PSaux    :: PSaux;
    FT_Mod_Err_PShinter :: PShinter;
    FT_Mod_Err_PSnames  :: PSnames;
    FT_Mod_Err_Raster   :: Raster;
    FT_Mod_Err_SFNT     :: SFNT;
    FT_Mod_Err_Smooth   :: Smooth;
    FT_Mod_Err_TrueType :: TrueType;
    FT_Mod_Err_Type1    :: Type1;
    FT_Mod_Err_Type42   :: Type42;
    FT_Mod_Err_Winfonts :: Winfonts;
    FT_Mod_Err_GXvalid  :: GXvalid;
    FT_Mod_Err_Sdf      :: Sdf;

    FT_Mod_Err_Max      :: Max;
}

FT_Err :: enum s32 {
    Ok                            :: 0;

    Cannot_Open_Resource          :: 1;

    Unknown_File_Format           :: 2;

    Invalid_File_Format           :: 3;

    Invalid_Version               :: 4;

    Lower_Module_Version          :: 5;

    Invalid_Argument              :: 6;

    Unimplemented_Feature         :: 7;

    Invalid_Table                 :: 8;

    Invalid_Offset                :: 9;

    Array_Too_Large               :: 10;

    Missing_Module                :: 11;

    Missing_Property              :: 12;

    Invalid_Glyph_Index           :: 16;

    Invalid_Character_Code        :: 17;

    Invalid_Glyph_Format          :: 18;

    Cannot_Render_Glyph           :: 19;

    Invalid_Outline               :: 20;

    Invalid_Composite             :: 21;

    Too_Many_Hints                :: 22;

    Invalid_Pixel_Size            :: 23;

    Invalid_SVG_Document          :: 24;

    Invalid_Handle                :: 32;

    Invalid_Library_Handle        :: 33;

    Invalid_Driver_Handle         :: 34;

    Invalid_Face_Handle           :: 35;

    Invalid_Size_Handle           :: 36;

    Invalid_Slot_Handle           :: 37;

    Invalid_CharMap_Handle        :: 38;

    Invalid_Cache_Handle          :: 39;

    Invalid_Stream_Handle         :: 40;

    Too_Many_Drivers              :: 48;

    Too_Many_Extensions           :: 49;

    Out_Of_Memory                 :: 64;

    Unlisted_Object               :: 65;

    Cannot_Open_Stream            :: 81;

    Invalid_Stream_Seek           :: 82;

    Invalid_Stream_Skip           :: 83;

    Invalid_Stream_Read           :: 84;

    Invalid_Stream_Operation      :: 85;

    Invalid_Frame_Operation       :: 86;

    Nested_Frame_Access           :: 87;

    Invalid_Frame_Read            :: 88;

    Raster_Uninitialized          :: 96;

    Raster_Corrupted              :: 97;

    Raster_Overflow               :: 98;

    Raster_Negative_Height        :: 99;

    Too_Many_Caches               :: 112;

    Invalid_Opcode                :: 128;

    Too_Few_Arguments             :: 129;

    Stack_Overflow                :: 130;

    Code_Overflow                 :: 131;

    Bad_Argument                  :: 132;

    Divide_By_Zero                :: 133;

    Invalid_Reference             :: 134;

    Debug_OpCode                  :: 135;

    ENDF_In_Exec_Stream           :: 136;

    Nested_DEFS                   :: 137;

    Invalid_CodeRange             :: 138;

    Execution_Too_Long            :: 139;

    Too_Many_Function_Defs        :: 140;

    Too_Many_Instruction_Defs     :: 141;

    Table_Missing                 :: 142;

    Horiz_Header_Missing          :: 143;

    Locations_Missing             :: 144;

    Name_Table_Missing            :: 145;

    CMap_Table_Missing            :: 146;

    Hmtx_Table_Missing            :: 147;

    Post_Table_Missing            :: 148;

    Invalid_Horiz_Metrics         :: 149;

    Invalid_CharMap_Format        :: 150;

    Invalid_PPem                  :: 151;

    Invalid_Vert_Metrics          :: 152;

    Could_Not_Find_Context        :: 153;

    Invalid_Post_Table_Format     :: 154;

    Invalid_Post_Table            :: 155;

    DEF_In_Glyf_Bytecode          :: 156;

    Missing_Bitmap                :: 157;

    Missing_SVG_Hooks             :: 158;

    Syntax_Error                  :: 160;

    Stack_Underflow               :: 161;

    Ignore                        :: 162;

    No_Unicode_Glyph_Name         :: 163;

    Glyph_Too_Big                 :: 164;

    Missing_Startfont_Field       :: 176;

    Missing_Font_Field            :: 177;

    Missing_Size_Field            :: 178;

    Missing_Fontboundingbox_Field :: 179;

    Missing_Chars_Field           :: 180;

    Missing_Startchar_Field       :: 181;

    Missing_Encoding_Field        :: 182;

    Missing_Bbx_Field             :: 183;

    Bbx_Too_Big                   :: 184;

    Corrupted_Font_Header         :: 185;

    Corrupted_Font_Glyphs         :: 186;

    Max                           :: 187;

    FT_Err_Ok                            :: Ok;

    FT_Err_Cannot_Open_Resource          :: Cannot_Open_Resource;

    FT_Err_Unknown_File_Format           :: Unknown_File_Format;

    FT_Err_Invalid_File_Format           :: Invalid_File_Format;

    FT_Err_Invalid_Version               :: Invalid_Version;

    FT_Err_Lower_Module_Version          :: Lower_Module_Version;

    FT_Err_Invalid_Argument              :: Invalid_Argument;

    FT_Err_Unimplemented_Feature         :: Unimplemented_Feature;

    FT_Err_Invalid_Table                 :: Invalid_Table;

    FT_Err_Invalid_Offset                :: Invalid_Offset;

    FT_Err_Array_Too_Large               :: Array_Too_Large;

    FT_Err_Missing_Module                :: Missing_Module;

    FT_Err_Missing_Property              :: Missing_Property;

    FT_Err_Invalid_Glyph_Index           :: Invalid_Glyph_Index;

    FT_Err_Invalid_Character_Code        :: Invalid_Character_Code;

    FT_Err_Invalid_Glyph_Format          :: Invalid_Glyph_Format;

    FT_Err_Cannot_Render_Glyph           :: Cannot_Render_Glyph;

    FT_Err_Invalid_Outline               :: Invalid_Outline;

    FT_Err_Invalid_Composite             :: Invalid_Composite;

    FT_Err_Too_Many_Hints                :: Too_Many_Hints;

    FT_Err_Invalid_Pixel_Size            :: Invalid_Pixel_Size;

    FT_Err_Invalid_SVG_Document          :: Invalid_SVG_Document;

    FT_Err_Invalid_Handle                :: Invalid_Handle;

    FT_Err_Invalid_Library_Handle        :: Invalid_Library_Handle;

    FT_Err_Invalid_Driver_Handle         :: Invalid_Driver_Handle;

    FT_Err_Invalid_Face_Handle           :: Invalid_Face_Handle;

    FT_Err_Invalid_Size_Handle           :: Invalid_Size_Handle;

    FT_Err_Invalid_Slot_Handle           :: Invalid_Slot_Handle;

    FT_Err_Invalid_CharMap_Handle        :: Invalid_CharMap_Handle;

    FT_Err_Invalid_Cache_Handle          :: Invalid_Cache_Handle;

    FT_Err_Invalid_Stream_Handle         :: Invalid_Stream_Handle;

    FT_Err_Too_Many_Drivers              :: Too_Many_Drivers;

    FT_Err_Too_Many_Extensions           :: Too_Many_Extensions;

    FT_Err_Out_Of_Memory                 :: Out_Of_Memory;

    FT_Err_Unlisted_Object               :: Unlisted_Object;

    FT_Err_Cannot_Open_Stream            :: Cannot_Open_Stream;

    FT_Err_Invalid_Stream_Seek           :: Invalid_Stream_Seek;

    FT_Err_Invalid_Stream_Skip           :: Invalid_Stream_Skip;

    FT_Err_Invalid_Stream_Read           :: Invalid_Stream_Read;

    FT_Err_Invalid_Stream_Operation      :: Invalid_Stream_Operation;

    FT_Err_Invalid_Frame_Operation       :: Invalid_Frame_Operation;

    FT_Err_Nested_Frame_Access           :: Nested_Frame_Access;

    FT_Err_Invalid_Frame_Read            :: Invalid_Frame_Read;

    FT_Err_Raster_Uninitialized          :: Raster_Uninitialized;

    FT_Err_Raster_Corrupted              :: Raster_Corrupted;

    FT_Err_Raster_Overflow               :: Raster_Overflow;

    FT_Err_Raster_Negative_Height        :: Raster_Negative_Height;

    FT_Err_Too_Many_Caches               :: Too_Many_Caches;

    FT_Err_Invalid_Opcode                :: Invalid_Opcode;

    FT_Err_Too_Few_Arguments             :: Too_Few_Arguments;

    FT_Err_Stack_Overflow                :: Stack_Overflow;

    FT_Err_Code_Overflow                 :: Code_Overflow;

    FT_Err_Bad_Argument                  :: Bad_Argument;

    FT_Err_Divide_By_Zero                :: Divide_By_Zero;

    FT_Err_Invalid_Reference             :: Invalid_Reference;

    FT_Err_Debug_OpCode                  :: Debug_OpCode;

    FT_Err_ENDF_In_Exec_Stream           :: ENDF_In_Exec_Stream;

    FT_Err_Nested_DEFS                   :: Nested_DEFS;

    FT_Err_Invalid_CodeRange             :: Invalid_CodeRange;

    FT_Err_Execution_Too_Long            :: Execution_Too_Long;

    FT_Err_Too_Many_Function_Defs        :: Too_Many_Function_Defs;

    FT_Err_Too_Many_Instruction_Defs     :: Too_Many_Instruction_Defs;

    FT_Err_Table_Missing                 :: Table_Missing;

    FT_Err_Horiz_Header_Missing          :: Horiz_Header_Missing;

    FT_Err_Locations_Missing             :: Locations_Missing;

    FT_Err_Name_Table_Missing            :: Name_Table_Missing;

    FT_Err_CMap_Table_Missing            :: CMap_Table_Missing;

    FT_Err_Hmtx_Table_Missing            :: Hmtx_Table_Missing;

    FT_Err_Post_Table_Missing            :: Post_Table_Missing;

    FT_Err_Invalid_Horiz_Metrics         :: Invalid_Horiz_Metrics;

    FT_Err_Invalid_CharMap_Format        :: Invalid_CharMap_Format;

    FT_Err_Invalid_PPem                  :: Invalid_PPem;

    FT_Err_Invalid_Vert_Metrics          :: Invalid_Vert_Metrics;

    FT_Err_Could_Not_Find_Context        :: Could_Not_Find_Context;

    FT_Err_Invalid_Post_Table_Format     :: Invalid_Post_Table_Format;

    FT_Err_Invalid_Post_Table            :: Invalid_Post_Table;

    FT_Err_DEF_In_Glyf_Bytecode          :: DEF_In_Glyf_Bytecode;

    FT_Err_Missing_Bitmap                :: Missing_Bitmap;

    FT_Err_Missing_SVG_Hooks             :: Missing_SVG_Hooks;

    FT_Err_Syntax_Error                  :: Syntax_Error;

    FT_Err_Stack_Underflow               :: Stack_Underflow;

    FT_Err_Ignore                        :: Ignore;

    FT_Err_No_Unicode_Glyph_Name         :: No_Unicode_Glyph_Name;

    FT_Err_Glyph_Too_Big                 :: Glyph_Too_Big;

    FT_Err_Missing_Startfont_Field       :: Missing_Startfont_Field;

    FT_Err_Missing_Font_Field            :: Missing_Font_Field;

    FT_Err_Missing_Size_Field            :: Missing_Size_Field;

    FT_Err_Missing_Fontboundingbox_Field :: Missing_Fontboundingbox_Field;

    FT_Err_Missing_Chars_Field           :: Missing_Chars_Field;

    FT_Err_Missing_Startchar_Field       :: Missing_Startchar_Field;

    FT_Err_Missing_Encoding_Field        :: Missing_Encoding_Field;

    FT_Err_Missing_Bbx_Field             :: Missing_Bbx_Field;

    FT_Err_Bbx_Too_Big                   :: Bbx_Too_Big;

    FT_Err_Corrupted_Font_Header         :: Corrupted_Font_Header;

    FT_Err_Corrupted_Font_Glyphs         :: Corrupted_Font_Glyphs;

    FT_Err_Max                           :: Max;
}

/**************************************************************************
*
* @function:
*   FT_Error_String
*
* @description:
*   Retrieve the description of a valid FreeType error code.
*
* @input:
*   error_code ::
*     A valid FreeType error code.
*
* @return:
*   A C~string or `NULL`, if any error occurred.
*
* @note:
*   FreeType has to be compiled with `FT_CONFIG_OPTION_ERROR_STRINGS` or
*   `FT_DEBUG_LEVEL_ERROR` to get meaningful descriptions.
*   'error_string' will be `NULL` otherwise.
*
*   Module identification will be ignored:
*
*   ```c
*     strcmp( FT_Error_String(  FT_Err_Unknown_File_Format ),
*             FT_Error_String( BDF_Err_Unknown_File_Format ) ) == 0;
*   ```
*/
FT_Error_String :: (error_code: FT_Error) -> *u8 #foreign freetype;

/**************************************************************************
*
* @struct:
*   FT_Glyph_Metrics
*
* @description:
*   A structure to model the metrics of a single glyph.  The values are
*   expressed in 26.6 fractional pixel format; if the flag
*   @FT_LOAD_NO_SCALE has been used while loading the glyph, values are
*   expressed in font units instead.
*
* @fields:
*   width ::
*     The glyph's width.
*
*   height ::
*     The glyph's height.
*
*   horiBearingX ::
*     Left side bearing for horizontal layout.
*
*   horiBearingY ::
*     Top side bearing for horizontal layout.
*
*   horiAdvance ::
*     Advance width for horizontal layout.
*
*   vertBearingX ::
*     Left side bearing for vertical layout.
*
*   vertBearingY ::
*     Top side bearing for vertical layout.  Larger positive values mean
*     further below the vertical glyph origin.
*
*   vertAdvance ::
*     Advance height for vertical layout.  Positive values mean the glyph
*     has a positive advance downward.
*
* @note:
*   If not disabled with @FT_LOAD_NO_HINTING, the values represent
*   dimensions of the hinted glyph (in case hinting is applicable).
*
*   Stroking a glyph with an outside border does not increase
*   `horiAdvance` or `vertAdvance`; you have to manually adjust these
*   values to account for the added width and height.
*
*   FreeType doesn't use the 'VORG' table data for CFF fonts because it
*   doesn't have an interface to quickly retrieve the glyph height.  The
*   y~coordinate of the vertical origin can be simply computed as
*   `vertBearingY + height` after loading a glyph.
*/
FT_Glyph_Metrics_ :: struct {
    width:        FT_Pos;
    height:       FT_Pos;

    horiBearingX: FT_Pos;
    horiBearingY: FT_Pos;
    horiAdvance:  FT_Pos;

    vertBearingX: FT_Pos;
    vertBearingY: FT_Pos;
    vertAdvance:  FT_Pos;
}

/**************************************************************************
*
* @struct:
*   FT_Glyph_Metrics
*
* @description:
*   A structure to model the metrics of a single glyph.  The values are
*   expressed in 26.6 fractional pixel format; if the flag
*   @FT_LOAD_NO_SCALE has been used while loading the glyph, values are
*   expressed in font units instead.
*
* @fields:
*   width ::
*     The glyph's width.
*
*   height ::
*     The glyph's height.
*
*   horiBearingX ::
*     Left side bearing for horizontal layout.
*
*   horiBearingY ::
*     Top side bearing for horizontal layout.
*
*   horiAdvance ::
*     Advance width for horizontal layout.
*
*   vertBearingX ::
*     Left side bearing for vertical layout.
*
*   vertBearingY ::
*     Top side bearing for vertical layout.  Larger positive values mean
*     further below the vertical glyph origin.
*
*   vertAdvance ::
*     Advance height for vertical layout.  Positive values mean the glyph
*     has a positive advance downward.
*
* @note:
*   If not disabled with @FT_LOAD_NO_HINTING, the values represent
*   dimensions of the hinted glyph (in case hinting is applicable).
*
*   Stroking a glyph with an outside border does not increase
*   `horiAdvance` or `vertAdvance`; you have to manually adjust these
*   values to account for the added width and height.
*
*   FreeType doesn't use the 'VORG' table data for CFF fonts because it
*   doesn't have an interface to quickly retrieve the glyph height.  The
*   y~coordinate of the vertical origin can be simply computed as
*   `vertBearingY + height` after loading a glyph.
*/
FT_Glyph_Metrics :: FT_Glyph_Metrics_;

/**************************************************************************
*
* @struct:
*   FT_Bitmap_Size
*
* @description:
*   This structure models the metrics of a bitmap strike (i.e., a set of
*   glyphs for a given point size and resolution) in a bitmap font.  It is
*   used for the `available_sizes` field of @FT_Face.
*
* @fields:
*   height ::
*     The vertical distance, in pixels, between two consecutive baselines.
*     It is always positive.
*
*   width ::
*     The average width, in pixels, of all glyphs in the strike.
*
*   size ::
*     The nominal size of the strike in 26.6 fractional points.  This
*     field is not very useful.
*
*   x_ppem ::
*     The horizontal ppem (nominal width) in 26.6 fractional pixels.
*
*   y_ppem ::
*     The vertical ppem (nominal height) in 26.6 fractional pixels.
*
* @note:
*   Windows FNT:
*     The nominal size given in a FNT font is not reliable.  If the driver
*     finds it incorrect, it sets `size` to some calculated values, and
*     `x_ppem` and `y_ppem` to the pixel width and height given in the
*     font, respectively.
*
*   TrueType embedded bitmaps:
*     `size`, `width`, and `height` values are not contained in the bitmap
*     strike itself.  They are computed from the global font parameters.
*/
FT_Bitmap_Size_ :: struct {
    height: FT_Short;
    width:  FT_Short;

    size:   FT_Pos;

    x_ppem: FT_Pos;
    y_ppem: FT_Pos;
}

/**************************************************************************
*
* @struct:
*   FT_Bitmap_Size
*
* @description:
*   This structure models the metrics of a bitmap strike (i.e., a set of
*   glyphs for a given point size and resolution) in a bitmap font.  It is
*   used for the `available_sizes` field of @FT_Face.
*
* @fields:
*   height ::
*     The vertical distance, in pixels, between two consecutive baselines.
*     It is always positive.
*
*   width ::
*     The average width, in pixels, of all glyphs in the strike.
*
*   size ::
*     The nominal size of the strike in 26.6 fractional points.  This
*     field is not very useful.
*
*   x_ppem ::
*     The horizontal ppem (nominal width) in 26.6 fractional pixels.
*
*   y_ppem ::
*     The vertical ppem (nominal height) in 26.6 fractional pixels.
*
* @note:
*   Windows FNT:
*     The nominal size given in a FNT font is not reliable.  If the driver
*     finds it incorrect, it sets `size` to some calculated values, and
*     `x_ppem` and `y_ppem` to the pixel width and height given in the
*     font, respectively.
*
*   TrueType embedded bitmaps:
*     `size`, `width`, and `height` values are not contained in the bitmap
*     strike itself.  They are computed from the global font parameters.
*/
FT_Bitmap_Size :: FT_Bitmap_Size_;

FT_LibraryRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Library
*
* @description:
*   A handle to a FreeType library instance.  Each 'library' is completely
*   independent from the others; it is the 'root' of a set of objects like
*   fonts, faces, sizes, etc.
*
*   It also embeds a memory manager (see @FT_Memory), as well as a
*   scan-line converter object (see @FT_Raster).
*
*   [Since 2.5.6] In multi-threaded applications it is easiest to use one
*   `FT_Library` object per thread.  In case this is too cumbersome, a
*   single `FT_Library` object across threads is possible also, as long as
*   a mutex lock is used around @FT_New_Face and @FT_Done_Face.
*
* @note:
*   Library objects are normally created by @FT_Init_FreeType, and
*   destroyed with @FT_Done_FreeType.  If you need reference-counting
*   (cf. @FT_Reference_Library), use @FT_New_Library and @FT_Done_Library.
*/
FT_Library :: *FT_LibraryRec_;

FT_ModuleRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Module
*
* @description:
*   A handle to a given FreeType module object.  A module can be a font
*   driver, a renderer, or anything else that provides services to the
*   former.
*/
FT_Module :: *FT_ModuleRec_;

FT_DriverRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Driver
*
* @description:
*   A handle to a given FreeType font driver object.  A font driver is a
*   module capable of creating faces from font files.
*/
FT_Driver :: *FT_DriverRec_;

FT_RendererRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Renderer
*
* @description:
*   A handle to a given FreeType renderer.  A renderer is a module in
*   charge of converting a glyph's outline image to a bitmap.  It supports
*   a single glyph image format, and one or more target surface depths.
*/
FT_Renderer :: *FT_RendererRec_;

/**************************************************************************
*
* @type:
*   FT_Face
*
* @description:
*   A handle to a typographic face object.  A face object models a given
*   typeface, in a given style.
*
* @note:
*   A face object also owns a single @FT_GlyphSlot object, as well as one
*   or more @FT_Size objects.
*
*   Use @FT_New_Face or @FT_Open_Face to create a new face object from a
*   given filepath or a custom input stream.
*
*   Use @FT_Done_Face to destroy it (along with its slot and sizes).
*
*   An `FT_Face` object can only be safely used from one thread at a time.
*   Similarly, creation and destruction of `FT_Face` with the same
*   @FT_Library object can only be done from one thread at a time.  On the
*   other hand, functions like @FT_Load_Glyph and its siblings are
*   thread-safe and do not need the lock to be held as long as the same
*   `FT_Face` object is not used from multiple threads at the same time.
*
* @also:
*   See @FT_FaceRec for the publicly accessible fields of a given face
*   object.
*/
FT_Face :: *FT_FaceRec_;

/**************************************************************************
*
* @type:
*   FT_Size
*
* @description:
*   A handle to an object that models a face scaled to a given character
*   size.
*
* @note:
*   An @FT_Face has one _active_ `FT_Size` object that is used by
*   functions like @FT_Load_Glyph to determine the scaling transformation
*   that in turn is used to load and hint glyphs and metrics.
*
*   A newly created `FT_Size` object contains only meaningless zero values.
*   You must use @FT_Set_Char_Size, @FT_Set_Pixel_Sizes, @FT_Request_Size
*   or even @FT_Select_Size to change the content (i.e., the scaling
*   values) of the active `FT_Size`.  Otherwise, the scaling and hinting
*   will not be performed.
*
*   You can use @FT_New_Size to create additional size objects for a given
*   @FT_Face, but they won't be used by other functions until you activate
*   it through @FT_Activate_Size.  Only one size can be activated at any
*   given time per face.
*
* @also:
*   See @FT_SizeRec for the publicly accessible fields of a given size
*   object.
*/
FT_Size :: *FT_SizeRec_;

/**************************************************************************
*
* @type:
*   FT_GlyphSlot
*
* @description:
*   A handle to a given 'glyph slot'.  A slot is a container that can hold
*   any of the glyphs contained in its parent face.
*
*   In other words, each time you call @FT_Load_Glyph or @FT_Load_Char,
*   the slot's content is erased by the new glyph data, i.e., the glyph's
*   metrics, its image (bitmap or outline), and other control information.
*
* @also:
*   See @FT_GlyphSlotRec for the publicly accessible glyph fields.
*/
FT_GlyphSlot :: *FT_GlyphSlotRec_;

/**************************************************************************
*
* @type:
*   FT_CharMap
*
* @description:
*   A handle to a character map (usually abbreviated to 'charmap').  A
*   charmap is used to translate character codes in a given encoding into
*   glyph indexes for its parent's face.  Some font formats may provide
*   several charmaps per font.
*
*   Each face object owns zero or more charmaps, but only one of them can
*   be 'active', providing the data used by @FT_Get_Char_Index or
*   @FT_Load_Char.
*
*   The list of available charmaps in a face is available through the
*   `face->num_charmaps` and `face->charmaps` fields of @FT_FaceRec.
*
*   The currently active charmap is available as `face->charmap`.  You
*   should call @FT_Set_Charmap to change it.
*
* @note:
*   When a new face is created (either through @FT_New_Face or
*   @FT_Open_Face), the library looks for a Unicode charmap within the
*   list and automatically activates it.  If there is no Unicode charmap,
*   FreeType doesn't set an 'active' charmap.
*
* @also:
*   See @FT_CharMapRec for the publicly accessible fields of a given
*   character map.
*/
FT_CharMap :: *FT_CharMapRec_;

/**************************************************************************
*
* @enum:
*   FT_Encoding
*
* @description:
*   An enumeration to specify character sets supported by charmaps.  Used
*   in the @FT_Select_Charmap API function.
*
* @note:
*   Despite the name, this enumeration lists specific character
*   repertoires (i.e., charsets), and not text encoding methods (e.g.,
*   UTF-8, UTF-16, etc.).
*
*   Other encodings might be defined in the future.
*
* @values:
*   FT_ENCODING_NONE ::
*     The encoding value~0 is reserved for all formats except BDF, PCF,
*     and Windows FNT; see below for more information.
*
*   FT_ENCODING_UNICODE ::
*     The Unicode character set.  This value covers all versions of the
*     Unicode repertoire, including ASCII and Latin-1.  Most fonts include
*     a Unicode charmap, but not all of them.
*
*     For example, if you want to access Unicode value U+1F028 (and the
*     font contains it), use value 0x1F028 as the input value for
*     @FT_Get_Char_Index.
*
*   FT_ENCODING_MS_SYMBOL ::
*     Microsoft Symbol encoding, used to encode mathematical symbols and
*     wingdings.  For more information, see
*     'https://learn.microsoft.com/typography/opentype/spec/recom#non-standard-symbol-fonts',
*     'http://www.kostis.net/charsets/symbol.htm', and
*     'http://www.kostis.net/charsets/wingding.htm'.
*
*     This encoding uses character codes from the PUA (Private Unicode
*     Area) in the range U+F020-U+F0FF.
*
*   FT_ENCODING_SJIS ::
*     Shift JIS encoding for Japanese.  More info at
*     'https://en.wikipedia.org/wiki/Shift_JIS'.  See note on multi-byte
*     encodings below.
*
*   FT_ENCODING_PRC ::
*     Corresponds to encoding systems mainly for Simplified Chinese as
*     used in People's Republic of China (PRC).  The encoding layout is
*     based on GB~2312 and its supersets GBK and GB~18030.
*
*   FT_ENCODING_BIG5 ::
*     Corresponds to an encoding system for Traditional Chinese as used in
*     Taiwan and Hong Kong.
*
*   FT_ENCODING_WANSUNG ::
*     Corresponds to the Korean encoding system known as Extended Wansung
*     (MS Windows code page 949).  For more information see
*     'https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit949.txt'.
*
*   FT_ENCODING_JOHAB ::
*     The Korean standard character set (KS~C 5601-1992), which
*     corresponds to MS Windows code page 1361.  This character set
*     includes all possible Hangul character combinations.
*
*   FT_ENCODING_ADOBE_LATIN_1 ::
*     Corresponds to a Latin-1 encoding as defined in a Type~1 PostScript
*     font.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_STANDARD ::
*     Adobe Standard encoding, as found in Type~1, CFF, and OpenType/CFF
*     fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_EXPERT ::
*     Adobe Expert encoding, as found in Type~1, CFF, and OpenType/CFF
*     fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_CUSTOM ::
*     Corresponds to a custom encoding, as found in Type~1, CFF, and
*     OpenType/CFF fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_APPLE_ROMAN ::
*     Apple roman encoding.  Many TrueType and OpenType fonts contain a
*     charmap for this 8-bit encoding, since older versions of Mac OS are
*     able to use it.
*
*   FT_ENCODING_OLD_LATIN_2 ::
*     This value is deprecated and was neither used nor reported by
*     FreeType.  Don't use or test for it.
*
*   FT_ENCODING_MS_SJIS ::
*     Same as FT_ENCODING_SJIS.  Deprecated.
*
*   FT_ENCODING_MS_GB2312 ::
*     Same as FT_ENCODING_PRC.  Deprecated.
*
*   FT_ENCODING_MS_BIG5 ::
*     Same as FT_ENCODING_BIG5.  Deprecated.
*
*   FT_ENCODING_MS_WANSUNG ::
*     Same as FT_ENCODING_WANSUNG.  Deprecated.
*
*   FT_ENCODING_MS_JOHAB ::
*     Same as FT_ENCODING_JOHAB.  Deprecated.
*
* @note:
*   When loading a font, FreeType makes a Unicode charmap active if
*   possible (either if the font provides such a charmap, or if FreeType
*   can synthesize one from PostScript glyph name dictionaries; in either
*   case, the charmap is tagged with `FT_ENCODING_UNICODE`).  If such a
*   charmap is synthesized, it is placed at the first position of the
*   charmap array.
*
*   All other encodings are considered legacy and tagged only if
*   explicitly defined in the font file.  Otherwise, `FT_ENCODING_NONE` is
*   used.
*
*   `FT_ENCODING_NONE` is set by the BDF and PCF drivers if the charmap is
*   neither Unicode nor ISO-8859-1 (otherwise it is set to
*   `FT_ENCODING_UNICODE`).  Use @FT_Get_BDF_Charset_ID to find out which
*   encoding is really present.  If, for example, the `cs_registry` field
*   is 'KOI8' and the `cs_encoding` field is 'R', the font is encoded in
*   KOI8-R.
*
*   `FT_ENCODING_NONE` is always set (with a single exception) by the
*   winfonts driver.  Use @FT_Get_WinFNT_Header and examine the `charset`
*   field of the @FT_WinFNT_HeaderRec structure to find out which encoding
*   is really present.  For example, @FT_WinFNT_ID_CP1251 (204) means
*   Windows code page 1251 (for Russian).
*
*   `FT_ENCODING_NONE` is set if `platform_id` is @TT_PLATFORM_MACINTOSH
*   and `encoding_id` is not `TT_MAC_ID_ROMAN` (otherwise it is set to
*   `FT_ENCODING_APPLE_ROMAN`).
*
*   If `platform_id` is @TT_PLATFORM_MACINTOSH, use the function
*   @FT_Get_CMap_Language_ID to query the Mac language ID that may be
*   needed to be able to distinguish Apple encoding variants.  See
*
*     https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/Readme.txt
*
*   to get an idea how to do that.  Basically, if the language ID is~0,
*   don't use it, otherwise subtract 1 from the language ID.  Then examine
*   `encoding_id`.  If, for example, `encoding_id` is `TT_MAC_ID_ROMAN`
*   and the language ID (minus~1) is `TT_MAC_LANGID_GREEK`, it is the
*   Greek encoding, not Roman.  `TT_MAC_ID_ARABIC` with
*   `TT_MAC_LANGID_FARSI` means the Farsi variant of the Arabic encoding.
*/
FT_Encoding_ :: enum s32 {
    NONE           :: 0;

    MS_SYMBOL      :: 1937337698;
    UNICODE        :: 1970170211;

    SJIS           :: 1936353651;
    PRC            :: 1734484000;
    BIG5           :: 1651074869;
    WANSUNG        :: 2002873971;
    JOHAB          :: 1785686113;

    GB2312         :: 1734484000;
    MS_SJIS        :: 1936353651;
    MS_GB2312      :: 1734484000;
    MS_BIG5        :: 1651074869;
    MS_WANSUNG     :: 2002873971;
    MS_JOHAB       :: 1785686113;

    ADOBE_STANDARD :: 1094995778;
    ADOBE_EXPERT   :: 1094992453;
    ADOBE_CUSTOM   :: 1094992451;
    ADOBE_LATIN_1  :: 1818326065;

    OLD_LATIN_2    :: 1818326066;

    APPLE_ROMAN    :: 1634889070;

    FT_ENCODING_NONE           :: NONE;

    FT_ENCODING_MS_SYMBOL      :: MS_SYMBOL;
    FT_ENCODING_UNICODE        :: UNICODE;

    FT_ENCODING_SJIS           :: SJIS;
    FT_ENCODING_PRC            :: PRC;
    FT_ENCODING_BIG5           :: BIG5;
    FT_ENCODING_WANSUNG        :: WANSUNG;
    FT_ENCODING_JOHAB          :: JOHAB;

    FT_ENCODING_GB2312         :: GB2312;
    FT_ENCODING_MS_SJIS        :: MS_SJIS;
    FT_ENCODING_MS_GB2312      :: MS_GB2312;
    FT_ENCODING_MS_BIG5        :: MS_BIG5;
    FT_ENCODING_MS_WANSUNG     :: MS_WANSUNG;
    FT_ENCODING_MS_JOHAB       :: MS_JOHAB;

    FT_ENCODING_ADOBE_STANDARD :: ADOBE_STANDARD;
    FT_ENCODING_ADOBE_EXPERT   :: ADOBE_EXPERT;
    FT_ENCODING_ADOBE_CUSTOM   :: ADOBE_CUSTOM;
    FT_ENCODING_ADOBE_LATIN_1  :: ADOBE_LATIN_1;

    FT_ENCODING_OLD_LATIN_2    :: OLD_LATIN_2;

    FT_ENCODING_APPLE_ROMAN    :: APPLE_ROMAN;
}

/**************************************************************************
*
* @enum:
*   FT_Encoding
*
* @description:
*   An enumeration to specify character sets supported by charmaps.  Used
*   in the @FT_Select_Charmap API function.
*
* @note:
*   Despite the name, this enumeration lists specific character
*   repertoires (i.e., charsets), and not text encoding methods (e.g.,
*   UTF-8, UTF-16, etc.).
*
*   Other encodings might be defined in the future.
*
* @values:
*   FT_ENCODING_NONE ::
*     The encoding value~0 is reserved for all formats except BDF, PCF,
*     and Windows FNT; see below for more information.
*
*   FT_ENCODING_UNICODE ::
*     The Unicode character set.  This value covers all versions of the
*     Unicode repertoire, including ASCII and Latin-1.  Most fonts include
*     a Unicode charmap, but not all of them.
*
*     For example, if you want to access Unicode value U+1F028 (and the
*     font contains it), use value 0x1F028 as the input value for
*     @FT_Get_Char_Index.
*
*   FT_ENCODING_MS_SYMBOL ::
*     Microsoft Symbol encoding, used to encode mathematical symbols and
*     wingdings.  For more information, see
*     'https://learn.microsoft.com/typography/opentype/spec/recom#non-standard-symbol-fonts',
*     'http://www.kostis.net/charsets/symbol.htm', and
*     'http://www.kostis.net/charsets/wingding.htm'.
*
*     This encoding uses character codes from the PUA (Private Unicode
*     Area) in the range U+F020-U+F0FF.
*
*   FT_ENCODING_SJIS ::
*     Shift JIS encoding for Japanese.  More info at
*     'https://en.wikipedia.org/wiki/Shift_JIS'.  See note on multi-byte
*     encodings below.
*
*   FT_ENCODING_PRC ::
*     Corresponds to encoding systems mainly for Simplified Chinese as
*     used in People's Republic of China (PRC).  The encoding layout is
*     based on GB~2312 and its supersets GBK and GB~18030.
*
*   FT_ENCODING_BIG5 ::
*     Corresponds to an encoding system for Traditional Chinese as used in
*     Taiwan and Hong Kong.
*
*   FT_ENCODING_WANSUNG ::
*     Corresponds to the Korean encoding system known as Extended Wansung
*     (MS Windows code page 949).  For more information see
*     'https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit949.txt'.
*
*   FT_ENCODING_JOHAB ::
*     The Korean standard character set (KS~C 5601-1992), which
*     corresponds to MS Windows code page 1361.  This character set
*     includes all possible Hangul character combinations.
*
*   FT_ENCODING_ADOBE_LATIN_1 ::
*     Corresponds to a Latin-1 encoding as defined in a Type~1 PostScript
*     font.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_STANDARD ::
*     Adobe Standard encoding, as found in Type~1, CFF, and OpenType/CFF
*     fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_EXPERT ::
*     Adobe Expert encoding, as found in Type~1, CFF, and OpenType/CFF
*     fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_ADOBE_CUSTOM ::
*     Corresponds to a custom encoding, as found in Type~1, CFF, and
*     OpenType/CFF fonts.  It is limited to 256 character codes.
*
*   FT_ENCODING_APPLE_ROMAN ::
*     Apple roman encoding.  Many TrueType and OpenType fonts contain a
*     charmap for this 8-bit encoding, since older versions of Mac OS are
*     able to use it.
*
*   FT_ENCODING_OLD_LATIN_2 ::
*     This value is deprecated and was neither used nor reported by
*     FreeType.  Don't use or test for it.
*
*   FT_ENCODING_MS_SJIS ::
*     Same as FT_ENCODING_SJIS.  Deprecated.
*
*   FT_ENCODING_MS_GB2312 ::
*     Same as FT_ENCODING_PRC.  Deprecated.
*
*   FT_ENCODING_MS_BIG5 ::
*     Same as FT_ENCODING_BIG5.  Deprecated.
*
*   FT_ENCODING_MS_WANSUNG ::
*     Same as FT_ENCODING_WANSUNG.  Deprecated.
*
*   FT_ENCODING_MS_JOHAB ::
*     Same as FT_ENCODING_JOHAB.  Deprecated.
*
* @note:
*   When loading a font, FreeType makes a Unicode charmap active if
*   possible (either if the font provides such a charmap, or if FreeType
*   can synthesize one from PostScript glyph name dictionaries; in either
*   case, the charmap is tagged with `FT_ENCODING_UNICODE`).  If such a
*   charmap is synthesized, it is placed at the first position of the
*   charmap array.
*
*   All other encodings are considered legacy and tagged only if
*   explicitly defined in the font file.  Otherwise, `FT_ENCODING_NONE` is
*   used.
*
*   `FT_ENCODING_NONE` is set by the BDF and PCF drivers if the charmap is
*   neither Unicode nor ISO-8859-1 (otherwise it is set to
*   `FT_ENCODING_UNICODE`).  Use @FT_Get_BDF_Charset_ID to find out which
*   encoding is really present.  If, for example, the `cs_registry` field
*   is 'KOI8' and the `cs_encoding` field is 'R', the font is encoded in
*   KOI8-R.
*
*   `FT_ENCODING_NONE` is always set (with a single exception) by the
*   winfonts driver.  Use @FT_Get_WinFNT_Header and examine the `charset`
*   field of the @FT_WinFNT_HeaderRec structure to find out which encoding
*   is really present.  For example, @FT_WinFNT_ID_CP1251 (204) means
*   Windows code page 1251 (for Russian).
*
*   `FT_ENCODING_NONE` is set if `platform_id` is @TT_PLATFORM_MACINTOSH
*   and `encoding_id` is not `TT_MAC_ID_ROMAN` (otherwise it is set to
*   `FT_ENCODING_APPLE_ROMAN`).
*
*   If `platform_id` is @TT_PLATFORM_MACINTOSH, use the function
*   @FT_Get_CMap_Language_ID to query the Mac language ID that may be
*   needed to be able to distinguish Apple encoding variants.  See
*
*     https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/Readme.txt
*
*   to get an idea how to do that.  Basically, if the language ID is~0,
*   don't use it, otherwise subtract 1 from the language ID.  Then examine
*   `encoding_id`.  If, for example, `encoding_id` is `TT_MAC_ID_ROMAN`
*   and the language ID (minus~1) is `TT_MAC_LANGID_GREEK`, it is the
*   Greek encoding, not Roman.  `TT_MAC_ID_ARABIC` with
*   `TT_MAC_LANGID_FARSI` means the Farsi variant of the Arabic encoding.
*/
FT_Encoding :: FT_Encoding_;

/**************************************************************************
*
* @struct:
*   FT_CharMapRec
*
* @description:
*   The base charmap structure.
*
* @fields:
*   face ::
*     A handle to the parent face object.
*
*   encoding ::
*     An @FT_Encoding tag identifying the charmap.  Use this with
*     @FT_Select_Charmap.
*
*   platform_id ::
*     An ID number describing the platform for the following encoding ID.
*     This comes directly from the TrueType specification and gets
*     emulated for other formats.
*
*   encoding_id ::
*     A platform-specific encoding number.  This also comes from the
*     TrueType specification and gets emulated similarly.
*/
FT_CharMapRec_ :: struct {
    face:        FT_Face;
    encoding:    FT_Encoding;
    platform_id: FT_UShort;
    encoding_id: FT_UShort;
}

/**************************************************************************
*
* @struct:
*   FT_CharMapRec
*
* @description:
*   The base charmap structure.
*
* @fields:
*   face ::
*     A handle to the parent face object.
*
*   encoding ::
*     An @FT_Encoding tag identifying the charmap.  Use this with
*     @FT_Select_Charmap.
*
*   platform_id ::
*     An ID number describing the platform for the following encoding ID.
*     This comes directly from the TrueType specification and gets
*     emulated for other formats.
*
*   encoding_id ::
*     A platform-specific encoding number.  This also comes from the
*     TrueType specification and gets emulated similarly.
*/
FT_CharMapRec :: FT_CharMapRec_;

FT_Face_InternalRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Face_Internal
*
* @description:
*   An opaque handle to an `FT_Face_InternalRec` structure that models the
*   private data of a given @FT_Face object.
*
*   This structure might change between releases of FreeType~2 and is not
*   generally available to client applications.
*/
FT_Face_Internal :: *FT_Face_InternalRec_;

/**************************************************************************
*
* @struct:
*   FT_FaceRec
*
* @description:
*   FreeType root face class structure.  A face object models a typeface
*   in a font file.
*
* @fields:
*   num_faces ::
*     The number of faces in the font file.  Some font formats can have
*     multiple faces in a single font file.
*
*   face_index ::
*     This field holds two different values.  Bits 0-15 are the index of
*     the face in the font file (starting with value~0).  They are set
*     to~0 if there is only one face in the font file.
*
*     [Since 2.6.1] Bits 16-30 are relevant to TrueType GX and OpenType
*     Font Variations only, holding the named instance index for the
*     current face index (starting with value~1; value~0 indicates font
*     access without a named instance).  For non-variation fonts, bits
*     16-30 are ignored.  If we have the third named instance of face~4,
*     say, `face_index` is set to 0x00030004.
*
*     Bit 31 is always zero (that is, `face_index` is always a positive
*     value).
*
*     [Since 2.9] Changing the design coordinates with
*     @FT_Set_Var_Design_Coordinates or @FT_Set_Var_Blend_Coordinates does
*     not influence the named instance index value (only
*     @FT_Set_Named_Instance does that).
*
*   face_flags ::
*     A set of bit flags that give important information about the face;
*     see @FT_FACE_FLAG_XXX for the details.
*
*   style_flags ::
*     The lower 16~bits contain a set of bit flags indicating the style of
*     the face; see @FT_STYLE_FLAG_XXX for the details.
*
*     [Since 2.6.1] Bits 16-30 hold the number of named instances
*     available for the current face if we have a TrueType GX or OpenType
*     Font Variation.  Bit 31 is always zero (that is, `style_flags` is
*     always a positive value).  Note that a variation font has always at
*     least one named instance, namely the default instance.
*
*   num_glyphs ::
*     The number of glyphs in the face.  If the face is scalable and has
*     sbits (see `num_fixed_sizes`), it is set to the number of outline
*     glyphs.
*
*     For CID-keyed fonts (not in an SFNT wrapper) this value gives the
*     highest CID used in the font.
*
*   family_name ::
*     The face's family name.  This is an ASCII string, usually in
*     English, that describes the typeface's family (like 'Times New
*     Roman', 'Bodoni', 'Garamond', etc).  This is a least common
*     denominator used to list fonts.  Some formats (TrueType & OpenType)
*     provide localized and Unicode versions of this string.  Applications
*     should use the format-specific interface to access them.  Can be
*     `NULL` (e.g., in fonts embedded in a PDF file).
*
*     In case the font doesn't provide a specific family name entry,
*     FreeType tries to synthesize one, deriving it from other name
*     entries.
*
*   style_name ::
*     The face's style name.  This is an ASCII string, usually in English,
*     that describes the typeface's style (like 'Italic', 'Bold',
*     'Condensed', etc).  Not all font formats provide a style name, so
*     this field is optional, and can be set to `NULL`.  As for
*     `family_name`, some formats provide localized and Unicode versions
*     of this string.  Applications should use the format-specific
*     interface to access them.
*
*   num_fixed_sizes ::
*     The number of bitmap strikes in the face.  Even if the face is
*     scalable, there might still be bitmap strikes, which are called
*     'sbits' in that case.
*
*   available_sizes ::
*     An array of @FT_Bitmap_Size for all bitmap strikes in the face.  It
*     is set to `NULL` if there is no bitmap strike.
*
*     Note that FreeType tries to sanitize the strike data since they are
*     sometimes sloppy or incorrect, but this can easily fail.
*
*   num_charmaps ::
*     The number of charmaps in the face.
*
*   charmaps ::
*     An array of the charmaps of the face.
*
*   generic ::
*     A field reserved for client uses.  See the @FT_Generic type
*     description.
*
*   bbox ::
*     The font bounding box.  Coordinates are expressed in font units (see
*     `units_per_EM`).  The box is large enough to contain any glyph from
*     the font.  Thus, `bbox.yMax` can be seen as the 'maximum ascender',
*     and `bbox.yMin` as the 'minimum descender'.  Only relevant for
*     scalable formats.
*
*     Note that the bounding box might be off by (at least) one pixel for
*     hinted fonts.  See @FT_Size_Metrics for further discussion.
*
*     Note that the bounding box does not vary in OpenType Font Variations
*     and should only be used in relation to the default instance.
*
*   units_per_EM ::
*     The number of font units per EM square for this face.  This is
*     typically 2048 for TrueType fonts, and 1000 for Type~1 fonts.  Only
*     relevant for scalable formats.
*
*   ascender ::
*     The typographic ascender of the face, expressed in font units.  For
*     font formats not having this information, it is set to `bbox.yMax`.
*     Only relevant for scalable formats.
*
*   descender ::
*     The typographic descender of the face, expressed in font units.  For
*     font formats not having this information, it is set to `bbox.yMin`.
*     Note that this field is negative for values below the baseline.
*     Only relevant for scalable formats.
*
*   height ::
*     This value is the vertical distance between two consecutive
*     baselines, expressed in font units.  It is always positive.  Only
*     relevant for scalable formats.
*
*     If you want the global glyph height, use `ascender - descender`.
*
*   max_advance_width ::
*     The maximum advance width, in font units, for all glyphs in this
*     face.  This can be used to make word wrapping computations faster.
*     Only relevant for scalable formats.
*
*   max_advance_height ::
*     The maximum advance height, in font units, for all glyphs in this
*     face.  This is only relevant for vertical layouts, and is set to
*     `height` for fonts that do not provide vertical metrics.  Only
*     relevant for scalable formats.
*
*   underline_position ::
*     The position, in font units, of the underline line for this face.
*     It is the center of the underlining stem.  Only relevant for
*     scalable formats.
*
*   underline_thickness ::
*     The thickness, in font units, of the underline for this face.  Only
*     relevant for scalable formats.
*
*   glyph ::
*     The face's associated glyph slot(s).
*
*   size ::
*     The current active size for this face.
*
*   charmap ::
*     The current active charmap for this face.
*
* @note:
*   Fields may be changed after a call to @FT_Attach_File or
*   @FT_Attach_Stream.
*
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `ascender`, `descender`, `height`,
*   `underline_position`, and `underline_thickness`.
*
*   Especially for TrueType fonts see also the documentation for
*   @FT_Size_Metrics.
*/
FT_FaceRec_ :: struct {
    num_faces:           FT_Long;
    face_index:          FT_Long;

    face_flags:          FT_Long;
    style_flags:         FT_Long;

    num_glyphs:          FT_Long;

    family_name:         *FT_String;
    style_name:          *FT_String;

    num_fixed_sizes:     FT_Int;
    available_sizes:     *FT_Bitmap_Size;

    num_charmaps:        FT_Int;
    charmaps:            *FT_CharMap;

    generic:             FT_Generic;

    /* The following member variables (down to `underline_thickness`) */
    /* are only relevant to scalable outlines; cf. @FT_Bitmap_Size    */
    /* for bitmap fonts.                                              */
    bbox:                FT_BBox;

    units_per_EM:        FT_UShort;
    ascender:            FT_Short;
    descender:           FT_Short;
    height:              FT_Short;

    max_advance_width:   FT_Short;
    max_advance_height:  FT_Short;

    underline_position:  FT_Short;
    underline_thickness: FT_Short;

    glyph:               FT_GlyphSlot;
    size:                FT_Size;
    charmap:             FT_CharMap;

    /* private fields, internal to FreeType */
    driver:              FT_Driver;
    memory:              FT_Memory;
    stream:              FT_Stream;

    sizes_list:          FT_ListRec;

    autohint:            FT_Generic; /* face-specific auto-hinter data */
    extensions:          *void; /* unused                         */

    internal:            FT_Face_Internal;
}

/**************************************************************************
*
* @struct:
*   FT_FaceRec
*
* @description:
*   FreeType root face class structure.  A face object models a typeface
*   in a font file.
*
* @fields:
*   num_faces ::
*     The number of faces in the font file.  Some font formats can have
*     multiple faces in a single font file.
*
*   face_index ::
*     This field holds two different values.  Bits 0-15 are the index of
*     the face in the font file (starting with value~0).  They are set
*     to~0 if there is only one face in the font file.
*
*     [Since 2.6.1] Bits 16-30 are relevant to TrueType GX and OpenType
*     Font Variations only, holding the named instance index for the
*     current face index (starting with value~1; value~0 indicates font
*     access without a named instance).  For non-variation fonts, bits
*     16-30 are ignored.  If we have the third named instance of face~4,
*     say, `face_index` is set to 0x00030004.
*
*     Bit 31 is always zero (that is, `face_index` is always a positive
*     value).
*
*     [Since 2.9] Changing the design coordinates with
*     @FT_Set_Var_Design_Coordinates or @FT_Set_Var_Blend_Coordinates does
*     not influence the named instance index value (only
*     @FT_Set_Named_Instance does that).
*
*   face_flags ::
*     A set of bit flags that give important information about the face;
*     see @FT_FACE_FLAG_XXX for the details.
*
*   style_flags ::
*     The lower 16~bits contain a set of bit flags indicating the style of
*     the face; see @FT_STYLE_FLAG_XXX for the details.
*
*     [Since 2.6.1] Bits 16-30 hold the number of named instances
*     available for the current face if we have a TrueType GX or OpenType
*     Font Variation.  Bit 31 is always zero (that is, `style_flags` is
*     always a positive value).  Note that a variation font has always at
*     least one named instance, namely the default instance.
*
*   num_glyphs ::
*     The number of glyphs in the face.  If the face is scalable and has
*     sbits (see `num_fixed_sizes`), it is set to the number of outline
*     glyphs.
*
*     For CID-keyed fonts (not in an SFNT wrapper) this value gives the
*     highest CID used in the font.
*
*   family_name ::
*     The face's family name.  This is an ASCII string, usually in
*     English, that describes the typeface's family (like 'Times New
*     Roman', 'Bodoni', 'Garamond', etc).  This is a least common
*     denominator used to list fonts.  Some formats (TrueType & OpenType)
*     provide localized and Unicode versions of this string.  Applications
*     should use the format-specific interface to access them.  Can be
*     `NULL` (e.g., in fonts embedded in a PDF file).
*
*     In case the font doesn't provide a specific family name entry,
*     FreeType tries to synthesize one, deriving it from other name
*     entries.
*
*   style_name ::
*     The face's style name.  This is an ASCII string, usually in English,
*     that describes the typeface's style (like 'Italic', 'Bold',
*     'Condensed', etc).  Not all font formats provide a style name, so
*     this field is optional, and can be set to `NULL`.  As for
*     `family_name`, some formats provide localized and Unicode versions
*     of this string.  Applications should use the format-specific
*     interface to access them.
*
*   num_fixed_sizes ::
*     The number of bitmap strikes in the face.  Even if the face is
*     scalable, there might still be bitmap strikes, which are called
*     'sbits' in that case.
*
*   available_sizes ::
*     An array of @FT_Bitmap_Size for all bitmap strikes in the face.  It
*     is set to `NULL` if there is no bitmap strike.
*
*     Note that FreeType tries to sanitize the strike data since they are
*     sometimes sloppy or incorrect, but this can easily fail.
*
*   num_charmaps ::
*     The number of charmaps in the face.
*
*   charmaps ::
*     An array of the charmaps of the face.
*
*   generic ::
*     A field reserved for client uses.  See the @FT_Generic type
*     description.
*
*   bbox ::
*     The font bounding box.  Coordinates are expressed in font units (see
*     `units_per_EM`).  The box is large enough to contain any glyph from
*     the font.  Thus, `bbox.yMax` can be seen as the 'maximum ascender',
*     and `bbox.yMin` as the 'minimum descender'.  Only relevant for
*     scalable formats.
*
*     Note that the bounding box might be off by (at least) one pixel for
*     hinted fonts.  See @FT_Size_Metrics for further discussion.
*
*     Note that the bounding box does not vary in OpenType Font Variations
*     and should only be used in relation to the default instance.
*
*   units_per_EM ::
*     The number of font units per EM square for this face.  This is
*     typically 2048 for TrueType fonts, and 1000 for Type~1 fonts.  Only
*     relevant for scalable formats.
*
*   ascender ::
*     The typographic ascender of the face, expressed in font units.  For
*     font formats not having this information, it is set to `bbox.yMax`.
*     Only relevant for scalable formats.
*
*   descender ::
*     The typographic descender of the face, expressed in font units.  For
*     font formats not having this information, it is set to `bbox.yMin`.
*     Note that this field is negative for values below the baseline.
*     Only relevant for scalable formats.
*
*   height ::
*     This value is the vertical distance between two consecutive
*     baselines, expressed in font units.  It is always positive.  Only
*     relevant for scalable formats.
*
*     If you want the global glyph height, use `ascender - descender`.
*
*   max_advance_width ::
*     The maximum advance width, in font units, for all glyphs in this
*     face.  This can be used to make word wrapping computations faster.
*     Only relevant for scalable formats.
*
*   max_advance_height ::
*     The maximum advance height, in font units, for all glyphs in this
*     face.  This is only relevant for vertical layouts, and is set to
*     `height` for fonts that do not provide vertical metrics.  Only
*     relevant for scalable formats.
*
*   underline_position ::
*     The position, in font units, of the underline line for this face.
*     It is the center of the underlining stem.  Only relevant for
*     scalable formats.
*
*   underline_thickness ::
*     The thickness, in font units, of the underline for this face.  Only
*     relevant for scalable formats.
*
*   glyph ::
*     The face's associated glyph slot(s).
*
*   size ::
*     The current active size for this face.
*
*   charmap ::
*     The current active charmap for this face.
*
* @note:
*   Fields may be changed after a call to @FT_Attach_File or
*   @FT_Attach_Stream.
*
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `ascender`, `descender`, `height`,
*   `underline_position`, and `underline_thickness`.
*
*   Especially for TrueType fonts see also the documentation for
*   @FT_Size_Metrics.
*/
FT_FaceRec :: FT_FaceRec_;

FT_Size_InternalRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Size_Internal
*
* @description:
*   An opaque handle to an `FT_Size_InternalRec` structure, used to model
*   private data of a given @FT_Size object.
*/
FT_Size_Internal :: *FT_Size_InternalRec_;

/**************************************************************************
*
* @struct:
*   FT_Size_Metrics
*
* @description:
*   The size metrics structure gives the metrics of a size object.
*
* @fields:
*   x_ppem ::
*     The width of the scaled EM square in pixels, hence the term 'ppem'
*     (pixels per EM).  It is also referred to as 'nominal width'.
*
*   y_ppem ::
*     The height of the scaled EM square in pixels, hence the term 'ppem'
*     (pixels per EM).  It is also referred to as 'nominal height'.
*
*   x_scale ::
*     A 16.16 fractional scaling value to convert horizontal metrics from
*     font units to 26.6 fractional pixels.  Only relevant for scalable
*     font formats.
*
*   y_scale ::
*     A 16.16 fractional scaling value to convert vertical metrics from
*     font units to 26.6 fractional pixels.  Only relevant for scalable
*     font formats.
*
*   ascender ::
*     The ascender in 26.6 fractional pixels, rounded up to an integer
*     value.  See @FT_FaceRec for the details.
*
*   descender ::
*     The descender in 26.6 fractional pixels, rounded down to an integer
*     value.  See @FT_FaceRec for the details.
*
*   height ::
*     The height in 26.6 fractional pixels, rounded to an integer value.
*     See @FT_FaceRec for the details.
*
*   max_advance ::
*     The maximum advance width in 26.6 fractional pixels, rounded to an
*     integer value.  See @FT_FaceRec for the details.
*
* @note:
*   The scaling values, if relevant, are determined first during a size
*   changing operation.  The remaining fields are then set by the driver.
*   For scalable formats, they are usually set to scaled values of the
*   corresponding fields in @FT_FaceRec.  Some values like ascender or
*   descender are rounded for historical reasons; more precise values (for
*   outline fonts) can be derived by scaling the corresponding @FT_FaceRec
*   values manually, with code similar to the following.
*
*   ```
*     scaled_ascender = FT_MulFix( face->ascender,
*                                  size_metrics->y_scale );
*   ```
*
*   Note that due to glyph hinting and the selected rendering mode these
*   values are usually not exact; consequently, they must be treated as
*   unreliable with an error margin of at least one pixel!
*
*   Indeed, the only way to get the exact metrics is to render _all_
*   glyphs.  As this would be a definite performance hit, it is up to
*   client applications to perform such computations.
*
*   The `FT_Size_Metrics` structure is valid for bitmap fonts also.
*
*
*   **TrueType fonts with native bytecode hinting**
*
*   All applications that handle TrueType fonts with native hinting must
*   be aware that TTFs expect different rounding of vertical font
*   dimensions.  The application has to cater for this, especially if it
*   wants to rely on a TTF's vertical data (for example, to properly align
*   box characters vertically).
*
*   Only the application knows _in advance_ that it is going to use native
*   hinting for TTFs!  FreeType, on the other hand, selects the hinting
*   mode not at the time of creating an @FT_Size object but much later,
*   namely while calling @FT_Load_Glyph.
*
*   Here is some pseudo code that illustrates a possible solution.
*
*   ```
*     font_format = FT_Get_Font_Format( face );
*
*     if ( !strcmp( font_format, "TrueType" ) &&
*          do_native_bytecode_hinting         )
*     {
*       ascender  = ROUND( FT_MulFix( face->ascender,
*                                     size_metrics->y_scale ) );
*       descender = ROUND( FT_MulFix( face->descender,
*                                     size_metrics->y_scale ) );
*     }
*     else
*     {
*       ascender  = size_metrics->ascender;
*       descender = size_metrics->descender;
*     }
*
*     height      = size_metrics->height;
*     max_advance = size_metrics->max_advance;
*   ```
*/
FT_Size_Metrics_ :: struct {
    x_ppem:      FT_UShort; /* horizontal pixels per EM               */
    y_ppem:      FT_UShort; /* vertical pixels per EM                 */

    x_scale:     FT_Fixed; /* scaling values used to convert font    */
    y_scale:     FT_Fixed; /* units to 26.6 fractional pixels        */

    ascender:    FT_Pos; /* ascender in 26.6 frac. pixels          */
    descender:   FT_Pos; /* descender in 26.6 frac. pixels         */
    height:      FT_Pos; /* text height in 26.6 frac. pixels       */
    max_advance: FT_Pos; /* max horizontal advance, in 26.6 pixels */
}

/**************************************************************************
*
* @struct:
*   FT_Size_Metrics
*
* @description:
*   The size metrics structure gives the metrics of a size object.
*
* @fields:
*   x_ppem ::
*     The width of the scaled EM square in pixels, hence the term 'ppem'
*     (pixels per EM).  It is also referred to as 'nominal width'.
*
*   y_ppem ::
*     The height of the scaled EM square in pixels, hence the term 'ppem'
*     (pixels per EM).  It is also referred to as 'nominal height'.
*
*   x_scale ::
*     A 16.16 fractional scaling value to convert horizontal metrics from
*     font units to 26.6 fractional pixels.  Only relevant for scalable
*     font formats.
*
*   y_scale ::
*     A 16.16 fractional scaling value to convert vertical metrics from
*     font units to 26.6 fractional pixels.  Only relevant for scalable
*     font formats.
*
*   ascender ::
*     The ascender in 26.6 fractional pixels, rounded up to an integer
*     value.  See @FT_FaceRec for the details.
*
*   descender ::
*     The descender in 26.6 fractional pixels, rounded down to an integer
*     value.  See @FT_FaceRec for the details.
*
*   height ::
*     The height in 26.6 fractional pixels, rounded to an integer value.
*     See @FT_FaceRec for the details.
*
*   max_advance ::
*     The maximum advance width in 26.6 fractional pixels, rounded to an
*     integer value.  See @FT_FaceRec for the details.
*
* @note:
*   The scaling values, if relevant, are determined first during a size
*   changing operation.  The remaining fields are then set by the driver.
*   For scalable formats, they are usually set to scaled values of the
*   corresponding fields in @FT_FaceRec.  Some values like ascender or
*   descender are rounded for historical reasons; more precise values (for
*   outline fonts) can be derived by scaling the corresponding @FT_FaceRec
*   values manually, with code similar to the following.
*
*   ```
*     scaled_ascender = FT_MulFix( face->ascender,
*                                  size_metrics->y_scale );
*   ```
*
*   Note that due to glyph hinting and the selected rendering mode these
*   values are usually not exact; consequently, they must be treated as
*   unreliable with an error margin of at least one pixel!
*
*   Indeed, the only way to get the exact metrics is to render _all_
*   glyphs.  As this would be a definite performance hit, it is up to
*   client applications to perform such computations.
*
*   The `FT_Size_Metrics` structure is valid for bitmap fonts also.
*
*
*   **TrueType fonts with native bytecode hinting**
*
*   All applications that handle TrueType fonts with native hinting must
*   be aware that TTFs expect different rounding of vertical font
*   dimensions.  The application has to cater for this, especially if it
*   wants to rely on a TTF's vertical data (for example, to properly align
*   box characters vertically).
*
*   Only the application knows _in advance_ that it is going to use native
*   hinting for TTFs!  FreeType, on the other hand, selects the hinting
*   mode not at the time of creating an @FT_Size object but much later,
*   namely while calling @FT_Load_Glyph.
*
*   Here is some pseudo code that illustrates a possible solution.
*
*   ```
*     font_format = FT_Get_Font_Format( face );
*
*     if ( !strcmp( font_format, "TrueType" ) &&
*          do_native_bytecode_hinting         )
*     {
*       ascender  = ROUND( FT_MulFix( face->ascender,
*                                     size_metrics->y_scale ) );
*       descender = ROUND( FT_MulFix( face->descender,
*                                     size_metrics->y_scale ) );
*     }
*     else
*     {
*       ascender  = size_metrics->ascender;
*       descender = size_metrics->descender;
*     }
*
*     height      = size_metrics->height;
*     max_advance = size_metrics->max_advance;
*   ```
*/
FT_Size_Metrics :: FT_Size_Metrics_;

/**************************************************************************
*
* @struct:
*   FT_SizeRec
*
* @description:
*   FreeType root size class structure.  A size object models a face
*   object at a given size.
*
* @fields:
*   face ::
*     Handle to the parent face object.
*
*   generic ::
*     A typeless pointer, unused by the FreeType library or any of its
*     drivers.  It can be used by client applications to link their own
*     data to each size object.
*
*   metrics ::
*     Metrics for this size object.  This field is read-only.
*/
FT_SizeRec_ :: struct {
    face:     FT_Face; /* parent face object              */
    generic:  FT_Generic; /* generic pointer for client uses */
    metrics:  FT_Size_Metrics; /* size metrics                    */
    internal: FT_Size_Internal;
}

/**************************************************************************
*
* @struct:
*   FT_SizeRec
*
* @description:
*   FreeType root size class structure.  A size object models a face
*   object at a given size.
*
* @fields:
*   face ::
*     Handle to the parent face object.
*
*   generic ::
*     A typeless pointer, unused by the FreeType library or any of its
*     drivers.  It can be used by client applications to link their own
*     data to each size object.
*
*   metrics ::
*     Metrics for this size object.  This field is read-only.
*/
FT_SizeRec :: FT_SizeRec_;

FT_SubGlyphRec_ :: struct {}
/**************************************************************************
*
* @struct:
*   FT_SubGlyph
*
* @description:
*   The subglyph structure is an internal object used to describe
*   subglyphs (for example, in the case of composites).
*
* @note:
*   The subglyph implementation is not part of the high-level API, hence
*   the forward structure declaration.
*
*   You can however retrieve subglyph information with
*   @FT_Get_SubGlyph_Info.
*/
FT_SubGlyph :: *FT_SubGlyphRec_;

FT_Slot_InternalRec_ :: struct {}
/**************************************************************************
*
* @type:
*   FT_Slot_Internal
*
* @description:
*   An opaque handle to an `FT_Slot_InternalRec` structure, used to model
*   private data of a given @FT_GlyphSlot object.
*/
FT_Slot_Internal :: *FT_Slot_InternalRec_;

/**************************************************************************
*
* @struct:
*   FT_GlyphSlotRec
*
* @description:
*   FreeType root glyph slot class structure.  A glyph slot is a container
*   where individual glyphs can be loaded, be they in outline or bitmap
*   format.
*
* @fields:
*   library ::
*     A handle to the FreeType library instance this slot belongs to.
*
*   face ::
*     A handle to the parent face object.
*
*   next ::
*     In some cases (like some font tools), several glyph slots per face
*     object can be a good thing.  As this is rare, the glyph slots are
*     listed through a direct, single-linked list using its `next` field.
*
*   glyph_index ::
*     [Since 2.10] The glyph index passed as an argument to @FT_Load_Glyph
*     while initializing the glyph slot.
*
*   generic ::
*     A typeless pointer unused by the FreeType library or any of its
*     drivers.  It can be used by client applications to link their own
*     data to each glyph slot object.
*
*   metrics ::
*     The metrics of the last loaded glyph in the slot.  The returned
*     values depend on the last load flags (see the @FT_Load_Glyph API
*     function) and can be expressed either in 26.6 fractional pixels or
*     font units.
*
*     Note that even when the glyph image is transformed, the metrics are
*     not.
*
*   linearHoriAdvance ::
*     The advance width of the unhinted glyph.  Its value is expressed in
*     16.16 fractional pixels, unless @FT_LOAD_LINEAR_DESIGN is set when
*     loading the glyph.  This field can be important to perform correct
*     WYSIWYG layout.  Only relevant for scalable glyphs.
*
*   linearVertAdvance ::
*     The advance height of the unhinted glyph.  Its value is expressed in
*     16.16 fractional pixels, unless @FT_LOAD_LINEAR_DESIGN is set when
*     loading the glyph.  This field can be important to perform correct
*     WYSIWYG layout.  Only relevant for scalable glyphs.
*
*   advance ::
*     This shorthand is, depending on @FT_LOAD_IGNORE_TRANSFORM, the
*     transformed (hinted) advance width for the glyph, in 26.6 fractional
*     pixel format.  As specified with @FT_LOAD_VERTICAL_LAYOUT, it uses
*     either the `horiAdvance` or the `vertAdvance` value of `metrics`
*     field.
*
*   format ::
*     This field indicates the format of the image contained in the glyph
*     slot.  Typically @FT_GLYPH_FORMAT_BITMAP, @FT_GLYPH_FORMAT_OUTLINE,
*     or @FT_GLYPH_FORMAT_COMPOSITE, but other values are possible.
*
*   bitmap ::
*     This field is used as a bitmap descriptor.  Note that the address
*     and content of the bitmap buffer can change between calls of
*     @FT_Load_Glyph and a few other functions.
*
*   bitmap_left ::
*     The bitmap's left bearing expressed in integer pixels.
*
*   bitmap_top ::
*     The bitmap's top bearing expressed in integer pixels.  This is the
*     distance from the baseline to the top-most glyph scanline, upwards
*     y~coordinates being **positive**.
*
*   outline ::
*     The outline descriptor for the current glyph image if its format is
*     @FT_GLYPH_FORMAT_OUTLINE.  Once a glyph is loaded, `outline` can be
*     transformed, distorted, emboldened, etc.  However, it must not be
*     freed.
*
*     [Since 2.10.1] If @FT_LOAD_NO_SCALE is set, outline coordinates of
*     OpenType Font Variations for a selected instance are internally
*     handled as 26.6 fractional font units but returned as (rounded)
*     integers, as expected.  To get unrounded font units, don't use
*     @FT_LOAD_NO_SCALE but load the glyph with @FT_LOAD_NO_HINTING and
*     scale it, using the font's `units_per_EM` value as the ppem.
*
*   num_subglyphs ::
*     The number of subglyphs in a composite glyph.  This field is only
*     valid for the composite glyph format that should normally only be
*     loaded with the @FT_LOAD_NO_RECURSE flag.
*
*   subglyphs ::
*     An array of subglyph descriptors for composite glyphs.  There are
*     `num_subglyphs` elements in there.  Currently internal to FreeType.
*
*   control_data ::
*     Certain font drivers can also return the control data for a given
*     glyph image (e.g.  TrueType bytecode, Type~1 charstrings, etc.).
*     This field is a pointer to such data; it is currently internal to
*     FreeType.
*
*   control_len ::
*     This is the length in bytes of the control data.  Currently internal
*     to FreeType.
*
*   other ::
*     Reserved.
*
*   lsb_delta ::
*     The difference between hinted and unhinted left side bearing while
*     auto-hinting is active.  Zero otherwise.
*
*   rsb_delta ::
*     The difference between hinted and unhinted right side bearing while
*     auto-hinting is active.  Zero otherwise.
*
* @note:
*   If @FT_Load_Glyph is called with default flags (see @FT_LOAD_DEFAULT)
*   the glyph image is loaded in the glyph slot in its native format
*   (e.g., an outline glyph for TrueType and Type~1 formats).  [Since 2.9]
*   The prospective bitmap metrics are calculated according to
*   @FT_LOAD_TARGET_XXX and other flags even for the outline glyph, even
*   if @FT_LOAD_RENDER is not set.
*
*   This image can later be converted into a bitmap by calling
*   @FT_Render_Glyph.  This function searches the current renderer for the
*   native image's format, then invokes it.
*
*   The renderer is in charge of transforming the native image through the
*   slot's face transformation fields, then converting it into a bitmap
*   that is returned in `slot->bitmap`.
*
*   Note that `slot->bitmap_left` and `slot->bitmap_top` are also used to
*   specify the position of the bitmap relative to the current pen
*   position (e.g., coordinates (0,0) on the baseline).  Of course,
*   `slot->format` is also changed to @FT_GLYPH_FORMAT_BITMAP.
*
*   Here is a small pseudo code fragment that shows how to use `lsb_delta`
*   and `rsb_delta` to do fractional positioning of glyphs:
*
*   ```
*     FT_GlyphSlot  slot     = face->glyph;
*     FT_Pos        origin_x = 0;
*
*
*     for all glyphs do
*       <load glyph with `FT_Load_Glyph'>
*
*       FT_Outline_Translate( slot->outline, origin_x & 63, 0 );
*
*       <save glyph image, or render glyph, or ...>
*
*       <compute kern between current and next glyph
*        and add it to `origin_x'>
*
*       origin_x += slot->advance.x;
*       origin_x += slot->lsb_delta - slot->rsb_delta;
*     endfor
*   ```
*
*   Here is another small pseudo code fragment that shows how to use
*   `lsb_delta` and `rsb_delta` to improve integer positioning of glyphs:
*
*   ```
*     FT_GlyphSlot  slot           = face->glyph;
*     FT_Pos        origin_x       = 0;
*     FT_Pos        prev_rsb_delta = 0;
*
*
*     for all glyphs do
*       <compute kern between current and previous glyph
*        and add it to `origin_x'>
*
*       <load glyph with `FT_Load_Glyph'>
*
*       if ( prev_rsb_delta - slot->lsb_delta >  32 )
*         origin_x -= 64;
*       else if ( prev_rsb_delta - slot->lsb_delta < -31 )
*         origin_x += 64;
*
*       prev_rsb_delta = slot->rsb_delta;
*
*       <save glyph image, or render glyph, or ...>
*
*       origin_x += slot->advance.x;
*     endfor
*   ```
*
*   If you use strong auto-hinting, you **must** apply these delta values!
*   Otherwise you will experience far too large inter-glyph spacing at
*   small rendering sizes in most cases.  Note that it doesn't harm to use
*   the above code for other hinting modes also, since the delta values
*   are zero then.
*/
FT_GlyphSlotRec_ :: struct {
    library:           FT_Library;
    face:              FT_Face;
    next:              FT_GlyphSlot;
    glyph_index:       FT_UInt; /* new in 2.10; was reserved previously */
    generic:           FT_Generic;

    metrics:           FT_Glyph_Metrics;
    linearHoriAdvance: FT_Fixed;
    linearVertAdvance: FT_Fixed;
    advance:           FT_Vector;

    format:            FT_Glyph_Format;

    bitmap:            FT_Bitmap;
    bitmap_left:       FT_Int;
    bitmap_top:        FT_Int;

    outline:           FT_Outline;

    num_subglyphs:     FT_UInt;
    subglyphs:         FT_SubGlyph;

    control_data:      *void;
    control_len:       s32;

    lsb_delta:         FT_Pos;
    rsb_delta:         FT_Pos;

    other:             *void;

    internal:          FT_Slot_Internal;
}

/**************************************************************************
*
* @struct:
*   FT_GlyphSlotRec
*
* @description:
*   FreeType root glyph slot class structure.  A glyph slot is a container
*   where individual glyphs can be loaded, be they in outline or bitmap
*   format.
*
* @fields:
*   library ::
*     A handle to the FreeType library instance this slot belongs to.
*
*   face ::
*     A handle to the parent face object.
*
*   next ::
*     In some cases (like some font tools), several glyph slots per face
*     object can be a good thing.  As this is rare, the glyph slots are
*     listed through a direct, single-linked list using its `next` field.
*
*   glyph_index ::
*     [Since 2.10] The glyph index passed as an argument to @FT_Load_Glyph
*     while initializing the glyph slot.
*
*   generic ::
*     A typeless pointer unused by the FreeType library or any of its
*     drivers.  It can be used by client applications to link their own
*     data to each glyph slot object.
*
*   metrics ::
*     The metrics of the last loaded glyph in the slot.  The returned
*     values depend on the last load flags (see the @FT_Load_Glyph API
*     function) and can be expressed either in 26.6 fractional pixels or
*     font units.
*
*     Note that even when the glyph image is transformed, the metrics are
*     not.
*
*   linearHoriAdvance ::
*     The advance width of the unhinted glyph.  Its value is expressed in
*     16.16 fractional pixels, unless @FT_LOAD_LINEAR_DESIGN is set when
*     loading the glyph.  This field can be important to perform correct
*     WYSIWYG layout.  Only relevant for scalable glyphs.
*
*   linearVertAdvance ::
*     The advance height of the unhinted glyph.  Its value is expressed in
*     16.16 fractional pixels, unless @FT_LOAD_LINEAR_DESIGN is set when
*     loading the glyph.  This field can be important to perform correct
*     WYSIWYG layout.  Only relevant for scalable glyphs.
*
*   advance ::
*     This shorthand is, depending on @FT_LOAD_IGNORE_TRANSFORM, the
*     transformed (hinted) advance width for the glyph, in 26.6 fractional
*     pixel format.  As specified with @FT_LOAD_VERTICAL_LAYOUT, it uses
*     either the `horiAdvance` or the `vertAdvance` value of `metrics`
*     field.
*
*   format ::
*     This field indicates the format of the image contained in the glyph
*     slot.  Typically @FT_GLYPH_FORMAT_BITMAP, @FT_GLYPH_FORMAT_OUTLINE,
*     or @FT_GLYPH_FORMAT_COMPOSITE, but other values are possible.
*
*   bitmap ::
*     This field is used as a bitmap descriptor.  Note that the address
*     and content of the bitmap buffer can change between calls of
*     @FT_Load_Glyph and a few other functions.
*
*   bitmap_left ::
*     The bitmap's left bearing expressed in integer pixels.
*
*   bitmap_top ::
*     The bitmap's top bearing expressed in integer pixels.  This is the
*     distance from the baseline to the top-most glyph scanline, upwards
*     y~coordinates being **positive**.
*
*   outline ::
*     The outline descriptor for the current glyph image if its format is
*     @FT_GLYPH_FORMAT_OUTLINE.  Once a glyph is loaded, `outline` can be
*     transformed, distorted, emboldened, etc.  However, it must not be
*     freed.
*
*     [Since 2.10.1] If @FT_LOAD_NO_SCALE is set, outline coordinates of
*     OpenType Font Variations for a selected instance are internally
*     handled as 26.6 fractional font units but returned as (rounded)
*     integers, as expected.  To get unrounded font units, don't use
*     @FT_LOAD_NO_SCALE but load the glyph with @FT_LOAD_NO_HINTING and
*     scale it, using the font's `units_per_EM` value as the ppem.
*
*   num_subglyphs ::
*     The number of subglyphs in a composite glyph.  This field is only
*     valid for the composite glyph format that should normally only be
*     loaded with the @FT_LOAD_NO_RECURSE flag.
*
*   subglyphs ::
*     An array of subglyph descriptors for composite glyphs.  There are
*     `num_subglyphs` elements in there.  Currently internal to FreeType.
*
*   control_data ::
*     Certain font drivers can also return the control data for a given
*     glyph image (e.g.  TrueType bytecode, Type~1 charstrings, etc.).
*     This field is a pointer to such data; it is currently internal to
*     FreeType.
*
*   control_len ::
*     This is the length in bytes of the control data.  Currently internal
*     to FreeType.
*
*   other ::
*     Reserved.
*
*   lsb_delta ::
*     The difference between hinted and unhinted left side bearing while
*     auto-hinting is active.  Zero otherwise.
*
*   rsb_delta ::
*     The difference between hinted and unhinted right side bearing while
*     auto-hinting is active.  Zero otherwise.
*
* @note:
*   If @FT_Load_Glyph is called with default flags (see @FT_LOAD_DEFAULT)
*   the glyph image is loaded in the glyph slot in its native format
*   (e.g., an outline glyph for TrueType and Type~1 formats).  [Since 2.9]
*   The prospective bitmap metrics are calculated according to
*   @FT_LOAD_TARGET_XXX and other flags even for the outline glyph, even
*   if @FT_LOAD_RENDER is not set.
*
*   This image can later be converted into a bitmap by calling
*   @FT_Render_Glyph.  This function searches the current renderer for the
*   native image's format, then invokes it.
*
*   The renderer is in charge of transforming the native image through the
*   slot's face transformation fields, then converting it into a bitmap
*   that is returned in `slot->bitmap`.
*
*   Note that `slot->bitmap_left` and `slot->bitmap_top` are also used to
*   specify the position of the bitmap relative to the current pen
*   position (e.g., coordinates (0,0) on the baseline).  Of course,
*   `slot->format` is also changed to @FT_GLYPH_FORMAT_BITMAP.
*
*   Here is a small pseudo code fragment that shows how to use `lsb_delta`
*   and `rsb_delta` to do fractional positioning of glyphs:
*
*   ```
*     FT_GlyphSlot  slot     = face->glyph;
*     FT_Pos        origin_x = 0;
*
*
*     for all glyphs do
*       <load glyph with `FT_Load_Glyph'>
*
*       FT_Outline_Translate( slot->outline, origin_x & 63, 0 );
*
*       <save glyph image, or render glyph, or ...>
*
*       <compute kern between current and next glyph
*        and add it to `origin_x'>
*
*       origin_x += slot->advance.x;
*       origin_x += slot->lsb_delta - slot->rsb_delta;
*     endfor
*   ```
*
*   Here is another small pseudo code fragment that shows how to use
*   `lsb_delta` and `rsb_delta` to improve integer positioning of glyphs:
*
*   ```
*     FT_GlyphSlot  slot           = face->glyph;
*     FT_Pos        origin_x       = 0;
*     FT_Pos        prev_rsb_delta = 0;
*
*
*     for all glyphs do
*       <compute kern between current and previous glyph
*        and add it to `origin_x'>
*
*       <load glyph with `FT_Load_Glyph'>
*
*       if ( prev_rsb_delta - slot->lsb_delta >  32 )
*         origin_x -= 64;
*       else if ( prev_rsb_delta - slot->lsb_delta < -31 )
*         origin_x += 64;
*
*       prev_rsb_delta = slot->rsb_delta;
*
*       <save glyph image, or render glyph, or ...>
*
*       origin_x += slot->advance.x;
*     endfor
*   ```
*
*   If you use strong auto-hinting, you **must** apply these delta values!
*   Otherwise you will experience far too large inter-glyph spacing at
*   small rendering sizes in most cases.  Note that it doesn't harm to use
*   the above code for other hinting modes also, since the delta values
*   are zero then.
*/
FT_GlyphSlotRec :: FT_GlyphSlotRec_;

/**************************************************************************
*
* @function:
*   FT_Init_FreeType
*
* @description:
*   Initialize a new FreeType library object.  The set of modules that are
*   registered by this function is determined at build time.
*
* @output:
*   alibrary ::
*     A handle to a new library object.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   In case you want to provide your own memory allocating routines, use
*   @FT_New_Library instead, followed by a call to @FT_Add_Default_Modules
*   (or a series of calls to @FT_Add_Module) and
*   @FT_Set_Default_Properties.
*
*   See the documentation of @FT_Library and @FT_Face for multi-threading
*   issues.
*
*   If you need reference-counting (cf. @FT_Reference_Library), use
*   @FT_New_Library and @FT_Done_Library.
*
*   If compilation option `FT_CONFIG_OPTION_ENVIRONMENT_PROPERTIES` is
*   set, this function reads the `FREETYPE_PROPERTIES` environment
*   variable to control driver properties.  See section @properties for
*   more.
*/
FT_Init_FreeType :: (alibrary: *FT_Library) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Done_FreeType
*
* @description:
*   Destroy a given FreeType library object and all of its children,
*   including resources, drivers, faces, sizes, etc.
*
* @input:
*   library ::
*     A handle to the target library object.
*
* @return:
*   FreeType error code.  0~means success.
*/
FT_Done_FreeType :: (library: FT_Library) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @struct:
*   FT_Parameter
*
* @description:
*   A simple structure to pass more or less generic parameters to
*   @FT_Open_Face and @FT_Face_Properties.
*
* @fields:
*   tag ::
*     A four-byte identification tag.
*
*   data ::
*     A pointer to the parameter data.
*
* @note:
*   The ID and function of parameters are driver-specific.  See section
*   @parameter_tags for more information.
*/
FT_Parameter_ :: struct {
    tag:  FT_ULong;
    data: FT_Pointer;
}

/**************************************************************************
*
* @struct:
*   FT_Parameter
*
* @description:
*   A simple structure to pass more or less generic parameters to
*   @FT_Open_Face and @FT_Face_Properties.
*
* @fields:
*   tag ::
*     A four-byte identification tag.
*
*   data ::
*     A pointer to the parameter data.
*
* @note:
*   The ID and function of parameters are driver-specific.  See section
*   @parameter_tags for more information.
*/
FT_Parameter :: FT_Parameter_;

/**************************************************************************
*
* @struct:
*   FT_Open_Args
*
* @description:
*   A structure to indicate how to open a new font file or stream.  A
*   pointer to such a structure can be used as a parameter for the
*   functions @FT_Open_Face and @FT_Attach_Stream.
*
* @fields:
*   flags ::
*     A set of bit flags indicating how to use the structure.
*
*   memory_base ::
*     The first byte of the file in memory.
*
*   memory_size ::
*     The size in bytes of the file in memory.
*
*   pathname ::
*     A pointer to an 8-bit file pathname, which must be a C~string (i.e.,
*     no null bytes except at the very end).  The pointer is not owned by
*     FreeType.
*
*   stream ::
*     A handle to a source stream object.
*
*   driver ::
*     This field is exclusively used by @FT_Open_Face; it simply specifies
*     the font driver to use for opening the face.  If set to `NULL`,
*     FreeType tries to load the face with each one of the drivers in its
*     list.
*
*   num_params ::
*     The number of extra parameters.
*
*   params ::
*     Extra parameters passed to the font driver when opening a new face.
*
* @note:
*   The stream type is determined by the contents of `flags`:
*
*   If the @FT_OPEN_MEMORY bit is set, assume that this is a memory file
*   of `memory_size` bytes, located at `memory_address`.  The data are not
*   copied, and the client is responsible for releasing and destroying
*   them _after_ the corresponding call to @FT_Done_Face.
*
*   Otherwise, if the @FT_OPEN_STREAM bit is set, assume that a custom
*   input stream `stream` is used.
*
*   Otherwise, if the @FT_OPEN_PATHNAME bit is set, assume that this is a
*   normal file and use `pathname` to open it.
*
*   If none of the above bits are set or if multiple are set at the same
*   time, the flags are invalid and @FT_Open_Face fails.
*
*   If the @FT_OPEN_DRIVER bit is set, @FT_Open_Face only tries to open
*   the file with the driver whose handler is in `driver`.
*
*   If the @FT_OPEN_PARAMS bit is set, the parameters given by
*   `num_params` and `params` is used.  They are ignored otherwise.
*
*   Ideally, both the `pathname` and `params` fields should be tagged as
*   'const'; this is missing for API backward compatibility.  In other
*   words, applications should treat them as read-only.
*/
FT_Open_Args_ :: struct {
    flags:       FT_UInt;
    memory_base: *FT_Byte;
    memory_size: FT_Long;
    pathname:    *FT_String;
    stream:      FT_Stream;
    driver:      FT_Module;
    num_params:  FT_Int;
    params:      *FT_Parameter;
}

/**************************************************************************
*
* @struct:
*   FT_Open_Args
*
* @description:
*   A structure to indicate how to open a new font file or stream.  A
*   pointer to such a structure can be used as a parameter for the
*   functions @FT_Open_Face and @FT_Attach_Stream.
*
* @fields:
*   flags ::
*     A set of bit flags indicating how to use the structure.
*
*   memory_base ::
*     The first byte of the file in memory.
*
*   memory_size ::
*     The size in bytes of the file in memory.
*
*   pathname ::
*     A pointer to an 8-bit file pathname, which must be a C~string (i.e.,
*     no null bytes except at the very end).  The pointer is not owned by
*     FreeType.
*
*   stream ::
*     A handle to a source stream object.
*
*   driver ::
*     This field is exclusively used by @FT_Open_Face; it simply specifies
*     the font driver to use for opening the face.  If set to `NULL`,
*     FreeType tries to load the face with each one of the drivers in its
*     list.
*
*   num_params ::
*     The number of extra parameters.
*
*   params ::
*     Extra parameters passed to the font driver when opening a new face.
*
* @note:
*   The stream type is determined by the contents of `flags`:
*
*   If the @FT_OPEN_MEMORY bit is set, assume that this is a memory file
*   of `memory_size` bytes, located at `memory_address`.  The data are not
*   copied, and the client is responsible for releasing and destroying
*   them _after_ the corresponding call to @FT_Done_Face.
*
*   Otherwise, if the @FT_OPEN_STREAM bit is set, assume that a custom
*   input stream `stream` is used.
*
*   Otherwise, if the @FT_OPEN_PATHNAME bit is set, assume that this is a
*   normal file and use `pathname` to open it.
*
*   If none of the above bits are set or if multiple are set at the same
*   time, the flags are invalid and @FT_Open_Face fails.
*
*   If the @FT_OPEN_DRIVER bit is set, @FT_Open_Face only tries to open
*   the file with the driver whose handler is in `driver`.
*
*   If the @FT_OPEN_PARAMS bit is set, the parameters given by
*   `num_params` and `params` is used.  They are ignored otherwise.
*
*   Ideally, both the `pathname` and `params` fields should be tagged as
*   'const'; this is missing for API backward compatibility.  In other
*   words, applications should treat them as read-only.
*/
FT_Open_Args :: FT_Open_Args_;

/**************************************************************************
*
* @function:
*   FT_New_Face
*
* @description:
*   Call @FT_Open_Face to open a font by its pathname.
*
* @inout:
*   library ::
*     A handle to the library resource.
*
* @input:
*   pathname ::
*     A path to the font file.
*
*   face_index ::
*     See @FT_Open_Face for a detailed description of this parameter.
*
* @output:
*   aface ::
*     A handle to a new face object.  If `face_index` is greater than or
*     equal to zero, it must be non-`NULL`.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   The `pathname` string should be recognizable as such by a standard
*   `fopen` call on your system; in particular, this means that `pathname`
*   must not contain null bytes.  If that is not sufficient to address all
*   file name possibilities (for example, to handle wide character file
*   names on Windows in UTF-16 encoding) you might use @FT_Open_Face to
*   pass a memory array or a stream object instead.
*
*   Use @FT_Done_Face to destroy the created @FT_Face object (along with
*   its slot and sizes).
*/
FT_New_Face :: (library: FT_Library, filepathname: *u8, face_index: FT_Long, aface: *FT_Face) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_New_Memory_Face
*
* @description:
*   Call @FT_Open_Face to open a font that has been loaded into memory.
*
* @inout:
*   library ::
*     A handle to the library resource.
*
* @input:
*   file_base ::
*     A pointer to the beginning of the font data.
*
*   file_size ::
*     The size of the memory chunk used by the font data.
*
*   face_index ::
*     See @FT_Open_Face for a detailed description of this parameter.
*
* @output:
*   aface ::
*     A handle to a new face object.  If `face_index` is greater than or
*     equal to zero, it must be non-`NULL`.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   You must not deallocate the memory before calling @FT_Done_Face.
*/
FT_New_Memory_Face :: (library: FT_Library, file_base: *FT_Byte, file_size: FT_Long, face_index: FT_Long, aface: *FT_Face) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Open_Face
*
* @description:
*   Create a face object from a given resource described by @FT_Open_Args.
*
* @inout:
*   library ::
*     A handle to the library resource.
*
* @input:
*   args ::
*     A pointer to an `FT_Open_Args` structure that must be filled by the
*     caller.
*
*   face_index ::
*     This field holds two different values.  Bits 0-15 are the index of
*     the face in the font file (starting with value~0).  Set it to~0 if
*     there is only one face in the font file.
*
*     [Since 2.6.1] Bits 16-30 are relevant to TrueType GX and OpenType
*     Font Variations only, specifying the named instance index for the
*     current face index (starting with value~1; value~0 makes FreeType
*     ignore named instances).  For non-variation fonts, bits 16-30 are
*     ignored.  Assuming that you want to access the third named instance
*     in face~4, `face_index` should be set to 0x00030004.  If you want
*     to access face~4 without variation handling, simply set
*     `face_index` to value~4.
*
*     `FT_Open_Face` and its siblings can be used to quickly check whether
*     the font format of a given font resource is supported by FreeType.
*     In general, if the `face_index` argument is negative, the function's
*     return value is~0 if the font format is recognized, or non-zero
*     otherwise.  The function allocates a more or less empty face handle
*     in `*aface` (if `aface` isn't `NULL`); the only two useful fields in
*     this special case are `face->num_faces` and `face->style_flags`.
*     For any negative value of `face_index`, `face->num_faces` gives the
*     number of faces within the font file.  For the negative value
*     '-(N+1)' (with 'N' a non-negative 16-bit value), bits 16-30 in
*     `face->style_flags` give the number of named instances in face 'N'
*     if we have a variation font (or zero otherwise).  After examination,
*     the returned @FT_Face structure should be deallocated with a call to
*     @FT_Done_Face.
*
* @output:
*   aface ::
*     A handle to a new face object.  If `face_index` is greater than or
*     equal to zero, it must be non-`NULL`.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   Unlike FreeType 1.x, this function automatically creates a glyph slot
*   for the face object that can be accessed directly through
*   `face->glyph`.
*
*   Each new face object created with this function also owns a default
*   @FT_Size object, accessible as `face->size`.
*
*   One @FT_Library instance can have multiple face objects, that is,
*   @FT_Open_Face and its siblings can be called multiple times using the
*   same `library` argument.
*
*   See the discussion of reference counters in the description of
*   @FT_Reference_Face.
*
*   If `FT_OPEN_STREAM` is set in `args->flags`, the stream in
*   `args->stream` is automatically closed before this function returns
*   any error (including `FT_Err_Invalid_Argument`).
*
* @example:
*   To loop over all faces, use code similar to the following snippet
*   (omitting the error handling).
*
*   ```
*     ...
*     FT_Face  face;
*     FT_Long  i, num_faces;
*
*
*     error = FT_Open_Face( library, args, -1, &face );
*     if ( error ) { ... }
*
*     num_faces = face->num_faces;
*     FT_Done_Face( face );
*
*     for ( i = 0; i < num_faces; i++ )
*     {
*       ...
*       error = FT_Open_Face( library, args, i, &face );
*       ...
*       FT_Done_Face( face );
*       ...
*     }
*   ```
*
*   To loop over all valid values for `face_index`, use something similar
*   to the following snippet, again without error handling.  The code
*   accesses all faces immediately (thus only a single call of
*   `FT_Open_Face` within the do-loop), with and without named instances.
*
*   ```
*     ...
*     FT_Face  face;
*
*     FT_Long  num_faces     = 0;
*     FT_Long  num_instances = 0;
*
*     FT_Long  face_idx     = 0;
*     FT_Long  instance_idx = 0;
*
*
*     do
*     {
*       FT_Long  id = ( instance_idx << 16 ) + face_idx;
*
*
*       error = FT_Open_Face( library, args, id, &face );
*       if ( error ) { ... }
*
*       num_faces     = face->num_faces;
*       num_instances = face->style_flags >> 16;
*
*       ...
*
*       FT_Done_Face( face );
*
*       if ( instance_idx < num_instances )
*         instance_idx++;
*       else
*       {
*         face_idx++;
*         instance_idx = 0;
*       }
*
*     } while ( face_idx < num_faces )
*   ```
*/
FT_Open_Face :: (library: FT_Library, args: *FT_Open_Args, face_index: FT_Long, aface: *FT_Face) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Attach_File
*
* @description:
*   Call @FT_Attach_Stream to attach a file.
*
* @inout:
*   face ::
*     The target face object.
*
* @input:
*   filepathname ::
*     The pathname.
*
* @return:
*   FreeType error code.  0~means success.
*/
FT_Attach_File :: (face: FT_Face, filepathname: *u8) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Attach_Stream
*
* @description:
*   'Attach' data to a face object.  Normally, this is used to read
*   additional information for the face object.  For example, you can
*   attach an AFM file that comes with a Type~1 font to get the kerning
*   values and other metrics.
*
* @inout:
*   face ::
*     The target face object.
*
* @input:
*   parameters ::
*     A pointer to @FT_Open_Args that must be filled by the caller.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   The meaning of the 'attach' (i.e., what really happens when the new
*   file is read) is not fixed by FreeType itself.  It really depends on
*   the font format (and thus the font driver).
*
*   Client applications are expected to know what they are doing when
*   invoking this function.  Most drivers simply do not implement file or
*   stream attachments.
*/
FT_Attach_Stream :: (face: FT_Face, parameters: *FT_Open_Args) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Reference_Face
*
* @description:
*   A counter gets initialized to~1 at the time an @FT_Face structure is
*   created.  This function increments the counter.  @FT_Done_Face then
*   only destroys a face if the counter is~1, otherwise it simply
*   decrements the counter.
*
*   This function helps in managing life-cycles of structures that
*   reference @FT_Face objects.
*
* @input:
*   face ::
*     A handle to a target face object.
*
* @return:
*   FreeType error code.  0~means success.
*
* @since:
*   2.4.2
*
*/
FT_Reference_Face :: (face: FT_Face) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Done_Face
*
* @description:
*   Discard a given face object, as well as all of its child slots and
*   sizes.
*
* @input:
*   face ::
*     A handle to a target face object.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   See the discussion of reference counters in the description of
*   @FT_Reference_Face.
*/
FT_Done_Face :: (face: FT_Face) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Select_Size
*
* @description:
*   Select a bitmap strike.  To be more precise, this function sets the
*   scaling factors of the active @FT_Size object in a face so that
*   bitmaps from this particular strike are taken by @FT_Load_Glyph and
*   friends.
*
* @inout:
*   face ::
*     A handle to a target face object.
*
* @input:
*   strike_index ::
*     The index of the bitmap strike in the `available_sizes` field of
*     @FT_FaceRec structure.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   For bitmaps embedded in outline fonts it is common that only a subset
*   of the available glyphs at a given ppem value is available.  FreeType
*   silently uses outlines if there is no bitmap for a given glyph index.
*
*   For TrueType GX and OpenType Font Variations, a bitmap strike makes
*   sense only if the default instance is active (that is, no glyph
*   variation takes place); otherwise, FreeType simply ignores bitmap
*   strikes.  The same is true for all named instances that are different
*   from the default instance.
*
*   Don't use this function if you are using the FreeType cache API.
*/
FT_Select_Size :: (face: FT_Face, strike_index: FT_Int) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @enum:
*   FT_Size_Request_Type
*
* @description:
*   An enumeration type that lists the supported size request types, i.e.,
*   what input size (in font units) maps to the requested output size (in
*   pixels, as computed from the arguments of @FT_Size_Request).
*
* @values:
*   FT_SIZE_REQUEST_TYPE_NOMINAL ::
*     The nominal size.  The `units_per_EM` field of @FT_FaceRec is used
*     to determine both scaling values.
*
*     This is the standard scaling found in most applications.  In
*     particular, use this size request type for TrueType fonts if they
*     provide optical scaling or something similar.  Note, however, that
*     `units_per_EM` is a rather abstract value which bears no relation to
*     the actual size of the glyphs in a font.
*
*   FT_SIZE_REQUEST_TYPE_REAL_DIM ::
*     The real dimension.  The sum of the `ascender` and (minus of) the
*     `descender` fields of @FT_FaceRec is used to determine both scaling
*     values.
*
*   FT_SIZE_REQUEST_TYPE_BBOX ::
*     The font bounding box.  The width and height of the `bbox` field of
*     @FT_FaceRec are used to determine the horizontal and vertical
*     scaling value, respectively.
*
*   FT_SIZE_REQUEST_TYPE_CELL ::
*     The `max_advance_width` field of @FT_FaceRec is used to determine
*     the horizontal scaling value; the vertical scaling value is
*     determined the same way as @FT_SIZE_REQUEST_TYPE_REAL_DIM does.
*     Finally, both scaling values are set to the smaller one.  This type
*     is useful if you want to specify the font size for, say, a window of
*     a given dimension and 80x24 cells.
*
*   FT_SIZE_REQUEST_TYPE_SCALES ::
*     Specify the scaling values directly.
*
* @note:
*   The above descriptions only apply to scalable formats.  For bitmap
*   formats, the behaviour is up to the driver.
*
*   See the note section of @FT_Size_Metrics if you wonder how size
*   requesting relates to scaling values.
*/
FT_Size_Request_Type_ :: enum s32 {
    NOMINAL  :: 0;
    REAL_DIM :: 1;
    BBOX     :: 2;
    CELL     :: 3;
    SCALES   :: 4;

    MAX      :: 5;

    FT_SIZE_REQUEST_TYPE_NOMINAL  :: NOMINAL;
    FT_SIZE_REQUEST_TYPE_REAL_DIM :: REAL_DIM;
    FT_SIZE_REQUEST_TYPE_BBOX     :: BBOX;
    FT_SIZE_REQUEST_TYPE_CELL     :: CELL;
    FT_SIZE_REQUEST_TYPE_SCALES   :: SCALES;

    FT_SIZE_REQUEST_TYPE_MAX      :: MAX;
}

/**************************************************************************
*
* @enum:
*   FT_Size_Request_Type
*
* @description:
*   An enumeration type that lists the supported size request types, i.e.,
*   what input size (in font units) maps to the requested output size (in
*   pixels, as computed from the arguments of @FT_Size_Request).
*
* @values:
*   FT_SIZE_REQUEST_TYPE_NOMINAL ::
*     The nominal size.  The `units_per_EM` field of @FT_FaceRec is used
*     to determine both scaling values.
*
*     This is the standard scaling found in most applications.  In
*     particular, use this size request type for TrueType fonts if they
*     provide optical scaling or something similar.  Note, however, that
*     `units_per_EM` is a rather abstract value which bears no relation to
*     the actual size of the glyphs in a font.
*
*   FT_SIZE_REQUEST_TYPE_REAL_DIM ::
*     The real dimension.  The sum of the `ascender` and (minus of) the
*     `descender` fields of @FT_FaceRec is used to determine both scaling
*     values.
*
*   FT_SIZE_REQUEST_TYPE_BBOX ::
*     The font bounding box.  The width and height of the `bbox` field of
*     @FT_FaceRec are used to determine the horizontal and vertical
*     scaling value, respectively.
*
*   FT_SIZE_REQUEST_TYPE_CELL ::
*     The `max_advance_width` field of @FT_FaceRec is used to determine
*     the horizontal scaling value; the vertical scaling value is
*     determined the same way as @FT_SIZE_REQUEST_TYPE_REAL_DIM does.
*     Finally, both scaling values are set to the smaller one.  This type
*     is useful if you want to specify the font size for, say, a window of
*     a given dimension and 80x24 cells.
*
*   FT_SIZE_REQUEST_TYPE_SCALES ::
*     Specify the scaling values directly.
*
* @note:
*   The above descriptions only apply to scalable formats.  For bitmap
*   formats, the behaviour is up to the driver.
*
*   See the note section of @FT_Size_Metrics if you wonder how size
*   requesting relates to scaling values.
*/
FT_Size_Request_Type :: FT_Size_Request_Type_;

/**************************************************************************
*
* @struct:
*   FT_Size_RequestRec
*
* @description:
*   A structure to model a size request.
*
* @fields:
*   type ::
*     See @FT_Size_Request_Type.
*
*   width ::
*     The desired width, given as a 26.6 fractional point value (with 72pt
*     = 1in).
*
*   height ::
*     The desired height, given as a 26.6 fractional point value (with
*     72pt = 1in).
*
*   horiResolution ::
*     The horizontal resolution (dpi, i.e., pixels per inch).  If set to
*     zero, `width` is treated as a 26.6 fractional **pixel** value, which
*     gets internally rounded to an integer.
*
*   vertResolution ::
*     The vertical resolution (dpi, i.e., pixels per inch).  If set to
*     zero, `height` is treated as a 26.6 fractional **pixel** value,
*     which gets internally rounded to an integer.
*
* @note:
*   If `width` is zero, the horizontal scaling value is set equal to the
*   vertical scaling value, and vice versa.
*
*   If `type` is `FT_SIZE_REQUEST_TYPE_SCALES`, `width` and `height` are
*   interpreted directly as 16.16 fractional scaling values, without any
*   further modification, and both `horiResolution` and `vertResolution`
*   are ignored.
*/
FT_Size_RequestRec_ :: struct {
    type:           FT_Size_Request_Type;
    width:          FT_Long;
    height:         FT_Long;
    horiResolution: FT_UInt;
    vertResolution: FT_UInt;
}

/**************************************************************************
*
* @struct:
*   FT_Size_RequestRec
*
* @description:
*   A structure to model a size request.
*
* @fields:
*   type ::
*     See @FT_Size_Request_Type.
*
*   width ::
*     The desired width, given as a 26.6 fractional point value (with 72pt
*     = 1in).
*
*   height ::
*     The desired height, given as a 26.6 fractional point value (with
*     72pt = 1in).
*
*   horiResolution ::
*     The horizontal resolution (dpi, i.e., pixels per inch).  If set to
*     zero, `width` is treated as a 26.6 fractional **pixel** value, which
*     gets internally rounded to an integer.
*
*   vertResolution ::
*     The vertical resolution (dpi, i.e., pixels per inch).  If set to
*     zero, `height` is treated as a 26.6 fractional **pixel** value,
*     which gets internally rounded to an integer.
*
* @note:
*   If `width` is zero, the horizontal scaling value is set equal to the
*   vertical scaling value, and vice versa.
*
*   If `type` is `FT_SIZE_REQUEST_TYPE_SCALES`, `width` and `height` are
*   interpreted directly as 16.16 fractional scaling values, without any
*   further modification, and both `horiResolution` and `vertResolution`
*   are ignored.
*/
FT_Size_RequestRec :: FT_Size_RequestRec_;

/**************************************************************************
*
* @struct:
*   FT_Size_Request
*
* @description:
*   A handle to a size request structure.
*/
FT_Size_Request :: *FT_Size_RequestRec_;

/**************************************************************************
*
* @function:
*   FT_Request_Size
*
* @description:
*   Resize the scale of the active @FT_Size object in a face.
*
* @inout:
*   face ::
*     A handle to a target face object.
*
* @input:
*   req ::
*     A pointer to a @FT_Size_RequestRec.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   Although drivers may select the bitmap strike matching the request,
*   you should not rely on this if you intend to select a particular
*   bitmap strike.  Use @FT_Select_Size instead in that case.
*
*   The relation between the requested size and the resulting glyph size
*   is dependent entirely on how the size is defined in the source face.
*   The font designer chooses the final size of each glyph relative to
*   this size.  For more information refer to
*   'https://freetype.org/freetype2/docs/glyphs/glyphs-2.html'.
*
*   Contrary to @FT_Set_Char_Size, this function doesn't have special code
*   to normalize zero-valued widths, heights, or resolutions, which are
*   treated as @FT_LOAD_NO_SCALE.
*
*   Don't use this function if you are using the FreeType cache API.
*/
FT_Request_Size :: (face: FT_Face, req: FT_Size_Request) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Set_Char_Size
*
* @description:
*   Call @FT_Request_Size to request the nominal size (in points).
*
* @inout:
*   face ::
*     A handle to a target face object.
*
* @input:
*   char_width ::
*     The nominal width, in 26.6 fractional points.
*
*   char_height ::
*     The nominal height, in 26.6 fractional points.
*
*   horz_resolution ::
*     The horizontal resolution in dpi.
*
*   vert_resolution ::
*     The vertical resolution in dpi.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   While this function allows fractional points as input values, the
*   resulting ppem value for the given resolution is always rounded to the
*   nearest integer.
*
*   If either the character width or height is zero, it is set equal to
*   the other value.
*
*   If either the horizontal or vertical resolution is zero, it is set
*   equal to the other value.
*
*   A character width or height smaller than 1pt is set to 1pt; if both
*   resolution values are zero, they are set to 72dpi.
*
*   Don't use this function if you are using the FreeType cache API.
*/
FT_Set_Char_Size :: (face: FT_Face, char_width: FT_F26Dot6, char_height: FT_F26Dot6, horz_resolution: FT_UInt, vert_resolution: FT_UInt) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Set_Pixel_Sizes
*
* @description:
*   Call @FT_Request_Size to request the nominal size (in pixels).
*
* @inout:
*   face ::
*     A handle to the target face object.
*
* @input:
*   pixel_width ::
*     The nominal width, in pixels.
*
*   pixel_height ::
*     The nominal height, in pixels.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   You should not rely on the resulting glyphs matching or being
*   constrained to this pixel size.  Refer to @FT_Request_Size to
*   understand how requested sizes relate to actual sizes.
*
*   Don't use this function if you are using the FreeType cache API.
*/
FT_Set_Pixel_Sizes :: (face: FT_Face, pixel_width: FT_UInt, pixel_height: FT_UInt) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Load_Glyph
*
* @description:
*   Load a glyph into the glyph slot of a face object.
*
* @inout:
*   face ::
*     A handle to the target face object where the glyph is loaded.
*
* @input:
*   glyph_index ::
*     The index of the glyph in the font file.  For CID-keyed fonts
*     (either in PS or in CFF format) this argument specifies the CID
*     value.
*
*   load_flags ::
*     A flag indicating what to load for this glyph.  The @FT_LOAD_XXX
*     flags can be used to control the glyph loading process (e.g.,
*     whether the outline should be scaled, whether to load bitmaps or
*     not, whether to hint the outline, etc).
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   For proper scaling and hinting, the active @FT_Size object owned by
*   the face has to be meaningfully initialized by calling
*   @FT_Set_Char_Size before this function, for example.  The loaded
*   glyph may be transformed.  See @FT_Set_Transform for the details.
*
*   For subsetted CID-keyed fonts, `FT_Err_Invalid_Argument` is returned
*   for invalid CID values (that is, for CID values that don't have a
*   corresponding glyph in the font).  See the discussion of the
*   @FT_FACE_FLAG_CID_KEYED flag for more details.
*
*   If you receive `FT_Err_Glyph_Too_Big`, try getting the glyph outline
*   at EM size, then scale it manually and fill it as a graphics
*   operation.
*/
FT_Load_Glyph :: (face: FT_Face, glyph_index: FT_UInt, load_flags: FT_Int32) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Load_Char
*
* @description:
*   Load a glyph into the glyph slot of a face object, accessed by its
*   character code.
*
* @inout:
*   face ::
*     A handle to a target face object where the glyph is loaded.
*
* @input:
*   char_code ::
*     The glyph's character code, according to the current charmap used in
*     the face.
*
*   load_flags ::
*     A flag indicating what to load for this glyph.  The @FT_LOAD_XXX
*     constants can be used to control the glyph loading process (e.g.,
*     whether the outline should be scaled, whether to load bitmaps or
*     not, whether to hint the outline, etc).
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   This function simply calls @FT_Get_Char_Index and @FT_Load_Glyph.
*
*   Many fonts contain glyphs that can't be loaded by this function since
*   its glyph indices are not listed in any of the font's charmaps.
*
*   If no active cmap is set up (i.e., `face->charmap` is zero), the call
*   to @FT_Get_Char_Index is omitted, and the function behaves identically
*   to @FT_Load_Glyph.
*/
FT_Load_Char :: (face: FT_Face, char_code: FT_ULong, load_flags: FT_Int32) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Set_Transform
*
* @description:
*   Set the transformation that is applied to glyph images when they are
*   loaded into a glyph slot through @FT_Load_Glyph.
*
* @inout:
*   face ::
*     A handle to the source face object.
*
* @input:
*   matrix ::
*     A pointer to the transformation's 2x2 matrix.  Use `NULL` for the
*     identity matrix.
*   delta ::
*     A pointer to the translation vector.  Use `NULL` for the null
*     vector.
*
* @note:
*   This function is provided as a convenience, but keep in mind that
*   @FT_Matrix coefficients are only 16.16 fixed-point values, which can
*   limit the accuracy of the results.  Using floating-point computations
*   to perform the transform directly in client code instead will always
*   yield better numbers.
*
*   The transformation is only applied to scalable image formats after the
*   glyph has been loaded.  It means that hinting is unaltered by the
*   transformation and is performed on the character size given in the
*   last call to @FT_Set_Char_Size or @FT_Set_Pixel_Sizes.
*
*   Note that this also transforms the `face.glyph.advance` field, but
*   **not** the values in `face.glyph.metrics`.
*/
FT_Set_Transform :: (face: FT_Face, matrix: *FT_Matrix, delta: *FT_Vector) -> void #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Transform
*
* @description:
*   Return the transformation that is applied to glyph images when they
*   are loaded into a glyph slot through @FT_Load_Glyph.  See
*   @FT_Set_Transform for more details.
*
* @input:
*   face ::
*     A handle to the source face object.
*
* @output:
*   matrix ::
*     A pointer to a transformation's 2x2 matrix.  Set this to NULL if you
*     are not interested in the value.
*
*   delta ::
*     A pointer to a translation vector.  Set this to NULL if you are not
*     interested in the value.
*
* @since:
*   2.11
*
*/
FT_Get_Transform :: (face: FT_Face, matrix: *FT_Matrix, delta: *FT_Vector) -> void #foreign freetype;

/**************************************************************************
*
* @enum:
*   FT_Render_Mode
*
* @description:
*   Render modes supported by FreeType~2.  Each mode corresponds to a
*   specific type of scanline conversion performed on the outline.
*
*   For bitmap fonts and embedded bitmaps the `bitmap->pixel_mode` field
*   in the @FT_GlyphSlotRec structure gives the format of the returned
*   bitmap.
*
*   All modes except @FT_RENDER_MODE_MONO use 256 levels of opacity,
*   indicating pixel coverage.  Use linear alpha blending and gamma
*   correction to correctly render non-monochrome glyph bitmaps onto a
*   surface; see @FT_Render_Glyph.
*
*   The @FT_RENDER_MODE_SDF is a special render mode that uses up to 256
*   distance values, indicating the signed distance from the grid position
*   to the nearest outline.
*
* @values:
*   FT_RENDER_MODE_NORMAL ::
*     Default render mode; it corresponds to 8-bit anti-aliased bitmaps.
*
*   FT_RENDER_MODE_LIGHT ::
*     This is equivalent to @FT_RENDER_MODE_NORMAL.  It is only defined as
*     a separate value because render modes are also used indirectly to
*     define hinting algorithm selectors.  See @FT_LOAD_TARGET_XXX for
*     details.
*
*   FT_RENDER_MODE_MONO ::
*     This mode corresponds to 1-bit bitmaps (with 2~levels of opacity).
*
*   FT_RENDER_MODE_LCD ::
*     This mode corresponds to horizontal RGB and BGR subpixel displays
*     like LCD screens.  It produces 8-bit bitmaps that are 3~times the
*     width of the original glyph outline in pixels, and which use the
*     @FT_PIXEL_MODE_LCD mode.
*
*   FT_RENDER_MODE_LCD_V ::
*     This mode corresponds to vertical RGB and BGR subpixel displays
*     (like PDA screens, rotated LCD displays, etc.).  It produces 8-bit
*     bitmaps that are 3~times the height of the original glyph outline in
*     pixels and use the @FT_PIXEL_MODE_LCD_V mode.
*
*   FT_RENDER_MODE_SDF ::
*     The positive (unsigned) 8-bit bitmap values can be converted to the
*     single-channel signed distance field (SDF) by subtracting 128, with
*     the positive and negative results corresponding to the inside and
*     the outside of a glyph contour, respectively.  The distance units are
*     arbitrarily determined by an adjustable @spread property.
*
* @note:
*   The selected render mode only affects scalable vector glyphs of a font.
*   Embedded bitmaps often have a different pixel mode like
*   @FT_PIXEL_MODE_MONO.  You can use @FT_Bitmap_Convert to transform them
*   into 8-bit pixmaps.
*
*/
FT_Render_Mode_ :: enum s32 {
    NORMAL :: 0;
    LIGHT  :: 1;
    MONO   :: 2;
    LCD    :: 3;
    LCD_V  :: 4;
    SDF    :: 5;

    MAX    :: 6;

    FT_RENDER_MODE_NORMAL :: NORMAL;
    FT_RENDER_MODE_LIGHT  :: LIGHT;
    FT_RENDER_MODE_MONO   :: MONO;
    FT_RENDER_MODE_LCD    :: LCD;
    FT_RENDER_MODE_LCD_V  :: LCD_V;
    FT_RENDER_MODE_SDF    :: SDF;

    FT_RENDER_MODE_MAX    :: MAX;
}

/**************************************************************************
*
* @enum:
*   FT_Render_Mode
*
* @description:
*   Render modes supported by FreeType~2.  Each mode corresponds to a
*   specific type of scanline conversion performed on the outline.
*
*   For bitmap fonts and embedded bitmaps the `bitmap->pixel_mode` field
*   in the @FT_GlyphSlotRec structure gives the format of the returned
*   bitmap.
*
*   All modes except @FT_RENDER_MODE_MONO use 256 levels of opacity,
*   indicating pixel coverage.  Use linear alpha blending and gamma
*   correction to correctly render non-monochrome glyph bitmaps onto a
*   surface; see @FT_Render_Glyph.
*
*   The @FT_RENDER_MODE_SDF is a special render mode that uses up to 256
*   distance values, indicating the signed distance from the grid position
*   to the nearest outline.
*
* @values:
*   FT_RENDER_MODE_NORMAL ::
*     Default render mode; it corresponds to 8-bit anti-aliased bitmaps.
*
*   FT_RENDER_MODE_LIGHT ::
*     This is equivalent to @FT_RENDER_MODE_NORMAL.  It is only defined as
*     a separate value because render modes are also used indirectly to
*     define hinting algorithm selectors.  See @FT_LOAD_TARGET_XXX for
*     details.
*
*   FT_RENDER_MODE_MONO ::
*     This mode corresponds to 1-bit bitmaps (with 2~levels of opacity).
*
*   FT_RENDER_MODE_LCD ::
*     This mode corresponds to horizontal RGB and BGR subpixel displays
*     like LCD screens.  It produces 8-bit bitmaps that are 3~times the
*     width of the original glyph outline in pixels, and which use the
*     @FT_PIXEL_MODE_LCD mode.
*
*   FT_RENDER_MODE_LCD_V ::
*     This mode corresponds to vertical RGB and BGR subpixel displays
*     (like PDA screens, rotated LCD displays, etc.).  It produces 8-bit
*     bitmaps that are 3~times the height of the original glyph outline in
*     pixels and use the @FT_PIXEL_MODE_LCD_V mode.
*
*   FT_RENDER_MODE_SDF ::
*     The positive (unsigned) 8-bit bitmap values can be converted to the
*     single-channel signed distance field (SDF) by subtracting 128, with
*     the positive and negative results corresponding to the inside and
*     the outside of a glyph contour, respectively.  The distance units are
*     arbitrarily determined by an adjustable @spread property.
*
* @note:
*   The selected render mode only affects scalable vector glyphs of a font.
*   Embedded bitmaps often have a different pixel mode like
*   @FT_PIXEL_MODE_MONO.  You can use @FT_Bitmap_Convert to transform them
*   into 8-bit pixmaps.
*
*/
FT_Render_Mode :: FT_Render_Mode_;

/**************************************************************************
*
* @function:
*   FT_Render_Glyph
*
* @description:
*   Convert a given glyph image to a bitmap.  It does so by inspecting the
*   glyph image format, finding the relevant renderer, and invoking it.
*
* @inout:
*   slot ::
*     A handle to the glyph slot containing the image to convert.
*
* @input:
*   render_mode ::
*     The render mode used to render the glyph image into a bitmap.  See
*     @FT_Render_Mode for a list of possible values.
*
*     If @FT_RENDER_MODE_NORMAL is used, a previous call of @FT_Load_Glyph
*     with flag @FT_LOAD_COLOR makes `FT_Render_Glyph` provide a default
*     blending of colored glyph layers associated with the current glyph
*     slot (provided the font contains such layers) instead of rendering
*     the glyph slot's outline.  This is an experimental feature; see
*     @FT_LOAD_COLOR for more information.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   When FreeType outputs a bitmap of a glyph, it really outputs an alpha
*   coverage map.  If a pixel is completely covered by a filled-in
*   outline, the bitmap contains 0xFF at that pixel, meaning that
*   0xFF/0xFF fraction of that pixel is covered, meaning the pixel is 100%
*   black (or 0% bright).  If a pixel is only 50% covered (value 0x80),
*   the pixel is made 50% black (50% bright or a middle shade of grey).
*   0% covered means 0% black (100% bright or white).
*
*   On high-DPI screens like on smartphones and tablets, the pixels are so
*   small that their chance of being completely covered and therefore
*   completely black are fairly good.  On the low-DPI screens, however,
*   the situation is different.  The pixels are too large for most of the
*   details of a glyph and shades of gray are the norm rather than the
*   exception.
*
*   This is relevant because all our screens have a second problem: they
*   are not linear.  1~+~1 is not~2.  Twice the value does not result in
*   twice the brightness.  When a pixel is only 50% covered, the coverage
*   map says 50% black, and this translates to a pixel value of 128 when
*   you use 8~bits per channel (0-255).  However, this does not translate
*   to 50% brightness for that pixel on our sRGB and gamma~2.2 screens.
*   Due to their non-linearity, they dwell longer in the darks and only a
*   pixel value of about 186 results in 50% brightness -- 128 ends up too
*   dark on both bright and dark backgrounds.  The net result is that dark
*   text looks burnt-out, pixely and blotchy on bright background, bright
*   text too frail on dark backgrounds, and colored text on colored
*   background (for example, red on green) seems to have dark halos or
*   'dirt' around it.  The situation is especially ugly for diagonal stems
*   like in 'w' glyph shapes where the quality of FreeType's anti-aliasing
*   depends on the correct display of grays.  On high-DPI screens where
*   smaller, fully black pixels reign supreme, this doesn't matter, but on
*   our low-DPI screens with all the gray shades, it does.  0% and 100%
*   brightness are the same things in linear and non-linear space, just
*   all the shades in-between aren't.
*
*   The blending function for placing text over a background is
*
*   ```
*     dst = alpha * src + (1 - alpha) * dst    ,
*   ```
*
*   which is known as the OVER operator.
*
*   To correctly composite an anti-aliased pixel of a glyph onto a
*   surface,
*
*   1. take the foreground and background colors (e.g., in sRGB space)
*      and apply gamma to get them in a linear space,
*
*   2. use OVER to blend the two linear colors using the glyph pixel
*      as the alpha value (remember, the glyph bitmap is an alpha coverage
*      bitmap), and
*
*   3. apply inverse gamma to the blended pixel and write it back to
*      the image.
*
*   Internal testing at Adobe found that a target inverse gamma of~1.8 for
*   step~3 gives good results across a wide range of displays with an sRGB
*   gamma curve or a similar one.
*
*   This process can cost performance.  There is an approximation that
*   does not need to know about the background color; see
*   https://web.archive.org/web/20211019204945/https://bel.fi/alankila/lcd/
*   and
*   https://web.archive.org/web/20210211002939/https://bel.fi/alankila/lcd/alpcor.html
*   for details.
*
*   **ATTENTION**: Linear blending is even more important when dealing
*   with subpixel-rendered glyphs to prevent color-fringing!  A
*   subpixel-rendered glyph must first be filtered with a filter that
*   gives equal weight to the three color primaries and does not exceed a
*   sum of 0x100, see section @lcd_rendering.  Then the only difference to
*   gray linear blending is that subpixel-rendered linear blending is done
*   3~times per pixel: red foreground subpixel to red background subpixel
*   and so on for green and blue.
*/
FT_Render_Glyph :: (slot: FT_GlyphSlot, render_mode: FT_Render_Mode) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @enum:
*   FT_Kerning_Mode
*
* @description:
*   An enumeration to specify the format of kerning values returned by
*   @FT_Get_Kerning.
*
* @values:
*   FT_KERNING_DEFAULT ::
*     Return grid-fitted kerning distances in 26.6 fractional pixels.
*
*   FT_KERNING_UNFITTED ::
*     Return un-grid-fitted kerning distances in 26.6 fractional pixels.
*
*   FT_KERNING_UNSCALED ::
*     Return the kerning vector in original font units.
*
* @note:
*   `FT_KERNING_DEFAULT` returns full pixel values; it also makes FreeType
*   heuristically scale down kerning distances at small ppem values so
*   that they don't become too big.
*
*   Both `FT_KERNING_DEFAULT` and `FT_KERNING_UNFITTED` use the current
*   horizontal scaling factor (as set e.g. with @FT_Set_Char_Size) to
*   convert font units to pixels.
*/
FT_Kerning_Mode_ :: enum s32 {
    DEFAULT  :: 0;
    UNFITTED :: 1;
    UNSCALED :: 2;

    FT_KERNING_DEFAULT  :: DEFAULT;
    FT_KERNING_UNFITTED :: UNFITTED;
    FT_KERNING_UNSCALED :: UNSCALED;
}

/**************************************************************************
*
* @enum:
*   FT_Kerning_Mode
*
* @description:
*   An enumeration to specify the format of kerning values returned by
*   @FT_Get_Kerning.
*
* @values:
*   FT_KERNING_DEFAULT ::
*     Return grid-fitted kerning distances in 26.6 fractional pixels.
*
*   FT_KERNING_UNFITTED ::
*     Return un-grid-fitted kerning distances in 26.6 fractional pixels.
*
*   FT_KERNING_UNSCALED ::
*     Return the kerning vector in original font units.
*
* @note:
*   `FT_KERNING_DEFAULT` returns full pixel values; it also makes FreeType
*   heuristically scale down kerning distances at small ppem values so
*   that they don't become too big.
*
*   Both `FT_KERNING_DEFAULT` and `FT_KERNING_UNFITTED` use the current
*   horizontal scaling factor (as set e.g. with @FT_Set_Char_Size) to
*   convert font units to pixels.
*/
FT_Kerning_Mode :: FT_Kerning_Mode_;

/**************************************************************************
*
* @function:
*   FT_Get_Kerning
*
* @description:
*   Return the kerning vector between two glyphs of the same face.
*
* @input:
*   face ::
*     A handle to a source face object.
*
*   left_glyph ::
*     The index of the left glyph in the kern pair.
*
*   right_glyph ::
*     The index of the right glyph in the kern pair.
*
*   kern_mode ::
*     See @FT_Kerning_Mode for more information.  Determines the scale and
*     dimension of the returned kerning vector.
*
* @output:
*   akerning ::
*     The kerning vector.  This is either in font units, fractional pixels
*     (26.6 format), or pixels for scalable formats, and in pixels for
*     fixed-sizes formats.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   Only horizontal layouts (left-to-right & right-to-left) are supported
*   by this method.  Other layouts, or more sophisticated kernings, are
*   out of the scope of this API function -- they can be implemented
*   through format-specific interfaces.
*
*   Note that, for TrueType and OpenType fonts only, this can extract data
*   from both the 'kern' table and the basic, pair-wise kerning feature
*   from the GPOS table (with `TT_CONFIG_OPTION_GPOS_KERNING` enabled),
*   though FreeType does not support the more advanced GPOS layout
*   features; use a library like HarfBuzz for those instead.  If a font
*   has both a 'kern' table and kern features of a GPOS table, the 'kern'
*   table will be used.
*
*   Also note for right-to-left scripts, the functionality may differ for
*   fonts with GPOS tables vs. 'kern' tables.  For GPOS, right-to-left
*   fonts typically use both a placement offset and an advance for pair
*   positioning, which this API does not support, so it would output
*   kerning values of zero; though if the right-to-left font used only
*   advances in GPOS pair positioning, then this API could output kerning
*   values for it, but it would use `left_glyph` to mean the first glyph
*   for that case.  Whereas 'kern' tables are always advance-only and
*   always store the left glyph first.
*
*   Use @FT_HAS_KERNING to find out whether a font has data that can be
*   extracted with `FT_Get_Kerning`.
*/
FT_Get_Kerning :: (face: FT_Face, left_glyph: FT_UInt, right_glyph: FT_UInt, kern_mode: FT_UInt, akerning: *FT_Vector) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Track_Kerning
*
* @description:
*   Return the track kerning for a given face object at a given size.
*
* @input:
*   face ::
*     A handle to a source face object.
*
*   point_size ::
*     The point size in 16.16 fractional points.
*
*   degree ::
*     The degree of tightness.  Increasingly negative values represent
*     tighter track kerning, while increasingly positive values represent
*     looser track kerning.  Value zero means no track kerning.
*
* @output:
*   akerning ::
*     The kerning in 16.16 fractional points, to be uniformly applied
*     between all glyphs.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   Currently, only the Type~1 font driver supports track kerning, using
*   data from AFM files (if attached with @FT_Attach_File or
*   @FT_Attach_Stream).
*
*   Only very few AFM files come with track kerning data; please refer to
*   Adobe's AFM specification for more details.
*/
FT_Get_Track_Kerning :: (face: FT_Face, point_size: FT_Fixed, degree: FT_Int, akerning: *FT_Fixed) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Select_Charmap
*
* @description:
*   Select a given charmap by its encoding tag (as listed in
*   `freetype.h`).
*
* @inout:
*   face ::
*     A handle to the source face object.
*
* @input:
*   encoding ::
*     A handle to the selected encoding.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   This function returns an error if no charmap in the face corresponds
*   to the encoding queried here.
*
*   Because many fonts contain more than a single cmap for Unicode
*   encoding, this function has some special code to select the one that
*   covers Unicode best ('best' in the sense that a UCS-4 cmap is
*   preferred to a UCS-2 cmap).  It is thus preferable to @FT_Set_Charmap
*   in this case.
*/
FT_Select_Charmap :: (face: FT_Face, encoding: FT_Encoding) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Set_Charmap
*
* @description:
*   Select a given charmap for character code to glyph index mapping.
*
* @inout:
*   face ::
*     A handle to the source face object.
*
* @input:
*   charmap ::
*     A handle to the selected charmap.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   This function returns an error if the charmap is not part of the face
*   (i.e., if it is not listed in the `face->charmaps` table).
*
*   It also fails if an OpenType type~14 charmap is selected (which
*   doesn't map character codes to glyph indices at all).
*/
FT_Set_Charmap :: (face: FT_Face, charmap: FT_CharMap) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Charmap_Index
*
* @description:
*   Retrieve index of a given charmap.
*
* @input:
*   charmap ::
*     A handle to a charmap.
*
* @return:
*   The index into the array of character maps within the face to which
*   `charmap` belongs.  If an error occurs, -1 is returned.
*
*/
FT_Get_Charmap_Index :: (charmap: FT_CharMap) -> FT_Int #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Char_Index
*
* @description:
*   Return the glyph index of a given character code.  This function uses
*   the currently selected charmap to do the mapping.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   charcode ::
*     The character code.
*
* @return:
*   The glyph index.  0~means 'undefined character code'.
*
* @note:
*   If you use FreeType to manipulate the contents of font files directly,
*   be aware that the glyph index returned by this function doesn't always
*   correspond to the internal indices used within the file.  This is done
*   to ensure that value~0 always corresponds to the 'missing glyph'.  If
*   the first glyph is not named '.notdef', then for Type~1 and Type~42
*   fonts, '.notdef' will be moved into the glyph ID~0 position, and
*   whatever was there will be moved to the position '.notdef' had.  For
*   Type~1 fonts, if there is no '.notdef' glyph at all, then one will be
*   created at index~0 and whatever was there will be moved to the last
*   index -- Type~42 fonts are considered invalid under this condition.
*/
FT_Get_Char_Index :: (face: FT_Face, charcode: FT_ULong) -> FT_UInt #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_First_Char
*
* @description:
*   Return the first character code in the current charmap of a given
*   face, together with its corresponding glyph index.
*
* @input:
*   face ::
*     A handle to the source face object.
*
* @output:
*   agindex ::
*     Glyph index of first character code.  0~if charmap is empty.
*
* @return:
*   The charmap's first character code.
*
* @note:
*   You should use this function together with @FT_Get_Next_Char to parse
*   all character codes available in a given charmap.  The code should
*   look like this:
*
*   ```
*     FT_ULong  charcode;
*     FT_UInt   gindex;
*
*
*     charcode = FT_Get_First_Char( face, &gindex );
*     while ( gindex != 0 )
*     {
*       ... do something with (charcode,gindex) pair ...
*
*       charcode = FT_Get_Next_Char( face, charcode, &gindex );
*     }
*   ```
*
*   Be aware that character codes can have values up to 0xFFFFFFFF; this
*   might happen for non-Unicode or malformed cmaps.  However, even with
*   regular Unicode encoding, so-called 'last resort fonts' (using SFNT
*   cmap format 13, see function @FT_Get_CMap_Format) normally have
*   entries for all Unicode characters up to 0x1FFFFF, which can cause *a
*   lot* of iterations.
*
*   Note that `*agindex` is set to~0 if the charmap is empty.  The result
*   itself can be~0 in two cases: if the charmap is empty or if the
*   value~0 is the first valid character code.
*/
FT_Get_First_Char :: (face: FT_Face, agindex: *FT_UInt) -> FT_ULong #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Next_Char
*
* @description:
*   Return the next character code in the current charmap of a given face
*   following the value `char_code`, as well as the corresponding glyph
*   index.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   char_code ::
*     The starting character code.
*
* @output:
*   agindex ::
*     Glyph index of next character code.  0~if charmap is empty.
*
* @return:
*   The charmap's next character code.
*
* @note:
*   You should use this function with @FT_Get_First_Char to walk over all
*   character codes available in a given charmap.  See the note for that
*   function for a simple code example.
*
*   Note that `*agindex` is set to~0 when there are no more codes in the
*   charmap.
*/
FT_Get_Next_Char :: (face: FT_Face, char_code: FT_ULong, agindex: *FT_UInt) -> FT_ULong #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_Properties
*
* @description:
*   Set or override certain (library or module-wide) properties on a
*   face-by-face basis.  Useful for finer-grained control and avoiding
*   locks on shared structures (threads can modify their own faces as they
*   see fit).
*
*   Contrary to @FT_Property_Set, this function uses @FT_Parameter so that
*   you can pass multiple properties to the target face in one call.  Note
*   that only a subset of the available properties can be controlled.
*
*   * @FT_PARAM_TAG_STEM_DARKENING (stem darkening, corresponding to the
*     property `no-stem-darkening` provided by the 'autofit', 'cff',
*     'type1', and 't1cid' modules; see @no-stem-darkening).
*
*   * @FT_PARAM_TAG_RANDOM_SEED (seed value for the CFF, Type~1, and CID
*     'random' operator, corresponding to the `random-seed` property
*     provided by the 'cff', 'type1', and 't1cid' modules; see
*     @random-seed).
*
*   * @FT_PARAM_TAG_LCD_FILTER_WEIGHTS (no longer supported).
*
*   Pass `NULL` as `data` in @FT_Parameter for a given tag to reset the
*   option and use the library or module default again.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   num_properties ::
*     The number of properties that follow.
*
*   properties ::
*     A handle to an @FT_Parameter array with `num_properties` elements.
*
* @return:
*   FreeType error code.  0~means success.
*
* @example:
*   Here is an example that sets three properties.  You must define
*   `FT_CONFIG_OPTION_SUBPIXEL_RENDERING` to make the LCD filter examples
*   work.
*
*   ```
*     FT_Parameter         property1;
*     FT_Bool              darken_stems = 1;
*
*     FT_Parameter         property2;
*     FT_Int32             random_seed = 314159265;
*
*     FT_Parameter         properties[2] = { property1,
*                                            property2 };
*
*
*     property1.tag  = FT_PARAM_TAG_STEM_DARKENING;
*     property1.data = &darken_stems;
*
*     property2.tag  = FT_PARAM_TAG_RANDOM_SEED;
*     property2.data = &random_seed;
*
*     FT_Face_Properties( face, 3, properties );
*   ```
*
*   The next example resets a single property to its default value.
*
*   ```
*     FT_Parameter  property;
*
*
*     property.tag  = FT_PARAM_TAG_STEM_DARKENING;
*     property.data = NULL;
*
*     FT_Face_Properties( face, 1, &property );
*   ```
*
* @since:
*   2.8
*
*/
FT_Face_Properties :: (face: FT_Face, num_properties: FT_UInt, properties: *FT_Parameter) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Name_Index
*
* @description:
*   Return the glyph index of a given glyph name.  This only works
*   for those faces where @FT_HAS_GLYPH_NAMES returns true.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   glyph_name ::
*     The glyph name.
*
* @return:
*   The glyph index.  0~means 'undefined character code'.
*
* @note:
*   Acceptable glyph names might come from the [Adobe Glyph
*   List](https://github.com/adobe-type-tools/agl-aglfn).  See
*   @FT_Get_Glyph_Name for the inverse functionality.
*
*   This function has limited capabilities if the config macro
*   `FT_CONFIG_OPTION_POSTSCRIPT_NAMES` is not defined in `ftoption.h`:
*   It then works only for fonts that actually embed glyph names (which
*   many recent OpenType fonts do not).
*/
FT_Get_Name_Index :: (face: FT_Face, glyph_name: *FT_String) -> FT_UInt #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Glyph_Name
*
* @description:
*   Retrieve the ASCII name of a given glyph in a face.  This only works
*   for those faces where @FT_HAS_GLYPH_NAMES returns true.
*
* @input:
*   face ::
*     A handle to a source face object.
*
*   glyph_index ::
*     The glyph index.
*
*   buffer_max ::
*     The maximum number of bytes available in the buffer.
*
* @output:
*   buffer ::
*     A pointer to a target buffer where the name is copied to.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   An error is returned if the face doesn't provide glyph names or if the
*   glyph index is invalid.  In all cases of failure, the first byte of
*   `buffer` is set to~0 to indicate an empty name.
*
*   The glyph name is truncated to fit within the buffer if it is too
*   long.  The returned string is always zero-terminated.
*
*   Be aware that FreeType reorders glyph indices internally so that glyph
*   index~0 always corresponds to the 'missing glyph' (called '.notdef').
*
*   This function has limited capabilities if the config macro
*   `FT_CONFIG_OPTION_POSTSCRIPT_NAMES` is not defined in `ftoption.h`:
*   It then works only for fonts that actually embed glyph names (which
*   many recent OpenType fonts do not).
*/
FT_Get_Glyph_Name :: (face: FT_Face, glyph_index: FT_UInt, buffer: FT_Pointer, buffer_max: FT_UInt) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_Postscript_Name
*
* @description:
*   Retrieve the ASCII PostScript name of a given face, if available.
*   This only works with PostScript, TrueType, and OpenType fonts.
*
* @input:
*   face ::
*     A handle to the source face object.
*
* @return:
*   A pointer to the face's PostScript name.  `NULL` if unavailable.
*
* @note:
*   The returned pointer is owned by the face and is destroyed with it.
*
*   For variation fonts, this string changes if you select a different
*   instance, and you have to call `FT_Get_PostScript_Name` again to
*   retrieve it.  FreeType follows Adobe TechNote #5902, 'Generating
*   PostScript Names for Fonts Using OpenType Font Variations'.
*
*     https://download.macromedia.com/pub/developer/opentype/tech-notes/5902.AdobePSNameGeneration.html
*
*   [Since 2.9] Special PostScript names for named instances are only
*   returned if the named instance is set with @FT_Set_Named_Instance (and
*   the font has corresponding entries in its 'fvar' table or is the
*   default named instance).  If @FT_IS_VARIATION returns true, the
*   algorithmically derived PostScript name is provided, not looking up
*   special entries for named instances.
*/
FT_Get_Postscript_Name :: (face: FT_Face) -> *u8 #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_SubGlyph_Info
*
* @description:
*   Retrieve a description of a given subglyph.  Only use it if
*   `glyph->format` is @FT_GLYPH_FORMAT_COMPOSITE; an error is returned
*   otherwise.
*
* @input:
*   glyph ::
*     The source glyph slot.
*
*   sub_index ::
*     The index of the subglyph.  Must be less than
*     `glyph->num_subglyphs`.
*
* @output:
*   p_index ::
*     The glyph index of the subglyph.
*
*   p_flags ::
*     The subglyph flags, see @FT_SUBGLYPH_FLAG_XXX.
*
*   p_arg1 ::
*     The subglyph's first argument (if any).
*
*   p_arg2 ::
*     The subglyph's second argument (if any).
*
*   p_transform ::
*     The subglyph transformation (if any).
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   The values of `*p_arg1`, `*p_arg2`, and `*p_transform` must be
*   interpreted depending on the flags returned in `*p_flags`.  See the
*   OpenType specification for details.
*
*     https://learn.microsoft.com/typography/opentype/spec/glyf#composite-glyph-description
*
*/
FT_Get_SubGlyph_Info :: (glyph: FT_GlyphSlot, sub_index: FT_UInt, p_index: *FT_Int, p_flags: *FT_UInt, p_arg1: *FT_Int, p_arg2: *FT_Int, p_transform: *FT_Matrix) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_FSType_Flags
*
* @description:
*   Return the `fsType` flags for a font.
*
* @input:
*   face ::
*     A handle to the source face object.
*
* @return:
*   The `fsType` flags, see @FT_FSTYPE_XXX.
*
* @note:
*   Use this function rather than directly reading the `fs_type` field in
*   the @PS_FontInfoRec structure, which is only guaranteed to return the
*   correct results for Type~1 fonts.
*
* @since:
*   2.3.8
*
*/
FT_Get_FSType_Flags :: (face: FT_Face) -> FT_UShort #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_GetCharVariantIndex
*
* @description:
*   Return the glyph index of a given character code as modified by the
*   variation selector.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   charcode ::
*     The character code point in Unicode.
*
*   variantSelector ::
*     The Unicode code point of the variation selector.
*
* @return:
*   The glyph index.  0~means either 'undefined character code', or
*   'undefined selector code', or 'no variation selector cmap subtable',
*   or 'current CharMap is not Unicode'.
*
* @note:
*   If you use FreeType to manipulate the contents of font files directly,
*   be aware that the glyph index returned by this function doesn't always
*   correspond to the internal indices used within the file.  This is done
*   to ensure that value~0 always corresponds to the 'missing glyph'.
*
*   This function is only meaningful if
*     a) the font has a variation selector cmap sub table, and
*     b) the current charmap has a Unicode encoding.
*
* @since:
*   2.3.6
*
*/
FT_Face_GetCharVariantIndex :: (face: FT_Face, charcode: FT_ULong, variantSelector: FT_ULong) -> FT_UInt #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_GetCharVariantIsDefault
*
* @description:
*   Check whether this variation of this Unicode character is the one to
*   be found in the charmap.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   charcode ::
*     The character codepoint in Unicode.
*
*   variantSelector ::
*     The Unicode codepoint of the variation selector.
*
* @return:
*   1~if found in the standard (Unicode) cmap, 0~if found in the variation
*   selector cmap, or -1 if it is not a variation.
*
* @note:
*   This function is only meaningful if the font has a variation selector
*   cmap subtable.
*
* @since:
*   2.3.6
*
*/
FT_Face_GetCharVariantIsDefault :: (face: FT_Face, charcode: FT_ULong, variantSelector: FT_ULong) -> FT_Int #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_GetVariantSelectors
*
* @description:
*   Return a zero-terminated list of Unicode variation selectors found in
*   the font.
*
* @input:
*   face ::
*     A handle to the source face object.
*
* @return:
*   A pointer to an array of selector code points, or `NULL` if there is
*   no valid variation selector cmap subtable.
*
* @note:
*   The last item in the array is~0; the array is owned by the @FT_Face
*   object but can be overwritten or released on the next call to a
*   FreeType function.
*
* @since:
*   2.3.6
*
*/
FT_Face_GetVariantSelectors :: (face: FT_Face) -> *FT_UInt32 #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_GetVariantsOfChar
*
* @description:
*   Return a zero-terminated list of Unicode variation selectors found for
*   the specified character code.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   charcode ::
*     The character codepoint in Unicode.
*
* @return:
*   A pointer to an array of variation selector code points that are
*   active for the given character, or `NULL` if the corresponding list is
*   empty.
*
* @note:
*   The last item in the array is~0; the array is owned by the @FT_Face
*   object but can be overwritten or released on the next call to a
*   FreeType function.
*
* @since:
*   2.3.6
*
*/
FT_Face_GetVariantsOfChar :: (face: FT_Face, charcode: FT_ULong) -> *FT_UInt32 #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_GetCharsOfVariant
*
* @description:
*   Return a zero-terminated list of Unicode character codes found for the
*   specified variation selector.
*
* @input:
*   face ::
*     A handle to the source face object.
*
*   variantSelector ::
*     The variation selector code point in Unicode.
*
* @return:
*   A list of all the code points that are specified by this selector
*   (both default and non-default codes are returned) or `NULL` if there
*   is no valid cmap or the variation selector is invalid.
*
* @note:
*   The last item in the array is~0; the array is owned by the @FT_Face
*   object but can be overwritten or released on the next call to a
*   FreeType function.
*
* @since:
*   2.3.6
*
*/
FT_Face_GetCharsOfVariant :: (face: FT_Face, variantSelector: FT_ULong) -> *FT_UInt32 #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_MulDiv
*
* @description:
*   Compute `(a*b)/c` with maximum accuracy, using a 64-bit intermediate
*   integer whenever necessary.
*
*   This function isn't necessarily as fast as some processor-specific
*   operations, but is at least completely portable.
*
* @input:
*   a ::
*     The first multiplier.
*
*   b ::
*     The second multiplier.
*
*   c ::
*     The divisor.
*
* @return:
*   The result of `(a*b)/c`.  This function never traps when trying to
*   divide by zero; it simply returns 'MaxInt' or 'MinInt' depending on
*   the signs of `a` and `b`.
*/
FT_MulDiv :: (a: FT_Long, b: FT_Long, c: FT_Long) -> FT_Long #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_MulFix
*
* @description:
*   Compute `(a*b)/0x10000` with maximum accuracy.  Its main use is to
*   multiply a given value by a 16.16 fixed-point factor.
*
* @input:
*   a ::
*     The first multiplier.
*
*   b ::
*     The second multiplier.  Use a 16.16 factor here whenever possible
*     (see note below).
*
* @return:
*   The result of `(a*b)/0x10000`.
*
* @note:
*   This function has been optimized for the case where the absolute value
*   of `a` is less than 2048, and `b` is a 16.16 scaling factor.  As this
*   happens mainly when scaling from notional units to fractional pixels
*   in FreeType, it resulted in noticeable speed improvements between
*   versions 2.x and 1.x.
*
*   As a conclusion, always try to place a 16.16 factor as the _second_
*   argument of this function; this can make a great difference.
*/
FT_MulFix :: (a: FT_Long, b: FT_Long) -> FT_Long #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_DivFix
*
* @description:
*   Compute `(a*0x10000)/b` with maximum accuracy.  Its main use is to
*   divide a given value by a 16.16 fixed-point factor.
*
* @input:
*   a ::
*     The numerator.
*
*   b ::
*     The denominator.  Use a 16.16 factor here.
*
* @return:
*   The result of `(a*0x10000)/b`.
*/
FT_DivFix :: (a: FT_Long, b: FT_Long) -> FT_Long #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_RoundFix
*
* @description:
*   Round a 16.16 fixed number.
*
* @input:
*   a ::
*     The number to be rounded.
*
* @return:
*   `a` rounded to the nearest 16.16 fixed integer, halfway cases away
*   from zero.
*
* @note:
*   The function uses wrap-around arithmetic.
*/
FT_RoundFix :: (a: FT_Fixed) -> FT_Fixed #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_CeilFix
*
* @description:
*   Compute the smallest following integer of a 16.16 fixed number.
*
* @input:
*   a ::
*     The number for which the ceiling function is to be computed.
*
* @return:
*   `a` rounded towards plus infinity.
*
* @note:
*   The function uses wrap-around arithmetic.
*/
FT_CeilFix :: (a: FT_Fixed) -> FT_Fixed #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_FloorFix
*
* @description:
*   Compute the largest previous integer of a 16.16 fixed number.
*
* @input:
*   a ::
*     The number for which the floor function is to be computed.
*
* @return:
*   `a` rounded towards minus infinity.
*/
FT_FloorFix :: (a: FT_Fixed) -> FT_Fixed #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Vector_Transform
*
* @description:
*   Transform a single vector through a 2x2 matrix.
*
* @inout:
*   vector ::
*     The target vector to transform.
*
* @input:
*   matrix ::
*     A pointer to the source 2x2 matrix.
*
* @note:
*   The result is undefined if either `vector` or `matrix` is invalid.
*/
FT_Vector_Transform :: (vector: *FT_Vector, matrix: *FT_Matrix) -> void #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Library_Version
*
* @description:
*   Return the version of the FreeType library being used.  This is useful
*   when dynamically linking to the library, since one cannot use the
*   macros @FREETYPE_MAJOR, @FREETYPE_MINOR, and @FREETYPE_PATCH.
*
* @input:
*   library ::
*     A source library handle.
*
* @output:
*   amajor ::
*     The major version number.
*
*   aminor ::
*     The minor version number.
*
*   apatch ::
*     The patch version number.
*
* @note:
*   The reason why this function takes a `library` argument is because
*   certain programs implement library initialization in a custom way that
*   doesn't use @FT_Init_FreeType.
*
*   In such cases, the library version might not be available before the
*   library object has been created.
*/
FT_Library_Version :: (library: FT_Library, amajor: *FT_Int, aminor: *FT_Int, apatch: *FT_Int) -> void #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_CheckTrueTypePatents
*
* @description:
*   Deprecated, does nothing.
*
* @input:
*   face ::
*     A face handle.
*
* @return:
*   Always returns false.
*
* @note:
*   Since May 2010, TrueType hinting is no longer patented.
*
* @since:
*   2.3.5
*
*/
FT_Face_CheckTrueTypePatents :: (face: FT_Face) -> FT_Bool #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Face_SetUnpatentedHinting
*
* @description:
*   Deprecated, does nothing.
*
* @input:
*   face ::
*     A face handle.
*
*   value ::
*     New boolean setting.
*
* @return:
*   Always returns false.
*
* @note:
*   Since May 2010, TrueType hinting is no longer patented.
*
* @since:
*   2.3.5
*
*/
FT_Face_SetUnpatentedHinting :: (face: FT_Face, value: FT_Bool) -> FT_Bool #foreign freetype;

/**************************************************************************
*
* @struct:
*   TT_Header
*
* @description:
*   A structure to model a TrueType font header table.  All fields follow
*   the OpenType specification.  The 64-bit timestamps are stored in
*   two-element arrays `Created` and `Modified`, first the upper then
*   the lower 32~bits.
*/
TT_Header_ :: struct {
    Table_Version:       FT_Fixed;
    Font_Revision:       FT_Fixed;

    CheckSum_Adjust:     FT_Long;
    Magic_Number:        FT_Long;

    Flags:               FT_UShort;
    Units_Per_EM:        FT_UShort;

    Created:             [2] FT_ULong;
    Modified:            [2] FT_ULong;

    xMin:                FT_Short;
    yMin:                FT_Short;
    xMax:                FT_Short;
    yMax:                FT_Short;

    Mac_Style:           FT_UShort;
    Lowest_Rec_PPEM:     FT_UShort;

    Font_Direction:      FT_Short;
    Index_To_Loc_Format: FT_Short;
    Glyph_Data_Format:   FT_Short;
}

/**************************************************************************
*
* @struct:
*   TT_Header
*
* @description:
*   A structure to model a TrueType font header table.  All fields follow
*   the OpenType specification.  The 64-bit timestamps are stored in
*   two-element arrays `Created` and `Modified`, first the upper then
*   the lower 32~bits.
*/
TT_Header :: TT_Header_;

/**************************************************************************
*
* @struct:
*   TT_HoriHeader
*
* @description:
*   A structure to model a TrueType horizontal header, the 'hhea' table,
*   as well as the corresponding horizontal metrics table, 'hmtx'.
*
* @fields:
*   Version ::
*     The table version.
*
*   Ascender ::
*     The font's ascender, i.e., the distance from the baseline to the
*     top-most of all glyph points found in the font.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoAscender` field of the 'OS/2' table instead
*     if you want the correct one.
*
*   Descender ::
*     The font's descender, i.e., the distance from the baseline to the
*     bottom-most of all glyph points found in the font.  It is negative.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoDescender` field of the 'OS/2' table
*     instead if you want the correct one.
*
*   Line_Gap ::
*     The font's line gap, i.e., the distance to add to the ascender and
*     descender to get the BTB, i.e., the baseline-to-baseline distance
*     for the font.
*
*   advance_Width_Max ::
*     This field is the maximum of all advance widths found in the font.
*     It can be used to compute the maximum width of an arbitrary string
*     of text.
*
*   min_Left_Side_Bearing ::
*     The minimum left side bearing of all glyphs within the font.
*
*   min_Right_Side_Bearing ::
*     The minimum right side bearing of all glyphs within the font.
*
*   xMax_Extent ::
*     The maximum horizontal extent (i.e., the 'width' of a glyph's
*     bounding box) for all glyphs in the font.
*
*   caret_Slope_Rise ::
*     The rise coefficient of the cursor's slope of the cursor
*     (slope=rise/run).
*
*   caret_Slope_Run ::
*     The run coefficient of the cursor's slope.
*
*   caret_Offset ::
*     The cursor's offset for slanted fonts.
*
*   Reserved ::
*     8~reserved bytes.
*
*   metric_Data_Format ::
*     Always~0.
*
*   number_Of_HMetrics ::
*     Number of HMetrics entries in the 'hmtx' table -- this value can be
*     smaller than the total number of glyphs in the font.
*
*   long_metrics ::
*     A pointer into the 'hmtx' table.
*
*   short_metrics ::
*     A pointer into the 'hmtx' table.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `caret_Slope_Rise`,
*   `caret_Slope_Run`, and `caret_Offset`.
*/
TT_HoriHeader_ :: struct {
    Version:                FT_Fixed;
    Ascender:               FT_Short;
    Descender:              FT_Short;
    Line_Gap:               FT_Short;

    advance_Width_Max:      FT_UShort; /* advance width maximum */

    min_Left_Side_Bearing:  FT_Short; /* minimum left-sb       */
    min_Right_Side_Bearing: FT_Short; /* minimum right-sb      */
    xMax_Extent:            FT_Short; /* xmax extents          */
    caret_Slope_Rise:       FT_Short;
    caret_Slope_Run:        FT_Short;
    caret_Offset:           FT_Short;

    Reserved:               [4] FT_Short;

    metric_Data_Format:     FT_Short;
    number_Of_HMetrics:     FT_UShort;

    /* The following fields are not defined by the OpenType specification */
    /* but they are used to connect the metrics header to the relevant    */
    /* 'hmtx' table.                                                      */
    long_metrics:           *void;
    short_metrics:          *void;
}

/**************************************************************************
*
* @struct:
*   TT_HoriHeader
*
* @description:
*   A structure to model a TrueType horizontal header, the 'hhea' table,
*   as well as the corresponding horizontal metrics table, 'hmtx'.
*
* @fields:
*   Version ::
*     The table version.
*
*   Ascender ::
*     The font's ascender, i.e., the distance from the baseline to the
*     top-most of all glyph points found in the font.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoAscender` field of the 'OS/2' table instead
*     if you want the correct one.
*
*   Descender ::
*     The font's descender, i.e., the distance from the baseline to the
*     bottom-most of all glyph points found in the font.  It is negative.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoDescender` field of the 'OS/2' table
*     instead if you want the correct one.
*
*   Line_Gap ::
*     The font's line gap, i.e., the distance to add to the ascender and
*     descender to get the BTB, i.e., the baseline-to-baseline distance
*     for the font.
*
*   advance_Width_Max ::
*     This field is the maximum of all advance widths found in the font.
*     It can be used to compute the maximum width of an arbitrary string
*     of text.
*
*   min_Left_Side_Bearing ::
*     The minimum left side bearing of all glyphs within the font.
*
*   min_Right_Side_Bearing ::
*     The minimum right side bearing of all glyphs within the font.
*
*   xMax_Extent ::
*     The maximum horizontal extent (i.e., the 'width' of a glyph's
*     bounding box) for all glyphs in the font.
*
*   caret_Slope_Rise ::
*     The rise coefficient of the cursor's slope of the cursor
*     (slope=rise/run).
*
*   caret_Slope_Run ::
*     The run coefficient of the cursor's slope.
*
*   caret_Offset ::
*     The cursor's offset for slanted fonts.
*
*   Reserved ::
*     8~reserved bytes.
*
*   metric_Data_Format ::
*     Always~0.
*
*   number_Of_HMetrics ::
*     Number of HMetrics entries in the 'hmtx' table -- this value can be
*     smaller than the total number of glyphs in the font.
*
*   long_metrics ::
*     A pointer into the 'hmtx' table.
*
*   short_metrics ::
*     A pointer into the 'hmtx' table.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `caret_Slope_Rise`,
*   `caret_Slope_Run`, and `caret_Offset`.
*/
TT_HoriHeader :: TT_HoriHeader_;

/**************************************************************************
*
* @struct:
*   TT_VertHeader
*
* @description:
*   A structure used to model a TrueType vertical header, the 'vhea'
*   table, as well as the corresponding vertical metrics table, 'vmtx'.
*
* @fields:
*   Version ::
*     The table version.
*
*   Ascender ::
*     The font's ascender, i.e., the distance from the baseline to the
*     top-most of all glyph points found in the font.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoAscender` field of the 'OS/2' table instead
*     if you want the correct one.
*
*   Descender ::
*     The font's descender, i.e., the distance from the baseline to the
*     bottom-most of all glyph points found in the font.  It is negative.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoDescender` field of the 'OS/2' table
*     instead if you want the correct one.
*
*   Line_Gap ::
*     The font's line gap, i.e., the distance to add to the ascender and
*     descender to get the BTB, i.e., the baseline-to-baseline distance
*     for the font.
*
*   advance_Height_Max ::
*     This field is the maximum of all advance heights found in the font.
*     It can be used to compute the maximum height of an arbitrary string
*     of text.
*
*   min_Top_Side_Bearing ::
*     The minimum top side bearing of all glyphs within the font.
*
*   min_Bottom_Side_Bearing ::
*     The minimum bottom side bearing of all glyphs within the font.
*
*   yMax_Extent ::
*     The maximum vertical extent (i.e., the 'height' of a glyph's
*     bounding box) for all glyphs in the font.
*
*   caret_Slope_Rise ::
*     The rise coefficient of the cursor's slope of the cursor
*     (slope=rise/run).
*
*   caret_Slope_Run ::
*     The run coefficient of the cursor's slope.
*
*   caret_Offset ::
*     The cursor's offset for slanted fonts.
*
*   Reserved ::
*     8~reserved bytes.
*
*   metric_Data_Format ::
*     Always~0.
*
*   number_Of_VMetrics ::
*     Number of VMetrics entries in the 'vmtx' table -- this value can be
*     smaller than the total number of glyphs in the font.
*
*   long_metrics ::
*     A pointer into the 'vmtx' table.
*
*   short_metrics ::
*     A pointer into the 'vmtx' table.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `Ascender`, `Descender`,
*   `Line_Gap`, `caret_Slope_Rise`, `caret_Slope_Run`, and `caret_Offset`.
*/
TT_VertHeader_ :: struct {
    Version:                 FT_Fixed;
    Ascender:                FT_Short;
    Descender:               FT_Short;
    Line_Gap:                FT_Short;

    advance_Height_Max:      FT_UShort; /* advance height maximum */

    min_Top_Side_Bearing:    FT_Short; /* minimum top-sb          */
    min_Bottom_Side_Bearing: FT_Short; /* minimum bottom-sb       */
    yMax_Extent:             FT_Short; /* ymax extents            */
    caret_Slope_Rise:        FT_Short;
    caret_Slope_Run:         FT_Short;
    caret_Offset:            FT_Short;

    Reserved:                [4] FT_Short;

    metric_Data_Format:      FT_Short;
    number_Of_VMetrics:      FT_UShort;

    /* The following fields are not defined by the OpenType specification */
    /* but they are used to connect the metrics header to the relevant    */
    /* 'vmtx' table.                                                      */
    long_metrics:            *void;
    short_metrics:           *void;
}

/**************************************************************************
*
* @struct:
*   TT_VertHeader
*
* @description:
*   A structure used to model a TrueType vertical header, the 'vhea'
*   table, as well as the corresponding vertical metrics table, 'vmtx'.
*
* @fields:
*   Version ::
*     The table version.
*
*   Ascender ::
*     The font's ascender, i.e., the distance from the baseline to the
*     top-most of all glyph points found in the font.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoAscender` field of the 'OS/2' table instead
*     if you want the correct one.
*
*   Descender ::
*     The font's descender, i.e., the distance from the baseline to the
*     bottom-most of all glyph points found in the font.  It is negative.
*
*     This value is invalid in many fonts, as it is usually set by the
*     font designer, and often reflects only a portion of the glyphs found
*     in the font (maybe ASCII).
*
*     You should use the `sTypoDescender` field of the 'OS/2' table
*     instead if you want the correct one.
*
*   Line_Gap ::
*     The font's line gap, i.e., the distance to add to the ascender and
*     descender to get the BTB, i.e., the baseline-to-baseline distance
*     for the font.
*
*   advance_Height_Max ::
*     This field is the maximum of all advance heights found in the font.
*     It can be used to compute the maximum height of an arbitrary string
*     of text.
*
*   min_Top_Side_Bearing ::
*     The minimum top side bearing of all glyphs within the font.
*
*   min_Bottom_Side_Bearing ::
*     The minimum bottom side bearing of all glyphs within the font.
*
*   yMax_Extent ::
*     The maximum vertical extent (i.e., the 'height' of a glyph's
*     bounding box) for all glyphs in the font.
*
*   caret_Slope_Rise ::
*     The rise coefficient of the cursor's slope of the cursor
*     (slope=rise/run).
*
*   caret_Slope_Run ::
*     The run coefficient of the cursor's slope.
*
*   caret_Offset ::
*     The cursor's offset for slanted fonts.
*
*   Reserved ::
*     8~reserved bytes.
*
*   metric_Data_Format ::
*     Always~0.
*
*   number_Of_VMetrics ::
*     Number of VMetrics entries in the 'vmtx' table -- this value can be
*     smaller than the total number of glyphs in the font.
*
*   long_metrics ::
*     A pointer into the 'vmtx' table.
*
*   short_metrics ::
*     A pointer into the 'vmtx' table.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `Ascender`, `Descender`,
*   `Line_Gap`, `caret_Slope_Rise`, `caret_Slope_Run`, and `caret_Offset`.
*/
TT_VertHeader :: TT_VertHeader_;

/**************************************************************************
*
* @struct:
*   TT_OS2
*
* @description:
*   A structure to model a TrueType 'OS/2' table.  All fields comply to
*   the OpenType specification.
*
*   Note that we now support old Mac fonts that do not include an 'OS/2'
*   table.  In this case, the `version` field is always set to 0xFFFF.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `sCapHeight`, `sTypoAscender`,
*   `sTypoDescender`, `sTypoLineGap`, `sxHeight`, `usWinAscent`,
*   `usWinDescent`, `yStrikeoutPosition`, `yStrikeoutSize`,
*   `ySubscriptXOffset`, `ySubScriptXSize`, `ySubscriptYOffset`,
*   `ySubscriptYSize`, `ySuperscriptXOffset`, `ySuperscriptXSize`,
*   `ySuperscriptYOffset`, and `ySuperscriptYSize`.
*
*   Possible values for bits in the `ulUnicodeRangeX` fields are given by
*   the @TT_UCR_XXX macros.
*/
TT_OS2_ :: struct {
    version:                 FT_UShort; /* 0x0001 - more or 0xFFFF */
    xAvgCharWidth:           FT_Short;
    usWeightClass:           FT_UShort;
    usWidthClass:            FT_UShort;
    fsType:                  FT_UShort;
    ySubscriptXSize:         FT_Short;
    ySubscriptYSize:         FT_Short;
    ySubscriptXOffset:       FT_Short;
    ySubscriptYOffset:       FT_Short;
    ySuperscriptXSize:       FT_Short;
    ySuperscriptYSize:       FT_Short;
    ySuperscriptXOffset:     FT_Short;
    ySuperscriptYOffset:     FT_Short;
    yStrikeoutSize:          FT_Short;
    yStrikeoutPosition:      FT_Short;
    sFamilyClass:            FT_Short;

    panose:                  [10] FT_Byte;

    ulUnicodeRange1:         FT_ULong; /* Bits 0-31   */
    ulUnicodeRange2:         FT_ULong; /* Bits 32-63  */
    ulUnicodeRange3:         FT_ULong; /* Bits 64-95  */
    ulUnicodeRange4:         FT_ULong; /* Bits 96-127 */

    achVendID:               [4] FT_Char;

    fsSelection:             FT_UShort;
    usFirstCharIndex:        FT_UShort;
    usLastCharIndex:         FT_UShort;
    sTypoAscender:           FT_Short;
    sTypoDescender:          FT_Short;
    sTypoLineGap:            FT_Short;
    usWinAscent:             FT_UShort;
    usWinDescent:            FT_UShort;

    ulCodePageRange1:        FT_ULong; /* Bits 0-31   */
    ulCodePageRange2:        FT_ULong; /* Bits 32-63  */

    /* only version 2 and higher: */
    sxHeight:                FT_Short;
    sCapHeight:              FT_Short;
    usDefaultChar:           FT_UShort;
    usBreakChar:             FT_UShort;
    usMaxContext:            FT_UShort;

    usLowerOpticalPointSize: FT_UShort; /* in twips (1/20 points) */
    usUpperOpticalPointSize: FT_UShort; /* in twips (1/20 points) */
}

/**************************************************************************
*
* @struct:
*   TT_OS2
*
* @description:
*   A structure to model a TrueType 'OS/2' table.  All fields comply to
*   the OpenType specification.
*
*   Note that we now support old Mac fonts that do not include an 'OS/2'
*   table.  In this case, the `version` field is always set to 0xFFFF.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `sCapHeight`, `sTypoAscender`,
*   `sTypoDescender`, `sTypoLineGap`, `sxHeight`, `usWinAscent`,
*   `usWinDescent`, `yStrikeoutPosition`, `yStrikeoutSize`,
*   `ySubscriptXOffset`, `ySubScriptXSize`, `ySubscriptYOffset`,
*   `ySubscriptYSize`, `ySuperscriptXOffset`, `ySuperscriptXSize`,
*   `ySuperscriptYOffset`, and `ySuperscriptYSize`.
*
*   Possible values for bits in the `ulUnicodeRangeX` fields are given by
*   the @TT_UCR_XXX macros.
*/
TT_OS2 :: TT_OS2_;

/**************************************************************************
*
* @struct:
*   TT_Postscript
*
* @description:
*   A structure to model a TrueType 'post' table.  All fields comply to
*   the OpenType specification.  This structure does not reference a
*   font's PostScript glyph names; use @FT_Get_Glyph_Name to retrieve
*   them.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `underlinePosition` and
*   `underlineThickness`.
*/
TT_Postscript_ :: struct {
    FormatType:         FT_Fixed;
    italicAngle:        FT_Fixed;
    underlinePosition:  FT_Short;
    underlineThickness: FT_Short;
    isFixedPitch:       FT_ULong;
    minMemType42:       FT_ULong;
    maxMemType42:       FT_ULong;
    minMemType1:        FT_ULong;
    maxMemType1:        FT_ULong;
}

/**************************************************************************
*
* @struct:
*   TT_Postscript
*
* @description:
*   A structure to model a TrueType 'post' table.  All fields comply to
*   the OpenType specification.  This structure does not reference a
*   font's PostScript glyph names; use @FT_Get_Glyph_Name to retrieve
*   them.
*
* @note:
*   For OpenType Font Variations, the values of the following fields can
*   change after a call to @FT_Set_Var_Design_Coordinates (and friends) if
*   the font contains an 'MVAR' table: `underlinePosition` and
*   `underlineThickness`.
*/
TT_Postscript :: TT_Postscript_;

/**************************************************************************
*
* @struct:
*   TT_PCLT
*
* @description:
*   A structure to model a TrueType 'PCLT' table.  All fields comply to
*   the OpenType specification.
*/
TT_PCLT_ :: struct {
    Version:             FT_Fixed;
    FontNumber:          FT_ULong;
    Pitch:               FT_UShort;
    xHeight:             FT_UShort;
    Style:               FT_UShort;
    TypeFamily:          FT_UShort;
    CapHeight:           FT_UShort;
    SymbolSet:           FT_UShort;
    TypeFace:            [16] FT_Char;
    CharacterComplement: [8] FT_Char;
    FileName:            [6] FT_Char;
    StrokeWeight:        FT_Char;
    WidthType:           FT_Char;
    SerifStyle:          FT_Byte;
    Reserved:            FT_Byte;
}

/**************************************************************************
*
* @struct:
*   TT_PCLT
*
* @description:
*   A structure to model a TrueType 'PCLT' table.  All fields comply to
*   the OpenType specification.
*/
TT_PCLT :: TT_PCLT_;

/**************************************************************************
*
* @struct:
*   TT_MaxProfile
*
* @description:
*   The maximum profile ('maxp') table contains many max values, which can
*   be used to pre-allocate arrays for speeding up glyph loading and
*   hinting.
*
* @fields:
*   version ::
*     The version number.
*
*   numGlyphs ::
*     The number of glyphs in this TrueType font.
*
*   maxPoints ::
*     The maximum number of points in a non-composite TrueType glyph.  See
*     also `maxCompositePoints`.
*
*   maxContours ::
*     The maximum number of contours in a non-composite TrueType glyph.
*     See also `maxCompositeContours`.
*
*   maxCompositePoints ::
*     The maximum number of points in a composite TrueType glyph.  See
*     also `maxPoints`.
*
*   maxCompositeContours ::
*     The maximum number of contours in a composite TrueType glyph.  See
*     also `maxContours`.
*
*   maxZones ::
*     The maximum number of zones used for glyph hinting.
*
*   maxTwilightPoints ::
*     The maximum number of points in the twilight zone used for glyph
*     hinting.
*
*   maxStorage ::
*     The maximum number of elements in the storage area used for glyph
*     hinting.
*
*   maxFunctionDefs ::
*     The maximum number of function definitions in the TrueType bytecode
*     for this font.
*
*   maxInstructionDefs ::
*     The maximum number of instruction definitions in the TrueType
*     bytecode for this font.
*
*   maxStackElements ::
*     The maximum number of stack elements used during bytecode
*     interpretation.
*
*   maxSizeOfInstructions ::
*     The maximum number of TrueType opcodes used for glyph hinting.
*
*   maxComponentElements ::
*     The maximum number of simple (i.e., non-composite) glyphs in a
*     composite glyph.
*
*   maxComponentDepth ::
*     The maximum nesting depth of composite glyphs.
*
* @note:
*   This structure is only used during font loading.
*/
TT_MaxProfile_ :: struct {
    version:               FT_Fixed;
    numGlyphs:             FT_UShort;
    maxPoints:             FT_UShort;
    maxContours:           FT_UShort;
    maxCompositePoints:    FT_UShort;
    maxCompositeContours:  FT_UShort;
    maxZones:              FT_UShort;
    maxTwilightPoints:     FT_UShort;
    maxStorage:            FT_UShort;
    maxFunctionDefs:       FT_UShort;
    maxInstructionDefs:    FT_UShort;
    maxStackElements:      FT_UShort;
    maxSizeOfInstructions: FT_UShort;
    maxComponentElements:  FT_UShort;
    maxComponentDepth:     FT_UShort;
}

/**************************************************************************
*
* @struct:
*   TT_MaxProfile
*
* @description:
*   The maximum profile ('maxp') table contains many max values, which can
*   be used to pre-allocate arrays for speeding up glyph loading and
*   hinting.
*
* @fields:
*   version ::
*     The version number.
*
*   numGlyphs ::
*     The number of glyphs in this TrueType font.
*
*   maxPoints ::
*     The maximum number of points in a non-composite TrueType glyph.  See
*     also `maxCompositePoints`.
*
*   maxContours ::
*     The maximum number of contours in a non-composite TrueType glyph.
*     See also `maxCompositeContours`.
*
*   maxCompositePoints ::
*     The maximum number of points in a composite TrueType glyph.  See
*     also `maxPoints`.
*
*   maxCompositeContours ::
*     The maximum number of contours in a composite TrueType glyph.  See
*     also `maxContours`.
*
*   maxZones ::
*     The maximum number of zones used for glyph hinting.
*
*   maxTwilightPoints ::
*     The maximum number of points in the twilight zone used for glyph
*     hinting.
*
*   maxStorage ::
*     The maximum number of elements in the storage area used for glyph
*     hinting.
*
*   maxFunctionDefs ::
*     The maximum number of function definitions in the TrueType bytecode
*     for this font.
*
*   maxInstructionDefs ::
*     The maximum number of instruction definitions in the TrueType
*     bytecode for this font.
*
*   maxStackElements ::
*     The maximum number of stack elements used during bytecode
*     interpretation.
*
*   maxSizeOfInstructions ::
*     The maximum number of TrueType opcodes used for glyph hinting.
*
*   maxComponentElements ::
*     The maximum number of simple (i.e., non-composite) glyphs in a
*     composite glyph.
*
*   maxComponentDepth ::
*     The maximum nesting depth of composite glyphs.
*
* @note:
*   This structure is only used during font loading.
*/
TT_MaxProfile :: TT_MaxProfile_;

/**************************************************************************
*
* @enum:
*   FT_Sfnt_Tag
*
* @description:
*   An enumeration to specify indices of SFNT tables loaded and parsed by
*   FreeType during initialization of an SFNT font.  Used in the
*   @FT_Get_Sfnt_Table API function.
*
* @values:
*   FT_SFNT_HEAD ::
*     To access the font's @TT_Header structure.
*
*   FT_SFNT_MAXP ::
*     To access the font's @TT_MaxProfile structure.
*
*   FT_SFNT_OS2 ::
*     To access the font's @TT_OS2 structure.
*
*   FT_SFNT_HHEA ::
*     To access the font's @TT_HoriHeader structure.
*
*   FT_SFNT_VHEA ::
*     To access the font's @TT_VertHeader structure.
*
*   FT_SFNT_POST ::
*     To access the font's @TT_Postscript structure.
*
*   FT_SFNT_PCLT ::
*     To access the font's @TT_PCLT structure.
*/
FT_Sfnt_Tag_ :: enum s32 {
    HEAD :: 0;
    MAXP :: 1;
    OS2  :: 2;
    HHEA :: 3;
    VHEA :: 4;
    POST :: 5;
    PCLT :: 6;

    MAX  :: 7;

    FT_SFNT_HEAD :: HEAD;
    FT_SFNT_MAXP :: MAXP;
    FT_SFNT_OS2  :: OS2;
    FT_SFNT_HHEA :: HHEA;
    FT_SFNT_VHEA :: VHEA;
    FT_SFNT_POST :: POST;
    FT_SFNT_PCLT :: PCLT;

    FT_SFNT_MAX  :: MAX;
}

/**************************************************************************
*
* @enum:
*   FT_Sfnt_Tag
*
* @description:
*   An enumeration to specify indices of SFNT tables loaded and parsed by
*   FreeType during initialization of an SFNT font.  Used in the
*   @FT_Get_Sfnt_Table API function.
*
* @values:
*   FT_SFNT_HEAD ::
*     To access the font's @TT_Header structure.
*
*   FT_SFNT_MAXP ::
*     To access the font's @TT_MaxProfile structure.
*
*   FT_SFNT_OS2 ::
*     To access the font's @TT_OS2 structure.
*
*   FT_SFNT_HHEA ::
*     To access the font's @TT_HoriHeader structure.
*
*   FT_SFNT_VHEA ::
*     To access the font's @TT_VertHeader structure.
*
*   FT_SFNT_POST ::
*     To access the font's @TT_Postscript structure.
*
*   FT_SFNT_PCLT ::
*     To access the font's @TT_PCLT structure.
*/
FT_Sfnt_Tag :: FT_Sfnt_Tag_;

/**************************************************************************
*
* @function:
*   FT_Get_Sfnt_Table
*
* @description:
*   Return a pointer to a given SFNT table stored within a face.
*
* @input:
*   face ::
*     A handle to the source.
*
*   tag ::
*     The index of the SFNT table.
*
* @return:
*   A type-less pointer to the table.  This will be `NULL` in case of
*   error, or if the corresponding table was not found **OR** loaded from
*   the file.
*
*   Use a typecast according to `tag` to access the structure elements.
*
* @note:
*   The table is owned by the face object and disappears with it.
*
*   This function is only useful to access SFNT tables that are loaded by
*   the sfnt, truetype, and opentype drivers.  See @FT_Sfnt_Tag for a
*   list.
*
* @example:
*   Here is an example demonstrating access to the 'vhea' table.
*
*   ```
*     TT_VertHeader*  vert_header;
*
*
*     vert_header =
*       (TT_VertHeader*)FT_Get_Sfnt_Table( face, FT_SFNT_VHEA );
*   ```
*/
FT_Get_Sfnt_Table :: (face: FT_Face, tag: FT_Sfnt_Tag) -> *void #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Load_Sfnt_Table
*
* @description:
*   Load any SFNT font table into client memory.
*
* @input:
*   face ::
*     A handle to the source face.
*
*   tag ::
*     The four-byte tag of the table to load.  Use value~0 if you want to
*     access the whole font file.  Otherwise, you can use one of the
*     definitions found in the @FT_TRUETYPE_TAGS_H file, or forge a new
*     one with @FT_MAKE_TAG.
*
*     [Since 2.14] Use value~1 if you want to access the table directory
*     of the (currently selected) font.
*
*   offset ::
*     The starting offset in the table (or file if tag~==~0).
*
* @output:
*   buffer ::
*     The target buffer address.  The client must ensure that the memory
*     array is big enough to hold the data.
*
* @inout:
*   length ::
*     If the `length` parameter is `NULL`, try to load the whole table.
*     Return an error code if it fails.
*
*     Else, if `*length` is~0, exit immediately while returning the
*     table's (or file) full size in it.
*
*     Else the number of bytes to read from the table or file, from the
*     starting offset.
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   If you need to determine the table's length you should first call this
*   function with `*length` set to~0, as in the following example:
*
*   ```
*     FT_ULong  length = 0;
*
*
*     error = FT_Load_Sfnt_Table( face, tag, 0, NULL, &length );
*     if ( error ) { ... table does not exist ... }
*
*     buffer = malloc( length );
*     if ( buffer == NULL ) { ... not enough memory ... }
*
*     error = FT_Load_Sfnt_Table( face, tag, 0, buffer, &length );
*     if ( error ) { ... could not load table ... }
*   ```
*
*   Note that structures like @TT_Header or @TT_OS2 can't be used with
*   this function; they are limited to @FT_Get_Sfnt_Table.  Reason is that
*   those structures depend on the processor architecture, with varying
*   size (e.g. 32bit vs. 64bit) or order (big endian vs. little endian).
*
*/
FT_Load_Sfnt_Table :: (face: FT_Face, tag: FT_ULong, offset: FT_Long, buffer: *FT_Byte, length: *FT_ULong) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Sfnt_Table_Info
*
* @description:
*   Return information on an SFNT table.
*
* @input:
*   face ::
*     A handle to the source face.
*
*   table_index ::
*     The index of an SFNT table.  The function returns
*     FT_Err_Table_Missing for an invalid value.
*
* @inout:
*   tag ::
*     The name tag of the SFNT table.  If the value is `NULL`,
*     `table_index` is ignored, and `length` returns the number of SFNT
*     tables in the font.
*
* @output:
*   length ::
*     The length of the SFNT table (or the number of SFNT tables,
*     depending on `tag`).
*
* @return:
*   FreeType error code.  0~means success.
*
* @note:
*   While parsing fonts, FreeType handles SFNT tables with length zero as
*   missing.
*
*/
FT_Sfnt_Table_Info :: (face: FT_Face, table_index: FT_UInt, tag: *FT_ULong, length: *FT_ULong) -> FT_Error #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_CMap_Language_ID
*
* @description:
*   Return cmap language ID as specified in the OpenType standard.
*   Definitions of language ID values are in file @FT_TRUETYPE_IDS_H.
*
* @input:
*   charmap ::
*     The target charmap.
*
* @return:
*   The language ID of `charmap`.  If `charmap` doesn't belong to an SFNT
*   face, just return~0 as the default value.
*
*   For a format~14 cmap (to access Unicode IVS), the return value is
*   0xFFFFFFFF.
*/
FT_Get_CMap_Language_ID :: (charmap: FT_CharMap) -> FT_ULong #foreign freetype;

/**************************************************************************
*
* @function:
*   FT_Get_CMap_Format
*
* @description:
*   Return the format of an SFNT 'cmap' table.
*
* @input:
*   charmap ::
*     The target charmap.
*
* @return:
*   The format of `charmap`.  If `charmap` doesn't belong to an SFNT face
*   (including the synthetic Unicode charmap sometimes created by
*   FreeType), return -1.
*/
FT_Get_CMap_Format :: (charmap: FT_CharMap) -> FT_Long #foreign freetype;

#scope_file

