//
// Floating point vectors
//
//
// TODO(jt): We are currently using the ones from JAI's math, becuase Simp uses them.
//

//
// Integer vectors
//

IVector2 :: struct {
    x: s32;
    y: s32;

    #overlay (x) component: [2] s32 = ---;
}

IVECTOR2_ZERO :: IVector2.{ 0, 0 };

IVECTOR2_POSITIVE_X :: IVector2.{  1,  0 };
IVECTOR2_NEGATIVE_X :: IVector2.{ -1,  0 };
IVECTOR2_POSITIVE_Y :: IVector2.{  0,  1 };
IVECTOR2_NEGATIVE_Y :: IVector2.{  0, -1 };

operator == :: (a: IVector2, b: IVector2) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator + :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x + b.x, a.y + b.y };
}

operator - :: (a: IVector2) -> IVector2 {
    return .{ -a.x, -a.y };
}

operator - :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x - b.x, a.y - b.y };
}

operator * :: (a: IVector2, b: s32) -> IVector2 #symmetric {
    return .{ a.x * b, a.y * b };
}

// Hadamard
operator * :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x * b.x, a.y * b.y };
}

operator / :: (a: IVector2, b: s32) -> IVector2 {
    return .{ a.x / b, a.y / b };
}

operator / :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ a.x / b.x, a.y / b.y };
}

min :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ min(a.x, b.x), min(a.y, b.y) };
}

max :: (a: IVector2, b: IVector2) -> IVector2 {
    return .{ max(a.x, b.x), max(a.y, b.y) };
}

ivector_to_vector :: inline (a: IVector2) -> Vector2 {
    return Vector2.{ cast(f32, a.x), cast(f32, a.y) };
}

//
// Floating point rects
//

Rect :: struct {
    // Points are not necessarily ordered. See rect_min, rect_max, rect_fixup.
    x0: f32;
    y0: f32;

    x1: f32;
    y1: f32;

    #overlay (x0) p0: Vector2;
    #overlay (x1) p1: Vector2;
}

make_rect :: inline (p0: Vector2, p1: Vector2) -> Rect {
    return { p0.x, p0.y, p1.x, p1.y };
}

rect_min :: inline (r: Rect) -> Vector2 {
    x := ifx x0 < x1 then x0 else x1;
    y := ifx y0 < y1 then y0 else y1;

    return { x, y };
}

rect_max :: inline (r: Rect) -> Vector2 {
    x := ifx x0 > x1 then x0 else x1;
    y := ifx y0 > y1 then y0 else y1;

    return { x, y };
}

rect_fixup :: (r: Rect) -> Rect {
    p0 := rect_min(r);
    p1 := rect_max(r);

    return make_rect(p0, p1);
}
