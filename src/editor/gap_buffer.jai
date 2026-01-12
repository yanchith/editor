// XXX: HERE Fix bugs here and then finish implementing the rest.

GAP_BUFFER_STARTING_COUNT :: 4; // TODO(jt): Intentionally low initially, to test this. Increase eventually!

Gap_Buffer :: struct {
    gap_index: s64;
    gap_count: s64;

    buffer: [..] u8;
}

gap_buffer_init :: (gb: *Gap_Buffer, count := GAP_BUFFER_STARTING_COUNT) {
    gb.gap_index = 0;
    gb.gap_count = count;

    array_reserve(*gb.buffer, count);
}

gap_buffer_move_gap :: (gb: *Gap_Buffer, index: s64) {

}

gap_buffer_insert :: (gb: *Gap_Buffer, text: string) {
    if text.count > gb.gap_count {
        // TODO(jt): @Speed @Memory Round up new buffer.count to a power of two, until we reach
        // page_size, after which point add in multiples of page_size.
        old_count := gb.buffer.count;
        new_count := gb.buffer.count + text.count - gb.gap_count;

        delta := new_count - old_count;

        tail_data  := gb.buffer.data + gb.gap_index + gb.gap_count;
        tail_count := gb.buffer.count - gb.gap_count - gb.gap_index;

        array_reserve(*gb.buffer, new_count);

        // TODO(jt): @Correctness Make sure memory is allowed to overlap in JAI's memcpy.
        memcpy(tail_data + delta, tail_data, tail_count);
    }

    memcpy(gb.buffer.data + gb.gap_index, text.data, text.count);
    gb.gap_count -= text.count;
}

gap_buffer_delete_forward :: (gb: *Gap_Buffer, count: s64) {
    if gb.gap_index + gb.gap_count < gb.buffer.count {
        gb.gap_count += 1;
    }
}

gap_buffer_delete_backward :: (gb: *Gap_Buffer, count: s64) {
    if gb.gap_index > 0 {
        gb.gap_index -= 1;
        gb.gap_size += 1;
    }
}

// TODO(jt): Implement gb_buffer_replace
// gap_buffer_replace :: (gb: *Gap_Buffer, count: s64, text: string) {
//
// }

// Returns either view of original data or allocated in Temporary_Storage, otherwise we'd have to
// always allocate.
gap_buffer_get_contiguous_view :: (gb: Gap_Buffer, index: s64, count: s64) -> string {
    if index + count <= gb.gap_index {
        return cast(string, array_view(gb.buffer, index, count));
    }

    if index >= gb.gap_index + gb.gap_count {
        return cast(string, array_view(gb.buffer, index, count));
    }

    result := NewArray(count, u8, initialized=false,, temp);

    head_data  := gb.buffer.data + index;
    head_count := gb.gap_index - index;

    tail_data  := gb.buffer.data + gb.gap_index + gb.gap_count;
    tail_count := count - head_count;

    memcpy(result.data, head_data, head_count);
    memcpy(result.data + head_count, tail_data, tail_count);

    return cast(string, result);
}
