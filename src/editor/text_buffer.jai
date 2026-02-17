// Currently, Gap_Buffer operates only on bytes and is oblivious to them being UTF8. The Buffer
// struct (this file) adds UTF8 knowledge. For now this is how it is.
Text_Buffer :: struct {
    arena: *Arena;

    cursor: Cursor;
    gb: Gap_Buffer;
    lines: [..] Line; // Always at least one.
}

Cursor :: struct {
    x: s64;
    y: s64;
}

operator == :: (a: Cursor, b: Cursor) -> bool {
    return a.x == b.x && a.y == b.y;
}

CURSOR_INVALID :: Cursor.{ -1, -1 };

Line :: struct {
    char_count: s64; // Including newline at the end
    byte_count: s64;
}

make_text_buffer :: (arena: *Arena) -> Text_Buffer {
    buffer: Text_Buffer;
    buffer.arena = arena;

    // TODO(jt): @Cleanup Find easier way of setting the gap buffer allocator. This is a little too nested.
    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);

    // TODO(jt): @Cleanup We currently have a implicit newline at the end of the file. Consider
    // making it explicit-but-undeletable (and adding/stripping it where necessary) to make stuff
    // here simpler. Look for 'buffer.lines.count - 1' to find code that detects it.
    array_add(*buffer.lines);

    assert_valid(buffer);

    return buffer;
}

text_buffer_insert_at_cursor :: (buffer: *Text_Buffer, text: string) {
    assert_valid(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    while text.count {
        newline, newline_advance := string_starts_with_newline(text);
        if newline {
            // XXX: HERE @Bug If we insert a anywhere except at the end, this corruprts our metadata.
            line_end := text_buffer_get_end_cursor_for_line(buffer, buffer.cursor.y);

            char_count_after_cursor := buffer.lines[buffer.cursor.y].char_count - buffer.cursor.x;
            byte_count_after_cursor := text_buffer_byte_count_between_cursors(buffer, buffer.cursor, line_end);

            gap_buffer_insert(*buffer.gb, String.slice(text, 0, newline_advance));
            advance(*text, newline_advance);

            buffer.lines[buffer.cursor.y].char_count += 1 - char_count_after_cursor;
            buffer.lines[buffer.cursor.y].byte_count += newline_advance - byte_count_after_cursor;

            array_insert_at(*buffer.lines, { char_count_after_cursor, byte_count_after_cursor }, buffer.cursor.y + 1);

            buffer.cursor.y += 1;
            buffer.cursor.x = 0;

            continue;
        }

        // TODO(jt): The Unicode module actually doesn't clamp this by itself and it can be as much
        // as 6 (this was valid in older specs?). Cleanup?
        codepoint_advance := clamp(Unicode.trailingBytesForUTF8[text[0]], 1, 4);
        gap_buffer_insert(*buffer.gb, String.slice(text, 0, codepoint_advance));
        advance(*text, codepoint_advance);

        buffer.lines[buffer.cursor.y].char_count += 1;
        buffer.lines[buffer.cursor.y].byte_count += codepoint_advance;
        buffer.cursor.x += 1;
    }

    assert_valid(buffer);
}

text_buffer_delete_forward_at_cursor :: (buffer: *Text_Buffer) {
    assert_valid(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_after_gap(buffer.gb);

    newline, newline_advance := string_starts_with_newline(bytes);
    if newline {
        if buffer.cursor.y == buffer.lines.count - 1 {
            assert(buffer.cursor.x == buffer.lines[buffer.cursor.y].char_count);
        } else {
            assert(buffer.cursor.x == buffer.lines[buffer.cursor.y].char_count - 1);
        }
        assert(buffer.cursor.y + 1 < buffer.lines.count);

        buffer.lines[buffer.cursor.y].char_count -= 1;
        buffer.lines[buffer.cursor.y].byte_count -= newline_advance;

        buffer.lines[buffer.cursor.y].char_count += buffer.lines[buffer.cursor.y + 1].char_count;
        buffer.lines[buffer.cursor.y].byte_count += buffer.lines[buffer.cursor.y + 1].byte_count;

        array_ordered_remove_by_index(*buffer.lines, buffer.cursor.y + 1);

        deleted := gap_buffer_delete_forward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted.count);
    } else {
        _, codepoint_advance := find_next_utf8_character_boundary(bytes, 0);
        if codepoint_advance {
            buffer.lines[buffer.cursor.y].char_count -= 1;
            buffer.lines[buffer.cursor.y].byte_count -= codepoint_advance;

            deleted := gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted.count);
        }
    }

    assert_valid(buffer);
}

text_buffer_delete_backward_at_cursor :: (buffer: *Text_Buffer) {
    assert_valid(buffer);

    gb_index := get_gap_buffer_index_for_cursor(buffer);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_before_gap(buffer.gb);

    newline, newline_advance := string_ends_with_newline(bytes);
    if newline {
        assert(buffer.cursor.x == 0);
        assert(buffer.cursor.y > 0);

        new_cursor_x := buffer.lines[buffer.cursor.y - 1].char_count - 1;

        buffer.lines[buffer.cursor.y - 1].char_count -= 1;
        buffer.lines[buffer.cursor.y - 1].byte_count -= newline_advance;

        buffer.lines[buffer.cursor.y - 1].char_count += buffer.lines[buffer.cursor.y].char_count;
        buffer.lines[buffer.cursor.y - 1].byte_count += buffer.lines[buffer.cursor.y].byte_count;

        array_ordered_remove_by_index(*buffer.lines, buffer.cursor.y);

        buffer.cursor.x = new_cursor_x;
        buffer.cursor.y -= 1;

        deleted := gap_buffer_delete_backward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted.count);
    } else {
        _, codepoint_advance := find_previous_utf8_character_boundary(bytes, bytes.count);
        if codepoint_advance {
            buffer.lines[buffer.cursor.y].char_count -= 1;
            buffer.lines[buffer.cursor.y].byte_count -= codepoint_advance;

            buffer.cursor.x -= 1;

            deleted := gap_buffer_delete_backward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted.count);
        }
    }

    assert_valid(buffer);
}

text_buffer_get_start_cursor_for_line :: (buffer: Text_Buffer, line_index: s64) -> Cursor {
    assert(line_index < buffer.lines.count);
    start: Cursor = { 0, line_index };

    return start;
}

text_buffer_get_end_cursor_for_line :: (buffer: Text_Buffer, line_index: s64) -> Cursor {
    assert(line_index < buffer.lines.count);
    line := buffer.lines[line_index];
    endx := ifx line_index == buffer.lines.count - 1 then line.char_count else line.char_count - 1;
    end:   Cursor = { endx, line_index };

    return end;
}

text_buffer_get_cursors_for_line :: (buffer: Text_Buffer, line_index: s64) -> start: Cursor, end: Cursor {
    start: Cursor = inline text_buffer_get_start_cursor_for_line(buffer, line_index);
    end:   Cursor = inline text_buffer_get_end_cursor_for_line(buffer, line_index);

    return start, end;
}

text_buffer_byte_count_between_cursors :: (buffer: Text_Buffer, _start: Cursor, _end: Cursor) -> s64 {
    assert_cursor_valid(buffer, _start);
    assert_cursor_valid(buffer, _end);

    start := _start;
    end   := _end;

    if start.y > end.y {
        swap(*start, *end);
    }

    if start.y == end.y && start.x > end.x {
        swap(*start.x, *end.x);
    }

    start_index := get_gap_buffer_index_for_cursor(buffer, start);
    end_index   := get_gap_buffer_index_for_cursor(buffer, end);

    return end_index - start_index;
}

text_buffer_view_between_cursors :: (buffer: Text_Buffer, _start: Cursor, _end: Cursor) -> string /* Pointing to the internal gap buffer, or allocated with context.allocator */ {
    assert_cursor_valid(buffer, _start);
    assert_cursor_valid(buffer, _end);

    start := _start;
    end   := _end;

    if start.y > end.y {
        swap(*start, *end);
    }

    if start.y == end.y && start.x > end.x {
        swap(*start.x, *end.x);
    }

    start_index := get_gap_buffer_index_for_cursor(buffer, start);
    end_index   := get_gap_buffer_index_for_cursor(buffer, end);

    view := gap_buffer_make_contiguous_view(buffer.gb, start_index, end_index - start_index);

    return cast(string, view);
}

text_buffer_maybe_move_cursor_x :: (buffer: *Text_Buffer, delta: s64) {
    assert_valid(buffer);

    if delta > 0 {
        while delta > 0 {
            // Cursor can be past the last non-newline character. However, the last line does not
            // have the newline character, so we only pretend it does.
            if buffer.cursor.y == buffer.lines.count - 1 {
                buffer.cursor.x = min(buffer.cursor.x + 1, buffer.lines[buffer.cursor.y].char_count);
            } else if buffer.cursor.x < buffer.lines[buffer.cursor.y].char_count - 1 {
                buffer.cursor.x += 1;
            } else {
                buffer.cursor.x = 0;
                buffer.cursor.y += 1;
            }

            delta -= 1;
        }
    } else if delta < 0 {
        while delta < 0 {
            if buffer.cursor.y == 0 {
                buffer.cursor.x = max(buffer.cursor.x - 1, 0);
            } else if buffer.cursor.x > 0 {
                buffer.cursor.x -= 1;
            } else {
                buffer.cursor.x = buffer.lines[buffer.cursor.y - 1].char_count - 1;
                buffer.cursor.y -= 1;
            }

            delta += 1;
        }
    }

    assert_valid(buffer);
}

text_buffer_maybe_move_cursor_y :: (buffer: *Text_Buffer, delta: s64) {
    assert_valid(buffer);

    // Cursor can not be past the last line
    buffer.cursor.y = clamp(buffer.cursor.y + delta, 0, buffer.lines.count - 1);

    // Clamp X.
    if buffer.cursor.y == buffer.lines.count - 1 {
        buffer.cursor.x = clamp(buffer.cursor.x, 0, buffer.lines[buffer.cursor.y].char_count);
    } else {
        buffer.cursor.x = clamp(buffer.cursor.x, 0, buffer.lines[buffer.cursor.y].char_count - 1);
    }

    assert_valid(buffer);
}

#scope_file

assert_valid :: (buffer: Text_Buffer) {
    assert(buffer.lines.count > 0, "Text_Buffer not initialized (has to have at least one line). Call make_buffer() to initialize.");
    assert_cursor_valid(buffer, buffer.cursor);

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

assert_cursor_valid :: (buffer: Text_Buffer, cursor: Cursor) {
    assert(cursor.y >= 0 && cursor.y < buffer.lines.count);
    if cursor.y == buffer.lines.count - 1 {
        assert(cursor.x >= 0 && cursor.x <= buffer.lines[cursor.y].char_count);
    } else {
        assert(cursor.x >= 0 && cursor.x < buffer.lines[cursor.y].char_count);
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

get_gap_buffer_index_for_cursor :: (buffer: Text_Buffer, _cursor := CURSOR_INVALID) -> s64 {
    cursor := _cursor;
    if _cursor == CURSOR_INVALID {
        cursor = buffer.cursor;
    }

    assert(cursor.y >= 0 && cursor.y < buffer.lines.count);
    if cursor.y == buffer.lines.count - 1 {
        assert(cursor.x >= 0 && cursor.x <= buffer.lines[cursor.y].char_count);
    } else {
        assert(cursor.x >= 0 && cursor.x < buffer.lines[cursor.y].char_count);
    }

    line_index := cursor.y;
    if line_index >= buffer.lines.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.occupied_count;
    }

    index := 0;
    for 0..line_index - 1 {
        index += buffer.lines[it].byte_count;
    }

    for 0..cursor.x - 1 {
        first_byte := gap_buffer_get_nongap_byte(buffer.gb, index);
        continuation_bytes := Unicode.trailingBytesForUTF8[first_byte];

        index += 1 + continuation_bytes;
    }

    return index;
}
