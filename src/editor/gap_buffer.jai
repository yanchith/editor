// XXX: HERE Fix bugs here and then finish implementing the rest.

GAP_BUFFER_STARTING_COUNT :: 4; // TODO(jt): Intentionally low initially, to test this. Increase eventually!

// TODO(jt): @Speed Gap Buffers potentially have problems:
//
// - Multiple cursors would require multiple gaps
// - We have to move the gap when start editing a new part of the buffer
// - They still have to reallocate from time to time when the gap is filled.
//
// The benefit of gap buffers is relative simplicity, though. Can we come up with something not much
// more complicated that deals with the problems above? People on the internet talk about ropes,
// piece tables, piece trees... but maybe just an array of lines could go a long way, especially if
// we are somewhat smart about line storage (could be pooled and size-classed).
Gap_Buffer :: struct {
    gap_index: s64;
    gap_count: s64;

    count: s64; // Stored here for the caller's convenience. Always buffer.count - gap_count.

    buffer: [..] u8;
}

gap_buffer_init :: (gb: *Gap_Buffer, count := GAP_BUFFER_STARTING_COUNT) {
    gb.gap_index = 0;
    gb.gap_count = count;

    array_reserve(*gb.buffer, count);
}

gap_buffer_move_gap :: (gb: *Gap_Buffer, index: s64) {
    // XXX
}

// Convenience for text, even if Gap_Buffer only operates on bytes.
gap_buffer_insert :: (gb: *Gap_Buffer, text: string) {
    gap_buffer_insert(gb, cast([] u8, text)); // TODO(jt): Inline call, but it screws debug symbols.
}

gap_buffer_insert :: (gb: *Gap_Buffer, bytes: [] u8) {
    if bytes.count > gb.gap_count {
        new_count   := round_up_grow_size(gb.buffer.count + bytes.count - gb.gap_count);
        grow_amount := new_count - gb.buffer.count;

        array_resize(*gb.buffer, new_count);

        tail_data  := gb.buffer.data + gb.gap_index + gb.gap_count;
        tail_count := gb.buffer.count - gb.gap_count - gb.gap_index;

        // tail_count can be zero if we started with an empty buffer, or if the gap was at the end,
        // but memcpy should be fine with it.
        //
        // TODO(jt): @Correctness Make sure memory is allowed to overlap in JAI's memcpy.
        memcpy(tail_data + grow_amount, tail_data, tail_count);

        // Preserve gap position, but enlarge it.
        gb.gap_count += grow_amount;
    }

    memcpy(gb.buffer.data + gb.gap_index, bytes.data, bytes.count);
    gb.gap_index += bytes.count;
    gb.gap_count -= bytes.count;

    gb.count += bytes.count;
}

gap_buffer_delete_forward :: (gb: *Gap_Buffer, count: s64) {
    if gb.gap_index + gb.gap_count + count <= gb.buffer.count {
        gb.gap_count += count;
        gb.count -= count;
    }
}

gap_buffer_delete_backward :: (gb: *Gap_Buffer, count: s64) {
    if gb.gap_index - count >= 0 {
        gb.gap_index -= count;
        gb.gap_size += count;
        gb.count -= count;
    }
}

// TODO(jt): @Speed @Memory Implement gap_buffer_replace :: (gb: *Gap_Buffer, count: s64, text: string) {}

// Returns either view of original data or allocated in Temporary_Storage, otherwise we'd have to
// always allocate.
gap_buffer_make_contiguous_view :: (gb: Gap_Buffer, index: s64, count: s64) -> [] u8 {
    assert(count <= gb.count);
    assert(index <= gb.count);
    assert(index + count <= gb.count);

    if index + count <= gb.gap_index {
        // Simple case 1: return contiguous array view before the gap.
        return array_view(gb.buffer, index, count);
    }

    if index >= gb.gap_index {
        // Simple case 2: return contiguous array view after the gap, modifying the index.
        return array_view(gb.buffer, index + gb.gap_count, count);
    }

    // General case: copy the before/after parts into a new array and return that.
    result := NewArray(count, u8,, temp);

    head_data  := gb.buffer.data + index;
    head_count := gb.gap_index - index;

    tail_data  := gb.buffer.data + gb.gap_index + gb.gap_count;
    tail_count := count - head_count;

    memcpy(result.data, head_data, head_count);
    memcpy(result.data + head_count, tail_data, tail_count);

    return result;
}


#scope_file

round_up_grow_size :: (required_size: s64) -> s64 {
    PAGE_SIZE :: 4096; // Not the actual page size on some systems, but we just need a threshold.

    if required_size > PAGE_SIZE {
        return round_up_to_align(required_size, PAGE_SIZE);
    } else {
        return round_up_to_next_power_of_two(required_size);
    }
}

round_up_to_align :: inline (x: s64, alignment: s64) -> s64 {
    // TODO(jt): #debug_assert This does NOT yet assert that alignment is a power of two.
    mask := alignment - 1;
    return (x + mask) & ~mask;
}

round_up_to_next_power_of_two :: inline (x: s64) -> s64 {
    // Taken from https://graphics.stanford.edu/%7Eseander/bithacks.html#RoundUpPowerOf2.
    // Maybe there's a better way to do this in 2026. Some bit_scan instructions maybe?

    // XXX: Audit code.
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
