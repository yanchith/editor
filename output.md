# Speeding up text_buffer_get_gap_buffer_index_for_line / _for_location

Analysis and plan, written by the clanker. 2026-08-19.

## What the functions do today

Both functions convert the editor's logical coordinates into content-space gap buffer indices
(0..gb.count, gap excluded; independent of where the gap currently sits — important later, because
it means moving the gap never invalidates anything we might cache).

`text_buffer_get_gap_buffer_index_for_line(buffer, line_index)` (text_buffer.jai:1713)

- Computes `sum(line_bytes[0 .. line_index-1])` from scratch, every call.
- **O(line_index)** adds. On a 1GB prose file (~10-20M lines), a single call near the end of the
  buffer is tens of millions of adds — single-digit milliseconds, per call.

`text_buffer_get_gap_buffer_index_for_location(buffer, loc)` (text_buffer.jai:1740)

- The same prefix sum over lines (duplicated code, not a call to the _for_line version), **plus**
- an O(loc.x) walk that decodes character widths one at a time. Every step reads `buffer.gb[index]`
  through `operator *[]`, which per byte runs `assert_valid` (a compare), a bounds assert, and a
  gap-position branch. So the x-part is O(x) with a fat constant.
- **O(loc.y + loc.x)** total.

The code's own comments already measure the pain:

- text_buffer.jai:1694: *"For 1GB files ... this takes too long, especially if called tens or
  hundreds of times per frame."*
- text_buffer.jai:1557: *"Searching through 45 lines towards the end of a 1GB file takes about 350
  milliseconds. Most of that time is spent in text_buffer_make_view_for_line."* — that's 45 calls,
  each redoing the full prefix sum.
- Four call sites already hand-roll the incremental workaround (`:IncrementalGapBufferIndices`):
  mini_panel_search.jai:101, modal_interaction_search_and_replace.jai:245, parentheses.jai:52,
  run_compilation (editor.jai:4931), plus strip_trailing_whitespace threading `__line_gb_index`
  into text_buffer_trim_line by hand. When call sites keep reimplementing the same workaround, the
  primitive is what needs fixing.

## Who calls them per frame

Direct calls are mostly inside text_buffer.jai; the per-frame traffic comes through the wrappers
`text_buffer_make_view_for_line`, `text_buffer_make_view_for_interval`,
`text_buffer_get_byte_count_for_interval`, `text_buffer_get_byte_at_location` (~50 call sites).

Every rendered frame, per document panel:

| Site | Calls | Cost each |
|---|---|---|
| draw_panel: viewport text view (editor.jai:4107) | 1 interval = 2 × _for_location | O(viewport_line) |
| draw_panel: highlights loop (editor.jai:3914) | 1 × _for_line **per visible highlight** | O(highlight line) |
| draw_panel: multi-line selection (editor.jai:3976..4027) | ~1 per visible selected line | O(line) |
| draw_panel: matching paren (editor.jai:4069 → get_position_for_location) | 1 | O(cursor line) |
| update_panel: get_position_at_cursor + get_line_length_at_cursor (editor.jai:3664, 3690) | 2–4 | O(cursor line) |
| update_and_render: old-cursor refresh (editor.jai:1034) | 0–1 | O(cursor line) |

So a frame showing the end of a large file does `(≈4 + visible_highlights + selected_lines)` full
prefix sums, each O(N). With SEARCH open (a highlight per match) this multiplies. That is the
"called too many times per frame, and each call is slow" combination.

Editing paths hit them too: every insert/delete does 1–2 `_for_location` calls, and the loop-style
operations (TOGGLE_COMMENT, INDENT_OR_AUTOCOMPLETE over a selection, SWAP_LINE_*) do it per line —
quadratic in selection size.

## Root causes

1. **Recomputation from line zero.** The line prefix sum is recomputed from scratch although
   consecutive queries are heavily correlated (viewport scans are sequential; cursor ops are
   local).
2. **The O(x) character walk** happens even for pure-ASCII lines, where the answer is just
   `line_start + x`. We already store enough data to detect that case for free:
   `line_bytes[y] == line_chars[y]`.
3. **No incremental API**, so loops either go quadratic or hand-roll gap-index arithmetic.

Existing @Speed TODOs propose SIMD and packing line_bytes to u32. Those attack the constant, not
the asymptotics — a 10M-line query is still ~1M adds with 8-wide SIMD. Do them later, if ever; the
fixes below make them mostly irrelevant.

## Plan

Four fixes, ordered by value/effort. Fix 1 and Fix 2 are the substance; they make both functions
effectively O(1) for real access patterns without changing any semantics.

### Fix 1: O(1) fast path for the character walk (tiny, do first)

In `_for_location`, after resolving the line start: if `line_bytes[y] == line_chars[y]`, every
character on the line is exactly one byte (this excludes multi-byte UTF-8 *and* CRLF, which counts
2 bytes / 1 char; binary mode always satisfies it since chars are bytes there). Then:

```jai
    index := <line start>;

    // Fast path: every char on this line is a single byte (no multi-byte UTF-8, no CRLF),
    // so the byte offset within the line equals the character index.
    if buffer.line_bytes[line_index] == buffer.line_chars[line_index] {
        return index + loc.x;
    }

    // ... existing per-character walk as the fallback ...
```

Nearly every line of real code/prose is pure ASCII, so this turns the x-part into O(1) almost
always. `loc.x == line_chars[y]` (write position at end of line) also works: it yields exactly the
next line's start.

Note on bare `\r` (the `:CarriageReturn` TODO at text_buffer.jai:1770): the index-building code
(update_index_for_insert) counts a bare `\r` as 1 byte / 1 char, while the walk in `_for_location`
treats any `\r` it sees as 2 bytes. Those two already disagree today — the fast path is actually
*consistent with the line index*, the walk isn't. No new breakage, but worth keeping in mind when
bare-\r support happens.

Optional follow-up for the (now rare) slow path: walk a contiguous view of the line instead of
per-byte `gb[i]` (the gap splits at most one line; walk the two halves), removing the per-byte
branch + asserts. Only bother if mixed-content lines ever show up in profiles.

### Fix 2: chunked line-start index with a dirty watermark (the main fix)

Cache prefix sums at chunk granularity so a query never rescans the whole file:

```jai
LINE_START_CHUNK :: 256; // Tunable; anything 64..1024 is fine.

Line_Start_Cache :: struct {
    // chunk_starts[c] == gap buffer index of the first byte of line c * LINE_START_CHUNK.
    // Invariants: chunk_starts.count >= first_stale_chunk >= 1, chunk_starts[0] == 0.
    // Entries at first_stale_chunk and beyond are garbage; rebuilt lazily on query.
    chunk_starts: [..] s64;
    first_stale_chunk: s64;
}
```

Query becomes: ensure chunks are valid up to `line/CHUNK` (lazy rebuild from the watermark), then
`chunk_starts[c] + sum(line_bytes[c*CHUNK .. line-1])` — **at most CHUNK adds**, i.e. O(256)
worst case, regardless of file size or access pattern:

```jai
text_buffer_get_gap_buffer_index_for_line :: (buffer: Text_Buffer, line_index: s64) -> s64 {
    assert_line_valid(buffer, line_index);

    if line_index >= buffer.line_bytes.count {
        return buffer.gb.count;
    }

    cache := buffer.line_start_cache;
    chunk := line_index / LINE_START_CHUNK;
    ensure_chunk_starts_valid(cache, buffer.line_bytes, chunk);

    index := cache.chunk_starts[chunk];
    for chunk * LINE_START_CHUNK..line_index - 1 {
        index += buffer.line_bytes[it];
    }

    return index;
}

ensure_chunk_starts_valid :: (cache: *Line_Start_Cache, line_bytes: [] s64, chunk: s64) {
    if chunk < cache.first_stale_chunk {
        return;
    }

    while cache.chunk_starts.count <= chunk {
        array_add(*cache.chunk_starts);
    }

    line  := (cache.first_stale_chunk - 1) * LINE_START_CHUNK;
    index := cache.chunk_starts[cache.first_stale_chunk - 1];

    for c: cache.first_stale_chunk..chunk {
        for line..c * LINE_START_CHUNK - 1 {
            index += line_bytes[it];
        }
        line = c * LINE_START_CHUNK;

        cache.chunk_starts[c] = index;
    }

    cache.first_stale_chunk = chunk + 1;
}
```

`_for_location` should call `_for_line` for its line part instead of duplicating the loop (dedup;
one cache path), then apply Fix 1 for the x part.

Invalidation is one rule: whenever `line_bytes[y]` changes, or a line is inserted/removed at index
y, chunks *after* the one containing y become stale (the containing chunk's own start only depends
on lines before it, so it survives):

```jai
mark_lines_dirty :: (buffer: *Text_Buffer, first_dirty_line: s64) {
    first_stale := first_dirty_line / LINE_START_CHUNK + 1;
    buffer.line_start_cache.first_stale_chunk = min(buffer.line_start_cache.first_stale_chunk, first_stale);
}
```

Amortization: a mutation only pays `min()`. The rebuild cost is paid once, on the first query past
the watermark, and is proportional to the distance — for the overwhelmingly common case (edit at
the cursor, then render the viewport around the cursor) that distance is a few chunks. Even the
pathological case (edit line 0 of a 10M-line file, then render a second panel at line 9M) is one
~9M-add rebuild per *edit*, not per *call* — and idle frames (scrolling, cursor blinking, mouse
motion) rebuild nothing at all.

**Complete list of invalidation points.** Everything that touches line structure funnels through a
small set of places in text_buffer.jai:

| Site | first_dirty_line |
|---|---|
| `add_line` (append) | nothing to do — appending can't affect existing chunk starts, but the chunk array count check in ensure handles growth; call `mark_lines_dirty(buffer, buffer.line_count)` for uniformity |
| `insert_line(index)` | `index` |
| `remove_line(index)` | `index` |
| `text_buffer_delete_forward` inline loop (lines ~406-432) | `cursors.c0.y` |
| `text_buffer_delete_backward` (~503-507, ~551-552) | `max(cursors.c0.y - 1, 0)` |
| `text_buffer_indent_line` (~809-810, ~859-860) | `cursors.c0.y` |
| `update_index_for_insert` (both binary and text loops) | starting `cursors.c0.y` |
| `update_index_for_delete_forward` | `cursors.c0.y` |
| `update_index_for_delete_backward` | `max(cursors.c0.y - 1, 0)` |
| `text_buffer_switch_to_binary_mode` | 0 |
| `text_buffer_reset` | 0 (plus `array_reset` of chunk_starts, see below) |

Since `insert_line`/`remove_line` themselves clamp, several of the rows above are redundant belt
and suspenders — `min()` makes redundancy free, and I'd rather be caught wearing both.

Things that do **not** invalidate: `gap_buffer_move_gap_to` (content-space indices don't see the
gap), cursor movement, undo/redo (they go through the update_index_* helpers), highlights, syntax
tokens.

**Where the cache lives.** The read API takes `buffer: Text_Buffer` by value (Maybe By Reference),
so the getters can't write an inline field. Two options:

- **(a) Interior pointer (recommended):** `line_start_cache: *Line_Start_Cache;` on Text_Buffer.
  Mutating the pointee from a by-value parameter is well-defined (the parameter's own bytes are
  untouched), copies of the struct share the same cache, and none of the ~50 read call sites
  change. Allocate the struct in `text_buffer_init` from `buffer.arena` **before**
  `arena_get_mark` is taken, so `text_buffer_reset`'s `arena_pop_to_mark` doesn't free it; give
  `chunk_starts` the arena allocator and `array_reset` it in `text_buffer_reset` before the pop
  (same discipline as line_bytes/line_chars/edits today). Document the single-thread assumption
  next to the field — if buffers are ever read from multiple threads, this memoization needs
  rethinking.
- **(b) Change the read API to `*Text_Buffer`:** more honest about mutation, but it erases the
  deliberate read-by-value / write-by-pointer split across the whole text_buffer API and churns
  every caller. I wouldn't.

### Fix 3: a real incremental line iterator (formalize :IncrementalGapBufferIndices)

Four call sites hand-roll `gb_index += line_bytes[it]` loops today (search, search&replace,
parentheses, compilation-error scan), and strip_trailing_whitespace threads `__line_gb_index`
manually. Give them a for_expansion:

```jai
// for :text_buffer_lines line, line_index: buffer { ... }
// `it` is the line view (may allocate with context.allocator if the line crosses the gap),
// also exports `gb_index` (line start) and `line_byte_count` into the body's scope.
text_buffer_lines :: (buffer: *Text_Buffer, body: Code, flags: For_Flags) #expand {
    #assert !(flags & .REVERSE) "text_buffer_lines does not support reverse iteration (yet)";
    #assert !(flags & .POINTER) "text_buffer_lines does not support pointer iteration";

    `gb_index := 0;
    for line_index: 0..buffer.line_count - 1 {
        `line_byte_count := buffer.line_bytes[line_index];
        defer gb_index += line_byte_count;

        `it_index := line_index;
        `it := cast(string, gap_buffer_make_view(buffer.gb, gb_index, line_byte_count));

        #insert (remove=#assert(false, "'remove' is not supported")) body;
    }
}
```

An optional `first_line` parameter (or a variant iterator) seeded via the Fix 2 cache covers the
viewport-only loops in draw_panel. Migrating the hand-rolled sites is mechanical and deletes the
trickiest copy-pasted arithmetic in the codebase; `text_buffer_trim_line`'s `__line_gb_index`
trusted parameter can then be dropped, since with Fix 2 the internal lookup is cheap.

This also directly resolves the blank-line-search TODO (text_buffer.jai:1557): with Fix 2 alone,
each `text_buffer_make_view_for_line` in that loop drops from O(N) to O(CHUNK); with the iterator
(walking from the cursor's line) it's strictly linear in lines visited.

### Fix 4: call-site hygiene (only if profiles still complain)

With Fixes 1–3 in, these are probably noise, but for the record:

- `update_panel` computes `get_position_at_cursor` + `get_line_length_at_cursor`, then possibly
  both again after clamping (editor.jai:3664, 3690) — each remakes the line view. The fusion TODO
  at editor.jai:5044 covers this.
- `draw_panel`'s highlight loop could reuse one line view per y when multiple highlights share a
  line (SEARCH produces at most one per line today, so not urgent).
- `update_index_for_insert(value, count)` allocates and memsets a temp string just to reuse the
  generic path (text_buffer.jai:1975) — the @Hack comment already knows.

## Rejected alternatives

- **Store absolute line starts instead of lengths.** O(1) queries, but every edit shifts all
  subsequent starts: O(N) per keystroke. (Related observation: `insert_line`/`remove_line` already
  pay an O(N) `array_insert_at`/`ordered_remove` memmove per newline-count-changing edit — on a
  10M-line file that's an ~80MB memmove per Enter press. Not this task, but it's the next
  structural limit after these fixes, and a chunked/gap line index would address both.)
- **Fenwick tree over line_bytes.** O(log N) query/update, but no line insert/remove support —
  you'd need an order-statistic tree, which is a lot of pointer-chasing machinery for worse
  practical constants than the chunk cache. Revisit only if the watermark rebuild ever shows up in
  profiles.
- **SIMD / packing line_bytes to u32** (existing TODOs). Attacks the constant only; keep as a
  possible cherry on top for the ≤CHUNK tail sum and the rebuild loop, where it composes nicely.
- **Threading.** Not for a memoized prefix sum.

## Expected impact

| Scenario | Today | After Fix 1+2 |
|---|---|---|
| Keystroke at end of 10M-line file (index part) | O(10M) adds ≈ ms | O(CHUNK) ≈ ~100ns |
| Frame at end of large file, SEARCH open with H visible matches | (4+H) × O(10M) | (4+H) × O(CHUNK), plus one amortized rebuild after an edit |
| M-p blank-line search near end of 1GB (measured 350ms) | 45 × O(N) | 45 × O(CHUNK) ≈ µs |
| TOGGLE_COMMENT / indent over an L-line selection | O(L·N) | O(L·CHUNK) |
| Memory | — | 8 bytes per 256 lines (~320KB per 10M lines) |

## Validation plan

- **SANITY parity:** extend `assert_valid_buffer`'s SANITY block to recompute all chunk starts
  from line_bytes and compare against every valid cache entry (< first_stale_chunk). Since the
  functions' outputs are unchanged by design, the only new failure mode is a missed invalidation,
  and this check catches exactly that. Exercise insert/delete/undo/redo/binary-switch/reset in a
  SANITY build (typing, benchgen-generated documents, search&replace).
- **Profiler:** both functions already have ProfileZones, and slow frames dump hits + inclusive
  millis. Compare before/after on: large benchgen document, cursor at end, (a) hold a key down,
  (b) SEARCH with a common query, (c) M-p/M-n, (d) two panels split on the same document at
  opposite ends.
- **Behavioral spot-check:** cursor rendering, selections spanning the gap, CRLF files,
  binary-mode files, and mixed UTF-8 lines (Fix 1's slow path).

## Implementation order

1. Fix 1 (fast path) — a handful of lines, independently shippable, immediately kills the O(x)
   term.
2. Fix 2 (cache + invalidation + SANITY parity) — the core. Route `_for_location` through
   `_for_line` while in there.
3. Fix 3 (iterator) — migrate the four hand-rolled sites + strip_trailing_whitespace; delete
   `__line_gb_index`.
4. Re-profile; only then consider Fix 4 / SIMD / u32 packing.

Drive-by observation, unrelated to performance: in both functions the
`if line_index >= buffer.line_bytes.count` branch is unreachable while `assert_line_valid`
(`line_index < line_count`) is live — one of the two should probably go.

Out of scope but noted while reading: `update_parenthesized_scopes` rescans the whole document on
every edit (parentheses.jai:3 says 8 seconds for a large indent), and `lang_jai_update_syntax_highlights`
copies + relexes the entire buffer per modified frame. After the index fixes land, those become the
frame-time ceiling for big files.
