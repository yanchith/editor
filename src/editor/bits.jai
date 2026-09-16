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

// Maybe we also want a version that doesn't check for zero for situations where it matters...
is_nonzero_power_of_two :: inline (x: s64) -> bool {
    return x && (x & (x - 1) == 0);
}

is_aligned :: inline (x: *void, alignment: s64) -> bool {
    return is_aligned(cast(s64, x), alignment);
}

// Alignment must be a nonzero power of two.
is_aligned :: inline (x: s64, alignment: s64) -> bool {
    sanity_assert(is_nonzero_power_of_two(alignment));
    return x == x & ~(alignment - 1);
}