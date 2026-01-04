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
