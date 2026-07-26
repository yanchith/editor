Interpolation :: struct (T: Type) {
    source: T;
    target: T;
    value: T;

    start: Apollo_Time;
    duration: f32;
}

interpolation_init :: (interpolation: *Interpolation($T), target: T) {
    interpolation.source = target;
    interpolation.target = target;
    interpolation.value = target;

    interpolation.start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes Int128 stuff in to_float64_seconds.
    interpolation.duration = 0.0;
}

interpolation_start :: (interpolation: *Interpolation($T), source: T, target: T, now: Apollo_Time, duration: f32) {
    interpolation.source = source;
    interpolation.target = target;
    interpolation.value = source;

    interpolation.start = now;
    interpolation.duration = duration;
}

interpolation_chain :: (interpolation: *Interpolation($T), target: T, now: Apollo_Time, duration: f32) {
    elapsed := to_float64_seconds(now - interpolation.start);
    if elapsed >= interpolation.duration {
        source := interpolation.target;

        interpolation.source = source;
        interpolation.target = target;
        interpolation.value = source;

        interpolation.start = now;
        interpolation.duration = duration;
    } else {
        // TODO(jt): This early return prevents changing current interpolation to one that's just
        // slightly different, and thus prolonging the animation and making it jittery. This
        // happens, when we hold down a button that triggers us setting up the interepolation (e.g
        // C-n when cursor-scrolling down). However, this is still a little jittery. Can we smooth
        // the animation?
        if target == interpolation.target {
            return;
        }

        interpolation.source = interpolation.value;
        interpolation.target = target;

        interpolation.start = now;
        interpolation.duration = duration;
    }
}

interpolation_update :: (interpolation: *Interpolation, now: Apollo_Time) -> running: bool {
    t: f32;
    if interpolation.duration == 0.0 {
        t = 1.0;
    } else {
        // TODO(jt): Better "integration". Should we add 1/2 of delta time or something to make it less laggy?
        t = cast(f32, to_float64_seconds(now) - to_float64_seconds(interpolation.start)) / interpolation.duration;
    }

    t = clamp(t, 0.0, 1.0);
    t = smoothstep(0.0, 1.0, t);

    interpolation.value = lerp(interpolation.source, interpolation.target, t);

    return t < 1.0;
}
