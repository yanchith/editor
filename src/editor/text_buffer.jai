// Currently, Gap_Buffer operates only on bytes and is oblivious to them being UTF8. The Buffer
// struct (this file) adds UTF8 knowledge. For now this is how it is.
Text_Buffer :: struct {
    arena: *Arena;

    cursor0: Cursor;
    cursor1: Cursor;

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

Line :: struct {
    char_count: s64; // Including newline at the end
    byte_count: s64;
}

text_buffer_init :: (buffer: *Text_Buffer, arena: *Arena) {
    buffer.* = {};

    buffer.arena = arena;

    // TODO(jt): @Cleanup Find easier way of setting the gap buffer allocator. This is a little too nested.
    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);

    // TODO(jt): @Cleanup We currently have a implicit newline at the end of the file. Consider
    // making it explicit-but-undeletable (and adding/stripping it where necessary) to make stuff
    // here simpler. Look for 'buffer.lines.count - 1' to find code that detects it.
    array_add(*buffer.lines);

    assert_valid(buffer);
}

text_buffer_insert :: (buffer: *Text_Buffer, text: string) {
    // TODO(jt): @Speed We currently insert things into the gap buffer byte by byte. Batch it!

    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_between_cursors(buffer);
        assert(buffer.cursor0 == buffer.cursor1);
    }

    gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, text_buffer_get_min_cursor(buffer));
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    while text.count {
        newline, newline_advance := string_starts_with_newline(text);
        if newline {
            line_start := text_buffer_get_start_cursor_for_line(buffer, buffer.cursor0.y);
            bytes_before_cursor := text_buffer_byte_count_between_cursors(buffer, line_start, buffer.cursor0);

            char_count_after_cursor := buffer.lines[buffer.cursor0.y].char_count - buffer.cursor0.x;
            byte_count_after_cursor := buffer.lines[buffer.cursor0.y].byte_count - bytes_before_cursor;

            gap_buffer_insert(*buffer.gb, String.slice(text, 0, newline_advance));
            advance(*text, newline_advance);

            // We treat \r\n as one character, if it happens to be in there.
            buffer.lines[buffer.cursor0.y].char_count += 1 - char_count_after_cursor;
            buffer.lines[buffer.cursor0.y].byte_count += newline_advance - byte_count_after_cursor;

            array_insert_at(*buffer.lines, { char_count_after_cursor, byte_count_after_cursor }, buffer.cursor0.y + 1);

            buffer.cursor0.y += 1;
            buffer.cursor0.x = 0;

            continue;
        }

        // TODO(jt): The Unicode module actually doesn't clamp this by itself and it can be as much
        // as 6 (this was valid in older specs?). Cleanup?
        codepoint_advance := clamp(1 + Unicode.trailingBytesForUTF8[text[0]], 1, 4);

        // TODO(jt): This probably shouldn't be an assert, but we need to do something about
        // incorrect unicode coming in and prevent it getting into the buffer. If we are ingesting a
        // new file, we should probably check ahead for encoding or something. If we are in
        // interactive mode, maybe it is okay to not insert.
        _, codepoint_advance_check := find_next_utf8_character_boundary(cast([] u8, text), 0);
        assert(codepoint_advance == codepoint_advance_check);

        gap_buffer_insert(*buffer.gb, String.slice(text, 0, codepoint_advance));
        advance(*text, codepoint_advance);

        buffer.lines[buffer.cursor0.y].char_count += 1;
        buffer.lines[buffer.cursor0.y].byte_count += codepoint_advance;
        buffer.cursor0.x += 1;
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);
}

text_buffer_delete_between_cursors :: (buffer: *Text_Buffer) {
    assert_valid(buffer);

    if buffer.cursor0 == buffer.cursor1 {
        return;
    }

    start_cursor := text_buffer_get_min_cursor(buffer);
    end_cursor   := text_buffer_get_max_cursor(buffer);

    start_gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, start_cursor);
    end_gb_index   := text_buffer_get_gap_buffer_index_for_cursor(buffer, end_cursor);

    gap_buffer_move_gap_to(*buffer.gb, start_gb_index);

    buffer.cursor0 = start_cursor;
    buffer.cursor1 = start_cursor;

    bytes := gap_buffer_get_bytes_after_gap(buffer.gb);

    delete_count := end_gb_index - start_gb_index;
    while delete_count > 0 {
        newline, newline_advance := string_starts_with_newline(bytes);
        if newline {
            if buffer.cursor0.y == buffer.lines.count - 1 {
                assert(buffer.cursor0.x == buffer.lines[buffer.cursor0.y].char_count);
            } else {
                assert(buffer.cursor0.x == buffer.lines[buffer.cursor0.y].char_count - 1);
            }
            assert(buffer.cursor0.y + 1 < buffer.lines.count);

            // We treat \r\n as one character, if it happens to be in there.
            buffer.lines[buffer.cursor0.y].char_count -= 1;
            buffer.lines[buffer.cursor0.y].byte_count -= newline_advance;

            buffer.lines[buffer.cursor0.y].char_count += buffer.lines[buffer.cursor0.y + 1].char_count;
            buffer.lines[buffer.cursor0.y].byte_count += buffer.lines[buffer.cursor0.y + 1].byte_count;

            array_ordered_remove_by_index(*buffer.lines, buffer.cursor0.y + 1);

            deleted := gap_buffer_delete_forward(*buffer.gb, newline_advance);
            assert(newline_advance == deleted);

            bytes = array_view(bytes, newline_advance);
            delete_count -= newline_advance;
        } else {
            _, codepoint_advance := find_next_utf8_character_boundary(bytes, 0);
            if codepoint_advance {
                buffer.lines[buffer.cursor0.y].char_count -= 1;
                buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

                deleted := gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
                assert(codepoint_advance == deleted);

                bytes = array_view(bytes, codepoint_advance);
                delete_count -= codepoint_advance;
            }
        }
    }

    assert_valid(buffer);
}

text_buffer_delete_forward :: (buffer: *Text_Buffer) {
    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_between_cursors(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        return;
    }

    gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, text_buffer_get_min_cursor(buffer));
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_after_gap(buffer.gb);

    newline, newline_advance := string_starts_with_newline(bytes);
    if newline {
        if buffer.cursor0.y == buffer.lines.count - 1 {
            assert(buffer.cursor0.x == buffer.lines[buffer.cursor0.y].char_count);
        } else {
            assert(buffer.cursor0.x == buffer.lines[buffer.cursor0.y].char_count - 1);
        }
        assert(buffer.cursor0.y + 1 < buffer.lines.count);

        // We treat \r\n as one character, if it happens to be in there.
        buffer.lines[buffer.cursor0.y].char_count -= 1;
        buffer.lines[buffer.cursor0.y].byte_count -= newline_advance;

        buffer.lines[buffer.cursor0.y].char_count += buffer.lines[buffer.cursor0.y + 1].char_count;
        buffer.lines[buffer.cursor0.y].byte_count += buffer.lines[buffer.cursor0.y + 1].byte_count;

        array_ordered_remove_by_index(*buffer.lines, buffer.cursor0.y + 1);

        deleted := gap_buffer_delete_forward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted);
    } else {
        _, codepoint_advance := find_next_utf8_character_boundary(bytes, 0);
        if codepoint_advance {
            buffer.lines[buffer.cursor0.y].char_count -= 1;
            buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

            deleted := gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted);
        }
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);
}

text_buffer_delete_backward :: (buffer: *Text_Buffer) {
    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_between_cursors(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        return;
    }

    gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, text_buffer_get_min_cursor(buffer));
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_before_gap(buffer.gb);

    newline, newline_advance := string_ends_with_newline(bytes);
    if newline {
        assert(buffer.cursor0.x == 0);
        assert(buffer.cursor0.y > 0);

        new_cursor_x := buffer.lines[buffer.cursor0.y - 1].char_count - 1;

        buffer.lines[buffer.cursor0.y - 1].char_count -= 1;
        buffer.lines[buffer.cursor0.y - 1].byte_count -= newline_advance;

        buffer.lines[buffer.cursor0.y - 1].char_count += buffer.lines[buffer.cursor0.y].char_count;
        buffer.lines[buffer.cursor0.y - 1].byte_count += buffer.lines[buffer.cursor0.y].byte_count;

        array_ordered_remove_by_index(*buffer.lines, buffer.cursor0.y);

        buffer.cursor0.x = new_cursor_x;
        buffer.cursor0.y -= 1;

        deleted := gap_buffer_delete_backward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted);
    } else {
        _, codepoint_advance := find_previous_utf8_character_boundary(bytes, bytes.count);
        if codepoint_advance {
            buffer.lines[buffer.cursor0.y].char_count -= 1;
            buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

            buffer.cursor0.x -= 1;

            deleted := gap_buffer_delete_backward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted);
        }
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);
}

text_buffer_get_start_cursor_for_line :: (buffer: Text_Buffer, line_index: s64) -> Cursor {
    assert(line_index < buffer.lines.count);
    start: Cursor = { 0, line_index };

    return start;
}

text_buffer_get_end_cursor_for_line :: (buffer: Text_Buffer, line_index: s64, include_newline := false) -> Cursor {
    assert(line_index < buffer.lines.count);
    line := buffer.lines[line_index];
    endx := ifx line_index == buffer.lines.count - 1 then line.char_count else line.char_count - 1;
    end:   Cursor = { endx, line_index };

    return end;
}

text_buffer_get_cursors_for_line :: (buffer: Text_Buffer, line_index: s64) -> Cursor, Cursor {
    start: Cursor = text_buffer_get_start_cursor_for_line(buffer, line_index);
    end:   Cursor = text_buffer_get_end_cursor_for_line(buffer, line_index);

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

    start_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, start);
    end_index   := text_buffer_get_gap_buffer_index_for_cursor(buffer, end);

    return end_index - start_index;
}

text_buffer_make_view_between_cursors :: (buffer: Text_Buffer, _start: Cursor, _end: Cursor) -> string /* Pointing to the internal gap buffer, or allocated with context.allocator */ {
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

    start_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, start);
    end_index   := text_buffer_get_gap_buffer_index_for_cursor(buffer, end);

    view := gap_buffer_make_contiguous_view(buffer.gb, start_index, end_index - start_index);

    return cast(string, view);
}

text_buffer_move_cursor_x :: (buffer: *Text_Buffer, delta: s64, selecting: bool) {
    assert_valid(buffer);

    if delta > 0 {
        while delta > 0 {
            // Cursor can be past the last non-newline character. However, the last line does not
            // have the newline character, so we only pretend it does.
            if buffer.cursor0.y == buffer.lines.count - 1 {
                buffer.cursor0.x = min(buffer.cursor0.x + 1, buffer.lines[buffer.cursor0.y].char_count);
            } else if buffer.cursor0.x < buffer.lines[buffer.cursor0.y].char_count - 1 {
                buffer.cursor0.x += 1;
            } else {
                buffer.cursor0.x = 0;
                buffer.cursor0.y += 1;
            }

            delta -= 1;
        }
    } else if delta < 0 {
        while delta < 0 {
            if buffer.cursor0.y == 0 {
                buffer.cursor0.x = max(buffer.cursor0.x - 1, 0);
            } else if buffer.cursor0.x > 0 {
                buffer.cursor0.x -= 1;
            } else {
                buffer.cursor0.x = buffer.lines[buffer.cursor0.y - 1].char_count - 1;
                buffer.cursor0.y -= 1;
            }

            delta += 1;
        }
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_y :: (buffer: *Text_Buffer, delta: s64, selecting: bool) {
    assert_valid(buffer);

    // Cursor can not be past the last line
    buffer.cursor0.y = clamp(buffer.cursor0.y + delta, 0, buffer.lines.count - 1);

    // Clamp X.
    if buffer.cursor0.y == buffer.lines.count - 1 {
        buffer.cursor0.x = clamp(buffer.cursor0.x, 0, buffer.lines[buffer.cursor0.y].char_count);
    } else {
        buffer.cursor0.x = clamp(buffer.cursor0.x, 0, buffer.lines[buffer.cursor0.y].char_count - 1);
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_start_of_line :: (buffer: *Text_Buffer, selecting: bool)  {
    assert_valid(buffer);

    line_start, line_end := text_buffer_get_cursors_for_line(buffer, buffer.cursor0.y);
    line_view            := text_buffer_make_view_between_cursors(buffer, line_start, line_end,, temp);

    first_nonspace_index := -1;
    for line_view {
        // We don't parse unicode here, because even if our whitespace is also a valid continuation
        // byte, it would have to be preceeded by a nonwhitespace byte.
        if !is_space(it) {
            first_nonspace_index = it_index;
            break;
        }
    }

    if first_nonspace_index == -1 || buffer.cursor0.x == first_nonspace_index {
        buffer.cursor0.x = 0;
    } else {
        buffer.cursor0.x = first_nonspace_index;
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_end_of_line :: (buffer: *Text_Buffer, selecting: bool)  {
    assert_valid(buffer);

    buffer.cursor0 = text_buffer_get_end_cursor_for_line(buffer, buffer.cursor0.y);

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_previous_word_boundary :: (buffer: *Text_Buffer, selecting: bool) -> y_changed: bool {
    assert_valid(buffer);

    y_changed := false;

    search_line_backward :: (line_view: string) -> found: bool, inside_word: bool, dx: s64 {
        // The line is empty, so we couldn't have started inside a word.
        if line_view.count == 0 {
            return false, false, 0;
        }

        inside_word_initial_set := false;
        inside_word             := false;

        found := false;
        dx := 0;
        for < :Unicode.utf8_iter line_view {
            is_nonword := character_is_nonword_character(it);

            if !inside_word_initial_set {
                inside_word             = !is_nonword;
                inside_word_initial_set = true;
            }

            if inside_word && is_nonword {
                found = true;
                break;
            }

            if !is_nonword {
                inside_word = true;
            }

            dx += 1;
        }

        return found, inside_word, dx;
    }

    line_start         := text_buffer_get_start_cursor_for_line(buffer, buffer.cursor0.y);
    view_before_cursor := text_buffer_make_view_between_cursors(buffer, line_start, buffer.cursor0,, temp);

    found, inside_word, dx := search_line_backward(view_before_cursor);
    if found || inside_word {
        buffer.cursor0.x -= dx;
    } else {
        while true {
            previous_cursor := buffer.cursor0;
            text_buffer_move_cursor_y(buffer, -1, selecting);
            if previous_cursor.y == buffer.cursor0.y {
                break;
            }

            y_changed = true;

            buffer.cursor0 = text_buffer_get_end_cursor_for_line(buffer, buffer.cursor0.y);

            line_start, line_end := text_buffer_get_cursors_for_line(buffer, buffer.cursor0.y);
            line_view            := text_buffer_make_view_between_cursors(buffer, line_start, line_end,, temp);

            found, inside_word, dx = search_line_backward(line_view);
            if found || inside_word {
                buffer.cursor0.x -= dx;
                break;
            }
        }
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return y_changed;
}

text_buffer_move_cursor_to_next_word_boundary :: (buffer: *Text_Buffer, selecting: bool) -> y_changed: bool {
    assert_valid(buffer);

    y_changed := false;

    search_line_forward :: (line_view: string) -> found: bool, inside_word: bool, dx: s64 {
        // The line is empty, so we couldn't have started inside a word.
        if line_view.count == 0 {
            return false, false, 0;
        }

        inside_word_initial_set := false;
        inside_word             := false;

        found := false;
        dx := 0;
        for :Unicode.utf8_iter line_view {
            is_nonword := character_is_nonword_character(it);

            if !inside_word_initial_set {
                inside_word             = !is_nonword;
                inside_word_initial_set = true;
            }

            if inside_word && is_nonword {
                found = true;
                break;
            }

            if !is_nonword {
                inside_word = true;
            }

            dx += 1;
        }

        return found, inside_word, dx;
    }

    line_end          := text_buffer_get_end_cursor_for_line(buffer, buffer.cursor0.y);
    view_after_cursor := text_buffer_make_view_between_cursors(buffer, buffer.cursor0, line_end,, temp);

    found, inside_word, dx := search_line_forward(view_after_cursor);
    if found || inside_word {
        buffer.cursor0.x += dx;
    } else {
        while true {
            previous_cursor := buffer.cursor0;
            text_buffer_move_cursor_y(buffer, 1, selecting);
            if previous_cursor.y == buffer.cursor0.y {
                break;
            }

            y_changed = true;

            buffer.cursor0.x = 0;

            line_start, line_end := text_buffer_get_cursors_for_line(buffer, buffer.cursor0.y);
            line_view            := text_buffer_make_view_between_cursors(buffer, line_start, line_end,, temp);

            found, inside_word, dx = search_line_forward(line_view);
            if found || inside_word {
                buffer.cursor0.x += dx;
                break;
            }
        }
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return y_changed;
}

text_buffer_move_cursor_to_previous_blank_line :: (buffer: *Text_Buffer, selecting: bool) {
    assert_valid(buffer);

    found := false;
    found_index := -1;
    {
        line_index := buffer.cursor0.y - 1;
        while !found && line_index >= 0 {
            line_start, line_end := text_buffer_get_cursors_for_line(buffer, line_index);
            line_view            := text_buffer_make_view_between_cursors(buffer, line_start, line_end,, temp);

            // We can avoid utf8 parsing, because we are looking strictly for whitespace-only lines
            // and we scan them whole.
            blank := true;
            for line_view {
                if !is_space(it) {
                    blank = false;
                    break;
                }
            }

            if blank {
                found = true;
                found_index = line_index;
            }

            line_index -= 1;
        }
    }

    if found {
        text_buffer_move_cursor_y(buffer, found_index - buffer.cursor0.y, selecting);
    } else {
        text_buffer_move_cursor_y(buffer, -1, selecting);
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_next_blank_line :: (buffer: *Text_Buffer, selecting: bool) {
    assert_valid(buffer);

    found := false;
    found_index := -1;
    {
        line_index := buffer.cursor0.y + 1;
        while !found && line_index < buffer.lines.count {
            line_start, line_end := text_buffer_get_cursors_for_line(buffer, line_index);
            line_view            := text_buffer_make_view_between_cursors(buffer, line_start, line_end,, temp);

            // We can avoid utf8 parsing, because we are looking strictly for whitespace-only lines
            // and we scan them whole.
            blank := true;
            for line_view {
                if !is_space(it) {
                    blank = false;
                    break;
                }
            }

            if blank {
                found = true;
                found_index = line_index;
            }

            line_index += 1;
        }
    }

    if found {
        text_buffer_move_cursor_y(buffer, found_index - buffer.cursor0.y, selecting);
    } else {
        text_buffer_move_cursor_y(buffer, +1, selecting);
    }

    assert_valid(buffer);
}

text_buffer_join_cursors :: (buffer: *Text_Buffer) {
    buffer.cursor1 = buffer.cursor0;
}

text_buffer_get_min_cursor :: (buffer: Text_Buffer) -> Cursor {
    if buffer.cursor0.y < buffer.cursor1.y {
        return buffer.cursor0;
    } else if buffer.cursor0.y > buffer.cursor1.y {
        return buffer.cursor1;
    } else if buffer.cursor0.x < buffer.cursor1.x {
        return buffer.cursor0;
    } else {
        return buffer.cursor1;
    }
}

text_buffer_get_max_cursor :: (buffer: Text_Buffer) -> Cursor {
    if buffer.cursor0.y < buffer.cursor1.y {
        return buffer.cursor1;
    } else if buffer.cursor0.y > buffer.cursor1.y {
        return buffer.cursor0;
    } else if buffer.cursor0.x < buffer.cursor1.x {
        return buffer.cursor1;
    } else {
        return buffer.cursor0;
    }
}

text_buffer_get_gap_buffer_index_for_cursor :: (buffer: Text_Buffer, cursor: Cursor) -> s64 {
    assert_cursor_valid(buffer, cursor);

    line_index := cursor.y;
    if line_index >= buffer.lines.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.count;
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

#scope_file

assert_valid :: (buffer: Text_Buffer) {
    assert(buffer.lines.count > 0, "Text_Buffer not initialized (has to have at least one line). Call text_buffer_init().");
    assert_cursor_valid(buffer, buffer.cursor0);
    assert_cursor_valid(buffer, buffer.cursor1);

    byte_count := 0;
    for 0..buffer.lines.count - 2 {
        assert(buffer.lines[it].char_count >= 0);
        assert(buffer.lines[it].byte_count >= 0);

        byte_count += buffer.lines[it].byte_count;

        // This should also work for \r\n newlines.
        assert(gap_buffer_get_nongap_byte(buffer.gb, byte_count - 1) == "\n");
    }

    if buffer.lines[buffer.lines.count - 1].byte_count > 0 {
        byte_count += buffer.lines[buffer.lines.count - 1].byte_count;
        assert(gap_buffer_get_nongap_byte(buffer.gb, byte_count - 1) != "\n");
    }

    // TODO(jt): Recompute metadata and compare to current instead?

    assert(byte_count == buffer.gb.count);
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

    assert(byte_is_utf8_character_boundary(bytes[index]));

    // When scanning forward, we could also trust the unicode and advance based on what we read? Not
    // sure if that's going to be faster, since it introduces a data dependency.
    next_index := index + 1;
    while next_index < bytes.count && !byte_is_utf8_character_boundary(bytes[next_index]) {
        next_index += 1;
    }

    scanned_count := next_index - index;
    assert(scanned_count <= 4);

    return next_index, scanned_count;
}

find_previous_utf8_character_boundary :: (bytes: [] u8, index: s64) -> index: s64, scanned_count: s64 {
    assert(index >= 0 && index <= bytes.count); // <=, because our cursor can be pointing past the buffer.
    if index == 0 {
        return 0, 0;
    }

    if index < bytes.count { // Otherwise index == count, which is a valid starting point.
        assert(byte_is_utf8_character_boundary(bytes[index]));
    }

    prev_index := index - 1;
    while prev_index > 0 && !byte_is_utf8_character_boundary(bytes[prev_index]) {
        prev_index -= 1;
    }

    scanned_count := index - prev_index;
    assert(scanned_count <= 4);

    return prev_index, index - prev_index;
}


byte_is_utf8_character_boundary :: inline (b: u8) -> bool {
    /* Taken from Rust's std.

    pub(crate) const fn is_utf8_char_boundary(self) -> bool {
        // This is bit magic equivalent to: b < 128 || b >= 192
        (self as i8) >= -0x40
    }
    */
    return b < 128 || b >= 192;
}

// TODO(jt): Make this configurable?
character_is_nonword_character :: inline (c: u32) -> bool {
    if c == {
        case #char " ";   #through;
        case #char "\t";  #through;
        case #char "_";   #through;
        case #char "-";   #through;
        case #char ".";   #through;
        case #char ",";   #through;
        case #char ";";   #through;
        case #char ":";   #through;
        case #char "(";   #through;
        case #char ")";   #through;
        case #char "<";   #through;
        case #char ">";   #through;
        case #char "{";   #through;
        case #char "}";   #through;
        case #char "[";   #through;
        case #char "]";   #through;
        case #char "\"";  #through;
        case #char "'";   return true;
        case;             return false;
    }
}
