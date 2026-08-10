// Rebuilds "part1 part2 part3 part4" into a regular expression that searches for part1, then part2, etc.
// The output can be fed into grep, git grep, ripgrep, etc.
line_search_prepare_regexp :: (line_query: string) -> string {
    parts := String.split(line_query, " ",, temp);
    for * parts {
        it.* = String.trim(it.*);
        if it.* == "" {
            remove it;
        }
    }

    result := String.join(..parts, ".+");
    return result;
}
