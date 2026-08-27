Token :: struct {
    loc0: Text_Location;
    loc1: Text_Location;

    byte0: s64;
    byte1: s64;

    type: Token_Type;
}

Token_Type :: enum u32 {
    UNINITIALIZED :: 0;

    EOF;

    KEYWORD;
    NUMBER_LITERAL;
    STRING_LITERAL;

    // We could add all sorts of stuff here that the syntax highlighter can target,
    // but for my personal use I care for just very minimal syntax highlighting.
    // We might expand this, if other people use the editor.

    // BUILTIN_TYPE;
    // BUILTIN_VALUE;
    // BUILTIN_IDENTIFIER;
    // BUILTIN_FUNCTION;

    // PUNCTUATION;
    // OPERATOR;
    // TYPE;
    // IDENTIFIER;

    DIRECTIVE; // Preprocessor directive in C. Compiler directive in JAI. Macro invocation in Rust.
    ATTRIBUTE; // [[attribute]] or __attribute__() in C. @Note in JAI, #[attribute] in Rust, [Attribute] in C#;

    LINE_COMMENT;
    BLOCK_COMMENT;
}

Lexer :: struct {
    input: string;
    index: s64;

    line_number: s64 = 1;
    column_number: s64 = 1;

    // Jai_Lexer has a really cool storage for last N tokens here.
    // We could do that, if we find need for it:
    //
    // recent_tokens: [MAX_RECENT_TOKEN_COUNT]; // count is power of two for bit-ops modulo
}
