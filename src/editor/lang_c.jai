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

lang_c_update_syntax_highlights :: (editor: *Editor, document: *Document, platform: Platform, input: Input) {
    ProfileZone("lang_c_syntax_highlights");


}