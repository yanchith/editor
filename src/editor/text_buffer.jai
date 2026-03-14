// Currently, Gap_Buffer operates only on bytes and is oblivious to them being UTF8. The Buffer
// struct (this file) adds UTF8 knowledge. For now this is how it is.
Text_Buffer :: struct {
    arena: *Arena;

    cursor0: Cursor;
    cursor1: Cursor;

    gb: Gap_Buffer;   // Stores the UTF-8 bytes.
    lines: [..] Line; // Stores line navigation data. Always at least one.

    patches: [..] Patch; // Patches store edit history.
    applied_patch_count: s64;    // Undoing decreases this. Redoing increses. When editing, this is the same as patches.count.
    // This arena stores the actual patch texts. This way, we can actually pop/decommit it at least
    // sometimes? Maybe this is overthinking it too much.
    patch_text_arena: *Arena;
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

Patch :: struct {
    text: string;
    text_mark: Arena_Mark; // Marks the restore point after the text of this patch has been inserted.

    gb_index_before: s64;
    gb_index_after:  s64;

    cursor0_before: Cursor;
    cursor0_after:  Cursor;
    cursor1_before: Cursor;
    cursor1_after:  Cursor;

    type: Patch_Type;
    flags: Patch_Flags;

    Patch_Type :: enum u32 {
        // We could have emulated delete backward with moving the cursor and deleting forward or
        // vice versa, but for now we haven't, so both these operations appear in undo.

        INSERT          :: 0; // Text was inserted. Delete backward when undoing. Insert when redoing.
        DELETE_FORWARD  :: 1; // Text was deleted forward. Insert when undoing. Delete forward when redoing.
        DELETE_BACKWARD :: 2; // Text was deleted backward. Insert (and reset cursor!) when undoing. Delete backward when redoing.
    }

    Patch_Flags :: enum_flags u32 {
        NONE    :: 0;
        THROUGH :: 0x01; // If this is the first processed patch, process all subsequent patches with this flag.
    }
}

// text_buffer_init has to be called, or someone must do its equivalent. We might redesign this.
text_buffer_init :: (buffer: *Text_Buffer, arena: *Arena, patch_text_arena: *Arena) {
    buffer.* = {};

    buffer.arena = arena;

    buffer.gb.buffer.allocator = arena_allocator(arena);
    buffer.lines.allocator     = arena_allocator(arena);
    buffer.patches.allocator   = arena_allocator(arena);

    buffer.patch_text_arena = patch_text_arena;

    array_add(*buffer.lines);

    assert_valid(buffer);
}

// TODO(jt): @Speed Inserting 1GB of prose takes almost 6 seconds, most of which is spent parsing
// unicode and updating the line metadata. We could do it SIMD?
text_buffer_insert :: (buffer: *Text_Buffer, text: string) {
    ProfileZone("text_buffer_insert");

    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_between_cursors(buffer);
        assert(buffer.cursor0 == buffer.cursor1);
    }

    if text.count == 0 {
        return;
    }

    // TODO(jt): So we insert the text into the gap buffer regardless of whether it is valid, and then
    // process the string to update our navigation structures. If we detect invalid unicode, we just
    // assert for now, but we should eventually patch the invalid sequences with unicode replacement
    // chararacters. (And go to read-only mode?)

    gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, text_buffer_get_min_cursor(buffer));
    gap_buffer_move_gap_to(*buffer.gb, gb_index);
    gap_buffer_insert(*buffer.gb, text);

    text_buffer_discard_unapplied_patches(buffer);
    patch := array_add(*buffer.patches);
    patch.text = arena_push_string(buffer.patch_text_arena, text);
    patch.text_mark = arena_get_mark(buffer.patch_text_arena);
    patch.gb_index_before = gb_index;
    patch.gb_index_after = gb_index + text.count; sanity_assert(patch.gb_index_after == buffer.gb.gap_index);
    patch.cursor0_before = buffer.cursor0;
    // patch.cursor0_after is set at the end of this function.
    patch.cursor1_before = buffer.cursor1;
    // patch.cursor1_after is set at the end of this function.
    patch.type = .INSERT;
    patch.flags = .NONE;
    if is_through_patch(text) {
        // TODO(jt): Also don't add through, if the patch timestamps were too far apart.
        patch.flags |= .THROUGH;
    }

    buffer.applied_patch_count = buffer.patches.count;

    update_after_insert(buffer, text);

    patch.cursor0_after = buffer.cursor0;
    patch.cursor1_after = buffer.cursor0;

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);
}

text_buffer_delete_between_cursors :: (buffer: *Text_Buffer) {
    inline text_buffer_delete_between_cursors(buffer, buffer.cursor0, buffer.cursor1);
}

text_buffer_delete_between_cursors :: (buffer: *Text_Buffer, __start: Cursor, __end: Cursor) {
    ProfileZone("text_buffer_delete_between_cursors");

    // Force copy to avoid "maybe by reference" aliasing.
    _start := __start;
    _end := __end;

    assert_valid(buffer);
    assert_cursor_valid(buffer, _start);
    assert_cursor_valid(buffer, _end);

    if _start == _end {
        return;
    }

    start := _start;
    end   := _end;
    swapped := sort_cursors(*start, *end);

    start_gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, start);
    end_gb_index   := text_buffer_get_gap_buffer_index_for_cursor(buffer, end);
    delete_count := end_gb_index - start_gb_index;

    gap_buffer_move_gap_to(*buffer.gb, start_gb_index);
    deleted_bytes := gap_buffer_delete_forward(*buffer.gb, delete_count);

    // gap_buffer clamps, but we should have calculated the indices correctly in this case.
    assert(deleted_bytes.count == delete_count);

    buffer.cursor0 = start;
    buffer.cursor1 = start;

    text_buffer_discard_unapplied_patches(buffer);
    patch := array_add(*buffer.patches);
    patch.text = arena_push_string(buffer.patch_text_arena, cast(string, deleted_bytes));
    patch.text_mark = arena_get_mark(buffer.patch_text_arena);
    patch.gb_index_before = start_gb_index;
    patch.gb_index_after = start_gb_index; sanity_assert(patch.gb_index_after == buffer.gb.gap_index);

    patch.cursor0_before = _start;
    patch.cursor0_after = start;
    patch.cursor1_before = _end;
    patch.cursor1_after = start;
    patch.type = .DELETE_FORWARD;
    patch.flags = .NONE;

    buffer.applied_patch_count = buffer.patches.count;

    while deleted_bytes.count > 0 {
        newline, newline_advance := string_starts_with_newline(deleted_bytes);
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
            assert(buffer.lines[buffer.cursor0.y].char_count >= 0);
            assert(buffer.lines[buffer.cursor0.y].byte_count >= 0);

            buffer.lines[buffer.cursor0.y].char_count += buffer.lines[buffer.cursor0.y + 1].char_count;
            buffer.lines[buffer.cursor0.y].byte_count += buffer.lines[buffer.cursor0.y + 1].byte_count;

            array_ordered_remove_by_index(*buffer.lines, buffer.cursor0.y + 1);

            deleted_bytes = array_view(deleted_bytes, newline_advance);
        } else {
            _, codepoint_advance := find_next_utf8_character_boundary(deleted_bytes, 0);
            if codepoint_advance {
                buffer.lines[buffer.cursor0.y].char_count -= 1;
                buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;
                assert(buffer.lines[buffer.cursor0.y].char_count >= 0);
                assert(buffer.lines[buffer.cursor0.y].byte_count >= 0);

                deleted_bytes = array_view(deleted_bytes, codepoint_advance);
            }
        }
    }

    assert_valid(buffer);
}

// TODO(jt): Take a second parameter to specify the count to delete. Do delete in batch, like
// text_buffer_delete_between_cursors does.
text_buffer_delete_forward :: (buffer: *Text_Buffer) {
    ProfileZone("text_buffer_delete_forward");

    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_between_cursors(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        return;
    }

    gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, buffer.cursor0);
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
        assert(newline_advance == deleted.count);

        text_buffer_discard_unapplied_patches(buffer);
        patch := array_add(*buffer.patches);
        patch.text = arena_push_string(buffer.patch_text_arena, cast(string, deleted));
        patch.text_mark = arena_get_mark(buffer.patch_text_arena);
        patch.gb_index_before = gb_index;
        patch.gb_index_after = gb_index; sanity_assert(patch.gb_index_after == buffer.gb.gap_index);
        patch.cursor0_before = buffer.cursor0;
        patch.cursor0_after = buffer.cursor0;
        patch.cursor1_before = buffer.cursor0;
        patch.cursor1_after = buffer.cursor0;
        patch.type = .DELETE_FORWARD;
        patch.flags = .NONE;
        if is_through_patch(cast(string, deleted)) {
            patch.flags |= .THROUGH;
        }

        buffer.applied_patch_count = buffer.patches.count;
    } else {
        _, codepoint_advance := find_next_utf8_character_boundary(bytes, 0);
        if codepoint_advance {
            buffer.lines[buffer.cursor0.y].char_count -= 1;
            buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

            deleted := gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted.count);

            text_buffer_discard_unapplied_patches(buffer);
            patch := array_add(*buffer.patches);
            patch.text = arena_push_string(buffer.patch_text_arena, cast(string, deleted));
            patch.text_mark = arena_get_mark(buffer.patch_text_arena);
            patch.gb_index_before = gb_index;
            patch.gb_index_after = gb_index; sanity_assert(patch.gb_index_after == buffer.gb.gap_index);
            patch.cursor0_before = buffer.cursor0;
            patch.cursor0_after = buffer.cursor0;
            patch.cursor1_before = buffer.cursor0;
            patch.cursor1_after = buffer.cursor0;
            patch.type = .DELETE_FORWARD;
            patch.flags = .NONE;
            if is_through_patch(cast(string, deleted)) {
                patch.flags |= .THROUGH;
            }

            buffer.applied_patch_count = buffer.patches.count;
        }
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);
}

// TODO(jt): Take a second parameter to specify the count to delete. Do delete in batch, like
// text_buffer_delete_between_cursors does.
text_buffer_delete_backward :: (buffer: *Text_Buffer) {
    ProfileZone("text_buffer_delete_backward");

    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_between_cursors(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        return;
    }

    gb_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, buffer.cursor0);
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

        old_cursor := buffer.cursor0;

        buffer.cursor0.x = new_cursor_x;
        buffer.cursor0.y -= 1;

        deleted := gap_buffer_delete_backward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted.count);

        text_buffer_discard_unapplied_patches(buffer);
        patch := array_add(*buffer.patches);
        patch.text = arena_push_string(buffer.patch_text_arena, cast(string, deleted));
        patch.text_mark = arena_get_mark(buffer.patch_text_arena);
        patch.gb_index_before = gb_index;
        patch.gb_index_after = gb_index - deleted.count; sanity_assert(patch.gb_index_after == buffer.gb.gap_index);
        patch.cursor0_before = old_cursor;
        patch.cursor0_after = buffer.cursor0;
        patch.cursor1_before = old_cursor;
        patch.cursor1_after = buffer.cursor0;
        patch.type = .DELETE_BACKWARD;
        patch.flags = .NONE;
        if is_through_patch(cast(string, deleted)) {
            patch.flags |= .THROUGH;
        }

        buffer.applied_patch_count = buffer.patches.count;
    } else {
        _, codepoint_advance := find_previous_utf8_character_boundary(bytes, bytes.count);
        if codepoint_advance {
            buffer.lines[buffer.cursor0.y].char_count -= 1;
            buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

            old_cursor := buffer.cursor0;

            buffer.cursor0.x -= 1;

            deleted := gap_buffer_delete_backward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted.count);

            text_buffer_discard_unapplied_patches(buffer);
            patch := array_add(*buffer.patches);
            patch.text = arena_push_string(buffer.patch_text_arena, cast(string, deleted));
            patch.text_mark = arena_get_mark(buffer.patch_text_arena);
            patch.gb_index_before = gb_index;
            patch.gb_index_after = gb_index - deleted.count; sanity_assert(patch.gb_index_after == buffer.gb.gap_index);
            patch.cursor0_before = old_cursor;
            patch.cursor0_after = buffer.cursor0;
            patch.cursor1_before = old_cursor;
            patch.cursor1_after = buffer.cursor0;
            patch.type = .DELETE_BACKWARD;
            patch.flags = .NONE;
            if is_through_patch(cast(string, deleted)) {
                patch.flags |= .THROUGH;
            }

            buffer.applied_patch_count = buffer.patches.count;
        }
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);
}

text_buffer_delete_line :: (buffer: *Text_Buffer) {
    line_end := text_buffer_get_end_cursor_for_line(buffer, buffer.cursor0.y);
    view     := text_buffer_make_view_between_cursors(buffer, buffer.cursor0, line_end,, temp);

    is_only_whitespace := true;
    for view {
        if !is_space(it) {
            is_only_whitespace = false;
            break;
        }
    }

    if is_only_whitespace {
        line_end := text_buffer_get_end_cursor_for_line(buffer, buffer.cursor0.y, include_newline = true);
        text_buffer_delete_between_cursors(buffer, buffer.cursor0, line_end);
    } else {
        text_buffer_delete_between_cursors(buffer, buffer.cursor0, line_end);
    }

}

text_buffer_undo_edit :: (buffer: *Text_Buffer) {
    ProfileZone("text_buffer_undo_edit");

    if buffer.applied_patch_count == 0 {
        return;
    }

    applied_count := 0;
    for < 0..buffer.applied_patch_count - 1 {
        patch := buffer.patches[it];

        buffer.cursor0 = patch.cursor0_after;
        buffer.cursor1 = patch.cursor1_after;
        gap_buffer_move_gap_to(*buffer.gb, patch.gb_index_after);

        if patch.type == {
            case .INSERT; {
                deleted_bytes := gap_buffer_delete_backward(*buffer.gb, patch.text.count);
                sanity_assert(cast(string, deleted_bytes) == patch.text);

                update_after_delete_backward(buffer, cast(string, deleted_bytes));
            }

            case .DELETE_FORWARD; {
                gap_buffer_insert(*buffer.gb, patch.text);
                update_after_insert(buffer, patch.text);
            }

            case .DELETE_BACKWARD; {
                gap_buffer_insert(*buffer.gb, patch.text);
                update_after_insert(buffer, patch.text);
            }
        };

        buffer.cursor0 = patch.cursor0_before;
        buffer.cursor1 = patch.cursor1_before;

        applied_count += 1;

        keep_undoing := true;
        if it > 0 {
            previous_patch := buffer.patches[it - 1];

            if !(previous_patch.flags & .THROUGH) {
                keep_undoing = false;
            }

            if previous_patch.type != patch.type {
                keep_undoing = false;
            }
        }

        if !keep_undoing {
            break;
        }
    }

    buffer.applied_patch_count -= applied_count;
}

// XXX: Fix this!
text_buffer_redo_edit :: (buffer: *Text_Buffer) {
    ProfileZone("text_buffer_redo_edit");

    if buffer.applied_patch_count == buffer.patches.count {
        return;
    }

    applied_count := 0;
    for buffer.applied_patch_count..buffer.patches.count - 1 {
        patch := buffer.patches[it];

        buffer.cursor0 = patch.cursor0_before;
        buffer.cursor1 = patch.cursor1_before;
        gap_buffer_move_gap_to(*buffer.gb, patch.gb_index_before);

        if patch.type == {
            case .INSERT; {
                gap_buffer_insert(*buffer.gb, patch.text);
                update_after_insert(buffer, patch.text);
            }

            case .DELETE_FORWARD; {
                deleted_bytes := gap_buffer_delete_forward(*buffer.gb, patch.text.count);
                sanity_assert(cast(string, deleted_bytes) == patch.text);

                update_after_delete_forward(buffer, cast(string, deleted_bytes));
            }

            case .DELETE_BACKWARD; {
                deleted_bytes := gap_buffer_delete_backward(*buffer.gb, patch.text.count);
                sanity_assert(cast(string, deleted_bytes) == patch.text);

                update_after_delete_backward(buffer, cast(string, deleted_bytes));
            }
        };

        sanity_assert(buffer.cursor0 == patch.cursor0_after);
        sanity_assert(buffer.cursor1 == patch.cursor1_after);
        buffer.cursor0 = patch.cursor0_after;
        buffer.cursor1 = patch.cursor1_after;

        applied_count += 1;

        keep_redoing := true;
        if it < buffer.patches.count - 1 {
            next_patch := buffer.patches[it + 1];

            if !(next_patch.flags & .THROUGH) {
                keep_redoing = false;
            }

            if next_patch.type != patch.type {
                keep_redoing = false;
            }
        }

        if !keep_redoing {
            break;
        }
    }

    buffer.applied_patch_count += applied_count;
}

text_buffer_discard_unapplied_patches :: (buffer: *Text_Buffer) {
    if buffer.applied_patch_count < buffer.patches.count {
        patch := buffer.patches[buffer.applied_patch_count];

        // Patch texts are allocated in order they were created. If we are hosing everything beyond
        // a certain point, we can just use the restore mark from the beginning of the chain.
        arena_pop_to_mark(buffer.patch_text_arena, patch.text_mark);

        buffer.patches.count = buffer.applied_patch_count;
    }
}

text_buffer_get_start_cursor_for_line :: (buffer: Text_Buffer, line_index: s64) -> Cursor {
    assert_line_valid(buffer, line_index);

    start: Cursor = { 0, line_index };

    return start;
}

text_buffer_get_end_cursor_for_line :: (buffer: Text_Buffer, line_index: s64, include_newline := false) -> Cursor {
    assert_line_valid(buffer, line_index);

    line := buffer.lines[line_index];
    endx: s64;
    if include_newline || line_index == buffer.lines.count - 1 {
        endx = line.char_count;
    } else {
        endx = line.char_count - 1;
    }

    end: Cursor = { endx, line_index };

    return end;
}

text_buffer_get_cursors_for_line :: (buffer: Text_Buffer, line_index: s64, include_newline := false) -> Cursor, Cursor {
    start: Cursor = text_buffer_get_start_cursor_for_line(buffer, line_index);
    end:   Cursor = text_buffer_get_end_cursor_for_line(buffer, line_index, include_newline);

    return start, end;
}

// A 2x-ish faster, specialized version of text_buffer_make_view_between_cursors. Use if you can.
text_buffer_make_view_for_line :: (buffer: Text_Buffer, line_index: s64, include_newline := false) -> string /* Pointing to the internal gap bufffer, or allocated with context.allocator */ {
    ProfileZone("text_buffer_make_view_for_line");

    assert_line_valid(buffer, line_index);

    line := buffer.lines[line_index];

    start_index := text_buffer_get_gap_buffer_index_for_line(buffer, line_index);
    view        := gap_buffer_make_contiguous_view(buffer.gb, start_index, line.byte_count);

    if !include_newline {
        _, newline_length := string_ends_with_newline(view);
        view.count -= newline_length;
    }

    return cast(string, view);
}

text_buffer_byte_count_between_cursors :: (buffer: Text_Buffer, _start: Cursor, _end: Cursor) -> s64 {
    ProfileZone("text_buffer_byte_count_between_cursors");

    assert_cursor_valid(buffer, _start);
    assert_cursor_valid(buffer, _end);

    start := _start;
    end   := _end;
    sort_cursors(*start, *end);

    start_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, start);
    end_index   := text_buffer_get_gap_buffer_index_for_cursor(buffer, end);

    return end_index - start_index;
}

text_buffer_make_view_between_cursors :: (buffer: Text_Buffer, _start: Cursor, _end: Cursor) -> string /* Pointing to the internal gap buffer, or allocated with context.allocator */ {
    ProfileZone("text_buffer_make_view_between_cursors");

    assert_cursor_valid(buffer, _start);
    assert_cursor_valid(buffer, _end);

    start := _start;
    end   := _end;
    sort_cursors(*start, *end);

    start_index := text_buffer_get_gap_buffer_index_for_cursor(buffer, start);
    end_index   := text_buffer_get_gap_buffer_index_for_cursor(buffer, end);

    view := gap_buffer_make_contiguous_view(buffer.gb, start_index, end_index - start_index);

    return cast(string, view);
}

text_buffer_move_cursor_x :: (buffer: *Text_Buffer, delta: s64, selecting: bool) {
    ProfileZone("text_buffer_move_cursor_x");

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
    ProfileZone("text_buffer_move_cursor_y");

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

text_buffer_move_cursor_to :: (buffer: *Text_Buffer, _x: s64, _y: s64, selecting: bool) {
    assert_valid(buffer);

    y := clamp(_y, 0, buffer.lines.count);
    x := clamp(_x, 0, buffer.lines[y].char_count);

    buffer.cursor0 = { x, y };

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_start :: (buffer: *Text_Buffer, selecting: bool) {
    assert_valid(buffer);

    buffer.cursor0 = { 0, 0 };

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_end :: (buffer: *Text_Buffer, selecting: bool) {
    assert_valid(buffer);

    y := buffer.lines.count - 1;
    x := buffer.lines[y].char_count;
    buffer.cursor0 = { x, y };

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_start_of_line :: (buffer: *Text_Buffer, selecting: bool)  {
    ProfileZone("text_buffer_move_cursor_to_start_of_line");

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
    ProfileZone("text_buffer_move_cursor_to_end_of_line");

    assert_valid(buffer);

    buffer.cursor0 = text_buffer_get_end_cursor_for_line(buffer, buffer.cursor0.y);

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_previous_word_boundary :: (buffer: *Text_Buffer, selecting: bool) -> y_changed: bool {
    ProfileZone("text_buffer_move_cursor_to_previous_word_boundary");

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
    ProfileZone("text_buffer_move_cursor_to_next_word_boundary");

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

// TODO(jt): @Speed Searching through 45 lines towards the end of a 1GB file takes about 350
// milliseconds. Most of that time is spent in text_buffer_make_view_for_line.
text_buffer_move_cursor_to_previous_blank_line :: (buffer: *Text_Buffer, selecting: bool) {
    ProfileZone("text_buffer_move_cursor_to_previous_blank_line");

    assert_valid(buffer);

    found := false;
    found_index := -1;
    {
        line_index := buffer.cursor0.y - 1;
        while !found && line_index >= 0 {
            line_view := text_buffer_make_view_for_line(buffer, line_index,, temp);

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

// TODO(jt): @Speed Searching through 45 lines towards the end of a 1GB file takes about 350
// milliseconds. Most of that time is spent in text_buffer_make_view_for_line.
text_buffer_move_cursor_to_next_blank_line :: (buffer: *Text_Buffer, selecting: bool) {
    ProfileZone("text_buffer_move_cursor_to_next_blank_line");

    assert_valid(buffer);

    found := false;
    found_index := -1;
    {
        line_index := buffer.cursor0.y + 1;
        while !found && line_index < buffer.lines.count {
            line_view := text_buffer_make_view_for_line(buffer, line_index,, temp);

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

// TODO(jt): @Speed For 1GB files of regular prose, this takes too long, especially if called tens
// or hundreds of times per frame. Can we do something about it? Maintain a list of "paragraphs"
// that have a stable mapping to lines that we could use to skip over most lines? The mapping would
// have to survive adding and deleting lines - we don't want to update every below the edit.
text_buffer_get_gap_buffer_index_for_line :: (buffer: Text_Buffer, line_index: s64) -> s64 {
    ProfileZone("text_buffer_get_gap_buffer_index_for_line");

    assert_line_valid(buffer, line_index);

    if line_index >= buffer.lines.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.count;
    }

    index := 0;
    for 0..line_index - 1 {
        index += buffer.lines[it].byte_count;
    }

    return index;
}

text_buffer_get_gap_buffer_index_for_cursor :: (buffer: Text_Buffer, cursor: Cursor) -> s64 {
    ProfileZone("text_buffer_get_gap_buffer_index_for_cursor");

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

    // This is too expensive to do in shipping builds.
    #if SANITY {
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

        assert(byte_count == buffer.gb.count);
    }
}

assert_line_valid :: (buffer: Text_Buffer, line_index: s64) {
    assert(line_index < buffer.lines.count);
}

assert_cursor_valid :: (buffer: Text_Buffer, cursor: Cursor) {
    assert(cursor.y >= 0 && cursor.y < buffer.lines.count);
    // The cursor can go past the last non-newline character, or past the last character on the last
    // line, where there is no newline at the end.
    assert(cursor.x >= 0 && cursor.x <= buffer.lines[cursor.y].char_count);
}

update_after_insert :: (buffer: *Text_Buffer, text: string) {
    ProfileZone("update_after_insert");
    // While we could compute bytes_on_line_before_cursor by asking our procedure to do that for
    // every line, that procedure has to iterate the lines array, and it would result in quadractic
    // behavior (observable once the file is at about 1MB). Therefore, we ask the procedure to
    // compute it once in the beginning, where we don't know the initial state, and update it
    // ourselves throughout the rest of the insert.
    bytes_on_line_before_cursor: s64;
    {
        line_start := text_buffer_get_start_cursor_for_line(buffer, buffer.cursor0.y);
        bytes_on_line_before_cursor = text_buffer_byte_count_between_cursors(buffer, line_start, buffer.cursor0);
    }

    while text.count {
        newline, newline_advance := string_starts_with_newline(text);
        if newline {
            char_count_after_cursor := buffer.lines[buffer.cursor0.y].char_count - buffer.cursor0.x;
            byte_count_after_cursor := buffer.lines[buffer.cursor0.y].byte_count - bytes_on_line_before_cursor;

            advance(*text, newline_advance);

            // We treat \r\n as one character, if it happens to be in there.
            buffer.lines[buffer.cursor0.y].char_count += 1 - char_count_after_cursor;
            buffer.lines[buffer.cursor0.y].byte_count += newline_advance - byte_count_after_cursor;

            // TODO(jt): @Speed We do this in a loop. Could we at least do the reserve and copy
            // first and then fill one by one?
            array_insert_at(*buffer.lines, { char_count_after_cursor, byte_count_after_cursor }, buffer.cursor0.y + 1);

            buffer.cursor0.y += 1;
            buffer.cursor0.x = 0;

            bytes_on_line_before_cursor = 0;

            continue;
        }

        // TODO(jt): The Unicode module actually doesn't clamp this by itself and it can be as much
        // as 6 (this was valid in older specs?). Cleanup?
        codepoint_advance := clamp(1 + Unicode.trailingBytesForUTF8[text[0]], 1, 4);

        // TODO(jt): This probably shouldn't be an assert, but we need to do something about
        // incorrect unicode coming in and prevent it getting into the buffer. If we are ingesting a
        // new file, we should probably check ahead for encoding or something. If we are in
        // interactive mode, maybe it is okay to not insert.
        //
        // UPDATE: Also shouldn't be an assert, because we have already inserted stuff into the gap
        // buffer, so maybe we want to revert that.
        _, codepoint_advance_check := find_next_utf8_character_boundary(cast([] u8, text), 0);
        assert(codepoint_advance == codepoint_advance_check);

        advance(*text, codepoint_advance);

        buffer.lines[buffer.cursor0.y].char_count += 1;
        buffer.lines[buffer.cursor0.y].byte_count += codepoint_advance;
        buffer.cursor0.x += 1;

        bytes_on_line_before_cursor += codepoint_advance;
    }

    // Cursor 1 has to be updated by whomever this is called.
}

update_after_delete_forward :: (buffer: *Text_Buffer, _text: string) {
    ProfileZone("update_after_delete_forward");

    text := _text;

    while text.count {
        newline, newline_advance := string_starts_with_newline(text);
        if newline {
            if buffer.cursor0.y == buffer.lines.count - 1 {
                assert(buffer.cursor0.x == buffer.lines[buffer.cursor0.y].char_count);
            } else {
                assert(buffer.cursor0.x == buffer.lines[buffer.cursor0.y].char_count - 1);
            }
            assert(buffer.cursor0.y + 1 < buffer.lines.count);

            buffer.lines[buffer.cursor0.y - 1].char_count -= 1;
            buffer.lines[buffer.cursor0.y - 1].byte_count -= newline_advance;

            buffer.lines[buffer.cursor0.y - 1].char_count += buffer.lines[buffer.cursor0.y].char_count;
            buffer.lines[buffer.cursor0.y - 1].byte_count += buffer.lines[buffer.cursor0.y].byte_count;

            array_ordered_remove_by_index(*buffer.lines, buffer.cursor0.y);

            advance(*text, newline_advance);
            assert(text.count >= 0);
        } else {
            _, codepoint_advance := find_next_utf8_character_boundary(text, 0);
            if codepoint_advance {
                buffer.lines[buffer.cursor0.y].char_count -= 1;
                buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

                advance(*text, codepoint_advance);
                assert(text.count >= 0);
            }
        }
    }

    // Cursor 1 has to be updated by whomever this is called.
}

update_after_delete_backward :: (buffer: *Text_Buffer, _text: string) {
    ProfileZone("update_after_delete_backward");

    text := _text;

    while text.count {
        newline, newline_advance := string_ends_with_newline(text);
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

            text.count -= newline_advance;
            assert(text.count >= 0);
        } else {
            _, codepoint_advance := find_previous_utf8_character_boundary(text, text.count);
            if codepoint_advance {
                buffer.lines[buffer.cursor0.y].char_count -= 1;
                buffer.lines[buffer.cursor0.y].byte_count -= codepoint_advance;

                buffer.cursor0.x -= 1;

                text.count -= codepoint_advance;
                assert(text.count >= 0);
            }
        }
    }

    // Cursor 1 has to be updated by whomever this is called.
}

is_through_patch :: (text: string) -> bool {
    if text != " " && text != "\n" && text != "\r\n" {
        trailing_bytes := Unicode.trailingBytesForUTF8[text[0]];
        if text.count == 1 + trailing_bytes {
            return true;
        }
    }

    return false;
}

sort_cursors :: (start: *Cursor, end: *Cursor) -> swapped: bool {
    if start.y > end.y {
        swap(start, end);
        return true;
    }

    if start.y == end.y && start.x > end.x {
        swap(start, end);
        return true;
    }

    return false;
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

find_next_utf8_character_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, scanned_count: s64 {
    found_index, scanned_count := find_next_utf8_character_boundary(cast(string, bytes), index);
    return found_index, scanned_count;
}

find_next_utf8_character_boundary :: (text: string, index: s64) -> found_index: s64, scanned_count: s64 {
    assert(index >= 0 && index <= text.count); // <=, because our cursor can be pointing past the buffer.
    if index == text.count {
        return text.count, 0;
    }

    assert(byte_is_utf8_character_boundary(text[index]));

    // When scanning forward, we could also trust the unicode and advance based on what we read? Not
    // sure if that's going to be faster, since it introduces a data dependency.
    next_index := index + 1;
    while next_index < text.count && !byte_is_utf8_character_boundary(text[next_index]) {
        next_index += 1;
    }

    scanned_count := next_index - index;
    assert(scanned_count <= 4);

    return next_index, scanned_count;
}

find_previous_utf8_character_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, scanned_count: s64 {
    found_index, scanned_count := inline find_previous_utf8_character_boundary(cast(string, bytes), index);
    return found_index, scanned_count;
}

find_previous_utf8_character_boundary :: (text: string, index: s64) -> found_index: s64, scanned_count: s64 {
    assert(index >= 0 && index <= text.count); // <=, because our cursor can be pointing past the buffer.
    if index == 0 {
        return 0, 0;
    }

    if index < text.count { // Otherwise index == count, which is a valid starting point.
        assert(byte_is_utf8_character_boundary(text[index]));
    }

    prev_index := index - 1;
    while prev_index > 0 && !byte_is_utf8_character_boundary(text[prev_index]) {
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
