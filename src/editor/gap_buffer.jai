// A gap buffer operating on bytes. The bytes are assumed to be utf8, but this module does not
// handle Unicode at all. The calling code has to do utf8 parsing and provide proper byte
// indices.
//
// TODO(jt): @Speed Gap Buffers have (theoretical?) problems with multiple cursors. Maybe we
// eventually want something more complicated?
Gap_Buffer :: struct {
    count: s64; // Stored here for the caller's convenience. Always buffer.count - gap_count.

    gap_index: s64;
    gap_count: s64;

    buffer: [..] u8;
}

// You don't have to call gap_buffer_init. It only helps you pre-allocate the internal buffer.
gap_buffer_init :: (gb: *Gap_Buffer, initial_gap_count := 256) {
    assert_valid(gb);

    gb.gap_count = initial_gap_count;
    array_resize(*gb.buffer, initial_gap_count);
}

gap_buffer_get_nongap_byte :: (gb: Gap_Buffer, index: s64) -> u8 {
    assert_valid(gb);

    assert(index >= 0 && index < gb.count);
    if index < gb.gap_index {
        return gb.buffer[index];
    } else {
        return gb.buffer[index + gb.gap_count];
    }
}

gap_buffer_get_bytes_before_gap :: (gb: Gap_Buffer) -> [] u8 {
    assert_valid(gb);

    view: [] u8;
    view.count = gb.gap_index;
    view.data = gb.buffer.data;

    return view;
}

gap_buffer_get_bytes_after_gap :: (gb: Gap_Buffer) -> [] u8 {
    assert_valid(gb);

    view: [] u8;
    view.count = gb.buffer.count - gb.gap_index - gb.gap_count;
    view.data = gb.buffer.data + gb.gap_index + gb.gap_count;

    // TODO(jt): @CompilerBug This autocasts the integer to pointer.
    // view.data = gb.gap_index + gb.gap_count;

    return view;
}

gap_buffer_move_gap_to :: (gb: *Gap_Buffer, index: s64) {
    assert_valid(gb);

    assert(index >= 0 && index <= gb.count);
    if gb.gap_index == index {
        return;
    }

    if index > gb.gap_index {
        // We are moving the gap forward, so copy data backward.
        copy_dest   := gb.buffer.data + gb.gap_index;
        copy_source := gb.buffer.data + gb.gap_index + gb.gap_count;
        copy_count  := index - gb.gap_index;

        Memory.copy(copy_dest, copy_source, copy_count);
    } else {
        // We are moving the gap backward, so copy data forward.
        copy_dest   := gb.buffer.data + index + gb.gap_count;
        copy_source := gb.buffer.data + index;
        copy_count  := gb.gap_index - index;

        Memory.copy(copy_dest, copy_source, copy_count);
    }

    gb.gap_index = index;

    #if DEBUG {
        memset(gb.buffer.data + gb.gap_index, 0xff, gb.gap_count);
    }
}

gap_buffer_insert :: (gb: *Gap_Buffer, text: string) {
    inline gap_buffer_insert(gb, cast([] u8, text));
}

// Inserts at the gap, advancing the gap index.
gap_buffer_insert :: (gb: *Gap_Buffer, bytes: [] u8) {
    ProfileZone("gap_buffer_insert");

    assert_valid(gb);

    if bytes.count > gb.gap_count {
        old_count   := gb.buffer.count;
        new_count   := round_up_grow_size(old_count + bytes.count - gb.gap_count);
        grow_amount := new_count - old_count;

        array_resize(*gb.buffer, new_count);

        tail_data  := gb.buffer.data + gb.gap_index + gb.gap_count;
        tail_count := old_count - gb.gap_count - gb.gap_index;

        // tail_count can be zero if we started with an empty buffer, or if the gap was at the end,
        // but the copy should be fine with it.
        Memory.copy(tail_data + grow_amount, tail_data, tail_count);

        // Preserve gap position, but enlarge it.
        gb.gap_count += grow_amount;
    }

    Memory.copy(gb.buffer.data + gb.gap_index, bytes.data, bytes.count);
    gb.gap_index += bytes.count;
    gb.gap_count -= bytes.count;

    gb.count += bytes.count;

    #if DEBUG {
        memset(gb.buffer.data + gb.gap_index, 0xff, gb.gap_count);
    }
}

// Deletes at the gap, moving forward. Returns view of deleted bytes.
gap_buffer_delete_forward :: (gb: *Gap_Buffer, delete_count: s64) -> [] u8 /* Pointing to this buffer */ {
    ProfileZone("gap_buffer_delete_forward");

    assert_valid(gb);

    max_delete_count := gb.buffer.count - gb.gap_index - gb.gap_count; // Everything after the gap.
    delete_count = min(delete_count, max_delete_count);

    gb.count -= delete_count;
    gb.gap_count += delete_count;

    view: [] u8;
    view.count = delete_count;
    view.data = gb.buffer.data + gb.gap_index;

    return view;
}

// Deletes at the gap, moving backward. Returns number of actually deleted bytes.
// TODO(jt): Think about returning the array view to deleted content instead (and not clearing the gap).
gap_buffer_delete_backward :: (gb: *Gap_Buffer, delete_count: s64) -> s64 {
    ProfileZone("gap_buffer_delete_backward");

    assert_valid(gb);

    max_delete_count := gb.gap_index;
    delete_count = min(delete_count, max_delete_count);

    gb.count -= delete_count;
    gb.gap_index -= delete_count;
    gb.gap_count += delete_count;

    #if DEBUG {
        memset(gb.buffer.data + gb.gap_index, 0xff, gb.gap_count);
    }

    return delete_count;
}

gap_buffer_replace :: (gb: *Gap_Buffer, delete_count: s64, insert_text: string) {
    gap_buffer_delete_forward(gb, delete_count);
    gap_buffer_insert(gb, insert_text);
}

// Returns either view of original data or new array in the context allocator. Note that if you are
// making a large view, you are negating the copy-avoidance benefits of the gap buffer, so this
// should be used to get screen-sized chunks of text, not the entire buffer.
gap_buffer_make_contiguous_view :: (gb: Gap_Buffer, index: s64, count: s64) -> [] u8 /* Pointing to this buffer, or allocated with context.allocator */ {
    assert_valid(gb);

    assert(index <= gb.count);
    assert(count <= gb.count);
    assert(index + count <= gb.count);

    if index >= gb.count {
        return .[];
    }

    if index + count <= gb.gap_index {
        // Simple case 1: return contiguous array view before the gap.
        return array_view(gb.buffer, index, count);
    }

    if index >= gb.gap_index {
        // Simple case 2: return contiguous array view after the gap, modifying the index.
        return array_view(gb.buffer, index + gb.gap_count, count);
    }

    // General case: copy the before/after parts into a new array and return that.
    result := NewArray(count, u8);

    head_data  := gb.buffer.data + index;
    head_count := gb.gap_index - index;

    tail_data  := gb.buffer.data + gb.gap_index + gb.gap_count;
    tail_count := count - head_count;

    Memory.copy(result.data, head_data, head_count);
    Memory.copy(result.data + head_count, tail_data, tail_count);

    return result;
}

#scope_file

assert_valid :: (gb: Gap_Buffer) {
    assert(gb.count == gb.buffer.count - gb.gap_count);
}

round_up_grow_size :: (required_size: s64) -> s64 {
    PAGE_SIZE :: 2 << 20; // Not the actual page size, just a grow multiplier threshold.

    if required_size < PAGE_SIZE {
        return round_up_to_power_of_two(required_size);
    } else {
        return round_up_to_align(required_size, PAGE_SIZE);
    }
}

round_up_to_align :: inline (x: s64, alignment: s64) -> s64 {
    debug_assert(alignment > 0 && is_power_of_two(alignment));
    mask := alignment - 1;
    return (x + mask) & ~mask;
}

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

is_power_of_two :: inline (value: s64) -> bool {
    return value & (value - 1) == 0;
}

Memory :: #import "Memory";
