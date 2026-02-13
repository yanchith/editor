// TODO(jt): @Cleanup #UnicodeGapBuffer
//
// Currently, Gap_Buffer operates only on bytes and is oblivious to them being UTF8. Buffer (this
// file) adds UTF8 knowledge. However, in multiple places (marked #UnicodeGapBuffer) it would be
// useful to know about Unicode in the gap buffer itself, so we could make its API smaller. Consider it.
Buffer :: struct {
    arena: *Arena;

    // TODO(jt): We want a true 2D cursor that can go anywhere, and we'll just insert spaces... Or
    // at least we want to try it to see if we like it.
    cursor_x: s64;
    cursor_y: s64;

    gb: Gap_Buffer;
    lines: [..] Line; // Always at least one.
}

Line :: struct {
    char_count: s64; // Including newline at the end
    byte_count: s64;
}

make_buffer :: (arena: *Arena) -> Buffer {
    buffer: Buffer;
    buffer.arena = arena;

    // TODO(jt): @Cleanup Find easier way of setting the gap buffer allocator. This is a little too nested.
    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);

    array_add(*buffer.lines);

    return buffer;
}

buffer_insert_at_cursor :: (buffer: *Buffer, text: string) {
    assert_init(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    while text.count {
        newline, newline_advance := string_starts_with_newline(text);
        if newline {
            gap_buffer_insert(*buffer.gb, String.slice(text, 0, newline_advance));
            advance(*text, newline_advance);

            buffer.lines[buffer.cursor_y].char_count += 1;
            buffer.lines[buffer.cursor_y].byte_count += newline_advance;
            buffer.cursor_y += 1;
            buffer.cursor_x = 0;

            array_insert_at(*buffer.lines, { 0, 0 }, buffer.cursor_y);

            continue;
        }

        // character_utf8_to_utf32 also returns the result, but since it automatically replaces
        // malformed characters with the replacement character, we are ignoring it for now.
        codepoint, codepoint_advance := Unicode.character_utf8_to_utf32(text.data, text.count, true);
        // TODO(jt): The Unicode module actually doesn't clamp this by itself and it can be as much as 6 (if the UTF8 is illegal). Cleanup?
        codepoint_advance = clamp(codepoint_advance, 1, 4);
        gap_buffer_insert(*buffer.gb, String.slice(text, 0, codepoint_advance));
        advance(*text, codepoint_advance);

        buffer.lines[buffer.cursor_y].char_count += 1;
        buffer.lines[buffer.cursor_y].byte_count += codepoint_advance;
        buffer.cursor_x += 1;
    }
}

buffer_delete_forward_at_cursor :: (buffer: *Buffer) {
    assert_init(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_after_gap(buffer.gb);

    newline, newline_advance := string_starts_with_newline(bytes);
    if newline {
        buffer.lines[buffer.cursor_y].char_count -= 1;
        buffer.lines[buffer.cursor_y].byte_count -= newline_advance;

        if buffer.cursor_y + 1 < buffer.lines.count {
            buffer.lines[buffer.cursor_y].char_count += buffer.lines[buffer.cursor_y + 1].char_count;
            buffer.lines[buffer.cursor_y].byte_count += buffer.lines[buffer.cursor_y + 1].byte_count;
            array_ordered_remove_by_index(*buffer.lines, buffer.cursor_y + 1);
        }

        gap_buffer_delete_forward(*buffer.gb, newline_advance);
    } else {
        // #UnicodeGapBuffer
        _, codepoint_advance := Unicode.character_utf8_to_utf32(bytes.data, bytes.count, true);
        // TODO(jt): The Unicode module actually doesn't clamp this by itself and it can be as much as 6 (if the UTF8 is illegal). Cleanup?
        codepoint_advance = clamp(codepoint_advance, 1, 4);
        gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
    }
}

buffer_delete_backward_at_cursor :: (buffer: *Buffer) {
    assert_init(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    // TODO(jt): Handle unicode and delete the entire character, not just the last byte.
    deleted := gap_buffer_delete_backward(*buffer.gb, 1);

    // XXX: HERE line management! Parse the deleted text for newlines and update buffer.lines
    // appropriately (like we do in forward delete, but harder, because it is backwards). What does
    // Rust do here?
}

buffer_maybe_move_cursor_x :: (buffer: *Buffer, delta: s64) {
    assert_init(buffer);

    // Cursor can be past the last character.
    buffer.cursor_x = clamp(buffer.cursor_x + delta, 0, buffer.lines[buffer.cursor_y].char_count);
}

buffer_maybe_move_cursor_y :: (buffer: *Buffer, delta: s64) {
    assert_init(buffer);

    // Cursor can not be past the last line
    buffer.cursor_y = clamp(buffer.cursor_y + delta, 0, buffer.lines.count - 1);
}

#scope_file

assert_init :: (buffer: Buffer) {
    assert(buffer.lines.count > 0, "Buffer not initialized. Call make_buffer() to initialize.");
}

string_starts_with_newline :: (bytes: [] u8) -> bool, newline_byte_length: s64 {
    newline, newline_byte_length := string_starts_with_newline(cast(string, bytes));
    return newline, newline_byte_length;
}

string_starts_with_newline :: (s: string) -> bool, newline_byte_length: s64 {
    if s.count > 0 && s[0] == "\n" {
        return true, 1;
    } else if s.count > 1 && s[0] == "\r" && s[1] == "\n" {
        return true, 2;
    }

    return false, 0;
}

get_gap_buffer_index_for_cursor :: (buffer: Buffer) -> s64 {
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

    for 0..buffer.cursor_x - 1 {
        // #UnicodeGapBuffer
        first_byte := gap_buffer_get_nongap_byte(buffer.gb, index);
        continuation_bytes := Unicode.trailingBytesForUTF8[first_byte];

        index += 1 + continuation_bytes;
    }

    return index;
}
