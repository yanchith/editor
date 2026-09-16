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

nocheckin_pcount: s64;
nocheckin_fcount: s64;
nocheckin_ffcount: s64;
nocheckin_scount: s64;

// nocheckin @Speed This gets called A LOT. SIMD.
lexer_eat_whitespace :: (lexer: *Lexer) {
    // Unaligned prefix
    while lexer.input.count && !is_aligned(lexer.input.data, 8) {
        nocheckin_pcount += 1;
        
        if !is_space(lexer.input[0]) {
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
    
    // SIMD core part
    if lexer.input.count {
        sanity_assert(is_aligned(lexer.input.data, 8));
        
        // TODO(jt): X64 SSE version.
        
        // Fallback to 64-bit "SIMD" for generic targets.
        _S :: #char " ";
        _T :: #char "\t";
        _R :: #char "\r";
        _N :: #char "\n";
        
        splat8 :: (byte: u8) -> u64 {
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
        
        S: u64 : #run splat8(_S);
        T: u64 : #run splat8(_T);
        R: u64 : #run splat8(_R);
        N: u64 : #run splat8(_N);
        
        while lexer.input.count >= 8 {
            nocheckin_fcount += 1;
            current: u64 = cast(*u64, lexer.input.data).*;
            
            // nocheckin get rid of negations here
            ms := ~(current ^ S);
            mt := ~(current ^ T);
            mr := ~(current ^ R);
            mn := ~(current ^ N);
            
            m := ms | mt | mr | mn;
            
            if m != U64_MAX {
                nocheckin_ffcount += 1;
                break; // Go to suffix loop.
            }
         
            // nocheckin HERE: So X64 bsf crashes on our input. Not great. But even if disabled, this is not yet correct.
            // And even once done, this might not be a performance benefit. Let's see.
            
            // In SIMD, we'd movemask_epi first.
            newlines_seen                  := popcount(mn) >> 3;
            spaces_after_last_newline_seen := bit_scan_forward(~mn) >> 3;
            
            lexer.line_index += newlines_seen;
            if newlines_seen {
                lexer.column_index = 0;
            }
            lexer.column_index += spaces_after_last_newline_seen;
            
            advance(*lexer.input, 8);
        }
    }
    
    // Small suffix
    while lexer.input.count {
        nocheckin_scount += 1;
        if !is_space(lexer.input[0]) {
            break;
        }
        
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

// nocheckin @Speed This Gets called a few times and we spend some time in here. SIMD?
lexer_eat_identifier :: (lexer: *Lexer) -> string {
    // ProfileZone("nochekin_lexer_eat_identifier");
    ident: string;
    ident.data = lexer.input.data;
    
    while lexer.input.count && (lexer_input_byte_matches(lexer, is_alnum) || lexer_input_byte_matches(lexer, is_nonascii_utf8_char_boundary)) {
        lexer_advance_horizontally(lexer);
    }
    
    ident.count = lexer.input.data - ident.data;
    
    return ident;
}

lexer_is_keyword :: (identifier: string, $keywords: [] string) -> bool {
    // TODO(jt): @Speed It is unclear whether the generated switch statement beats array_find.
    // We need a benchmark.
    //
    // return inline array_find(keywords, identifier);
    
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
    
    #insert #run make_keyword_matcher(keywords);
    return match_keyword(identifier);
}
