// TODO(jt): Support regular expressions to be on par with external search tools.
// TODO(jt): Support equivalent of ripgrep's --smart-case to match behavior with directory search.

line_search :: (line_to_search: string, parts: [] string) -> found: bool, found_indices: [..] s64 {
    ProfileZone("line_search");

    found_indices: [..] s64;

    if parts.count == 0 {
        array_add(*found_indices, 0);
        return true, found_indices; // No queries? We found them all!
    }

    for parts {
        found_index := find_index_from_left_nocase(line_to_search, it);
        if found_index == -1 {
            arr: [..] s64;
            return false, arr;
        }

        array_add(*found_indices, found_index);
        advance(*line_to_search, found_index);
    }

    return true, found_indices;
}

line_search_prepare_parts :: (line_query: string) -> [] string {
    parts := String.split(line_query, " ");
    for * parts {
        it.* = String.trim(it.*);
        if it.* == "" {
            remove it;
        }
    }

    return parts;
}

// Rebuilds "part1 part2 part3 part4" into a regular expression that searches for part1, then part2, etc.
// The output can be fed into grep, git grep, ripgrep, etc. and emulate what we do in line_search.
line_search_prepare_regexp :: (line_query: string) -> string {
    parts := line_search_prepare_parts(line_query,, temp);

    result := String.join(..parts, ".+");
    return result;
}
