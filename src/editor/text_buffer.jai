// Currently, Gap_Buffer operates only on bytes and is oblivious to them being UTF8. The Buffer
// struct (this file) adds UTF8 knowledge. For now this is how it is.
TextBuffer :: struct {
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

make_text_buffer :: (arena: *Arena) -> TextBuffer {
    buffer: TextBuffer;
    buffer.arena = arena;

    // TODO(jt): @Cleanup Find easier way of setting the gap buffer allocator. This is a little too nested.
    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);

    array_add(*buffer.lines);

    assert_valid(buffer);

    return buffer;
}

text_buffer_insert_at_cursor :: (buffer: *TextBuffer, text: string) {
    assert_valid(buffer);

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

        // TODO(jt): The Unicode module actually doesn't clamp this by itself and it can be as much
        // as 6 (this was valid in older specs?). Cleanup?
        codepoint_advance := clamp(Unicode.trailingBytesForUTF8[text[0]], 1, 4);
        gap_buffer_insert(*buffer.gb, String.slice(text, 0, codepoint_advance));
        advance(*text, codepoint_advance);

        buffer.lines[buffer.cursor_y].char_count += 1;
        buffer.lines[buffer.cursor_y].byte_count += codepoint_advance;
        buffer.cursor_x += 1;
    }

    assert_valid(buffer);
}

text_buffer_delete_forward_at_cursor :: (buffer: *TextBuffer) {
    assert_valid(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_after_gap(buffer.gb);

    newline, newline_advance := string_starts_with_newline(bytes);
    if newline {
        if buffer.cursor_y == buffer.lines.count - 1 {
            assert(buffer.cursor_x == buffer.lines[buffer.cursor_y].char_count);
        } else {
            assert(buffer.cursor_x == buffer.lines[buffer.cursor_y].char_count - 1);
        }
        assert(buffer.cursor_y + 1 < buffer.lines.count);

        buffer.lines[buffer.cursor_y].char_count -= 1;
        buffer.lines[buffer.cursor_y].byte_count -= newline_advance;

        buffer.lines[buffer.cursor_y].char_count += buffer.lines[buffer.cursor_y + 1].char_count;
        buffer.lines[buffer.cursor_y].byte_count += buffer.lines[buffer.cursor_y + 1].byte_count;

        array_ordered_remove_by_index(*buffer.lines, buffer.cursor_y + 1);

        gap_buffer_delete_forward(*buffer.gb, newline_advance);
    } else {
        _, codepoint_advance := find_next_utf8_character_boundary(bytes, 0);
        if codepoint_advance {
            buffer.lines[buffer.cursor_y].char_count -= 1;
            buffer.lines[buffer.cursor_y].byte_count -= codepoint_advance;

            gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
        }
    }

    assert_valid(buffer);
}

// XXX: @Bug Double backspace after startup crashes this.
text_buffer_delete_backward_at_cursor :: (buffer: *TextBuffer) {
    assert_valid(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_before_gap(buffer.gb);

    newline, newline_advance := string_ends_with_newline(bytes);
    if newline {
        assert(buffer.cursor_x == 0);
        assert(buffer.cursor_y > 1);

        new_cursor_x := buffer.lines[buffer.cursor_y - 1].char_count - 1;

        buffer.lines[buffer.cursor_y - 1].char_count -= 1;
        buffer.lines[buffer.cursor_y - 1].byte_count -= newline_advance;

        buffer.lines[buffer.cursor_y - 1].char_count += buffer.lines[buffer.cursor_y].char_count;
        buffer.lines[buffer.cursor_y - 1].byte_count += buffer.lines[buffer.cursor_y].byte_count;

        array_ordered_remove_by_index(*buffer.lines, buffer.cursor_y);

        buffer.cursor_x = new_cursor_x;
        buffer.cursor_y -= 1;

        gap_buffer_delete_backward(*buffer.gb, newline_advance);
    } else {
        _, codepoint_advance := find_previous_utf8_character_boundary(bytes, bytes.count);
        if codepoint_advance {
            buffer.lines[buffer.cursor_y].char_count -= 1;
            buffer.lines[buffer.cursor_y].byte_count -= codepoint_advance;

            gap_buffer_delete_backward(*buffer.gb, codepoint_advance);
        }
    }

    assert_valid(buffer);
}

text_buffer_maybe_move_cursor_x :: (buffer: *TextBuffer, delta: s64) {
    assert_valid(buffer);

    if delta > 0 {
        while delta > 0 {
            // Cursor can be past the last non-newline character. However, the last line does not
            // have the newline character, so we only pretend it does.
            if buffer.cursor_y == buffer.lines.count - 1 {
                buffer.cursor_x = min(buffer.cursor_x + 1, buffer.lines[buffer.cursor_y].char_count);
            } else if buffer.cursor_x < buffer.lines[buffer.cursor_y].char_count {
                buffer.cursor_x += 1;
            } else {
                buffer.cursor_x = 0;
                buffer.cursor_y += 1;
            }

            delta -= 1;
        }
    } else if delta < 0 {
        while delta < 0 {
            if buffer.cursor_y == 0 {
                buffer.cursor_x = max(buffer.cursor_x - 1, 0);
            } else if buffer.cursor_x > 0 {
                buffer.cursor_x -= 1;
            } else {
                buffer.cursor_x = buffer.lines[buffer.cursor_y - 1].char_count - 1;
                buffer.cursor_y -= 1;
            }

            delta += 1;
        }
    }

    assert_valid(buffer);
}

text_buffer_maybe_move_cursor_y :: (buffer: *TextBuffer, delta: s64) {
    assert_valid(buffer);

    // Cursor can not be past the last line
    buffer.cursor_y = clamp(buffer.cursor_y + delta, 0, buffer.lines.count - 1);

    // Clamp X.
    if buffer.cursor_y == buffer.lines.count - 1 {
        buffer.cursor_x = clamp(buffer.cursor_x, 0, buffer.lines[buffer.cursor_y].char_count);
    } else {
        buffer.cursor_x = clamp(buffer.cursor_x, 0, buffer.lines[buffer.cursor_y].char_count - 1);
    }

    assert_valid(buffer);
}

#scope_file

assert_valid :: (buffer: TextBuffer) {
    assert(buffer.lines.count > 0, "TextBuffer not initialized (has to have at least one line). Call make_buffer() to initialize.");

    assert(buffer.cursor_y >= 0 && buffer.cursor_y < buffer.lines.count);
    if buffer.cursor_y == buffer.lines.count - 1 {
        assert(buffer.cursor_x >= 0 && buffer.cursor_x <= buffer.lines[buffer.cursor_y].char_count);
    } else {
        assert(buffer.cursor_x >= 0 && buffer.cursor_x < buffer.lines[buffer.cursor_y].char_count);
    }

    count := 0;
    for 0..buffer.lines.count - 2 {
        assert(buffer.lines[it].char_count >= 0);
        assert(buffer.lines[it].byte_count >= 0);

        line_byte_count := buffer.lines[it].byte_count;
        count += line_byte_count;

        assert(gap_buffer_get_nongap_byte(buffer.gb, count - 1) == "\n");
    }

    line_byte_count := buffer.lines[buffer.lines.count - 1].byte_count;
    if line_byte_count > 0 {
        count += line_byte_count;
        assert(gap_buffer_get_nongap_byte(buffer.gb, count - 1) != "\n");
    }
}

string_starts_with_newline :: (bytes: [] u8) -> bool, newline_byte_length: s64 {
    newline, newline_byte_length := inline string_starts_with_newline(cast(string, bytes));
    return newline, newline_byte_length;
}

string_starts_with_newline :: (s: string) -> bool, newline_byte_length: s64 {
    if s.count > 1 && s[0] == "\r" && s[1] == "\n" {
        return true, 2;
    } else if s.count > 0 && s[0] == "\n" {
        return true, 1;
    }

    return false, 0;
}

string_ends_with_newline :: (bytes: [] u8) -> bool, newline_byte_length: s64 {
    newline, newline_byte_length := inline string_ends_with_newline(cast(string, bytes));
    return newline, newline_byte_length;
}

string_ends_with_newline :: (s: string) -> bool, newline_byte_length: s64 {
    if s.count > 1 && s[s.count - 2] == "\r" && s[s.count - 1] == "\n" {
        return true, 2;
    } else if s.count > 0 && s[s.count - 1] == "\n" {
        return true, 1;
    }

    return false, 0;
}

find_next_utf8_character_boundary :: (bytes: [] u8, index: s64) -> index: s64, scanned_count: s64 {
    assert(index >= 0 && index <= bytes.count); // <=, because our cursor can be pointing past the buffer.
    if index == bytes.count {
        return bytes.count, 0;
    }

    // When scanning forward, we could also trust the unicode and advance based on what we read? Not
    // sure if that's going to be faster, since it introduces a data dependency.
    next_index := index + 1;
    while next_index < bytes.count && Unicode.trailingBytesForUTF8[bytes[next_index]] > 0 {
        next_index += 1;
    }

    return next_index, next_index - index;
}

find_previous_utf8_character_boundary :: (bytes: [] u8, index: s64) -> index: s64, scanned_count: s64 {
    assert(index >= 0 && index <= bytes.count); // <=, because our cursor can be pointing past the buffer.
    if index == 0 {
        return 0, 0;
    }

    prev_index := index - 1;
    while prev_index > 0 && Unicode.trailingBytesForUTF8[bytes[prev_index]] > 0 {
        prev_index -= 1;
    }

    return prev_index, index - prev_index;
}

get_gap_buffer_index_for_cursor :: (buffer: TextBuffer) -> s64 {
    assert(buffer.cursor_y >= 0 && buffer.cursor_y < buffer.lines.count);
    if buffer.cursor_y == buffer.lines.count - 1 {
        assert(buffer.cursor_x >= 0 && buffer.cursor_x <= buffer.lines[buffer.cursor_y].char_count);
    } else {
        assert(buffer.cursor_x >= 0 && buffer.cursor_x < buffer.lines[buffer.cursor_y].char_count);
    }

    line_index := buffer.cursor_y;
    if line_index >= buffer.lines.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.occupied_count;
    }

    index := 0;
    for 0..line_index - 1 {
        index += buffer.lines[it].byte_count;
    }

    for 0..buffer.cursor_x - 1 {
        first_byte := gap_buffer_get_nongap_byte(buffer.gb, index);
        continuation_bytes := Unicode.trailingBytesForUTF8[first_byte];

        index += 1 + continuation_bytes;
    }

    return index;
}
