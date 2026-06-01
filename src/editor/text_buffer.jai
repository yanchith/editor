Text_Buffer :: struct {
    // TODO(jt): @Cleanup Key_Map, inspired by Bucket_Array gives you a way to easily set the
    // allocator in one place, so you can declare on stack and set the allocator, like you are used
    // to with regular arrays:
    //
    // key_map: Key_Map;
    // key_map.allocator = arena_allocator(editor.perm_arena);
    // key_map_init(*key_map, 128);
    //
    // Let's think of a way of doing this with Text_Buffer and its two arenas. The problem here is
    // the amount of entry points, but maybe that can be thought through?

    arena: *Arena;
    arena_mark: Arena_Mark;

    binary_mode: bool;

    cursor0: Text_Location;
    cursor1: Text_Location;

    gb: Gap_Buffer;   // Stores the UTF-8 bytes.
    // SoA version of a line struct:
    //
    // Line :: struct {
    //    char_count: s64; // Including newline at the end
    //    byte_count: s64;
    // }
    //
    // TODO(jt): @Speed keep line_chars empty in binary mode, because they are the same as bytes.
    line_bytes: [..] s64; // Always at least one.
    line_chars: [..] s64; // Always at least one.
    line_count: s64;

    // TODO(jt): @Memory A slight improvement on having edit texts in a separate arena is also
    // having the edits there as a linked list. When we discard_unapplied_edits, we can also fully
    // nuke the edit metadata. This will leave just gap_buffer, line_bytes and line_chars sharing
    // the main arena.
    edits: [..] Edit;
    // Undoing decreases this. Redoing increases. When editing, this is the same as edits.count,
    // because edits that were undone are discarded (at least until we do Emacs-like undo)
    applied_edit_count: s64;
    // This arena stores the actual edit texts. This way, we can actually pop/decommit it at least
    // sometimes? Maybe this is overthinking it too much.
    edit_text_arena: *Arena;
    edit_text_arena_mark: Arena_Mark;
}

Text_Location :: struct {
    x: s64;
    y: s64;
}

operator == :: (a: Text_Location, b: Text_Location) -> bool {
    return a.x == b.x && a.y == b.y;
}

Edit :: struct {
    type:  Type;
    flags: Flags;

    text: string;
    text_mark: Arena_Mark = { -1 }; // Marks the restore point after the text of this edit has been inserted.

    // Nonzero, if this is INSERT_MEMSET, in which case use this and ignore text and text_mark.
    memset_value: u8;
    memset_count: s64;

    gb_index_before: s64;
    gb_index_after:  s64;

    // The actual positions the cursors were before and after the operation. They are not sorted!
    cursor0_before: Text_Location;
    cursor0_after:  Text_Location;
    cursor1_before: Text_Location;
    cursor1_after:  Text_Location;

    Type :: enum u32 {
        // All of these operations restore cursors to the values defined by the edit. Editing
        // forward always collapses cursors (because that's what mutating text does), but undoing
        // edits restores cursors in case of DELETE_SELECTION. The cursor restoration is automatic
        // (the edit values are taken).
        INSERT;
        INSERT_MEMSET;

        DELETE_SELECTION;
        DELETE_FORWARD;
        DELETE_BACKWARD;
        DELETE_BACKWARD_MEMSET;
    }

    Flags :: enum_flags u32 {
        NONE :: 0;

        THROUGH :: 0x1; // When undoing or redoing edits, process all directly subsequent edits with this flag.
        BARRIER :: 0x2; // Suppresses looking for THROUGH.

        FUSED_WITH_PREVIOUS :: 0x4; // When undoing, also apply previous edit, regardless of current edit's BARRIER.
        FUSED_WITH_NEXT     :: 0x8; // When redoing, also apply next edit, regardless of current edit's BARRIER.
    }
}

// text_buffer_init has to be called, or someone must do its equivalent (create the first line)
//
// The two arenas can either be the same (easier to setup), or two distinct dedicated arenas (allows
// memory in the edit_text_arena to be reclaimed for changes that are no longer used). Text_Buffer
// preserves allocations already present in these arenas, but you should not use them after they
// have been passed in here. We might redesign this.
text_buffer_init :: (buffer: *Text_Buffer, arena: *Arena, _edit_text_arena: *Arena = null) {
    buffer.* = {};

    buffer.arena = arena;
    buffer.arena_mark = arena_get_mark(arena);

    buffer.gb.allocator = arena_allocator(arena);

    buffer.line_bytes.allocator = arena_allocator(arena);
    buffer.line_chars.allocator = arena_allocator(arena);
    buffer.edits.allocator = arena_allocator(arena);

    edit_text_arena := ifx _edit_text_arena then _edit_text_arena else arena;

    buffer.edit_text_arena = edit_text_arena;
    buffer.edit_text_arena_mark = arena_get_mark(edit_text_arena);

    add_line(buffer); // This is the only invariant we uphold for now.

    assert_valid(buffer);
}

text_buffer_reset :: (buffer: *Text_Buffer) {
    assert_valid(buffer);

    buffer.binary_mode = false;

    gap_buffer_reset(*buffer.gb);

    array_reset(*buffer.line_bytes);
    array_reset(*buffer.line_chars);
    buffer.line_count = 0;

    array_reset(*buffer.edits);

    arena_pop_to_mark(buffer.arena, buffer.arena_mark);
    arena_pop_to_mark(buffer.edit_text_arena, buffer.edit_text_arena_mark);

    buffer.cursor0 = {};
    buffer.cursor1 = {};

    buffer.applied_edit_count = 0;

    add_line(buffer); // This is the only invariant we uphold for now.

    assert_valid(buffer);
}

text_buffer_insert :: (buffer: *Text_Buffer, bytes: [] u8, undo_barrier := false, undo_fuse_with_delete_selection := false) -> changed: bool {
    /*inline?*/ return text_buffer_insert(buffer, cast(string, bytes), undo_barrier, undo_fuse_with_delete_selection);
}

// TODO(jt): Add binary_switch_strategy, which can customize the behavior of inserts causing the
// switch to binary. For instance, the mini panel buffer doesn't ever want to switch, so we would
// supply .REVERT, etc.
text_buffer_insert :: (buffer: *Text_Buffer, text: string, undo_barrier := false, undo_fuse_with_delete_selection := false) -> changed: bool {
    ProfileZone("text_buffer_insert");

    assert_valid(buffer);

    if text.count == 0 {
        return false;
    }

    insert_caused_delete_selection := false;

    if buffer.cursor0 != buffer.cursor1 {
        text_buffer_delete_selection(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        insert_caused_delete_selection = true;

        // Fallthrough!
    }

    gb_index := text_buffer_get_gap_buffer_index_for_location(buffer, text_buffer_get_min_cursor(buffer));
    gap_buffer_move_gap_to(*buffer.gb, gb_index);
    gap_buffer_insert(*buffer.gb, text);

    discard_unapplied_edits(buffer);
    edit := array_add(*buffer.edits);
    edit.type = .INSERT;
    edit.flags = .NONE;
    if undo_barrier {
        edit.flags |= .BARRIER;
    } else if is_through_edit(text) {
        // TODO(jt): Also don't add through, if the edit timestamps were too far apart.
        edit.flags |= .THROUGH;
    }
    edit.text = arena_push_string(buffer.edit_text_arena, text);
    edit.text_mark = arena_get_mark(buffer.edit_text_arena);
    edit.gb_index_before = gb_index;
    edit.gb_index_after = gb_index + text.count; sanity_assert(edit.gb_index_after == buffer.gb.gap_index);
    edit.cursor0_before = buffer.cursor0;
    // edit.cursor0_after is set at the end of this function.
    edit.cursor1_before = buffer.cursor1;
    // edit.cursor1_after is set at the end of this function.

    if insert_caused_delete_selection && undo_fuse_with_delete_selection {
        edit.flags |= .FUSED_WITH_PREVIOUS;

        previous_edit := *buffer.edits[buffer.edits.count - 2];
        assert(previous_edit.type == .DELETE_SELECTION);
        previous_edit.flags |= .FUSED_WITH_NEXT;
    }

    buffer.applied_edit_count = buffer.edits.count;

    update_index_for_insert(buffer, text);

    edit.cursor0_after = buffer.cursor0;
    edit.cursor1_after = buffer.cursor0;

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);

    return true;
}

text_buffer_delete_selection :: (buffer: *Text_Buffer) -> string /* Pointing to the internal gap buffer */ {
    return /*inline?*/ text_buffer_delete_selection(buffer, buffer.cursor0, buffer.cursor1);
}

text_buffer_delete_selection :: (buffer: *Text_Buffer, __start: Text_Location, __end: Text_Location) -> string /* Pointing to the internal gap buffer */ {
    ProfileZone("text_buffer_delete_selection");

    // Force copy to avoid "maybe by reference" aliasing.
    _start := __start;
    _end := __end;

    assert_valid(buffer);
    assert_location_valid(buffer, _start);
    assert_location_valid(buffer, _end);

    if _start == _end {
        return "";
    }

    start := _start;
    end   := _end;
    sort_locations(*start, *end);

    start_gb_index := text_buffer_get_gap_buffer_index_for_location(buffer, start);
    end_gb_index   := text_buffer_get_gap_buffer_index_for_location(buffer, end);
    delete_count := end_gb_index - start_gb_index;

    gap_buffer_move_gap_to(*buffer.gb, start_gb_index);
    deleted_bytes := gap_buffer_delete_forward(*buffer.gb, delete_count);
    deleted       := cast(string, deleted_bytes);

    // gap_buffer clamps, but we should have calculated the indices correctly in this case.
    assert(deleted_bytes.count == delete_count);

    buffer.cursor0 = start;
    buffer.cursor1 = start;

    discard_unapplied_edits(buffer);
    edit := array_add(*buffer.edits);
    edit.type = .DELETE_SELECTION; // nocheckin get rid of DELETE SELECTION, and unify everything under {insert/delete}_{forward/backward}{_memset}?
    edit.flags = .BARRIER;
    edit.text = arena_push_string(buffer.edit_text_arena, deleted);
    edit.text_mark = arena_get_mark(buffer.edit_text_arena);
    edit.gb_index_before = start_gb_index;
    edit.gb_index_after = start_gb_index; sanity_assert(edit.gb_index_after == buffer.gb.gap_index);

    edit.cursor0_before = _start;
    edit.cursor0_after = start;
    edit.cursor1_before = _end;
    edit.cursor1_after = start;

    buffer.applied_edit_count = buffer.edits.count;

    update_index_for_delete_forward(buffer, deleted, deleting_selection = true);

    assert_valid(buffer);

    return deleted;
}

// TODO(jt): Take a second parameter to specify the count to delete. Do delete in batch, like
// text_buffer_delete_selection does. There's also an update index function we can call.
text_buffer_delete_forward :: (buffer: *Text_Buffer) -> changed: bool {
    ProfileZone("text_buffer_delete_forward");

    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        deleted := text_buffer_delete_selection(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        return deleted.count > 0;
    }

    gb_index := text_buffer_get_gap_buffer_index_for_location(buffer, buffer.cursor0);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_after_gap(buffer.gb);
    if bytes.count == 0 {
        return false;
    }

    newline_advance := string_starts_with_newline(bytes, binary = buffer.binary_mode);
    if newline_advance {
        assert(buffer.cursor0.y < buffer.line_chars.count - 1);              // The last line can't have a newline.
        assert(buffer.cursor0.x == buffer.line_chars[buffer.cursor0.y] - 1); // The newline has to be the last char.

        // We treat \r\n as one character, if it happens to be in there.
        buffer.line_chars[buffer.cursor0.y] -= 1;
        buffer.line_bytes[buffer.cursor0.y] -= newline_advance;

        buffer.line_chars[buffer.cursor0.y] += buffer.line_chars[buffer.cursor0.y + 1];
        buffer.line_bytes[buffer.cursor0.y] += buffer.line_bytes[buffer.cursor0.y + 1];

        remove_line(buffer, buffer.cursor0.y + 1);

        deleted := gap_buffer_delete_forward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted.count);

        discard_unapplied_edits(buffer);
        edit := array_add(*buffer.edits);
        edit.type = .DELETE_FORWARD;
        edit.flags = .NONE;
        if is_through_edit(cast(string, deleted)) {
            edit.flags |= .THROUGH;
        }
        edit.text = arena_push_string(buffer.edit_text_arena, cast(string, deleted));
        edit.text_mark = arena_get_mark(buffer.edit_text_arena);
        edit.gb_index_before = gb_index;
        edit.gb_index_after = gb_index; sanity_assert(edit.gb_index_after == buffer.gb.gap_index);
        edit.cursor0_before = buffer.cursor0;
        edit.cursor0_after = buffer.cursor0;
        edit.cursor1_before = buffer.cursor0;
        edit.cursor1_after = buffer.cursor0;

        buffer.applied_edit_count = buffer.edits.count;
    } else {
        codepoint_advance: s64 = 1;
        if !buffer.binary_mode {
            _, codepoint_advance = find_next_utf8_char_boundary(bytes, 0);
        }

        if codepoint_advance {
            buffer.line_chars[buffer.cursor0.y] -= 1;
            buffer.line_bytes[buffer.cursor0.y] -= codepoint_advance;

            deleted := gap_buffer_delete_forward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted.count);

            discard_unapplied_edits(buffer);
            edit := array_add(*buffer.edits);
            edit.type = .DELETE_FORWARD;
            edit.flags = .NONE;
            if is_through_edit(cast(string, deleted)) {
                edit.flags |= .THROUGH;
            }

            edit.text = arena_push_string(buffer.edit_text_arena, cast(string, deleted));
            edit.text_mark = arena_get_mark(buffer.edit_text_arena);
            edit.gb_index_before = gb_index;
            edit.gb_index_after = gb_index; sanity_assert(edit.gb_index_after == buffer.gb.gap_index);
            edit.cursor0_before = buffer.cursor0;
            edit.cursor0_after = buffer.cursor0;
            edit.cursor1_before = buffer.cursor0;
            edit.cursor1_after = buffer.cursor0;

            buffer.applied_edit_count = buffer.edits.count;
        }
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);

    return true;
}

// TODO(jt): Take a second parameter to specify the count to delete. Do delete in batch, like
// text_buffer_delete_selection does. There's also an update index function we can call.
text_buffer_delete_backward :: (buffer: *Text_Buffer) -> changed: bool {
    ProfileZone("text_buffer_delete_backward");

    assert_valid(buffer);

    if buffer.cursor0 != buffer.cursor1 {
        deleted := text_buffer_delete_selection(buffer);
        assert(buffer.cursor0 == buffer.cursor1);

        return deleted.count > 0;
    }

    gb_index := text_buffer_get_gap_buffer_index_for_location(buffer, buffer.cursor0);
    gap_buffer_move_gap_to(*buffer.gb, gb_index);

    bytes := gap_buffer_get_bytes_before_gap(buffer.gb);
    if bytes.count == 0 {
        return false;
    }

    newline_advance := string_ends_with_newline(bytes, binary = buffer.binary_mode);
    if newline_advance {
        assert(buffer.cursor0.x == 0);
        assert(buffer.cursor0.y > 0);

        new_cursor_x := buffer.line_chars[buffer.cursor0.y - 1] - 1;

        buffer.line_chars[buffer.cursor0.y - 1] -= 1;
        buffer.line_bytes[buffer.cursor0.y - 1] -= newline_advance;

        buffer.line_chars[buffer.cursor0.y - 1] += buffer.line_chars[buffer.cursor0.y];
        buffer.line_bytes[buffer.cursor0.y - 1] += buffer.line_bytes[buffer.cursor0.y];

        remove_line(buffer, buffer.cursor0.y);

        old_cursor := buffer.cursor0;

        buffer.cursor0.x = new_cursor_x;
        buffer.cursor0.y -= 1;

        deleted := gap_buffer_delete_backward(*buffer.gb, newline_advance);
        assert(newline_advance == deleted.count);

        discard_unapplied_edits(buffer);
        edit := array_add(*buffer.edits);
        edit.type = .DELETE_BACKWARD;
        edit.flags = .NONE;
        if is_through_edit(cast(string, deleted)) {
            edit.flags |= .THROUGH;
        }

        edit.text = arena_push_string(buffer.edit_text_arena, cast(string, deleted));
        edit.text_mark = arena_get_mark(buffer.edit_text_arena);
        edit.gb_index_before = gb_index;
        edit.gb_index_after = gb_index - deleted.count; sanity_assert(edit.gb_index_after == buffer.gb.gap_index);
        edit.cursor0_before = old_cursor;
        edit.cursor0_after = buffer.cursor0;
        edit.cursor1_before = old_cursor;
        edit.cursor1_after = buffer.cursor0;

        buffer.applied_edit_count = buffer.edits.count;
    } else {
        codepoint_advance: s64 = 1;
        if !buffer.binary_mode {
            _, codepoint_advance = find_previous_utf8_char_boundary(bytes, bytes.count);
        }

        if codepoint_advance {
            buffer.line_chars[buffer.cursor0.y] -= 1;
            buffer.line_bytes[buffer.cursor0.y] -= codepoint_advance;

            old_cursor := buffer.cursor0;

            buffer.cursor0.x -= 1;

            deleted := gap_buffer_delete_backward(*buffer.gb, codepoint_advance);
            assert(codepoint_advance == deleted.count);

            discard_unapplied_edits(buffer);
            edit := array_add(*buffer.edits);
            edit.text = arena_push_string(buffer.edit_text_arena, cast(string, deleted));
            edit.text_mark = arena_get_mark(buffer.edit_text_arena);
            edit.gb_index_before = gb_index;
            edit.gb_index_after = gb_index - deleted.count; sanity_assert(edit.gb_index_after == buffer.gb.gap_index);
            edit.cursor0_before = old_cursor;
            edit.cursor0_after = buffer.cursor0;
            edit.cursor1_before = old_cursor;
            edit.cursor1_after = buffer.cursor0;
            edit.type = .DELETE_BACKWARD;
            edit.flags = .NONE;
            if is_through_edit(cast(string, deleted)) {
                edit.flags |= .THROUGH;
            }

            buffer.applied_edit_count = buffer.edits.count;
        }
    }

    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);

    return true;
}

// TODO(jt): @Bug Undoing this restores the selection as though we'd have selected it manually, but we haven't.
text_buffer_delete_line :: (buffer: *Text_Buffer) -> string {
    ProfileZone("text_buffer_delete_line");

    line_end := text_buffer_get_end_of_line(buffer, buffer.cursor0.y);
    view     := text_buffer_make_view_for_interval(buffer, buffer.cursor0, line_end,, temp);

    is_only_whitespace := true;
    for view {
        if !is_space(it) {
            is_only_whitespace = false;
            break;
        }
    }

    if is_only_whitespace {
        line_end := text_buffer_get_end_of_line(buffer, buffer.cursor0.y, include_newline = true);
        return text_buffer_delete_selection(buffer, buffer.cursor0, line_end);
    } else {
        return text_buffer_delete_selection(buffer, buffer.cursor0, line_end);
    }
}

// nocheckin the undo/redo here is buggy AF. It could be because we give it user-visible cursors
// which it then uses for insertion/deletion, but we maybe want to give it one set of cursors for
// index updating and another set of cursors to restore for the user. If this is the case, maybe we
// should revisit assertability of cursors in undo/redo... The ones that are there to update the
// indices should maybe be assertable?
text_buffer_indent_line :: (buffer: *Text_Buffer, indentation_level: s64) -> changed: bool {
    ProfileZone("text_buffer_indent_line");

    assert_valid(buffer);

    original_cursor0 := buffer.cursor0;
    original_cursor1 := buffer.cursor1;

    buffer.cursor0.x = 0;

    line_gb_index := text_buffer_get_gap_buffer_index_for_line(buffer, buffer.cursor0.y);

    line_start := line_gb_index;
    line_end   := line_gb_index + buffer.line_bytes[buffer.cursor0.y] - 1;

    // TODO(jt): @Speed SIMDify loop.
    space_count := 0;
    for line_start..line_end {
        if buffer.gb[it] != #char " " {
            break;
        }
        space_count += 1;
    }

    cursor_after: Text_Location = { indentation_level, buffer.cursor0.y };

    changed := false;
    if space_count > indentation_level {
        delete_count := space_count - indentation_level;
        log("nocheckin delete count: %", delete_count);

        gap_buffer_move_gap_to(*buffer.gb, line_gb_index + indentation_level);
        gb_index_before := buffer.gb.gap_index;

        gap_buffer_delete_backward(*buffer.gb, delete_count);
        gb_index_after := buffer.gb.gap_index;

        buffer.line_bytes[buffer.cursor0.y] -= delete_count;
        buffer.line_chars[buffer.cursor0.y] -= delete_count;

        edit := array_add(*buffer.edits);
        edit.type = .DELETE_BACKWARD_MEMSET;
        edit.flags = .BARRIER;
        edit.memset_value = #char " ";
        edit.memset_count = delete_count;
        // gb_index_before actually doesn't correspond to cursor0_before, because the cursor could
        // have been anyplace on the line and we place the gap index to line up with the operation.
        // This is probably fine.
        edit.gb_index_before = gb_index_before;
        edit.gb_index_after  = gb_index_after;
        edit.cursor0_before = original_cursor0;
        edit.cursor0_after  = cursor_after;
        edit.cursor1_before = original_cursor1;
        edit.cursor0_after  = cursor_after;

        changed = true;
    } else if indentation_level > space_count {
        insert_count := indentation_level - space_count;
        log("nocheckin insert count: %", insert_count);

        gap_buffer_move_gap_to(*buffer.gb, line_gb_index + space_count);
        gb_index_before := buffer.gb.gap_index;

        gap_buffer_insert(*buffer.gb, #char " ", insert_count);
        gb_index_after := buffer.gb.gap_index;

        buffer.line_bytes[buffer.cursor0.y] += insert_count;
        buffer.line_chars[buffer.cursor0.y] += insert_count;

        edit := array_add(*buffer.edits);
        edit.type = .INSERT_MEMSET;
        edit.flags = .BARRIER;
        edit.memset_value = #char " ";
        edit.memset_count = insert_count;
        // gb_index_before actually doesn't correspond to cursor0_before, because the cursor could
        // have been anyplace on the line and we place the gap index to line up with the operation.
        // This is probably fine.
        edit.gb_index_before = gb_index_before;
        edit.gb_index_after = gb_index_after;
        edit.cursor0_before = original_cursor0;
        edit.cursor0_after  = cursor_after;
        edit.cursor1_before = original_cursor1;
        edit.cursor0_after  = cursor_after;

        changed = true;
    }

    buffer.cursor0 = cursor_after;
    buffer.cursor1 = buffer.cursor0;

    assert_valid(buffer);

    return changed;
}

text_buffer_undo_edit :: (buffer: *Text_Buffer) -> changed: bool {
    ProfileZone("text_buffer_undo_edit");

    assert_valid(buffer);

    if buffer.applied_edit_count == 0 {
        return false;
    }

    applied_count := 0;
    for < 0..buffer.applied_edit_count - 1 {
        edit := buffer.edits[it];

        buffer.cursor0 = edit.cursor0_after;
        buffer.cursor1 = edit.cursor1_after;
        gap_buffer_move_gap_to(*buffer.gb, edit.gb_index_after);

        if #complete edit.type == {
            case .INSERT; {
                deleted_bytes := gap_buffer_delete_backward(*buffer.gb, edit.text.count);
                sanity_assert(cast(string, deleted_bytes) == edit.text);

                update_index_for_delete_backward(buffer, cast(string, deleted_bytes));
            }

            case .INSERT_MEMSET; {
                deleted_bytes := gap_buffer_delete_backward(*buffer.gb, edit.memset_count);
                #if SANITY {
                    for deleted_bytes {
                        sanity_assert(it == edit.memset_value);
                    }
                }

                update_index_for_delete_backward(buffer, cast(string, deleted_bytes));
            }

            case .DELETE_SELECTION; {
                gap_buffer_insert(*buffer.gb, edit.text);
                update_index_for_insert(buffer, edit.text);
            }

            case .DELETE_FORWARD; {
                gap_buffer_insert(*buffer.gb, edit.text);
                update_index_for_insert(buffer, edit.text);
            }

            case .DELETE_BACKWARD; {
                gap_buffer_insert(*buffer.gb, edit.text);
                update_index_for_insert(buffer, edit.text);
            }

            case .DELETE_BACKWARD_MEMSET; {
                gap_buffer_insert(*buffer.gb, edit.memset_value, edit.memset_count);
                update_index_for_insert(buffer, edit.memset_value, edit.memset_count);
            }
        };

        buffer.cursor0 = edit.cursor0_before;
        buffer.cursor1 = edit.cursor1_before;

        applied_count += 1;

        if !(edit.flags & .FUSED_WITH_PREVIOUS) {
            stop_undoing := cast(bool, edit.flags & .BARRIER);
            if !stop_undoing && it > 0 {
                previous_edit := buffer.edits[it - 1];

                if !(previous_edit.flags & .THROUGH) {
                    stop_undoing = true;
                }

                if previous_edit.type != edit.type {
                    stop_undoing = true;
                }
            }

            if stop_undoing {
                break;
            }
        }
    }

    buffer.applied_edit_count -= applied_count;

    assert_valid(buffer);

    return true;
}

text_buffer_redo_edit :: (buffer: *Text_Buffer) -> changed: bool {
    ProfileZone("text_buffer_redo_edit");

    assert_valid(buffer);

    if buffer.applied_edit_count == buffer.edits.count {
        return false;
    }

    applied_count := 0;
    for buffer.applied_edit_count..buffer.edits.count - 1 {
        edit := buffer.edits[it];

        buffer.cursor0 = edit.cursor0_before;
        buffer.cursor1 = edit.cursor1_before;
        gap_buffer_move_gap_to(*buffer.gb, edit.gb_index_before);

        if #complete edit.type == {
            case .INSERT; {
                gap_buffer_insert(*buffer.gb, edit.text);
                update_index_for_insert(buffer, edit.text);
            }

            case .INSERT_MEMSET; {
                gap_buffer_insert(*buffer.gb, edit.memset_value, edit.memset_count);
                update_index_for_insert(buffer, edit.memset_value, edit.memset_count);
            }

            case .DELETE_SELECTION; {
                deleted_bytes := gap_buffer_delete_forward(*buffer.gb, edit.text.count);
                sanity_assert(cast(string, deleted_bytes) == edit.text);

                update_index_for_delete_forward(buffer, cast(string, deleted_bytes), deleting_selection = true);
            }

            case .DELETE_FORWARD; {
                deleted_bytes := gap_buffer_delete_forward(*buffer.gb, edit.text.count);
                sanity_assert(cast(string, deleted_bytes) == edit.text);

                update_index_for_delete_forward(buffer, cast(string, deleted_bytes));
            }

            case .DELETE_BACKWARD; {
                deleted_bytes := gap_buffer_delete_backward(*buffer.gb, edit.text.count);
                sanity_assert(cast(string, deleted_bytes) == edit.text);

                update_index_for_delete_backward(buffer, cast(string, deleted_bytes));
            }

            case .DELETE_BACKWARD_MEMSET; {
                deleted_bytes := gap_buffer_delete_backward(*buffer.gb, edit.memset_count);
                #if SANITY {
                    for deleted_bytes {
                        sanity_assert(it == edit.memset_value);
                    }
                }

                update_index_for_delete_backward(buffer, cast(string, deleted_bytes));
            }
        };

        buffer.cursor0 = edit.cursor0_after;
        buffer.cursor1 = edit.cursor1_after;

        applied_count += 1;

        if !(edit.flags & .FUSED_WITH_NEXT) {
            stop_redoing := cast(bool, edit.flags & .BARRIER);
            if !stop_redoing && it < buffer.edits.count - 1 {
                next_edit := buffer.edits[it + 1];

                if !(next_edit.flags & .THROUGH) {
                    stop_redoing = true;
                }

                if next_edit.type != edit.type {
                    stop_redoing = true;
                }
            }

            if stop_redoing {
                break;
            }
        }
    }

    buffer.applied_edit_count += applied_count;

    assert_valid(buffer);

    return true;
}

text_buffer_get_start_of_line :: (buffer: Text_Buffer, line_index: s64) -> Text_Location {
    assert_line_valid(buffer, line_index);

    start: Text_Location = { 0, line_index };

    return start;
}

text_buffer_get_end_of_line :: (buffer: Text_Buffer, line_index: s64, include_newline := false) -> Text_Location {
    assert_line_valid(buffer, line_index);

    line_chars := buffer.line_chars[line_index];
    endx: s64;
    if include_newline || line_index == buffer.line_chars.count - 1 {
        endx = line_chars;
    } else {
        endx = line_chars - 1;
    }

    end: Text_Location = { endx, line_index };

    return end;
}

// A 2x-ish faster, specialized version of text_buffer_make_view_for_interval. Use if you can.
text_buffer_make_view_for_line :: (buffer: Text_Buffer, line_index: s64, include_newline := false, force_allocate := false) -> string /* Pointing to the internal gap buffer, or allocated with context.allocator */ {
    ProfileZone("text_buffer_make_view_for_line");

    assert_line_valid(buffer, line_index);

    line_bytes := buffer.line_bytes[line_index];

    start_index := text_buffer_get_gap_buffer_index_for_line(buffer, line_index);
    view        := gap_buffer_make_view(buffer.gb, start_index, line_bytes, force_allocate = force_allocate);

    if !include_newline {
        newline_advance := string_ends_with_newline(view, binary = buffer.binary_mode);
        view.count -= newline_advance;
    }

    return cast(string, view);
}

text_buffer_get_byte_count_for_interval :: (buffer: Text_Buffer, _start: Text_Location, _end: Text_Location) -> s64 {
    ProfileZone("text_buffer_get_byte_count_for_interval");

    assert_location_valid(buffer, _start);
    assert_location_valid(buffer, _end);

    start := _start;
    end   := _end;
    sort_locations(*start, *end);

    start_index := text_buffer_get_gap_buffer_index_for_location(buffer, start);
    end_index   := text_buffer_get_gap_buffer_index_for_location(buffer, end);

    return end_index - start_index;
}

text_buffer_make_view_for_interval :: (buffer: Text_Buffer, _start: Text_Location, _end: Text_Location, force_allocate := false) -> string /* Pointing to the internal gap buffer, or allocated with context.allocator */ {
    ProfileZone("text_buffer_make_view_for_interval");

    assert_location_valid(buffer, _start);
    assert_location_valid(buffer, _end);

    start := _start;
    end   := _end;
    sort_locations(*start, *end);

    start_index := text_buffer_get_gap_buffer_index_for_location(buffer, start);
    end_index   := text_buffer_get_gap_buffer_index_for_location(buffer, end);

    view := gap_buffer_make_view(buffer.gb, start_index, end_index - start_index, force_allocate = force_allocate);

    return cast(string, view);
}

text_buffer_move_cursor_x :: (buffer: *Text_Buffer, delta: s64, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_x");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    if delta > 0 {
        while delta > 0 {
            // Text_Location can be past the last non-newline character. However, the last line does not
            // have the newline character, so we only pretend it does.
            if buffer.cursor0.y == buffer.line_chars.count - 1 {
                buffer.cursor0.x = min(buffer.cursor0.x + 1, buffer.line_chars[buffer.cursor0.y]);
            } else if buffer.cursor0.x < buffer.line_chars[buffer.cursor0.y] - 1 {
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
                buffer.cursor0.x = buffer.line_chars[buffer.cursor0.y - 1] - 1;
                buffer.cursor0.y -= 1;
            }

            delta += 1;
        }
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return original_cursor != buffer.cursor0;
}

text_buffer_move_cursor_y :: (buffer: *Text_Buffer, delta: s64, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_y");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    // Text_Location can not be past the last line
    buffer.cursor0.y = clamp(buffer.cursor0.y + delta, 0, buffer.line_chars.count - 1);

    // Clamp X.
    if buffer.cursor0.y == buffer.line_chars.count - 1 {
        buffer.cursor0.x = clamp(buffer.cursor0.x, 0, buffer.line_chars[buffer.cursor0.y]);
    } else {
        buffer.cursor0.x = clamp(buffer.cursor0.x, 0, buffer.line_chars[buffer.cursor0.y] - 1);
    }

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return original_cursor != buffer.cursor0;
}

text_buffer_move_cursor_to :: (buffer: *Text_Buffer, _x: s64, _y: s64, selecting: bool) {
    ProfileZone("text_buffer_move_cursor_to");

    assert_valid(buffer);

    y := clamp(_y, 0, buffer.line_count - 1);
    x := clamp(_x, 0, buffer.line_chars[y]);

    buffer.cursor0 = { x, y };

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);
}

text_buffer_move_cursor_to_start :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_start");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    buffer.cursor0 = { 0, 0 };

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return original_cursor != buffer.cursor0;
}

text_buffer_move_cursor_to_end :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_end");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    y := buffer.line_chars.count - 1;
    x := buffer.line_chars[y];
    buffer.cursor0 = { x, y };

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return original_cursor != buffer.cursor0;
}

text_buffer_move_cursor_to_start_of_line :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_start_of_line");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    line_view := text_buffer_make_view_for_line(buffer, buffer.cursor0.y,, temp);

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

    return original_cursor != buffer.cursor0;
}

text_buffer_move_cursor_to_end_of_line :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_end_of_line");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    buffer.cursor0 = text_buffer_get_end_of_line(buffer, buffer.cursor0.y);

    if !selecting {
        buffer.cursor1 = buffer.cursor0;
    }

    assert_valid(buffer);

    return original_cursor != buffer.cursor0;
}

text_buffer_move_cursor_to_previous_word_boundary :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool, cursor_y_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_previous_word_boundary");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    _search_line_backward :: (line_view: string, $binary: bool) -> found: bool, inside_word: bool, dx: s64 {
        // The line is empty, so we couldn't have started inside a word.
        if line_view.count == 0 {
            return false, false, 0;
        }

        inside_word_initial_set := false;
        inside_word             := false;

        found := false;
        dx := 0;

        ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
        for < :ITERATOR line_view {
            is_nonword := #ifx binary then char_is_nonword_binary(it) else char_is_nonword_utf8(it);

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

    search_line_backward :: (line_view: string, binary: bool) -> found: bool, inside_word: bool, dx: s64 {
        if binary {
            found, inside_word, dx :=  _search_line_backward(line_view, true);
            return found, inside_word, dx;
        } else {
            found, inside_word, dx :=  _search_line_backward(line_view, false);
            return found, inside_word, dx;
        }
    }

    line_start         := text_buffer_get_start_of_line(buffer, buffer.cursor0.y);
    view_before_cursor := text_buffer_make_view_for_interval(buffer, line_start, buffer.cursor0,, temp);

    found, inside_word, dx := search_line_backward(view_before_cursor, buffer.binary_mode);
    if found || inside_word {
        buffer.cursor0.x -= dx;
    } else {
        while true {
            previous_cursor := buffer.cursor0;
            text_buffer_move_cursor_y(buffer, -1, selecting);
            if previous_cursor.y == buffer.cursor0.y {
                break;
            }

            buffer.cursor0 = text_buffer_get_end_of_line(buffer, buffer.cursor0.y);

            line_view := text_buffer_make_view_for_line(buffer, buffer.cursor0.y,, temp);

            found, inside_word, dx = search_line_backward(line_view, buffer.binary_mode);
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

    return original_cursor != buffer.cursor0, original_cursor.y != buffer.cursor0.y;
}

text_buffer_move_cursor_to_next_word_boundary :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool, cursor_y_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_next_word_boundary");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    _search_line_forward :: (line_view: string, $binary: bool) -> found: bool, inside_word: bool, dx: s64 {
        // The line is empty, so we couldn't have started inside a word.
        if line_view.count == 0 {
            return false, false, 0;
        }

        inside_word_initial_set := false;
        inside_word             := false;

        found := false;
        dx := 0;

        ITERATOR :: #ifx binary then string_bytes_iter else Unicode.utf8_iter;
        for :ITERATOR line_view {
            is_nonword := #ifx binary then char_is_nonword_binary(it) else char_is_nonword_utf8(it);

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

    search_line_forward :: (line_view: string, binary: bool) -> found: bool, inside_word: bool, dx: s64 {
        if binary {
            found, inside_word, dx :=  _search_line_forward(line_view, true);
            return found, inside_word, dx;
        } else {
            found, inside_word, dx :=  _search_line_forward(line_view, false);
            return found, inside_word, dx;
        }
    }

    line_end          := text_buffer_get_end_of_line(buffer, buffer.cursor0.y);
    view_after_cursor := text_buffer_make_view_for_interval(buffer, buffer.cursor0, line_end,, temp);

    found, inside_word, dx := search_line_forward(view_after_cursor, buffer.binary_mode);
    if found || inside_word {
        buffer.cursor0.x += dx;
    } else {
        while true {
            previous_cursor := buffer.cursor0;
            text_buffer_move_cursor_y(buffer, 1, selecting);
            if previous_cursor.y == buffer.cursor0.y {
                break;
            }

            buffer.cursor0.x = 0;

            line_view := text_buffer_make_view_for_line(buffer, buffer.cursor0.y,, temp);

            found, inside_word, dx = search_line_forward(line_view, buffer.binary_mode);
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

    return original_cursor != buffer.cursor0, original_cursor.y != buffer.cursor0.y;
}

// TODO(jt): @Speed Searching through 45 lines towards the end of a 1GB file takes about 350
// milliseconds. Most of that time is spent in text_buffer_make_view_for_line.
text_buffer_move_cursor_to_previous_blank_line :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_previous_blank_line");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

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

    return original_cursor != buffer.cursor0;
}

// TODO(jt): @Speed Searching through 45 lines towards the end of a 1GB file takes about 350
// milliseconds. Most of that time is spent in text_buffer_make_view_for_line.
text_buffer_move_cursor_to_next_blank_line :: (buffer: *Text_Buffer, selecting: bool) -> cursor_moved: bool {
    ProfileZone("text_buffer_move_cursor_to_next_blank_line");

    assert_valid(buffer);

    original_cursor := buffer.cursor0;

    found := false;
    found_index := -1;
    {
        line_index := buffer.cursor0.y + 1;
        while !found && line_index < buffer.line_bytes.count {
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

    return original_cursor != buffer.cursor0;
}

text_buffer_join_cursors :: (buffer: *Text_Buffer) {
    buffer.cursor1 = buffer.cursor0;
}

text_buffer_get_min_cursor :: (buffer: Text_Buffer) -> Text_Location {
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

text_buffer_get_max_cursor :: (buffer: Text_Buffer) -> Text_Location {
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

text_buffer_switch_to_binary_mode :: (buffer: *Text_Buffer) {
    buffer.binary_mode = true;

    array_reset_keeping_memory(*buffer.line_bytes);
    array_reset_keeping_memory(*buffer.line_chars);
    buffer.line_count = 0;

    add_line(buffer);

    // TODO(jt): The edit cursors become invalid after we switch to binary_mode. We currently
    // destroy the undo history to avoid that, but we could recompute the edit cursor positions
    // instead. We can preserve cursors by converting them to gap buffer indices and back.
    //
    // :BinaryMode
    array_reset_keeping_memory(*buffer.edits);
    if (buffer.edit_text_arena != buffer.arena) {
        arena_pop_to_mark(buffer.edit_text_arena, buffer.edit_text_arena_mark);
    }

    buffer.applied_edit_count = 0;

    for buffer.gb {
        lb := peek_pointer(buffer.line_bytes);
        lc := peek_pointer(buffer.line_chars);

        lb.* += 1;
        lc.* += 1;

        if it == #char "\n" {
            add_line(buffer);
        }
    }

    // TODO(jt): Preserve cursor when pasting binary data from clipboard, although apparently it
    // isn't that easy to get binary data from the clipboard. We can preserve cursors by converting
    // them to gap buffer indices and back.
    //
    // :BinaryMode
    buffer.cursor0 = { 0, 0 };
    buffer.cursor1 = { 0, 0 };

    buffer.line_count = buffer.line_bytes.count;
}

// TODO(jt): @Speed For 1GB files of regular prose, this takes too long, especially if called tens
// or hundreds of times per frame. Can we do something about it?
//
// UPDATE:
//
// :IncrementalGapBufferIndices
//
// Many times we call this on a subsequent run of lines (usually not directly, but through making a
// view). We could have a batch version that internally computes incrementally to avoid having to
// start from the beginning every time:
//
//   text_buffer_get_gap_buffer_index_for_lines(buffer,line_index0,line_index1) -> [] s64
//
// In addition to that, we probably we might want an explicitly incremental version:
//
//   text_buffer_get_gap_buffer_index_for_line_incremental(buffer,line_index,previous_line_and_index) -> next_line: s64, next_index: s64
//
// (Note that we already do this manually in places, so it might be good to make a set of APIs to
// make this easier.)
text_buffer_get_gap_buffer_index_for_line :: (buffer: Text_Buffer, line_index: s64) -> s64 {
    ProfileZone("text_buffer_get_gap_buffer_index_for_line");

    assert_line_valid(buffer, line_index);

    if line_index >= buffer.line_bytes.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.count;
    }

    // TODO(jt): @Speed SIMD this!
    //
    // TODO(jt): @Speed After doing SoA on the line arrays, this got a big boost. Likely another big
    // boost would be to pack the data tighter, but that introduces a lot of noisy casts in places,
    // so we'll have to try multiple versions and pick the least ugly, e.g. making only these line
    // arrays u32, or also making cursor u32, decide where to put the casts, etc.
    //
    // @Speed I tried unrolling this loop manually, but the speed benefits were negligible. Maybe
    // the compiler already unrolls?
    index := 0;
    for 0..line_index - 1 {
        index += buffer.line_bytes[it];
    }

    return index;
}

text_buffer_get_gap_buffer_index_for_location :: (buffer: Text_Buffer, location: Text_Location) -> s64 {
    ProfileZone("text_buffer_get_gap_buffer_index_for_location");

    assert_location_valid(buffer, location);

    line_index := location.y;
    if line_index >= buffer.line_bytes.count {
        // We are past the last line. Return index past the last byte in the gap buffer.
        return buffer.gb.count;
    }

    // TODO(jt): @Speed SIMD this!
    //
    // TODO(jt): @Speed After doing SoA on the line arrays, this got a big boost. Likely another big
    // boost would be to pack the data tighter, but that introduces a lot of noisy casts in places,
    // so we'll have to try multiple versions and pick the least ugly, e.g. making only these line
    // arrays u32, or also making Text_Location u32, decide where to put the casts, etc.
    //
    // @Speed I tried unrolling this loop manually, but the speed benefits were negligible. Maybe
    // the compiler already unrolls?
    index := 0;
    for 0..line_index - 1 {
        index += buffer.line_bytes[it];
    }

    for 0..location.x - 1 {
        first_byte := buffer.gb[index];

        codepoint_bytes: s64 = 1;
        if !buffer.binary_mode {
            // :CarriageReturn
            //
            // Even if in ascii \r\n is two characters, we treat them as one character when moving
            // cursors around, and we can't really have a byte index that goes in between these two,
            // if they are next to each other.
            codepoint_bytes = ifx first_byte == #char "\r" then 2 else UTF8_LENGTH_FOR_STARTING_BYTE[first_byte];
        }

        index += codepoint_bytes;
    }

    return index;
}

#scope_file

assert_valid :: (buffer: Text_Buffer) {
    ProfileZone("assert_valid");

    assert(buffer.line_bytes.count > 0, "Text_Buffer not initialized (has to have at least one line). Call text_buffer_init().");
    assert(buffer.line_bytes.count == buffer.line_chars.count, "Line arrays desync");
    assert_location_valid(buffer, buffer.cursor0);
    assert_location_valid(buffer, buffer.cursor1);

    // This is too expensive to do in shipping builds. We completely recreate the line index from
    // the buffer contents and compare.
    #if SANITY {
        if buffer.binary_mode {
            line_bytes: [..] s64;
            line_bytes.allocator = temp;

            array_reserve(*line_bytes, buffer.line_bytes.count);
            array_add(*line_bytes);

            view := cast(string, gap_buffer_make_view(buffer.gb, 0, buffer.gb.count,, temp));
            while view.count {
                newline_advance := string_starts_with_newline(view, binary = true);
                if newline_advance {
                    assert(newline_advance == 1);
                    line_bytes[line_bytes.count - 1] += 1;

                    array_add(*line_bytes);

                    advance(*view, newline_advance);
                } else {
                    line_bytes[line_bytes.count - 1] += 1;

                    advance(*view, 1);
                }
            }

            assert(line_bytes.count == buffer.line_bytes.count);
            assert(line_bytes.count == buffer.line_chars.count);
            assert(line_bytes.count == buffer.line_count);

            for 0..line_bytes.count - 1 {
                want_bytes := line_bytes[it];
                want_chars := want_bytes;
                have_bytes := buffer.line_bytes[it];
                have_chars := buffer.line_chars[it];

                assert(want_bytes == have_bytes, "Different byte count on line %: % (computed) != % (stored)", it, want_bytes, have_bytes);
                assert(want_chars == have_chars, "Different char count on line %: % (computed) != % (stored)", it, want_chars, have_chars);
            }
        } else {
            line_bytes: [..] s64;
            line_chars: [..] s64;
            line_bytes.allocator = temp;
            line_chars.allocator = temp;

            array_reserve(*line_bytes, buffer.line_bytes.count);
            array_reserve(*line_chars, buffer.line_chars.count);
            array_add(*line_bytes);
            array_add(*line_chars);

            view := cast(string, gap_buffer_make_view(buffer.gb, 0, buffer.gb.count,, temp));
            while view.count {
                newline_advance := string_starts_with_newline(view, binary = false);
                if newline_advance {
                    line_chars[line_chars.count - 1] += 1;
                    line_bytes[line_bytes.count - 1] += newline_advance;

                    array_add(*line_bytes);
                    array_add(*line_chars);

                    advance(*view, newline_advance);
                } else {
                    _, codepoint_advance := find_next_utf8_char_boundary(view, 0);

                    line_chars[line_chars.count - 1] += 1;
                    line_bytes[line_bytes.count - 1] += codepoint_advance;

                    advance(*view, codepoint_advance);
                }
            }

            assert(line_bytes.count == line_chars.count);
            assert(line_bytes.count == buffer.line_bytes.count);
            assert(line_chars.count == buffer.line_chars.count);
            assert(line_bytes.count == buffer.line_count);
            for 0..line_bytes.count - 1 {
                want_chars := line_chars[it];
                have_chars := buffer.line_chars[it];
                want_bytes := line_bytes[it];
                have_bytes := buffer.line_bytes[it];

                assert(want_bytes == have_bytes, "Different byte count on line %: % (computed) != % (stored)", it, want_bytes, have_bytes);
                assert(want_chars == have_chars, "Different char count on line %: % (computed) != % (stored)", it, want_chars, have_chars);
            }
        }
    }
}

assert_line_valid :: (buffer: Text_Buffer, line_index: s64) {
    assert(line_index < buffer.line_bytes.count);
}

assert_location_valid :: (buffer: Text_Buffer, loc: Text_Location) {
    assert(loc.y >= 0 && loc.y < buffer.line_bytes.count);
    // The location/cursor can go past the last non-newline character, or past the last character on
    // the last line, where there is no newline at the end.
    assert(loc.x >= 0 && loc.x <= buffer.line_chars[loc.y]);
}

discard_unapplied_edits :: (buffer: *Text_Buffer) {
    if buffer.edits.count && buffer.applied_edit_count < buffer.edits.count {

        // Edit texts are allocated in order they were created. If we are hosing everything beyond a
        // certain point, we can just use the restore mark from the beginning of the chain.
        //
        // However, we can only do it if we have a unique arena for the edit text.
        if buffer.arena != buffer.edit_text_arena {
            // Additionally, some edits don't have their text allocated at all (INSERT_MEMSET), so
            // we need to find the first that does (by looking at their arena marks).

            edit_index := buffer.applied_edit_count - 1;
            edit       := *buffer.edits[edit_index];

            while edit.text_mark.allocated == -1 && edit_index > 0 {
                edit_index -= 1;
                edit        = *buffer.edits[edit_index];
            }

            if edit.text_mark.allocated != -1 {
                arena_pop_to_mark(buffer.edit_text_arena, edit.text_mark);
            }
        }

        buffer.edits.count = buffer.applied_edit_count;
    }
}

update_index_for_insert :: (buffer: *Text_Buffer, value: u8, count: s64) {
    // TODO(jt): @Cleanup @Hack @Speed We can do much better than calling the generic thing.
    text := alloc_string(count,, temp);
    memset(text.data, value, count);

    update_index_for_insert(buffer, text);
}

// TODO(jt): @Speed This is super slow on large data to the point that it takes the most of the
// time. We could parse lines with SIMD?
update_index_for_insert :: (buffer: *Text_Buffer, _text: string) {
    ProfileZone("update_index_for_insert");

    // Insert never happens for spread cursors.
    assert(buffer.cursor0 == buffer.cursor1);

    text := _text;

    // While we could compute bytes_on_line_before_cursor by asking our procedure to do that for
    // every line, that procedure has to iterate the lines array, and it would result in quadractic
    // behavior (observable once the file is at about 1MB). Therefore, we ask the procedure to
    // compute it once in the beginning, where we don't know the initial state, and update it
    // ourselves throughout the rest of the insert.
    bytes_on_line_before_cursor: s64;
    {
        line_start := text_buffer_get_start_of_line(buffer, buffer.cursor0.y);
        bytes_on_line_before_cursor = text_buffer_get_byte_count_for_interval(buffer, line_start, buffer.cursor0);
    }

    if buffer.binary_mode {
        for text {
            if it == "\n" {
                count_after_cursor := buffer.line_bytes[buffer.cursor0.y] - bytes_on_line_before_cursor;

                buffer.line_bytes[buffer.cursor0.y] += 1 - count_after_cursor;
                buffer.line_chars[buffer.cursor0.y] += 1 - count_after_cursor;

                insert_line(buffer, buffer.cursor0.y + 1, count_after_cursor, count_after_cursor);

                buffer.cursor0.y += 1;
                buffer.cursor0.x = 0;

                bytes_on_line_before_cursor = 0;

                continue;
            }

            buffer.line_bytes[buffer.cursor0.y] += 1;
            buffer.line_chars[buffer.cursor0.y] += 1;

            buffer.cursor0.x += 1;

            bytes_on_line_before_cursor += 1;
        }
    } else {
        while text.count {
            newline_advance := string_starts_with_newline(text, binary = false);
            if newline_advance {
                byte_count_after_cursor := buffer.line_bytes[buffer.cursor0.y] - bytes_on_line_before_cursor;
                char_count_after_cursor := buffer.line_chars[buffer.cursor0.y] - buffer.cursor0.x;

                advance(*text, newline_advance);

                buffer.line_bytes[buffer.cursor0.y] += newline_advance - byte_count_after_cursor;
                buffer.line_chars[buffer.cursor0.y] += 1 - char_count_after_cursor;

                insert_line(buffer, buffer.cursor0.y + 1, byte_count_after_cursor, char_count_after_cursor);

                buffer.cursor0.y += 1;
                buffer.cursor0.x = 0;

                bytes_on_line_before_cursor = 0;

                continue;
            }

            codepoint_advance := UTF8_LENGTH_FOR_STARTING_BYTE[text[0]];

            {
                // TODO(jt): Do Proper RFC-compliant utf8 validation. We also need to make it fast.
                //
                // if !validate_utf8_codepoint(s) {
                //     text_buffer_switch_to_binary_mode(buffer);
                //     return;
                // }

                // Must be first, because the rest doesn't check for OOB.
                if codepoint_advance > text.count {
                    text_buffer_switch_to_binary_mode(buffer);
                    return;
                }

                {
                    zero_found := false;
                    for 0..codepoint_advance - 1 {
                        zero_found |= text[it] == 0;
                    }

                    if zero_found {
                        text_buffer_switch_to_binary_mode(buffer);
                        return;
                    }
                }

                if !byte_is_utf8_char_boundary(text[0]) {
                    text_buffer_switch_to_binary_mode(buffer);
                    return;
                }

                _, codepoint_advance_check := find_next_utf8_char_boundary(text, 0, sanity = false);
                if codepoint_advance != codepoint_advance_check {
                    text_buffer_switch_to_binary_mode(buffer);
                    return;
                }
            }

            assert(!buffer.binary_mode);

            advance(*text, codepoint_advance);

            buffer.line_bytes[buffer.cursor0.y] += codepoint_advance;
            buffer.line_chars[buffer.cursor0.y] += 1;
            buffer.cursor0.x += 1;

            bytes_on_line_before_cursor += codepoint_advance;
        }
    }

    // The calling code must manage cursor1
}

update_index_for_delete_forward :: (buffer: *Text_Buffer, _text: string, deleting_selection := false) {
    ProfileZone("update_index_for_delete_forward");

    if deleting_selection {
        // The selection delete sorts cursors, and so must we.
        sort_locations(*buffer.cursor0, *buffer.cursor1);
    }

    text := _text;

    while text.count {
        newline_advance := string_starts_with_newline(text, binary = buffer.binary_mode);
        if newline_advance {
            assert(buffer.cursor0.y < buffer.line_bytes.count - 1);              // The last line can't have a newline.
            assert(buffer.cursor0.x == buffer.line_chars[buffer.cursor0.y] - 1); // The newline has to be the last char.

            buffer.line_chars[buffer.cursor0.y] -= 1;
            buffer.line_bytes[buffer.cursor0.y] -= newline_advance;

            buffer.line_chars[buffer.cursor0.y] += buffer.line_chars[buffer.cursor0.y + 1];
            buffer.line_bytes[buffer.cursor0.y] += buffer.line_bytes[buffer.cursor0.y + 1];

            remove_line(buffer, buffer.cursor0.y + 1);

            advance(*text, newline_advance);
            assert(text.count >= 0);
        } else {
            codepoint_advance: s64 = 1;
            if !buffer.binary_mode {
                _, codepoint_advance = find_next_utf8_char_boundary(text, 0);
            }

            buffer.line_chars[buffer.cursor0.y] -= 1;
            buffer.line_bytes[buffer.cursor0.y] -= codepoint_advance;

            advance(*text, codepoint_advance);
            assert(text.count >= 0);
        }
    }

    // The calling code must manage cursor1
}

update_index_for_delete_backward :: (buffer: *Text_Buffer, _text: string) {
    ProfileZone("update_index_for_delete_backward");

    text := _text;

    // Delete backward never happens for spread cursors.
    assert(buffer.cursor0 == buffer.cursor1);

    while text.count {
        newline_advance := string_ends_with_newline(text, binary = buffer.binary_mode);
        if newline_advance {
            assert(buffer.cursor0.x == 0);
            assert(buffer.cursor0.y > 0);

            new_cursor_x := buffer.line_chars[buffer.cursor0.y - 1] - 1;

            buffer.line_chars[buffer.cursor0.y - 1] -= 1;
            buffer.line_bytes[buffer.cursor0.y - 1] -= newline_advance;

            buffer.line_chars[buffer.cursor0.y - 1] += buffer.line_chars[buffer.cursor0.y];
            buffer.line_bytes[buffer.cursor0.y - 1] += buffer.line_bytes[buffer.cursor0.y];

            remove_line(buffer, buffer.cursor0.y);

            buffer.cursor0.x = new_cursor_x;
            buffer.cursor0.y -= 1;

            text.count -= newline_advance;
            assert(text.count >= 0);
        } else {
            codepoint_advance: s64 = 1;
            if !buffer.binary_mode {
                _, codepoint_advance = find_previous_utf8_char_boundary(text, text.count);
            }

            if codepoint_advance {
                buffer.line_chars[buffer.cursor0.y] -= 1;
                buffer.line_bytes[buffer.cursor0.y] -= codepoint_advance;

                buffer.cursor0.x -= 1;

                text.count -= codepoint_advance;
                assert(text.count >= 0);
            }
        }
    }

    // The calling code must manage cursor1
}

add_line :: (buffer: *Text_Buffer) {
    sanity_assert(buffer.line_count == buffer.line_bytes.count);
    sanity_assert(buffer.line_count == buffer.line_chars.count);

    array_add(*buffer.line_bytes);
    array_add(*buffer.line_chars);
    buffer.line_count += 1;
}

insert_line :: (buffer: *Text_Buffer, index: s64, byte_count: s64, char_count: s64) {
    sanity_assert(buffer.line_count == buffer.line_bytes.count);
    sanity_assert(buffer.line_count == buffer.line_chars.count);

    array_insert_at(*buffer.line_bytes, byte_count, index);
    array_insert_at(*buffer.line_chars, char_count, index);
    buffer.line_count += 1;
}

remove_line :: (buffer: *Text_Buffer, index: s64) {
    sanity_assert(buffer.line_count == buffer.line_bytes.count);
    sanity_assert(buffer.line_count == buffer.line_chars.count);

    array_ordered_remove_by_index(*buffer.line_bytes, index);
    array_ordered_remove_by_index(*buffer.line_chars, index);
    buffer.line_count -= 1;
}

is_through_edit :: (text: string) -> bool {
    if text != " " && text != "\n" && text != "\r\n" {
        if text.count && text.count == UTF8_LENGTH_FOR_STARTING_BYTE[text[0]] {
            return true;
        }
    }

    return false;
}

sort_locations :: (start: *Text_Location, end: *Text_Location) {
    if start.y > end.y {
        swap(start, end);
    } else if start.y == end.y && start.x > end.x {
        swap(start, end);
    }
}

// TODO(jt): Make this configurable (per-programming language)?  :Config
char_is_nonword_utf8 :: inline (c: u32) -> bool {
    if c == {
        case #char " ";   return true;
        case #char "\t";  return true;
        case #char "_";   return true;
        case #char "-";   return true;
        case #char ".";   return true;
        case #char ",";   return true;
        case #char ";";   return true;
        case #char ":";   return true;
        case #char "(";   return true;
        case #char ")";   return true;
        case #char "<";   return true;
        case #char ">";   return true;
        case #char "{";   return true;
        case #char "}";   return true;
        case #char "[";   return true;
        case #char "]";   return true;
        case #char "\"";  return true;
        case #char "'";   return true;
    }

    return false;
}

char_is_nonword_binary :: inline (c: u8) -> bool {
    if c >= 48 && c <= 57   return false; // 0..9
    if c >= 64 && c <= 90   return false; // A..Z
    if c >= 97 && c <= 122  return false; // a..z
    if c >= 43 && c <= 44   return false; // pound and dollar

    return true;
}
