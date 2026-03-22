// If x is already a power of two, this does nothing.
// Taken from https://graphics.stanford.edu/%7Eseander/bithacks.html#RoundUpPowerOf2.
round_up_to_power_of_two :: inline (x: s64) -> s64 {
    // Bitwise OR with the power of two downshifts smear the set bits all the way down, producing a
    // number that once incremented will be a power of two.
    //
    // However, this is a long dependency chain of operations, so it can't be parallel. Maybe there
    // is a better way of doing this on modern computers, like scan the highest bit and produce a
    // mask we'd bitwise-or with?

    x -= 1;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    x |= x >> 32;
    x += 1;

    return x;
}

// Also returns true for 0, but that may not be what you want, so check it yourself.
is_power_of_two :: inline (value: s64) -> bool {
    return value & (value - 1) == 0;
}
