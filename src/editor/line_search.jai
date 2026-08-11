// TODO(jt): Support regular expressions to be on par with external search tools.

line_search :: (line_to_search: string, parts: [] string, smartcase: bool) -> found: bool, found_indices: [..] s64 {
    ProfileZone("line_search");

    found_indices: [..] s64;

    if parts.count == 0 {
        array_add(*found_indices, 0);
        return true, found_indices; // No queries? We found them all!
    }

    start_index: s64 = 0;

    for part: parts {
        found_index: s64;
        if smartcase {
            found_index = find_index_from_left_nocase(line_to_search, part, start_index);
        } else {
            found_index = String.find_index_from_left(line_to_search, part, start_index);
        }

        if found_index == -1 {
            arr: [..] s64;
            return false, arr;
        }

        array_add(*found_indices, start_index + found_index);

        start_index = found_index + part.count;
    }

    return true, found_indices;
}

line_search_prepare_parts :: (line_query: string) -> parts: [] string, smartcase: bool {
    smartcase := true;

    parts := String.split(line_query, " ");
    for * part: parts {
        part.* = String.trim(part.*);
        if part.* == "" {
            remove part;
        }

        // TODO(jt): Do unicode based smartcase detection.
        for byte: part.* {
            if byte >= #char "A" && byte <= #char "Z" {
                smartcase = false;
                break;
            }
        }
    }

    return parts, smartcase;
}

// Rebuilds "part1 part2 part3 part4" into a regular expression that searches for part1, then part2, etc.
// The output can be fed into grep, git grep, ripgrep, etc. and emulate what we do in line_search.
line_search_prepare_regexp :: (line_query: string) -> string {
    parts := line_search_prepare_parts(line_query,, temp);

    result := String.join(..parts, ".+");
    return result;
}
