//
// Float vectors
//
//
// For float vectors, we are currently using JAI's math, becuase Simp uses them.
//

//
// Double vectors
//
// We use double vectors to have enough precision for 100MB+ text buffers for stuff that is not
// mapped into the screen's coordinate system. We could eventually switch to something even more
// robust, like s64 + f32 offset, or 58:6 fixed point, but doubles are more than enough for
// many-gigabyte file sizes.
//
// :FloatPrecision
//

DVector2 :: struct {
    x: f64;
    y: f64;

    #overlay (x) component: [2] f64 = ---;
}

operator == :: (a: DVector2, b: DVector2) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator + :: (a: DVector2, b: DVector2) -> DVector2 {
    return { a.x + b.x, a.y + b.y };
}

operator - :: (a: DVector2) -> DVector2 {
    return { -a.x, -a.y };
}

operator - :: (a: DVector2, b: DVector2) -> DVector2 {
    return { a.x - b.x, a.y - b.y };
}

operator * :: (a: DVector2, b: f64) -> DVector2 #symmetric {
    return { a.x * b, a.y * b };
}

operator * :: (a: DVector2, b: DVector2) -> DVector2 {
    return { a.x * b.x, a.y * b.y };
}

operator / :: (a: DVector2, b: f64) -> DVector2 {
    return { a.x / b, a.y / b };
}

operator / :: (a: DVector2, b: DVector2) -> DVector2 {
    return { a.x / b.x, a.y / b.y };
}

min :: inline (a: DVector2, b: DVector2) -> DVector2 {
    return { min(a.x, b.x), min(a.y, b.y) };
}

max :: inline (a: DVector2, b: DVector2) -> DVector2 {
    return { max(a.x, b.x), max(a.y, b.y) };
}

dot_product :: inline (a: DVector2, b: DVector2) -> f64 {
    return a.x * b.x + a.y * b.y;
}

lerp :: inline (a: DVector2, b: DVector2, t: f64) -> DVector2 {
    return a + (b - a) * t;
}

length :: inline (a: DVector2) -> f64 {
    return sqrt(a.x * a.x + a.y * a.y);
}

length_squared :: inline (a: DVector2) -> f64 {
    return a.x * a.x + a.y * a.y;
}

//
// Integer vectors
//

IVector2 :: struct {
    x: s32;
    y: s32;

    #overlay (x) component: [2] s32 = ---;
}

operator == :: (a: IVector2, b: IVector2) -> bool {
    return a.x == b.x && a.y == b.y;
}

operator + :: (a: IVector2, b: IVector2) -> IVector2 {
    return { a.x + b.x, a.y + b.y };
}

operator - :: (a: IVector2) -> IVector2 {
    return { -a.x, -a.y };
}

operator - :: (a: IVector2, b: IVector2) -> IVector2 {
    return { a.x - b.x, a.y - b.y };
}

operator * :: (a: IVector2, b: s32) -> IVector2 #symmetric {
    return { a.x * b, a.y * b };
}

operator * :: (a: IVector2, b: IVector2) -> IVector2 {
    return { a.x * b.x, a.y * b.y };
}

operator / :: (a: IVector2, b: s32) -> IVector2 {
    return { a.x / b, a.y / b };
}

operator / :: (a: IVector2, b: IVector2) -> IVector2 {
    return { a.x / b.x, a.y / b.y };
}

min :: inline (a: IVector2, b: IVector2) -> IVector2 {
    return { min(a.x, b.x), min(a.y, b.y) };
}

max :: inline (a: IVector2, b: IVector2) -> IVector2 {
    return { max(a.x, b.x), max(a.y, b.y) };
}

ivector_to_vector :: inline (a: IVector2) -> Vector2 {
    return { cast(f32, a.x), cast(f32, a.y) };
}

//
// Float rect
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

rect_from_point_and_size :: inline (x0: f32, y0: f32, width: f32, height: f32) -> Rect {
    p0: Vector2 = { x0, y0 };
    p1: Vector2 = { x0 + width, y0 + height};

    return { p0.x, p0.y, p1.x, p1.y };
}

rect_min :: inline (r: Rect) -> Vector2 {
    x := ifx r.x0 < r.x1 then r.x0 else r.x1;
    y := ifx r.y0 < r.y1 then r.y0 else r.y1;

    return { x, y };
}

rect_max :: inline (r: Rect) -> Vector2 {
    x := ifx r.x0 > r.x1 then r.x0 else r.x1;
    y := ifx r.y0 > r.y1 then r.y0 else r.y1;

    return { x, y };
}

rect_width :: inline (r: Rect) -> f32 {
    if r.x0 < r.x1 {
        return r.x1 - r.x0;
    } else {
        return r.x0 - r.x1;
    }
}

rect_height :: inline (r: Rect) -> f32 {
    if r.y0 < r.y1 {
        return r.y1 - r.y0;
    } else {
        return r.y0 - r.y1;
    }
}

rect_contains_vector :: inline (r: Rect, v: Vector2) -> bool {
    // TODO(jt): This actually requires a fixup.
    contains_x := v.x >= r.x0 && v.x < r.x1;
    contains_y := v.y >= r.y0 && v.y < r.y1;

    return contains_x && contains_y;
}

rect_intersects_rect :: inline (r: Rect, other: Rect) -> bool {
    // TODO(jt): This actually requires a fixup.
    intersects_x := r.x0 <= other.x1 && r.x1 >= other.x0;
    intersects_y := r.y0 <= other.y1 && r.y1 >= other.y0;

    return intersects_x && intersects_y;
}

rect_fixup :: (r: Rect) -> Rect {
    p0 := rect_min(r);
    p1 := rect_max(r);

    result: Rect;
    result.p0 = p0;
    result.p1 = p1;

    return result;
}

operator + :: (r: Rect, v: Vector2) -> Rect {
    result: Rect = ---;
    result.p0 = r.p0 + v;
    result.p1 = r.p1 + v;
    return result;
}

operator - :: (r: Rect, v: Vector2) -> Rect {
    result: Rect = ---;
    result.p0 = r.p0 - v;
    result.p1 = r.p1 - v;
    return result;
}

//
// Double rect
//
// See :FloatPrecision.
//

DRect :: struct {
    // Points are not necessarily ordered. See rect_min, rect_max, rect_fixup.
    x0: f64;
    y0: f64;

    x1: f64;
    y1: f64;

    #overlay (x0) p0: DVector2;
    #overlay (x1) p1: DVector2;
}

drect_from_point_and_size :: inline (x0: f64, y0: f64, width: f64, height: f64) -> DRect {
    p0: DVector2 = { x0, y0 };
    p1: DVector2 = { x0 + width, y0 + height};

    return { p0.x, p0.y, p1.x, p1.y };
}

drect_min :: inline (r: DRect) -> DVector2 {
    x := ifx r.x0 < r.x1 then r.x0 else r.x1;
    y := ifx r.y0 < r.y1 then r.y0 else r.y1;

    return { x, y };
}

drect_max :: inline (r: DRect) -> DVector2 {
    x := ifx r.x0 > r.x1 then r.x0 else r.x1;
    y := ifx r.y0 > r.y1 then r.y0 else r.y1;

    return { x, y };
}

drect_width :: inline (r: DRect) -> f64 {
    if r.x0 < r.x1 {
        return r.x1 - r.x0;
    } else {
        return r.x0 - r.x1;
    }
}

drect_height :: inline (r: DRect) -> f64 {
    if r.y0 < r.y1 {
        return r.y1 - r.y0;
    } else {
        return r.y0 - r.y1;
    }
}

drect_fixup :: (r: DRect) -> DRect {
    p0 := rect_min(r);
    p1 := rect_max(r);

    result: DRect;
    result.p0 = p0;
    result.p1 = p1;

    return result;
}

operator + :: (r: DRect, v: DVector2) -> DRect {
    result: DRect = ---;
    result.p0 = r.p0 + v;
    result.p1 = r.p1 + v;
    return result;
}

operator - :: (r: DRect, v: DVector2) -> DRect {
    result: DRect = ---;
    result.p0 = r.p0 - v;
    result.p1 = r.p1 - v;
    return result;
}

drect_to_rect :: (r: DRect) -> Rect {
    return { cast(f32, r.x0), cast(f32, r.y0), cast(f32, r.x1), cast(f32, r.y1) };
}

//
// Integer rect
//

IRect :: struct {
    // Points are not necessarily ordered. See irect_min, irect_max, irect_fixup.
    x0: s32;
    y0: s32;

    x1: s32;
    y1: s32;

    #overlay (x0) p0: IVector2;
    #overlay (x1) p1: IVector2;
}

irect_from_point_and_size :: inline (x0: s32, y0: s32, width: s32, height: s32) -> IRect {
    p0: IVector2 = { x0, y0 };
    p1: IVector2 = { x0 + width, y0 + height};

    return { p0.x, p0.y, p1.x, p1.y };
}

irect_min :: inline (r: IRect) -> IVector2 {
    x := ifx r.x0 < r.x1 then r.x0 else r.x1;
    y := ifx r.y0 < r.y1 then r.y0 else r.y1;

    return { x, y };
}

irect_max :: inline (r: IRect) -> IVector2 {
    x := ifx r.x0 > r.x1 then r.x0 else r.x1;
    y := ifx r.y0 > r.y1 then r.y0 else r.y1;

    return { x, y };
}

irect_width :: inline (r: IRect) -> s32 {
    if r.x0 < r.x1 {
        return r.x1 - r.x0;
    } else {
        return r.x0 - r.x1;
    }
}

irect_height :: inline (r: IRect) -> s32 {
    if r.y0 < r.y1 {
        return r.y1 - r.y0;
    } else {
        return r.y0 - r.y1;
    }
}

irect_fixup :: (r: IRect) -> IRect {
    p0 := irect_min(r);
    p1 := irect_max(r);

    result: IRect;
    result.p0 = p0;
    result.p1 = p1;

    return result;
}

irect_union_or_zero :: (rs: ..IRect) -> IRect {
    return inline irect_union_or_zero(rs);
}

irect_union_or_zero :: (rs: [] IRect) -> IRect {
    if rs.count == 0 {
        return { 0, 0, 0, 0 };
    }

    result := irect_fixup(rs[0]);
    for 1..rs.count - 1 {
        r := *rs[it];

        // This doesn't assume the rects are already fixed up, so maybe it does a little bit too
        // many conditional moves.

        if r.x0 < result.x0 then result.x0 = r.x0;
        if r.y0 < result.y0 then result.y0 = r.y0;
        if r.x1 < result.x0 then result.x0 = r.x1;
        if r.y1 < result.y0 then result.y0 = r.y1;

        if r.x0 > result.x1 then result.x1 = r.x0;
        if r.y0 > result.y1 then result.y1 = r.y0;
        if r.x1 > result.x1 then result.x1 = r.x1;
        if r.y1 > result.y1 then result.y1 = r.y1;
    }

    return result;
}

//
// Other useful stuff
//

round :: (x: f32) -> f32 {
    result := floor(x + 0.5);
    return result;
}

smoothstep :: (edge0: f32, edge1: f32, x: f32) -> f32 {
    t := clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
