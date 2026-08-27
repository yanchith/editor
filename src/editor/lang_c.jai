LANG_C_LINE_COMMENT        :: "//";
LANG_C_BLOCK_COMMENT_START :: "/*";
LANG_C_BLOCK_COMMENT_END   :: "*/";
LANG_C_BLOCK_COMMENTS_CAN_NEST :: false;

LANG_C_SURROUND_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
    { #char "\"", #char "\"" },
];

LANG_C_INDENTATION_PAREN_PAIRS: [] Paren_Pair = .[
    { #char "{", #char "}" },
    { #char "(", #char ")" },
    { #char "[", #char "]" },
];

lang_c_update_tokens :: (document: *Document) {
    ProfileZone("lang_c_update_tokens");

    sanity_assert(document != null);
    if document == null {
        return;
    }

    array_reset_keeping_memory(*document.tokens);

    // nocheckin try this with our own lexer
    // TODO(jt): @Speed @Memory This always copies the entire text buffer. This is bad! Instead
    // split the lexing loop into two and lex on the contents of the gap buffer.
    start := Text_Location.{ 0, 0 };
    end   := text_buffer_get_end_of_line(document.buffer, document.buffer.line_count - 1);
    contents := text_buffer_make_view_for_interval(document.buffer, start, end,, temp);

    lexer: Lexer;
    lexer.input = contents;

    while 1 {
        token := get_next_token(*lexer);


    }
}

#scope_file

get_next_token :: (lexer: *Lexer) -> Token {
    token: Token;

    // nocheckin fill this!

    return token;
}