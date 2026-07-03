// TODO(jt): @Speed FNV-1a is very slow for large inputs, because it only has one stream and
// operates on bytes. Change this to a faster (but still portable!) hash here, like xxHash64.

hash_file_contents :: (bytes: [] u8) -> u64 {
    ProfileZone("hash_file_contents");
    return fnv1a_hash(bytes);
}

hash_text_buffer_contents :: (buffer: Text_Buffer) -> u64 {
    ProfileZone("hash_text_buffer_contents");

    bytes_before_gap := gap_buffer_get_bytes_before_gap(buffer.gb);
    bytes_after_gap  := gap_buffer_get_bytes_after_gap(buffer.gb);

    hash := fnv1a_hash(bytes_before_gap);
    hash = fnv1a_hash(bytes_after_gap, seed = hash);

    return hash;
}

//
// The FNV-1a hash.
//
// Pretty simple, but not very fast, as it is very serial and operates on single bytes. Good for
// small strings/arrays, as there isn't a setup/finalization step.
//
// http://www.isthe.com/chongo/tech/comp/fnv/index.html
//

FNV1A_SEED: u64 : 0xcbf29ce484222325;

fnv1a_hash :: (bytes: [] u8, seed := FNV1A_SEED) -> u64 {
    PRIME: u64 : 0x100000001b3;
    h := seed;

    for bytes #no_aoc {
        h ^= it;
        h *= PRIME;
    }

    return h;
}

//
// For more complicated hash functions, we will also want a more involved "streaming" API:
//
// My_Hash_State state;
// my_hash_init(*state, seed);
// my_hash_update(*state, bytes1);
// my_hash_update(*state, bytes2);
// my_hash_update(*state, bytes3);
// hash := my_hash_finalize(*state);
//
// We can also retrofit this API for FNV-1a once we do that, but for now that seems overkill, as
// FNV-1a can be easily chained manually and requires almost no setup, and no finalization.
//
