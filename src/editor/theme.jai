// TODO(jt): Make themes configurable. :Config
Theme :: struct {
    cursor_color: Vector4;
    cursor_color_active: Vector4;
    cursor_color_readonly: Vector4;
    line_color: Vector4;
    hover_color: Vector4;
    selection_color: Vector4;
    highlight_color: Vector4;
    highlight_color_active: Vector4;
    matching_parenthesis_color: Vector4;

    modeline_color: Vector4;
    modeline_color_active: Vector4;

    background_color: Vector4;
    gutter_color: Vector4;
    separator_color: Vector4;

    listing_item_color: Vector4;

    system_text_color: Vector4;
    system_text_variant: Font_Variant;
    text_color: Vector4;
    text_variant: Font_Variant;
    keyword_color: Vector4;
    keyword_variant: Font_Variant;
    attribute_color: Vector4;
    attribute_variant: Font_Variant;
    directive_color: Vector4;
    directive_variant: Font_Variant;
    string_literal_color: Vector4;
    string_literal_variant: Font_Variant;
    number_literal_color: Vector4;
    number_literal_variant: Font_Variant;
    comment_color: Vector4;
    comment_variant: Font_Variant;

    mini_panel_line_color: Vector4;
    mini_panel_item_text_color: Vector4;
    mini_panel_item_warning_text_color: Vector4;
}

abulafia_theme :: () -> Theme {
    cursor_color          := unpack_srgba(0x50ffa0ff);
    text_color            := unpack_srgba(0xcdaa7dff);
    background_color      := unpack_srgba(0x191919ff);
    modeline_color_active := unpack_srgba(0x090909ff);
    keyword_color         := unpack_srgba(0xe95410ff);

    t: Theme;
    t.cursor_color               = cursor_color;
    t.cursor_color_active        = unpack_srgba(0xffffffff);
    t.cursor_color_readonly      = unpack_srgba(0xff0000ff);
    t.line_color                 = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.050);
    t.hover_color                = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.100);
    t.selection_color            = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.150);
    t.highlight_color            = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.200);
    t.highlight_color_active     = unpack_srgba(0xd09090c0);
    t.matching_parenthesis_color = unpack_srgba(0x70a0f0ff);
    t.modeline_color             = unpack_srgba(0x111111ff);
    t.modeline_color_active      = modeline_color_active;

    t.background_color           = background_color;
    t.gutter_color               = background_color;
    t.separator_color            = modeline_color_active;

    t.listing_item_color = text_color;

    t.system_text_color    = unpack_srgba(0xb0b0b0ff);
    t.text_color           = text_color;
    t.keyword_color        = keyword_color;
    t.attribute_color      = keyword_color;
    t.attribute_variant    = .BOLD;
    t.directive_color      = keyword_color;
    t.directive_variant    = .BOLD;
    t.string_literal_color = unpack_srgba(0x98c379ff);
    t.number_literal_color = unpack_srgba(0x759fbfff);
    t.comment_color        = unpack_srgba(0xa0a0a0ff);

    t.mini_panel_line_color      = set_alpha(adjust_saturation_and_value(cursor_color, 0.5, 1.2), 0.1);
    t.mini_panel_item_text_color = text_color;
    t.mini_panel_item_warning_text_color = unpack_srgba(0xe95410ff);

    return t;
}

naysayer_theme :: () -> Theme {
    cursor_color          := unpack_srgba(0x90ee90ff);
    text_color            := unpack_srgba(0xc4b58dff);
    background_color      := unpack_srgba(0x072626ff);

    t: Theme;
    t.cursor_color               = cursor_color;
    t.cursor_color_active        = unpack_srgba(0xffffffff);
    t.cursor_color_readonly      = unpack_srgba(0xff0000ff);
    t.line_color                 = { 0, 0, 0, 0 };
    t.hover_color                = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.100);
    t.selection_color            = unpack_srgba(0x0000ffff);
    t.highlight_color            = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.200);
    t.highlight_color_active     = unpack_srgba(0xd09090c0);
    t.matching_parenthesis_color = unpack_srgba(0x70a0f0ff);
    t.modeline_color             = unpack_srgba(0xc5c5c9ff);
    t.modeline_color_active      = text_color;

    t.background_color           = background_color;
    t.gutter_color               = background_color;
    t.separator_color            = unpack_srgba(0x000000ff);

    t.listing_item_color = text_color;

    t.system_text_color    = unpack_srgba(0x000000ff);
    t.text_color           = text_color;
    t.keyword_color        = unpack_srgba(0xffffffff);
    t.attribute_color      = unpack_srgba(0x9bdfa5ff); // Jon also uses this for known types, like s8, bool, int.
    t.directive_color      = unpack_srgba(0x9bdfa5ff); // Jon also uses this for known types, like s8, bool, int.
    t.string_literal_color = unpack_srgba(0x0fdfafff);
    t.number_literal_color = unpack_srgba(0x92e5cfff); // Jon also uses this for boolean literals
    t.comment_color        = unpack_srgba(0x3ddf23ff);

    t.mini_panel_line_color      = set_alpha(adjust_saturation_and_value(cursor_color, 0.5, 1.2), 0.1);
    t.mini_panel_item_text_color = text_color;
    t.mini_panel_item_warning_text_color = unpack_srgba(0xe95410ff);

    return t;
}

handmade_theme :: () -> Theme {
    cursor_color          := unpack_srgba(0x40ff40ff);
    text_color            := unpack_srgba(0xcdaa7dff);
    background_color      := unpack_srgba(0x191919ff);
    modeline_color_active := unpack_srgba(0x090909ff);

    t: Theme;
    t.cursor_color               = cursor_color;
    t.cursor_color_active        = unpack_srgba(0xffffffff);
    t.cursor_color_readonly      = unpack_srgba(0xff0000ff);
    t.line_color                 = { 0, 0, 0, 0 };
    t.hover_color                = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.100);
    t.selection_color            = unpack_srgba(0x0000ffff);
    t.highlight_color            = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.200);
    t.highlight_color_active     = unpack_srgba(0xd09090c0);
    t.matching_parenthesis_color = unpack_srgba(0x70a0f0ff);
    t.modeline_color             = unpack_srgba(0x111111ff);
    t.modeline_color_active      = modeline_color_active;

    t.background_color           = background_color;
    t.gutter_color               = background_color;
    t.separator_color            = modeline_color_active;

    t.listing_item_color = text_color;

    t.system_text_color    = unpack_srgba(0xb0b0b0ff);
    t.text_color           = text_color;
    t.keyword_color        = unpack_srgba(0xc38d03ff);
    t.attribute_color      = unpack_srgba(0xdab98fff);
    t.directive_color      = unpack_srgba(0xdab98fff);
    t.string_literal_color = unpack_srgba(0x6b8e23ff);
    t.number_literal_color = unpack_srgba(0x759fbfff);
    t.comment_color        = unpack_srgba(0xa0a0a0ff);

    t.mini_panel_line_color      = set_alpha(adjust_saturation_and_value(cursor_color, 0.5, 1.2), 0.1);
    t.mini_panel_item_text_color = text_color;
    t.mini_panel_item_warning_text_color = unpack_srgba(0xe95410ff);

    return t;
}

zenburn_theme :: () -> Theme {
    cursor_color          := unpack_srgba(0x8faf9fff);
    text_color            := unpack_srgba(0xdcdccdff);
    keyword_color         := unpack_srgba(0xf0dfafff);
    background_color      := unpack_srgba(0x3f3f3fff);

    t: Theme;
    t.cursor_color               = cursor_color;
    t.cursor_color_active        = unpack_srgba(0xffffffff);
    t.cursor_color_readonly      = unpack_srgba(0xcc9393ff);
    t.line_color                 = { 0, 0, 0, 0 };
    t.hover_color                = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.100);
    t.selection_color            = unpack_srgba(0x2b2b2bff);
    t.highlight_color            = set_alpha(adjust_saturation_and_value(cursor_color, 0.25, 1.2), 0.200);
    t.highlight_color_active     = unpack_srgba(0xd09090c0);
    t.matching_parenthesis_color = unpack_srgba(0x70a0f0ff);
    t.modeline_color             = unpack_srgba(0x2b2b2bff);
    t.modeline_color_active      = unpack_srgba(0x2b2b2bff); // Make a different color for active.

    t.background_color           = background_color;
    t.gutter_color               = background_color;
    t.separator_color            = unpack_srgba(0x000000ff);

    t.listing_item_color = text_color;

    t.system_text_color    = keyword_color;
    t.text_color           = text_color;
    t.keyword_color        = keyword_color;
    t.keyword_variant      = .BOLD;
    t.attribute_color      = text_color;
    t.attribute_variant    = .BOLD;
    t.directive_color      = unpack_srgba(0xf0dfafff);
    t.directive_variant    = .BOLD;
    t.string_literal_color = unpack_srgba(0xcc9393ff);
    t.number_literal_color = unpack_srgba(0x8cd0d3ff);
    t.comment_color        = unpack_srgba(0x859e82ff);

    t.mini_panel_line_color      = set_alpha(adjust_saturation_and_value(cursor_color, 0.5, 1.2), 0.1);
    t.mini_panel_item_text_color = text_color;
    t.mini_panel_item_warning_text_color = unpack_srgba(0xecb3b3ff);

    return t;
}

#scope_file

set_alpha :: (_rgba: Vector4, a: f32) -> Vector4 {
    rgba := _rgba;
    rgba.w = a;

    return rgba;
}
