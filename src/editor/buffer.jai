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
    byte_count: s64;
}

make_buffer :: (arena: *Arena) -> Buffer {
    buffer: Buffer;
    buffer.arena = arena;

    // TODO(jt): @Cleanup Find easier way of setting the gap buffer allocator. This is a little too nested.
    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);

    return buffer;
}

insert_to_buffer_at_cursor :: (buffer: *Buffer, text: string) {
    gb_index := get_gap_buffer_index(buffer);

    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    while text.count {
        newline, newline_advance := string_starts_with_newline(text);
        if newline {
            gap_buffer_insert(*buffer.gb, String.slice(text, 0, newline_advance));
            advance(*text, newline_advance);

            assert(buffer.cursor_y <= buffer.lines.count);
            if buffer.cursor_y == buffer.lines.count {
                array_add(*buffer.lines);
            }

            buffer.lines[buffer.cursor_y].char_count += 1; // Q: Should we be taking the newline as a new character?
            buffer.lines[buffer.cursor_y].byte_count += newline_advance;
            buffer.cursor_y += 1;
            buffer.cursor_x = 0;

            // XXX: HERE Splice new line. Note that we have a virtual line at the end.

            continue;
        }

        // character_utf8_to_utf32 also returns the result, but since it automatically replaces
        // malformed characters with the replacement character, we are ignoring it for now.
        codepoint, codepoint_advance := Unicode.character_utf8_to_utf32(text.data, text.count);
        gap_buffer_insert(*buffer.gb, String.slice(text, 0, codepoint_advance));
        advance(*text, codepoint_advance);

        assert(buffer.cursor_y <= buffer.lines.count);
        if buffer.cursor_y == buffer.lines.count {
            array_add(*buffer.lines);
        }

        buffer.lines[buffer.cursor_y].char_count += 1;
        buffer.lines[buffer.cursor_y].byte_count += codepoint_advance;
        buffer.cursor_x += 1;
    }

    // XXX: Move cursor forward!
    // XXX: HERE line management! Parse the inserted text for newlines and update buffer.lines appropriately.

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

maybe_move_buffer_cursor_x :: (buffer: *Buffer, delta: s64) {
    // Cursor can be past the last character.
    buffer.cursor_x = clamp(buffer.cursor_x + delta, 0, buffer.lines[buffer.cursor_y].char_count);
}

maybe_move_buffer_cursor_y :: (buffer: *Buffer, delta: s64) {
    // Cursor can be past the last line
    buffer.cursor_y = clamp(buffer.cursor_y + delta, 0, buffer.lines.count);
}

#scope_file

string_starts_with_newline :: (s: string) -> bool, advance: s64 {
    if s.count > 0 && s[0] == "\n" {
        return true, 1;
    } else if s.count > 1 && s[0] == "\r" && s[1] == "\n" {
        return true, 2;
    }

    return false, 0;
}

get_gap_buffer_index :: (buffer: Buffer) -> s64 {
    assert(buffer.cursor_y >= 0 && buffer.cursor_y <= buffer.lines.count);
    assert(buffer.cursor_x >= 0 && (buffer.cursor_y == buffer.lines.count || buffer.cursor_x <= buffer.lines[buffer.cursor_y].char_count));

    line_index := buffer.cursor_y;
    if line_index >= buffer.lines.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.count;
    }

    index := 0;
    for 0..line_index - 1 {
        index += buffer.lines[it].byte_count;
    }

    for 0..buffer.cursor_x {
        index += 1; // XXX: @Incomplete Parse utf8 here to know the byte offset.
    }

    return index;
}
