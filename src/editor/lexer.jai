Token :: struct {
    loc0: Token_Location;
    loc1: Token_Location; // Exclusive!
    // Token ranges were end-inclusive before, because font ranges are, but it was
    // more work and harder to think for each lexer.

    type: Token_Type;
    userdata: u16; // Lexer implementations can hide info here for their benefit.
}

// Text_Location is 64-bit, but the lexer isn't nearly fast enough to lex things that big, so we might as well save space.
Token_Location :: struct {
    x: s32;
    y: s32;
}

operator== :: (a: Token_Location, b: Token_Location) -> bool {
    return a.x == b.x && a.y == b.y;
}

Token_Type :: enum u16 {
    UNINITIALIZED :: 0;

    INVALID;

    END_OF_INPUT;

    KEYWORD;
    NUMBER_LITERAL;
    STRING_LITERAL;
    CHAR_LITERAL;

    // We could add all sorts of stuff here that the syntax highlighter can target,
    // but for my personal use I care for just very minimal syntax highlighting.
    // We might expand this, if other people use the editor.

    // BUILTIN_TYPE;
    // BUILTIN_VALUE;
    // BUILTIN_IDENTIFIER;
    // BUILTIN_FUNCTION;

    PUNCTUATION;
    // OPERATOR;
    // TYPE;
    IDENTIFIER;

    DIRECTIVE; // Preprocessor directive in C. Compiler directive in JAI. Macro invocation in Rust.
    ATTRIBUTE; // [[attribute]] or __attribute__() in C. @Note in JAI, #[attribute] in Rust, [Attribute] in C#;

    LINE_COMMENT;
    BLOCK_COMMENT;
}

Lexer :: struct {
    input: string;

    reported_error: bool;

    line_index: s32;    // Starts at 0
    column_index: s32;  // Starts at 0

    // Storage of recently seen tokens, so we can look back without the caller
    // having to provide us with data.
    //
    // Thank you for this storage idea, Jai_Lexer!
    recent_tokens: [MAX_RECENT_TOKEN_COUNT] Token;
    recent_token_index_for_writes: s64;

    MAX_RECENT_TOKEN_COUNT :: 8; // Must be power of two for the bit-op modulo.
}

lexer_write_recent_token :: (lexer: *Lexer, token: Token) {
    #assert is_nonzero_power_of_two(lexer.MAX_RECENT_TOKEN_COUNT);

    lexer.recent_tokens[lexer.recent_token_index_for_writes] = token;

    lexer.recent_token_index_for_writes += 1;
    lexer.recent_token_index_for_writes &= lexer.MAX_RECENT_TOKEN_COUNT - 1;
}

// Pass -1 for previous token, -2 for the one before that, etc.
// 0th index is the current (yet unwritten!) token.
lexer_read_recent_token :: (lexer: Lexer, index: s64 = -1) -> *Token {
    #assert is_nonzero_power_of_two(lexer.MAX_RECENT_TOKEN_COUNT);

    i := lexer.recent_token_index_for_writes + index;
    i &= lexer.MAX_RECENT_TOKEN_COUNT - 1;

    token := *lexer.recent_tokens[i];

    return token;
}

lexer_set_token_start :: inline (lexer: Lexer, token: *Token) {
    token.loc0.x = lexer.column_index;
    token.loc0.y = lexer.line_index;
}

// Lexer tokens are end-exclusive. Call this once you are done with the token.
lexer_set_token_end :: inline (lexer: Lexer, token: *Token) {
    token.loc1.x = lexer.column_index;
    token.loc1.y = lexer.line_index;
}

lexer_input_byte_at_index_equals :: inline (lexer: Lexer, c: u8, index: s64) -> bool {
    if lexer.input.count > index {
        return lexer.input[index] == c;
    }

    return false;
}

lexer_input_byte_equals :: inline (lexer: Lexer, c: u8) -> bool {
    if lexer.input.count {
        return lexer.input[0] == c;
    }

    return false;
}

lexer_input_byte_is_any :: inline (lexer: Lexer, bytes: string) -> bool {
    if lexer.input.count {
        for bytes {
            if lexer.input[0] == it {
                return true;
            }
        }
    }

    return false;
}

lexer_input_byte_matches :: inline (lexer: Lexer, matcher: (c: u8) -> bool) -> bool {
    if lexer.input.count {
        if matcher(lexer.input[0]) {
            return true;
        }
    }

    return false;
}

lexer_advance :: inline (lexer: *Lexer) {
    sanity_assert(lexer.input.count > 0);

    if lexer.input[0] == "\n" {
        lexer.line_index += 1;
        lexer.column_index = 0;
        advance(*lexer.input);
    } else {
        lexer_advance_horizontally(lexer);
    }
}

lexer_advance_horizontally :: inline (lexer: *Lexer) {
    sanity_assert(lexer.input.count > 0);
    sanity_assert(lexer.input[0] != "\n");

    // We (almost) completely trust the table for utf8 lengths, however
    // we clamp the length to 4 (because our table is from an older RFC?), and
    // we also clamp and emit error if the character would cause us to go
    // out of bounds.
    char_length: s64 = min(UTF8_LENGTH_FOR_STARTING_BYTE[lexer.input[0]], 4);
    if char_length > lexer.input.count {
        lexer.reported_error = true;
        char_length = lexer.input.count;
    }

    lexer.column_index += 1;
    advance(*lexer.input, char_length);
}

lexer_eat_whitespace :: (lexer: *Lexer) {
    //
    // A lookup table for is_space from modules/Basic. Faster than calling it (because LLVM doesn't generate this?).
    //
    // On Zen3, the IS_SPACE LUT is noticably faster than is_space. Bitpacking the table doesn't make the code faster further.
    // On M4, the original is_space, the LUT and the bitpacked LUT are the same speed.
    //
    IS_SPACE :: u8.[
        0,0,0,0,0,0,0,0, 0,1,1,0,0,1,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    ];
    
    //
    // I tried SSE2 and "fake SIMD" with u64. They were both a little slower than the original loop at the bottom of this procedure.
    // They also both had a couple of problems:
    //
    // 1) In regular source files, there is not enough opportunity for 8/16 bytes at a time to trigger all that often.
    //    Having to run a pre-alignment loop does not help.
    //
    // 2) When the SIMD loops triggered, any speed gains from processing multiple bytes at a time were overshadowed by the
    //    followup expensive serial part to determine how much to advance line/column indices: 1x bsf, 1x bsr, 1x popcnt + some branches.
    //    Maybe there is a way to be smarter about that. I am leaving the SSE2 version here as a comment.
    //    The "fake SIMD" was similar, but instead of pcmpeqb it had to use an 11-long dependency chain for lane-wise cmpeq on u64,
    //    and had 64 bit masks instead of 16-bit, because there was no movemask_epi8. The only thing it had going for it was triggering
    //    more often, because it required less space and alignment.
    //
    #if 1 && CPU == .X64 {
        WIDTH :: 16;

        // Unaligned prefix
        while lexer.input.count && !is_aligned(lexer.input.data, WIDTH) {
            if !IS_SPACE[lexer.input[0]] {
                return;
            }

            if lexer.input[0] == "\n" {
                lexer.line_index += 1;
                lexer.column_index = 0;
            } else {
                lexer.column_index += 1;
            }

            advance(*lexer.input);
        }

        // SIMD loop
        s_pointer := *sx16.array;
        t_pointer := *tx16.array;
        r_pointer := *rx16.array;
        n_pointer := *nx16.array;

        while lexer.input.count >= WIDTH {
            current_pointer := lexer.input.data;

            m:  u16 = ---;
            mn: u16 = ---;
            #asm {
                // These start out with loaded patterns to compare with, but contain the comparison results after.
                s: vec;
                t: vec;
                r: vec;
                n: vec;

                mask: vec;

                current: vec;

                movdqu s, [s_pointer];
                movdqu t, [t_pointer];
                movdqu r, [r_pointer];
                movdqu n, [n_pointer];

                movdqu current, [current_pointer];

                pcmpeqb s, current;
                pcmpeqb t, current;
                pcmpeqb r, current;
                pcmpeqb n, current;

                movdqu mask, s;
                por mask, t;
                por mask, r;
                por mask, n;

                pmovmskb m, mask;
                pmovmskb mn, n;
            }

            whitespace_only := m == U16_MAX;

            leading_whitespace_count := ifx whitespace_only then WIDTH else bit_scan_forward(~m) - 1;
            if !leading_whitespace_count {
                return;
            }

            leading_whitespace_mask: u16 = ---;
            #no_aoc {
                // If leading_whitespace_count == 16, this would underflow. (We checked for leading_whitespace_count == 0 above.)
                ONE: u16 : 1;
                leading_whitespace_mask = (ONE << leading_whitespace_count) - ONE;
            }

            mn &= leading_whitespace_mask;

            newlines := popcount(mn);
            spaces_after_last_newline: s32 = ifx mn == 0 then WIDTH else WIDTH - bit_scan_reverse(mn);
            spaces_after_last_newline -= cast,trunc(s32, WIDTH - leading_whitespace_count);

            lexer.line_index += newlines;
            if newlines {
                lexer.column_index = 0;
            }
            lexer.column_index += spaces_after_last_newline;

            advance(*lexer.input, leading_whitespace_count);
            if !whitespace_only {
                return;
            }
        }
    }
    
    // Small suffix and/or scalar fallback
    while lexer.input.count && IS_SPACE[lexer.input[0]] {
        if lexer.input[0] == "\n" {
            lexer.line_index += 1;
            lexer.column_index = 0;
        } else {
            lexer.column_index += 1;
        }

        advance(*lexer.input);
    }
}

lexer_eat_until_newline :: (lexer: *Lexer) {
    while lexer.input.count {
        c := lexer.input[0];
        if c == "\n" {
            break;
        }

        lexer_advance_horizontally(lexer);
    }
}

// nocheckin @Speed This Gets called a few times and we spend some time in here. Table drive?
lexer_eat_identifier :: (lexer: *Lexer) -> string {
    ident: string;
    ident.data = lexer.input.data;

    while lexer.input.count && (lexer_input_byte_matches(lexer, is_alnum) || lexer_input_byte_matches(lexer, is_nonascii_utf8_char_boundary)) {
        lexer_advance_horizontally(lexer);
    }

    ident.count = lexer.input.data - ident.data;

    return ident;
}

lexer_is_keyword :: (identifier: string, $keywords: [] string) -> bool {
    // For lang_c, building a matcher is about 8% less time than naive array_find.
    // Not particularly great, we should try other approaches.
    #insert #run make_keyword_matcher(keywords);
    return match_keyword(identifier);
}

#scope_file

S :: #char " ";
T :: #char "\t";
R :: #char "\r";
N :: #char "\n";

Sx8: u64 : #run splat(S);
Tx8: u64 : #run splat(T);
Rx8: u64 : #run splat(R);
Nx8: u64 : #run splat(N);

u8x16 :: struct {
    array: [16] u8 #align 16;
}

sx16 := u8x16.{ .[S, S, S, S, S, S, S, S, S, S, S, S, S, S, S, S] };
tx16 := u8x16.{ .[T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T] };
rx16 := u8x16.{ .[R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R] };
nx16 := u8x16.{ .[N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N] };

splat :: (byte: u8) -> u64 {
    result: u64;
    result |= cast(u64, byte) << 0;
    result |= cast(u64, byte) << 8;
    result |= cast(u64, byte) << 16;
    result |= cast(u64, byte) << 24;
    result |= cast(u64, byte) << 32;
    result |= cast(u64, byte) << 40;
    result |= cast(u64, byte) << 48;
    result |= cast(u64, byte) << 56;
    return result;
}

// A very bad "SIMD" cmpeq.
//
// ~(a ^ b) gives us full ones of equal lanes, but not full zeroes for non-equal lanes.
//
// To achieve full zeroes, we OR all of the lane's bits into one after doing the initial XOR.
//
// Afterwards, we negate the bit we care about and multiply by 0xff,
// which broadcasts it back to the full lane.
cmpeq_u8x8 :: inline (a: u64, b: u64) -> u64 {
    x := a ^ b;

    /*
    Original version

    x = (x | (x >> 4)) & 0x0f0f0f0f0f0f0f0f;
    x = (x | (x >> 2)) & 0x0303030303030303;
    x = (x | (x >> 1)) & 0x0101010101010101;

    The masks are not necessary. Bits from neighboring lanes won't reach the
    single bit we care about in our lane.
    */

    x |= x >> 4;
    x |= x >> 2;
    x |= x >> 1;

    x = ~x & 0x0101010101010101;

    result := x * 0xff;

    return result;
}

make_keyword_matcher :: (keywords: [] string) -> string {
    keywords_by_length: [..][..] string;
    for keyword: keywords {
        if keyword.count > keywords_by_length.count - 1 {
            array_resize(*keywords_by_length, keyword.count + 1);
        }

        keywords := *keywords_by_length[keyword.count];
        array_add(keywords, keyword);
    }

    sb: String_Builder;
    append(*sb, "match_keyword :: inline (identifier: string) -> bool {\n");
    append(*sb, "  if identifier.count == {\n");
    for keywords, keyword_length: keywords_by_length {
        if keyword_length == 0  continue;
        if keywords.count == 0  continue;

        print(*sb, "  case %;\n", keyword_length);
        for keywords {
            print(*sb, "    if identifier == \"%\"  return true;\n", it);
        }
        append(*sb, "    return false;\n");
    }
    append(*sb, "  }\n");
    append(*sb, "  return false;\n");
    append(*sb, "}\n");

    return builder_to_string(*sb);
}

