Interpolation :: struct (T: Type, ROUND: bool) {
    source: T;
    target: T;
    value: T;

    start: Apollo_Time;
    start_is_discontinuous: bool;
    
    duration: f32;
}

interpolation_init :: (interpolation: *Interpolation, _target: interpolation.T) {
    discontinuous := interpolation.value != _target;
    
    target := _target;
    #if interpolation.ROUND {
        target = round(target);
    }

    interpolation.source = target;
    interpolation.target = target;
    interpolation.value = target;

    interpolation.start = {}; // Zero instead of APOLLO_TIME_INVALID, as that crashes Int128 stuff in to_float64_seconds.
    interpolation.start_is_discontinuous = discontinuous;
    
    interpolation.duration = 0.0;
}

interpolation_start :: (interpolation: *Interpolation, _source: interpolation.T, _target: interpolation.T, now: Apollo_Time, duration: f32) {
    discontinuous := interpolation.value != _source;
    
    source := _source;
    target := _target;
    #if interpolation.ROUND {
        source = round(source);
        target = round(target);
    }

    interpolation.source = source;
    interpolation.target = target;
    interpolation.value = source;

    interpolation.start = now;
    interpolation.start_is_discontinuous = discontinuous;
    
    interpolation.duration = duration;
}

interpolation_chain :: (interpolation: *Interpolation, _target: interpolation.T, now: Apollo_Time, duration: f32) {
    target := _target;
    #if interpolation.ROUND {
         target = round(target);
    }

    elapsed := to_float64_seconds(now - interpolation.start);
    if elapsed >= interpolation.duration {
        source := interpolation.target;
        
        discontinuous := interpolation.value != source;

        interpolation.source = source;
        interpolation.target = target;
        interpolation.value = source;

        interpolation.start = now;
        interpolation.start_is_discontinuous = discontinuous;
        
        interpolation.duration = duration;
    } else {
        // This early return prevents changing current interpolation to one that only differs in source,
        // and thus prolonging the animation and making it jittery. This happens, when we hold down a button that
        // triggers us setting up the interepolation (e.g C-n when cursor-scrolling down).
        if target == interpolation.target {
            return;
        }

        interpolation.source = interpolation.value;
        interpolation.target = target;

        interpolation.start = now;
        interpolation.start_is_discontinuous = false;
        
        interpolation.duration = duration;
    }
}

interpolation_update :: (interpolation: *Interpolation, now: Apollo_Time, dt: f64) -> running: bool {
    t: f32;
    if interpolation.duration == 0.0 {
        t = 1.0;
    } else {
        a := ifx interpolation.start_is_discontinuous then 0.0 else 0.5 * dt;
        t = cast(f32, to_float64_seconds(now) + a - to_float64_seconds(interpolation.start)) / interpolation.duration;
    }

    t = clamp(t, 0.0, 1.0);
    t = smoothstep(0.0, 1.0, t);

    interpolation.value = lerp(interpolation.source, interpolation.target, t);
    if interpolation.ROUND {
        interpolation.value = round(interpolation.value);
    }

    return t < 1.0;
}

