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

//
// TODO(jt): @Speed Even with the micro-tweaks in this file (I am hesitant to call them optimizations),
// lexing is still not efficient enough to run always. On kb_text_shape.h (a realistic larger source-file),
// it still sometimes misses a frame, but more seriously, it visibly increases power consumption when typing.
// We need to do better! See below.
//
// I had a shower thought about incremental lexing. Instead of lexing "a screenful of text", which
// would miss big multiline tokens, we'd try to lex the neighborhood of the edit, using the tokens
// from the previous lexing pass to inform us about how far back/forward we need to go: if the edit
// interesects a token, we use that token's text span to enlarge the area to rescan.
//
// We'd also have to go and patch each subsequent token't position information, unless we encoded them
// relative to the previous token, and only translated to absolute coordinates for the tokens that get
// used for syntax highlighting. Either way, correctly integrating the incrementally scanned tokens
// with the pre-existing ones seems like the tricky part.
//
// Note that a single token spanning the entire file would still force us to do a lot of work, but these
// are fortunately quite rare. (In this codebase, one such token exists in modal_interaction_benchgen.)
//
//   -jt, 20 September 2026

Lexer :: struct {
    input: string;

    reported_error: bool;

    line_index: s32;    // Starts at 0
    column_index: s32;  // Starts at 0

    // Storage of recently seen tokens, so we can look back without the caller
    // having to provide us with data.
    //
    // Thank you for this storage idea, Jai_Lexer!
    RECENT_TOKEN_COUNT :: 8; // Must be power of two for the bit-op modulo.
    recent_tokens: [RECENT_TOKEN_COUNT] Token;
    recent_token_index_for_writes: s64;

    userdata: *void;
}

lexer_write_recent_token :: (lexer: *Lexer, token: Token) {
    #assert is_nonzero_power_of_two(lexer.RECENT_TOKEN_COUNT);

    lexer.recent_tokens[lexer.recent_token_index_for_writes] = token;

    lexer.recent_token_index_for_writes += 1;
    lexer.recent_token_index_for_writes &= lexer.RECENT_TOKEN_COUNT - 1;
}

// Pass -1 for previous token, -2 for the one before that, etc.
// 0th index is the current (yet unwritten!) token.
lexer_read_recent_token :: (lexer: Lexer, index: s64 = -1) -> *Token {
    #assert is_nonzero_power_of_two(lexer.RECENT_TOKEN_COUNT);

    i := lexer.recent_token_index_for_writes + index;
    i &= lexer.RECENT_TOKEN_COUNT - 1;

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

lexer_byte_equals :: inline (lexer: Lexer, c: u8, index := 0) -> bool {
    if lexer.input.count > index {
        return lexer.input[index] == c;
    }

    return false;
}

lexer_byte_is_any :: inline (lexer: Lexer, $bytes: string, index := 0) -> bool {
    #insert #run make_lut(cast([] u8, bytes));
    return lexer.input.count > index && LUT[lexer.input[index]];
}

lexer_byte_matches :: inline (lexer: Lexer, matcher: (c: u8) -> bool, index := 0) -> bool {
    if lexer.input.count > index {
        if matcher(lexer.input[index]) {
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
        
        // See :ManualAdvance.
        lexer.input.data  += 1;
        lexer.input.count -= 1;
    } else {
        lexer_advance_horizontally(lexer);
    }
}

lexer_advance_horizontally :: inline (lexer: *Lexer) {
    sanity_assert(lexer.input.count > 0);
    sanity_assert(lexer.input[0] != "\n");

    // We (almost) completely trust the table for utf8 lengths, however
    // we clamp the length to 4 (because our table is from an older RFC?), and
    // we also clamp to input size and emit error if the character would cause
    // us to go out of bounds.
    char_length: s64 = UTF8_LENGTH_FOR_STARTING_BYTE_CLAMPED[lexer.input[0]];
    if char_length > lexer.input.count {
        lexer.reported_error = true;
        char_length = lexer.input.count;
    }

    lexer.column_index += 1;

    // :ManualAdvance
    //
    // This used to be a regular advance from Simple_String, but this is for some reason super slow?
    // This is weird, because advance is marked inline (and LLVM should inline it regardless).
    // Bytecode, LLVM IR and the disassembly is much smaller, if we manually inline advance without its asserts.
    // The resulting code is also significantly faster, which is at least a little surprising, because
    // the asserts never go off, so the branches should be completely predictable.
    //
    // advance(*lexer.input, char_length);
    lexer.input.count -= char_length;
    lexer.input.data  += char_length;
}

lexer_eat_whitespace :: (lexer: *Lexer) {
    //
    // I tried SSE2 and "fake SIMD" with u64 for this procedure. They were both a little slower than the original loop
    // at the bottom of this procedure. They also both had a couple of problems:
    //
    // 1) In regular source files, there is not enough opportunity for 8/16 bytes at a time to trigger all that often.
    //    Having to run a pre-alignment loop does not help.
    //
    // 2) When the SIMD loops triggered, any speed gains from processing multiple bytes at a time were overshadowed by the
    //    followup expensive serial part to determine how much to advance line/column indices: 1x bsf, 1x bsr, 1x popcnt
    //    + some hard to predict branches. Maybe there is a way to be smarter about that. The "fake SIMD" was even worse,
    //    because instead of pcmpeqb it had to use an 11-long dependency chain for lane-wise cmpeq on u64.
    //
    //           -jt, 21 September 2026
    
    
    //
    // A lookup table for is_space from modules/Basic.
    //
    // On Zen3, IS_SPACE_LUT is noticably faster than is_space.
    // On M4, the original is_space and the LUT are the same speed.
    //
    IS_SPACE_LUT :: u8.[
        0,0,0,0,0,0,0,0, 0,1,1,0,0,1,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
    ];
    
    while lexer.input.count && IS_SPACE_LUT[lexer.input[0]] {
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
    while lexer.input.count && lexer.input[0] != "\n" {
        lexer_advance_horizontally(lexer);
    }
}

lexer_eat_identifier :: (lexer: *Lexer) -> string {
    ident: string;
    ident.data = lexer.input.data;
    
    IS_ALNUM_OR_MULTIBYTE_UTF8_CHAR_BOUNDARY_LUT :: u8.[
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 1,1,1,1,1,1,1,1, 1,1,0,0,0,0,0,0, // 0-9
        0,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,1, // A-Z, underscore
        0,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,0,0,0,0,0, // a-z
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // First bytes of multibyte codepoints
        1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1, // First bytes of multibyte codepoints
    ];

    while lexer.input.count && IS_ALNUM_OR_MULTIBYTE_UTF8_CHAR_BOUNDARY_LUT[lexer.input[0]] {
        lexer_advance_horizontally(lexer);
    }

    ident.count = lexer.input.data - ident.data;

    return ident;
}

lexer_is_keyword :: (identifier: string, $keywords: [] string) -> bool {
    // For lang_c, building a matcher saves about 1ms compared to array_find on kb_text_shape.h.
    // Tested on Zen3 and M4.
    #insert #run make_keyword_matcher(keywords);
    return match_keyword(identifier);
}

#scope_file

S :: #char " ";
T :: #char "\t";
R :: #char "\r";
N :: #char "\n";

u8x16 :: struct {
    array: [16] u8 #align 16;
}

sx16 := u8x16.{ .[S, S, S, S, S, S, S, S, S, S, S, S, S, S, S, S] };
tx16 := u8x16.{ .[T, T, T, T, T, T, T, T, T, T, T, T, T, T, T, T] };
rx16 := u8x16.{ .[R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R] };
nx16 := u8x16.{ .[N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N] };

make_lut :: (bytes: [] u8) -> string {
    sb: String_Builder;
    append(*sb, "LUT :: u8.[\n");
    for 0..31     append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 32..63    append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 64..95    append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 96..127   append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 128..159  append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 160..191  append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 192..223  append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    for 224..255  append(*sb, ifx array_find(bytes, cast(u8, it)) then "1," else "0,");
    append(*sb, "\n");
    append(*sb, "];\n");
                            
    return builder_to_string(*sb);
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

