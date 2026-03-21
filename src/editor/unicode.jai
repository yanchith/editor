// TODO(jt): @Cleanup This file contains our fixed version of modules/Unicode utf8_iter. We can
// delete it after our bug reports get fixed. The fixes are:
//
// - Checking for the string actually being empty (!s vs !s.data || !s.count)
// - Properly handling continue statements instead of infinite looping.

utf8_iter :: (s: *string, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .POINTER) "POINTER traversal is not supported by this iterator, because a that point you have to call character_utf8_to_utf32 and are kind of just doing it yourself so why use the iterator?";

    // NOTE(jt): Fixed check for empty strings. (I believe this is already fixed in the unreleased beta.)
    if !s        return;
    if !s.data   return;
    if !s.count  return;

    end := s.data + s.count;

    `it: u32;
    `it_index: s64;

    #if flags & .REVERSE {
        cursor := end - 1;
        `it_index = -1;  // it_index is not supported for reverse iteration. Deal with it. If you want that, this has to be a 2-pass algorithm where we count the characters in the first pass, and that's slower. But maybe we will do that.

        while cursor >= s.data {
            // Seek backward to the first character that is < 127.
            while ((cursor.* & 0xc0) == 0x80) && (cursor > s.data) {
                cursor -= 1;
            }

            if (cursor.* & 0xc0) == 0x80 {
                Basic.log_error("The input string starts in the middle of a Unicode character. (cursor is % bytes from s.data)", cursor - s.data);
                break;
            }

            code, bytes, unicode_result := character_utf8_to_utf32(cursor, end - cursor, true);
            if unicode_result != .CONVERSION_OK {
                Basic.log_error("Unicode conversion error: %", unicode_result);
                break;
            }

            `it = code;

            // Advance cursor *before* inserting body, because the body can do continue!
            cursor -= 1;

            #insert body;
        }
    } else {
        cursor := s.data;
        index  := 0;

        while cursor < end {
            code, bytes, unicode_result := character_utf8_to_utf32(cursor, end - cursor, true);
            if unicode_result != .CONVERSION_OK {
                Basic.log_error("Unicode conversion error: %", unicode_result);
                break;
            }

            `it = code;
            `it_index = index;

            // Advance cursor and index *before* inserting body, because the body can do continue!
            cursor += bytes;
            index  += 1;
            Basic.assert(cursor <= end);

            #insert body;
        }
    }
}


#scope_file // To keep the routine above as close to the original as possible.
Basic :: #import "Basic";
character_utf8_to_utf32 :: Unicode.character_utf8_to_utf32;
