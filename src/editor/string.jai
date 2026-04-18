// Common string utilities. Something like modules/Simple_String or modules/String, but specific to what we need.

string_starts_with_newline :: (bytes: [] u8) -> newline_byte_length: u32 {
    return inline string_starts_with_newline(cast(string, bytes));
}

string_starts_with_newline :: (s: string) -> newline_byte_length: u32 {
    if s.count > 1 && s[0] == "\r" && s[1] == "\n" {
        return 2;
    } else if s.count > 0 && s[0] == "\n" {
        return 1;
    }

    return 0;
}

string_ends_with_newline :: (bytes: [] u8) -> newline_byte_length: u32 {
    return inline string_ends_with_newline(cast(string, bytes));
}

string_ends_with_newline :: (s: string) -> newline_byte_length: u32 {
    if s.count > 1 && s[s.count - 2] == "\r" && s[s.count - 1] == "\n" {
        return 2;
    } else if s.count > 0 && s[s.count - 1] == "\n" {
        return 1;
    }

    return 0;
}

count_utf8_characters :: (bytes: [] u8) -> s64 {
    return inline count_utf8_characters(cast(string, bytes));
}

count_utf8_characters :: (text: string) -> s64 {
    if text.count == 0 {
        return 0;
    }

    assert(byte_is_utf8_character_boundary(text[0]));

    // TODO(jt): @Speed SIMD this!
    count := 1;
    for 1..text.count - 1 {
        if byte_is_utf8_character_boundary(text[it]) {
            count += 1;
        }
    }

    return count;
}

// TODO(jt): @Speed If we trust the input, we can do a much faster version of
// find_next/previous_utf8_character_boundary.

find_next_utf8_character_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, scanned_count: u32 {
    found_index, scanned_count := find_next_utf8_character_boundary(cast(string, bytes), index);
    return found_index, scanned_count;
}

find_next_utf8_character_boundary :: (text: string, index: s64) -> found_index: s64, scanned_count: u32 {
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

    return next_index, cast(u32, scanned_count);
}

find_previous_utf8_character_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, scanned_count: u32 {
    found_index, scanned_count := inline find_previous_utf8_character_boundary(cast(string, bytes), index);
    return found_index, scanned_count;
}

find_previous_utf8_character_boundary :: (text: string, index: s64) -> found_index: s64, scanned_count: u32 {
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

    return prev_index, cast(u32, scanned_count);
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

// The javascript stuff...

left_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    for s.count..length - 1 {
        append(*builder, " ");
    }

    append(*builder, s);

    return builder_to_string(*builder);
}

right_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, s);

    for s.count..length - 1 {
        append(*builder, " ");
    }

    return builder_to_string(*builder);
}

temp_left_pad :: (s: string, length: s64) -> string {
    return inline left_pad(s, length,, temp);
}

temp_right_pad :: (s: string, length: s64) -> string {
    return inline right_pad(s, length,, temp);
}
