Token :: struct {
    loc0: Text_Location;
    loc1: Text_Location;

    byte0: s64;
    byte1: s64;

    type: Token_Type;
}

Token_Type :: enum u32 {
    UNINITIALIZED :: 0;

    KEYWORD;
    NUMBER_LITERAL;
    STRING_LITERAL;

    // BUILTIN_TYPE;
    // BUILTIN_VALUE;
    // BUILTIN_IDENTIFIER;
    // BUILTIN_FUNCTION;

    // OPERATOR;
    // TYPE;
    // IDENTIFIER;

    DIRECTIVE; // Preprocessor directive in C. Compiler directive in JAI. Macro invocation in Rust.
    ATTRIBUTE; // [[attribute]] or __attribute__() in C. @Note in JAI, #[attribute] in Rust, [Attribute] in C#;

    LINE_COMMENT;
    BLOCK_COMMENT;
}