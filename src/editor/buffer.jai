Buffer :: struct {
    arena: *Arena;

    // TODO(jt): We want a true 2D cursor that can go anywhere, and we'll just insert spaces... Or
    // at least we want to try it to see if we like it.
    cursor_x: s64;
    cursor_y: s64;

    gb: Gap_Buffer;
    lines: [..] Line;
}

Line :: struct {
    char_count: s64;
}

make_buffer :: (arena: *Arena) -> Buffer {
    buffer: Buffer;
    buffer.arena = arena;

    // TODO(jt): Find easier way of setting the gap buffer allocator. This is a little too nested.
    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);

    // Make sure at least one line exists. Code later just assumes it.
    array_add(*buffer.lines, { 0 });

    return buffer;
}

insert_to_buffer_at_cursor :: (buffer: *Buffer, text: string) {
    gb_index := get_gap_buffer_index(buffer);

    // XXX: Move cursor forward!
    // XXX: HERE line management! Parse the inserted text for newlines and update buffer.lines appropriately.

    gap_buffer_move_gap_to(*buffer.gb, gb_index);
    gap_buffer_insert(*buffer.gb, text);
}

delete_forward_from_buffer_at_cursor :: (buffer: *Buffer) {
    gb_index := get_gap_buffer_index(buffer);

    gap_buffer_move_gap_to(*buffer.gb, gb_index);
    // TODO(jt): Handle unicode and delete the entire character, not just the first byte.
    deleted := gap_buffer_delete_forward(*buffer.gb, 1);

    // XXX: HERE line management! Parse the deleted text for newlines and update buffer.lines appropriately.
}

delete_backward_from_buffer_at_cursor :: (buffer: *Buffer) {
    gb_index := get_gap_buffer_index(buffer);

    gap_buffer_move_gap_to(*buffer.gb, gb_index);
    // TODO(jt): Handle unicode and delete the entire character, not just the last byte.
    deleted := gap_buffer_delete_backward(*buffer.gb, 1);

    // XXX: HERE line management! Parse the deleted text for newlines and update buffer.lines appropriately.
}

maybe_move_buffer_cursor :: (buffer: *Buffer, horizontal_move: s64, vertical_move: s64 = 0) {
    buffer.cursor_x = clamp(buffer.cursor_x + horizontal_move, 0, buffer.gb.count);   // Cursor can be past the last character
    buffer.cursor_y = clamp(buffer.cursor_y + vertical_move, 0, buffer.lines.count);  // Cursor can be past the last line
}

#scope_file

get_gap_buffer_index :: (buffer: Buffer) -> s64 {
    assert(buffer.cursor_y >= 0 && buffer.cursor_y <= buffer.lines.count);
    assert(buffer.cursor_x >= 0 && buffer.cursor_x <= buffer.lines[buffer.cursor_y].char_count);

    line_index := buffer.cursor_y;
    if line_index >= buffer.lines.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.count;
    }

    index := 0;
    for 0..line_index - 1 {
        index += buffer.lines[it].char_count;
    }

    index += buffer.cursor_x;

    return index;
}
