// XXX: HERE Do this!

Arena_Procs :: struct {
    page_size: s64;

    mem_reserve:  (size: s64) -> *void;
    mem_release:  (pointer: *void, size: s64);
    mem_commit:   (pointer: *void, size: s64);
    mem_decommit: (pointer: *void, size: s64);
}

Arena_Flags :: enum_flags u32 {
    NONE :: 0;

    CAN_CHAIN              :: 0x01;
    CAN_RELEASE_FIST_BLOCK :: 0x02;
}

Arena :: struct {
    current: *Arena_Block_Header;

    procs: Arena_Procs;
    reserve_size: s64;
    commit_size: s64;
    flags: Arena_Flags;
}

arena_init :: (arena: *Arena, procs: Arena_Procs, first_block: [..] u8) {

}

arena_push :: (arena: *Arena, value: $T) -> *T {

}

arena_push :: (arena: *Arena, size: s64, align: s64 = 16) -> *void {

}

arena_pop_to :: (arena: *Arena, to_size: s64) {

}

arena_reset :: inline (arena: *Arena) {
    arena_pop_to(arena, 0);
}

// TODO(jt): Like auto_release_temp
ArenaAutoPop :: (arena: *Arena) #expand {

}

#scope_file

Block_Header :: struct {
    size_before_this_block: s64;

    base:  *void;
    start: *void;
    end:   *void;

}
