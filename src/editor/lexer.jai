Token :: struct {
    loc0: Text_Location;
    loc1: Text_Location; // Exclusive!
    type: Token_Type;
    userdata: u32; // Lexer implementations can hide info here for their benefit.
}

Token_Type :: enum u32 {
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

    line_index: s64;    // Starts at 0
    column_index: s64;  // Starts at 0

    // Storage of recently seen tokens, so we can look back without the caller
    // having to provide us with data.
    //
    // Thank you for this storage idea, Jai_Lexer!
    recent_tokens: [MAX_RECENT_TOKEN_COUNT] Token;
    recent_token_index_for_writes: s64;

    MAX_RECENT_TOKEN_COUNT :: 8; // Must be power of two for the bit-op modulo.
}

lexer_write_recent_token :: (lexer: *Lexer, token: Token) {
    #assert is_power_of_two(lexer.MAX_RECENT_TOKEN_COUNT);

    lexer.recent_tokens[lexer.recent_token_index_for_writes] = token;

    lexer.recent_token_index_for_writes += 1;
    lexer.recent_token_index_for_writes &= lexer.MAX_RECENT_TOKEN_COUNT - 1;
}

// Pass -1 for previous token, -2 for the one before that, etc.
// 0th index is the current (yet unwritten!) token.
lexer_read_recent_token :: (lexer: Lexer, index: s64 = -1) -> *Token {
    #assert is_power_of_two(lexer.MAX_RECENT_TOKEN_COUNT);

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

lexer_advance :: (lexer: *Lexer) {
    sanity_assert(lexer.input.count > 0);

    c := lexer.input[0];
    if c == "\n" {
        lexer.line_index += 1;
        lexer.column_index = 0;
        advance(*lexer.input);
    } else {
        lexer_advance_horizontally(lexer);
    }
}

lexer_advance_horizontally :: (lexer: *Lexer) {
    sanity_assert(lexer.input.count > 0);
    sanity_assert(lexer.input[0] != "\n");

    c := lexer.input[0];

    // We (almost) completely trust the table for utf8 lengths, however
    // we clamp the length to 4 (because our table is from an older RFC?), and
    // we also clamp and emit error if the character would cause us to go
    // out of bounds.
    char_length: s64 = min(UTF8_LENGTH_FOR_STARTING_BYTE[c], 4);
    if char_length > lexer.input.count {
        lexer.reported_error = true;
        char_length = lexer.input.count;
    }

    lexer.column_index += 1;
    advance(*lexer.input, char_length);
}

lexer_eat_whitespace :: (lexer: *Lexer) {
    while lexer.input.count {
        c := lexer.input[0];
        if !is_space(c) {
            break;
        }

        advance(*lexer.input);

        if c == "\n" {
            lexer.line_index += 1;
            lexer.column_index = 0;
        } else {
            lexer.column_index += 1;
        }
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

lexer_eat_identifier :: (lexer: *Lexer) -> string {
    ident: string;
    ident.data = lexer.input.data;
    
    while lexer.input.count && (lexer_input_byte_matches(lexer, is_alnum) || lexer_input_byte_matches(lexer, is_nonascii_utf8_char_boundary)) {
        lexer_advance_horizontally(lexer);
    }
    
    ident.count = lexer.input.data - ident.data;
    
    return ident;
}
