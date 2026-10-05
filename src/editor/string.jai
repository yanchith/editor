//
// Additions to and modifications of modules/String.
//

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

contains_only_whitespace :: (s: string) -> bool {
    only_whitespace := true;
    for s {
        if !is_space(it) {
            only_whitespace = false;
            break;
        }
    }

    return only_whitespace;
}

// TODO(jt): @Cleanup This is a simpler overload of slice from modules/String. We should mail this in.
// An additional modification is the change from assert to sanity_assert+clamp, because asserts harm codegen
// (verified in beta 0.2.030), producing additional basic blocks and machine code. Real-world performance suffers.
slice :: inline (s: string, index: s64) -> string {
    sanity_assert(index >= 0, "index = %", index);
    if index < 0         index = 0;

    if index >= s.count  return "";

    c: string = ---;
    c.data    = s.data + index;
    c.count   = s.count - index;
    return c;
}

//
// Unicode stuff
//

// RFC 3629 from 2003 (https://www.rfc-editor.org/info/rfc3629/).
// The table contains zeroes in places where the starting byte is invalid.
UTF8_LENGTH_FOR_STARTING_BYTE :: u8.[
//  0 1 2 3 4 5 6 7  8 9 A B C D E F
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 0
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 1
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 2
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 3
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 4
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 5
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 6
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // 7
    
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, // 8
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, // 9
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, // A
    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, // B
    0,0,2,2,2,2,2,2, 2,2,2,2,2,2,2,2, // C
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2, // D
    3,3,3,3,3,3,3,3, 3,3,3,3,3,3,3,3, // E
    4,4,4,4,4,0,0,0, 0,0,0,0,0,0,0,0, // F
];

// Like the previous table, but doesn't contain zeroes for invalid bytes.
// Instead contains number of bytes we'd advance if the starting byte was valid.
//
// We use this table in places where it advances a while loop, so that we don't loop infinitely,
// if somehow invalid UTF8 slipped past validation. We probably shouldn't.
UTF8_LENGTH_FOR_STARTING_BYTE_CLAMPED :: u8.[
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2, 2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3, 3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4, 4,4,4,4,4,4,4,4,
];

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

// Must be called on valid utf8, otherwise will return garbage (or sanity assert).
find_next_utf8_char_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, byte_count: u32 {
    found_index, byte_count := inline find_next_utf8_char_boundary(cast(string, bytes), index);
    return found_index, byte_count;
}

// Must be called on valid utf8, otherwise will return garbage (or sanity assert).
find_next_utf8_char_boundary :: (text: string, index: s64) -> found_index: s64, byte_count: u32 {
    assert(index >= 0 && index <= text.count); // <=, because our cursor can be pointing past the buffer.
    if index == text.count {
        return text.count, 0;
    }

    assert(is_utf8_char_boundary(text[index]));

    byte_count := UTF8_LENGTH_FOR_STARTING_BYTE_CLAMPED[text[index]];
    next_index := index + byte_count;

    sanity_assert(byte_count <= 4);
    sanity_assert(next_index <= text.count); // We can return up to text.count.

    return next_index, byte_count;
}

// Must be called on valid utf8, otherwise will return garbage (or sanity assert).
find_previous_utf8_char_boundary :: (bytes: [] u8, index: s64) -> found_index: s64, byte_count: u32 {
    found_index, byte_count := inline find_previous_utf8_char_boundary(cast(string, bytes), index);
    return found_index, byte_count;
}

// Must be called on valid utf8, otherwise will return garbage (or sanity assert).
find_previous_utf8_char_boundary :: (text: string, index: s64) -> found_index: s64, byte_count: u32 {
    assert(index >= 0 && index <= text.count); // <=, because our cursor can be pointing past the buffer.
    if index == 0 {
        return 0, 0;
    }

    // index == count is also a valid starting point.
    assert(index == text.count || is_utf8_char_boundary(text[index]));

    // TODO(jt): @Speed There should be a fake SIMD, Hacker's Delight style way of finding the
    // previous character index instead of this loop.
    prev_index := index - 1;
    while prev_index > 0 && !is_utf8_char_boundary(text[prev_index]) {
        prev_index -= 1;
    }

    byte_count := index - prev_index;

    sanity_assert(byte_count <= 4);
    sanity_assert(prev_index >= 0);
    sanity_assert(index == prev_index + UTF8_LENGTH_FOR_STARTING_BYTE_CLAMPED[text[prev_index]]);

    return prev_index, cast(u32, byte_count);
}

is_utf8_char_boundary :: inline (b: u8) -> bool {
    // TODO(jt): @Speed Apparently there's a bit magic thing where we could avoid the OR:
    //
    //     cast(s8, b) >= -0x40;
    //
    return b < 128 || b >= 192;
}

validate_utf8 :: (s: string) -> bool, length: s64 {
    if !s.count {
        return false, 0;
    }
    
    b0 := s[0];
    
    length := UTF8_LENGTH_FOR_STARTING_BYTE[b0];
    valid  := cast(bool, length);
    
    if !valid            return false, length;
    if length > s.count  return false, s.count;

    // Transcription of Table 3-7 of the Unicode specification,
    // except the first byte's validity is already handled by UTF8_LENGTH_FOR_STARTING_BYTE.
    //
    // https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-3/#G27506
    //
    // TODO(jt): @Speed Consider making LUTs for the 5 other cases for byte 2 (and 3 and 4).
    
    // The range is almost always 80..bf, except for 4 edge cases on the second byte.
    if b0 >= 0xc2 && b0 <= 0xdf {
        b1 := s[1];
        valid = b1 >= 0x80 && b1 <= 0xbf;
    } else if b0 == 0xe0 {
        // Edge case on second byte!
        b1 := s[1];
        b2 := s[2];
        valid = b1 >= 0xa0 && b1 <= 0xbf && b2 >= 0x80 && b2 <= 0xbf;
    } else if b0 >= 0xe1 && b0 <= 0xec {
        b1 := s[1];
        b2 := s[2];
        valid = b1 >= 0x80 && b1 <= 0xbf && b2 >= 0x80 && b2 <= 0xbf;
    } else if b0 == 0xed {
        // Edge case on second byte!
        b1 := s[1];
        b2 := s[2];
        valid = b1 >= 0x80 && b1 <= 0x9f && b2 >= 0x80 && b2 <= 0xbf;
    } else if b0 >= 0xee && b0 <= 0xef {
        b1 := s[1];
        b2 := s[2];
        valid = b1 >= 0x80 && b1 <= 0xbf && b2 >= 0x80 && b2 <= 0xbf;
    } else if b0 == 0xf0 {
        // Edge case on second byte!
        b1 := s[1];
        b2 := s[2];
        b3 := s[3];
        valid = b1 >= 0x90 && b1 <= 0xbf && b2 >= 0x80 && b2 <= 0xbf && b3 >= 0x80 && b3 <= 0xbf;
    } else if b0 >= 0xf1 && b0 <= 0xf3 {
        b1 := s[1];
        b2 := s[2];
        b3 := s[3];
        valid = b1 >= 0x80 && b1 <= 0xbf && b2 >= 0x80 && b2 <= 0xbf && b3 >= 0x80 && b3 <= 0xbf;
    } else if b0 == 0xf4 {
        // Edge case on second byte!
        b1 := s[1];
        b2 := s[2];
        b3 := s[3];
        valid = b1 >= 0x80 && b1 <= 0x8f && b2 >= 0x80 && b2 <= 0xbf && b3 >= 0x80 && b3 <= 0xbf;
    }
    
    return valid, length;
}

//
// Additions to Simple_String.jai
//

is_hex :: inline (b: u8) -> bool {
    return is_digit(b) || b >= "a" && b <= "f" || b >= "A" && b <= "F";
}

is_alnum32 :: inline (c: u32) -> bool {
    return c >= #char "0" && c <= #char "9" || c >= #char "A" && c <= #char "Z" || c >= #char "a" && c <= #char "z";
}

is_punct32 :: inline (c: u32) -> bool {
    return c >= #char "!" && c <= #char "/" || c >= #char ":" && c <= #char "@" || c >= #char "[" && c <= #char "`" || c >= #char "{" && c <= #char "~";
}

is_nonnewline_space32 :: inline (c: u32) -> bool {
    return c == #char "\t" || c == #char " ";
}

is_newline32 :: inline (c: u32) -> bool {
    return c == #char "\r" || c == #char "\n";
}

//
// Iterator stuff
//

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

// Like path_filename, but extracts last N parts of the path. Returns actual number of path parts.
path_trailing_parts :: (path: string, n: s64) -> string, count: s64 {
    count := 1;

    index := find_index_from_right(path, #char "/");
    if index == -1 {
        return path, count;
    }

    while count < n {
        count += 1;

        index = find_index_from_right(path, #char "/", index - 1);
        if index == -1 {
            return path, count;
        }
    }

    index += 1;
    return String.slice(path, index, path.count - index), count;
}

// Like begins_with, but accounts for path parts, so projects/jai is not a prefix of projects/jai-thingy,
// but projects/jai is a prefix of projects/jai/thingy.
path_begins_with :: (_path: string, _prefix: string) -> bool {
    path   := _path;
    prefix := _prefix;

    while path.count && prefix.count {
        path_part_count   := String.find_index_from_left(path, #char "/");
        prefix_part_count := String.find_index_from_left(prefix, #char "/");
        path_advance   := path_part_count + 1;
        prefix_advance := prefix_part_count + 1;

        if path_part_count == -1 {
            path_part_count = path.count;
            path_advance    = path.count;
        }
        if prefix_part_count == -1 {
            prefix_part_count = prefix.count;
            prefix_advance    = prefix.count;
        }

        path_part   := String.slice(path, 0, path_part_count);
        prefix_part := String.slice(prefix, 0, prefix_part_count);

        if path_part != prefix_part {
            return false;
        }

        advance(*path, path_advance);
        advance(*prefix, prefix_advance);
    }

    return prefix.count == 0;
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
