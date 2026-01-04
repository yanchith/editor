// XXX: HERE Do this!

// TODO(jt): Should we be caring about alignment? Our old Rust arena certainly does care, but maybe
// there is no underlying/hardware reason to care about it and it was all just LLVM crap?
arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .FREE;   return null;
        case .RESIZE; #through;
        case .ALLOCATE; {
            arena := cast(*Arena, allocator_data);
            assert(arena != null);

            result := arena_push(arena, requested_size);

            // TODO(jt): Support in-place realloc if the allocation is the last allocation.
            // TODO(jt): Don't do anything, if this is RESIZE and requested_size < old_size.
            if mode == .RESIZE {
                size_to_copy := ifx old_size < requested_size then old_size else requested_size;
                if result && size_to_copy {
                    memcpy(result, old_memory, size_to_copy);
                }
            }

            return result;
        }

        case .STARTUP;      #through;
        case .SHUTDOWN;
        return null;

        case .THREAD_START; #through;
        case .THREAD_STOP;
        assert(false, "Multithreaded access is not supported by arena_allocator_proc.\n");
        return null;

        case .CREATE_HEAP;  #through;
        case .DESTROY_HEAP;
        assert(false, "Create/Destroy heap are not supported by arena_allocator_proc\n");
        return null;

        case .IS_THIS_YOURS;
        // TODO(jt): Support IS_THIS_YOURS. It should not be that hard.
        assert(false, "IS_THIS_YOURS is not supported by arena_allocator_proc yet\n");
        return null;

        case .CAPS; {
            if old_memory {
                cast(*string, old_memory).* = CAPS_VERSION_STRING;
            }

            return cast(*void, Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR);
        }
    }
}

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
    current_block: *Arena_Block_Header;

    procs: Arena_Procs;
    reserve_size: s64;
    commit_size: s64;
    flags: Arena_Flags;
}

arena_init :: (arena: *Arena, procs: Arena_Procs, first_block: [] u8) {

}

arena_get_mark :: (arena: Arena) -> s64 {

}

arena_push :: (arena: *Arena, size: s64, align: s64 = 16) -> *void {

}

arena_pop_to_mark :: (arena: *Arena, mark: s64, overwrite_memory := false) {

}

arena_reset :: inline (arena: *Arena, overwrite_memory := false) {
    arena_pop_to_mark(arena, 0, overwrite_memory);
}

// TODO(jt): Like auto_release_temp
ArenaAutoPop :: (arena: *Arena) #expand {

}

#scope_module

CAPS_VERSION_STRING :: "modules/Arena";

Arena_Block_Header :: struct {
    start: *void;
    end:   *void;

    allocated: *void;
    committed: *void;

    size_before_this_block: s64;
    previous_block: *Block_Header;
}

assert :: (condition: bool, message: string) {
    // TODO(jt): Make a lightweight assert, so that we don't have to import Basic.
}
