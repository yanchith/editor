// TODO(jt): @Cleanup Remove this.

// Simplest possible memcpy.
copy :: (destination: *void, source: *void, count: s64) {
    d := cast(*u8) destination;  s := cast(*u8) source;

    overlapping := destination > source && destination < source + count;
    if !overlapping {
        for 0 .. count - 1
            d[it] = s[it];
    } else {
        for <  0 .. count - 1
            d[it] = s[it];
    }
}
