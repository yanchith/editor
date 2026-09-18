// Common string utilities. Something like modules/Simple_String or modules/String, but specific to what we need.

// TODO(jt): There are no 5-byte or 6-byte utf8 codepoints. Find out what this table should really
// look like and/or explain. (The table is a modified version of modules/Unicode.trailingBytesForUTF8)
//
// Also see UTF8_LENGTH_FOR_STARTING_BYTE_CLAMPED.
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

UTF8_LENGTH_FOR_STARTING_BYTE_CLAMPED :: u8.[
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3, 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
];

// TODO(jt): @Speed @Cleanup This is a deprecated routine from modules/String,
// called index_of_string_nocase, slightly modified with find_index_from_left.
// It is very slow, so let's either pick up the thing that's going to replace it in modules,
// or optimize it ourselves.
find_index_from_left_nocase :: (s: string, substring: string, start_index := 0) -> s64 {
    if !substring return -1;

    // This is SO SLOW! @Cleanup.
    for i: start_index..s.count-substring.count {
        t := String.slice(s, i, substring.count);
        if String.equal_nocase(t, substring) return i;
    }

    return -1;
}

// TODO(jt): @Cleanup This is find_index_from_right from modules/String that also supports a start_index.
// It is a todo in the module's code, so we should mail this in.
find_index_from_right :: (s: string, byte: u8, start_index := S64_MAX) -> s64  #no_abc {  // Returns -1 if the byte is not found in the string.
    cursor := min(start_index, s.count - 1);
    while cursor >= 0 {
        if s[cursor] == byte  return cursor;
        cursor -= 1;
    }

    return -1;
}

// TODO(jt): @Cleanup This is a simpler overload of slice from modules/String. We should mail this in.
slice :: inline (s: string, index: s64) -> string {
    assert(index >= 0, "index = %", index);
    if index >= s.count  return "";

    c: string = ---;
    c.data    = s.data + index;
    c.count   = s.count - index;
    return c;
}

count_utf8_chars :: (bytes: [] u8) -> s64 {
    return inline count_utf8_chars(cast(string, bytes));
}

count_utf8_chars :: (text: string) -> s64 {
    if text.count == 0 {
        return 0;
    }

    assert(is_utf8_char_boundary(text[0]));

    // TODO(jt): @Speed SIMD this!
    count := 1;
    for 1..text.count - 1 {
        if is_utf8_char_boundary(text[it]) {
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

    assert(is_utf8_char_boundary(text[index]));

    byte_count := UTF8_LENGTH_FOR_STARTING_BYTE[text[index]];
    next_index := index + byte_count;

    assert(byte_count <= 4);
    assert(next_index <= text.count); // This procedure can return up to text.count.

    // TODO(jt): The $sanity parameter is here to suppress sanity-checks for when we are detecting
    // binary files. We should probably do a better detection that's completely separate.
    #if SANITY && sanity {
        next_index_check := index + 1;
        while next_index_check < text.count && !is_utf8_char_boundary(text[next_index_check]) {
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
    assert(index == text.count || is_utf8_char_boundary(text[index]));

    // TODO(jt): @Speed There should be a SIMD-ish, Hacker's Delight style way of finding the
    // previous character index instead of this loop.
    prev_index := index - 1;
    while prev_index > 0 && !is_utf8_char_boundary(text[prev_index]) {
        prev_index -= 1;
    }

    byte_count := index - prev_index;

    assert(byte_count <= 4);
    assert(prev_index >= 0);

    sanity_assert(index == prev_index + UTF8_LENGTH_FOR_STARTING_BYTE[text[prev_index]]);

    return prev_index, cast(u32, byte_count);
}

is_utf8_char_boundary :: inline (b: u8) -> bool {
    /* Taken from Rust's std.

    pub(crate) const fn is_utf8_char_boundary(self) -> bool {
        // This is bit magic equivalent to: b < 128 || b >= 192
        (self as i8) >= -0x40
    }
    */
    return b < 128 || b >= 192;
}

is_nonascii_utf8_char_boundary :: inline (b: u8) -> bool {
    // See comment for is_utf8_char_bounday
    return b >= 192;
}

is_hex :: inline (b: u8) -> bool {
    return is_digit(b) || b >= "a" && b <= "f" || b >= "A" && b <= "F";
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

//
// Path stuff
//

// Like path_filename, but extracts last N parts of the path. Returns actual number of paths.
path_trailing_parts :: (path: string, n: s64) -> string, count: s64 {
    count := 1;

    index := find_index_from_right(path, "/");
    if index == -1 {
        return path, count;
    }

    while count < n {
        count += 1;

        index = find_index_from_right(path, "/", index - 1);
        if index == -1 {
            return path, count;
        }
    }

    index += 1;
    return String.slice(path, index, path.count - index), count;
}

//
// Formatting stuff
//

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
