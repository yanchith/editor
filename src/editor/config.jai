apply_config :: (editor: *Editor, _input: string) {
    input := _input;

    success := true;

    version:, success = String.parse_int(*input);
    if !success  return;

    section := Section.Global;

    eat_until_newline(*input);
    eat_whitespace(*input);

    if String.starts_with(input, SECTION_OPEN) {
        success, section = parse_section(*input)
    } else {

    }
}

#scope_file

parse_section :: (input: *string) {
    line := eat_until_newline(input);

    String.find_index_from_left(line, #char "]");
}

eat_until_newline :: (input: *string) -> string {
    result: string;
    result.data = input.data;

    while input.count {
        c := input[0];
        if c == "\n" {
            break;
        }

        advance(input);
    }

    result.count = input.data - result.data;

    return result;
}

eat_whitespace :: (input: *string) -> string {
    result: string;
    result.data = input.data;

    while input.count {
        if !is_space(input[0]) {
            break;
        }

        advance(input);
    }

    result.count = input.data - result.data;

    return result;
}

Section :: enum {
    Global;
    Keybinds;
}

GLOBAL_SECTION_KEYS : [] string : .[
    "theme",
];
GLOBAL_SECTION_VALUES : [][] string : .[
    .["abulafia", "naysayer", "handmade", "stb", "zenburn", "visual_studio_light"]
]

// TODO(jt): @Hack Our scope parse doesn't support strings, so we put this down here...
SECTION_OPEN :: #char "[";
SECTION_CLOSE :: #char "]";