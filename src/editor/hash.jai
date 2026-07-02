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
