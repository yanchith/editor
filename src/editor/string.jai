// Common string utilities. Something like modules/Simple_String or modules/String, but specific to what we need.

// TODO(jt): There are no 5-byte or 6-byte utf8 codepoints. Find out what this table should really
// look like and/or explain. (The table is a modified version of modules/Unicode.trailingBytesForUTF8)
UTF8_LENGTH_FOR_STARTING_BYTE :: u8.[
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3, 4,4,4,4,4,4,4,4,5,5,5,5,6,6,6,6,
];

string_starts_with_newline :: (bytes: [] u8, binary: bool) -> newline_byte_length: u32 {
    return inline string_starts_with_newline(cast(string, bytes), binary);
}

string_starts_with_newline :: (s: string, binary: bool) -> newline_byte_length: u32 {
    if binary {
        if s.count > 0 && s[0] == "\n" {
            return 1;
        }
    } else {
        if s.count > 1 && s[0] == "\r" && s[1] == "\n" {
            return 2;
        } else if s.count > 0 && s[0] == "\n" {
            return 1;
        }
    }

    return 0;
}

string_ends_with_newline :: (bytes: [] u8, binary: bool) -> newline_byte_length: u32 {
    return inline string_ends_with_newline(cast(string, bytes), binary);
}

string_ends_with_newline :: (s: string, binary: bool) -> newline_byte_length: u32 {
    if binary {
        if s.count > 0 && s[s.count - 1] == "\n" {
            return 1;
        }
    } else {
        if s.count > 1 && s[s.count - 2] == "\r" && s[s.count - 1] == "\n" {
            return 2;
        } else if s.count > 0 && s[s.count - 1] == "\n" {
            return 1;
        }
    }

    return 0;
}

// TODO(jt): @Speed @Cleanup This temporarily exists, because we want to see it on profiles (and we
// don't want to put a profiling block around every callsite). Also, the JAI version is deprecated
// and slow, and will eventually be replaced with something faster, but maybe we will have to
// optimize this before that happens.
find_index_from_left_nocase :: (s: string, substring: string) -> s64 {
    ProfileZone("find_index_from_left_nocase");
    found_index, found := String.index_of_string_nocase(s, substring);

    if !found {
        return -1;
    }

    return found_index;
}


count_leading_whitespace_chars :: (bytes: [] u8) -> s64 {
    return inline count_leading_whitespace_chars(cast(string, bytes));
}

count_utf8_chars :: (bytes: [] u8) -> s64 {
    return inline count_utf8_chars(cast(string, bytes));
}

count_utf8_chars :: (text: string) -> s64 {
    if text.count == 0 {
        return 0;
    }

    assert(byte_is_utf8_char_boundary(text[0]));

    // TODO(jt): @Speed SIMD this!
    count := 1;
    for 1..text.count - 1 {
        if byte_is_utf8_char_boundary(text[it]) {
            count += 1;
        }
    }

    return count;
}

// Has to be called on valid utf8, otherwise it will assert.
find_next_utf8_char_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, byte_count: u32 {
    found_index, byte_count := inline find_next_utf8_char_boundary(cast(string, bytes), index);
    return found_index, byte_count;
}

// Has to be called on valid utf8, otherwise it will assert.
find_next_utf8_char_boundary :: (text: string, index: s64, $sanity: bool = true) -> found_index: s64, byte_count: u32 {
    assert(index >= 0 && index <= text.count); // <=, because our cursor can be pointing past the buffer.
    if index == text.count {
        return text.count, 0;
    }

    assert(byte_is_utf8_char_boundary(text[index]));

    byte_count := UTF8_LENGTH_FOR_STARTING_BYTE[text[index]];
    next_index := index + byte_count;

    assert(byte_count <= 4);
    assert(next_index <= text.count); // This procedure can return up to text.count.

    // TODO(jt): The $sanity parameter is here to suppress sanity-checks for when we are detecting
    // binary files. We should probably do a better detection that's completely separate.
    #if SANITY && sanity {
        next_index_check := index + 1;
        while next_index_check < text.count && !byte_is_utf8_char_boundary(text[next_index_check]) {
            next_index_check += 1;
        }

        sanity_assert(next_index == next_index_check);
    }

    return next_index, byte_count;
}

// Has to be called on valid utf8, otherwise it will assert.
find_previous_utf8_char_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, byte_count: u32 {
    found_index, byte_count := inline find_previous_utf8_char_boundary(cast(string, bytes), index);
    return found_index, byte_count;
}

// Has to be called on valid utf8, otherwise it will assert.
find_previous_utf8_char_boundary :: (text: string, index: s64) -> found_index: s64, byte_count: u32 {
    assert(index >= 0 && index <= text.count); // <=, because our cursor can be pointing past the buffer.
    if index == 0 {
        return 0, 0;
    }

    // index == count is also a valid starting point.
    assert(index == text.count || byte_is_utf8_char_boundary(text[index]));

    // TODO(jt): @Speed There should be a SIMD-ish, Hacker's Delight style way of finding the
    // previous character index instead of this loop.
    prev_index := index - 1;
    while prev_index > 0 && !byte_is_utf8_char_boundary(text[prev_index]) {
        prev_index -= 1;
    }

    byte_count := index - prev_index;

    assert(byte_count <= 4);
    assert(prev_index >= 0);

    sanity_assert(index == prev_index + UTF8_LENGTH_FOR_STARTING_BYTE[text[prev_index]]);

    return prev_index, cast(u32, byte_count);
}

byte_is_utf8_char_boundary :: inline (b: u8) -> bool {
    /* Taken from Rust's std.

    pub(crate) const fn is_utf8_char_boundary(self) -> bool {
        // This is bit magic equivalent to: b < 128 || b >= 192
        (self as i8) >= -0x40
    }
    */
    return b < 128 || b >= 192;
}

// This is just a wrapper around the regular string iterator, in case you need to refer to it by name.
string_bytes_iter :: (s: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER) "Iteration by pointer is not supported yet";

    `it: u8;
    `it_index: s64;

    #if flags & .REVERSE {
        for < s_it, s_it_index: s.* {
            it = s_it;
            it_index = s_it_index;

            #insert body;
        }
    } else {
        for s_it, s_it_index: s.* {
            it = s_it;
            it_index = s_it_index;

            #insert body;
        }
    }
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
