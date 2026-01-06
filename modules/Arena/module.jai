#module_parameters () (DEBUG_ASSERT := true);

// TODO(jt): @Cleanup We could copy over the few things we use from these.
#import "Basic";          // For assert
#import "Bit_Operations"; // For popcount

// This arena aims to be simple and minimal. It only does virtual memory reserve, and then
// commits/decommits on the go. You tweak the minimal amount of retained memory to prevent releasing
// all memory back to the OS only to allocate it again.
//
// The following may be added eventually, if they are actually needed:
//
// - Block chaining and releasing blocks. We'd only need this if we can't use virtual memory or decommit doesn't work for some reason.
// - User-given first block.
//

ARENA_DEFAULT_RESERVE_SIZE: s64 : 256 << 20;
ARENA_DEFAULT_COMMIT_SIZE:  s64 :  64 << 10;
ARENA_DEFAULT_KEEP_SIZE:    s64 :  32 << 20;

// TODO(jt): Should we be caring about alignment? Our old Rust arena certainly does care, but maybe
// there is no underlying/hardware reason to care and it was all just LLVM crap?
arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        // TODO(jt): Try shrinking in-place with arena_maybe_modify_last_push.
        case .FREE;   return null;

        case .RESIZE; {
            // TODO(jt): Try growing/shrinking in-place with arena_maybe_modify_last_push
            if requested_size <= old_size {
                return old_memory;
            }

            arena := cast(*Arena, allocator_data);
            assert(arena != null);

            result := arena_push(arena, requested_size);
            if result && old_size {
                memcpy(result, old_memory, old_size);
            }

            return result;
        }

        case .ALLOCATE; {
            arena := cast(*Arena, allocator_data);
            assert(arena != null);

            result := arena_push(arena, requested_size);

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

        case .IS_THIS_YOURS; {
            arena := cast(*Arena, allocator_data);
            result := old_memory >= arena.memory_start && old_memory < arena.memory_start + arena.allocated;

            return cast(*void, cast(s64, result));
        }

        case .CAPS; {
            if old_memory {
                cast(*string, old_memory).* = CAPS_VERSION_STRING;
            }

            return cast(*void, Allocator_Caps.HINT_I_AM_A_FAST_BUMP_ALLOCATOR);
        }
    }
}

Arena_Mark :: struct {
    allocated: s64;
}

Arena_Procs :: struct {
    page_size: s64;

    mem_reserve:  (size: s64) -> *void;
    mem_release:  (pointer: *void, size: s64);
    mem_commit:   (pointer: *void, size: s64) -> bool;
    mem_decommit: (pointer: *void, size: s64);
}

Arena :: struct {
    // Things given by the caller. At least procs must be manually set.
    procs: Arena_Procs;
    reserve_size := ARENA_DEFAULT_RESERVE_SIZE; // How much memory we reserve, aligned to page size. Can't get more.
    commit_size  := ARENA_DEFAULT_COMMIT_SIZE;  // The minimal size that is committed, aligned to page size.
    keep_size    := ARENA_DEFAULT_KEEP_SIZE;    // The minimal size that is not decommitted once it has been committed, aligned to page size.

    memory_start: *void;
    memory_end:   *void;

    allocated: s64;
    committed: s64;
}

arena_init :: (arena: *Arena) {
    assert(popcount(arena.procs.page_size) == 1, "page_size must be a power of two, but is %", arena.procs.page_size);
    // TODO(jt): Should we assert some more things here?

    arena.reserve_size = align(max(1, arena.reserve_size), arena.procs.page_size);
    arena.commit_size  = align(max(1, arena.commit_size), arena.procs.page_size);
    arena.keep_size    = align(max(1, arena.keep_size), arena.procs.page_size);

    start := arena.procs.mem_reserve(arena.reserve_size);
    debug_assert(is_aligned(start, arena.procs.page_size));
    if !start {
        log_error("Arena failed to reserve % bytes", arena.reserve_size);
    }

    arena.memory_start = start;
    arena.memory_end   = arena.memory_start + arena.reserve_size;

    arena.allocated = 0;
    arena.committed = 0;
}

// Release all the memory back to the OS. You don't have to do it your program is going to end anyway.
arena_release :: (arena: *Arena) {
    if !arena.memory_start {
        return;
    }

    arena.procs.mem_release(arena.memory_start, arena.memory_end - arena.memory_start);

    arena.memory_start = null;
    arena.memory_end   = null;

    arena.allocated = 0;
    arena.committed = 0;
}

arena_get_mark :: (arena: Arena) -> Arena_Mark {
    return { arena.allocated };
}

arena_push :: (arena: *Arena, $T: Type) -> *T {
    result := arena_push(arena, size_of(T), align_of(T));

    initializer :: initializer_of(T);
    #if initializer {
        initializer(result);
    } else {
        memset(result, 0, size_of(T));
    }

    return result;
}

arena_push :: (arena: *Arena, size: s64, alignment: s64 = 16) -> *void {
    if !arena.memory_start {
        arena_init(arena);
    }

    pointer := align(arena.memory_start + arena.allocated, alignment);
    padding_size := cast(s64, pointer) - cast(s64, arena.memory_start + arena.allocated);

    arena.allocated += padding_size + size;

    if arena.memory_start + arena.allocated > arena.memory_end {
        // Nothing we can do here. We return null so that the user notices the error sooner.
        log_error("Arena ran out of reserved space allocating % bytes", size);
        return null;
    }

    if arena.allocated > arena.committed {
        commit_base := arena.memory_start + arena.committed;
        commit_size := max(align(size, arena.procs.page_size), arena.commit_size);

        result := arena.procs.mem_commit(commit_base, commit_size);
        if !result {
            // Nothing we can do here. We return null so that the user notices the error sooner.
            log_error("Arena failed to commit % bytes", commit_size);
            return null;
        }

        arena.committed += commit_size;
    }

    return pointer;
}

arena_pop_to_mark :: (arena: *Arena, mark: Arena_Mark, overwrite_memory := false) {
    debug_assert(arena.allocated >= mark.allocated);
    if overwrite_memory && arena.allocated > mark.allocated {
        STAMP :: 0xcc;
        overwrite_base := arena.memory_start + mark.allocated;
        overwrite_size := arena.allocated - mark.allocated;

        memset(overwrite_base, STAMP, overwrite_size);
    }

    arena.allocated = mark.allocated;

    if arena.committed > arena.keep_size {
        decommit_size := arena.committed - align(arena.allocated, arena.procs.page_size);
        if arena.committed - decommit_size < arena.keep_size {
            decommit_size = arena.committed - arena.keep_size;
        }

        if decommit_size {
            debug_assert(is_aligned(decommit_size, arena.procs.page_size));
            decommit_base := arena.memory_start + arena.committed - decommit_size;
            debug_assert(is_aligned(decommit_base, arena.procs.page_size));

            arena.procs.mem_decommit(decommit_base, decommit_size);

            arena.committed -= decommit_size;
        }
    }
}

arena_reset :: inline (arena: *Arena, overwrite_memory := false) {
    arena_pop_to_mark(arena, { 0 }, overwrite_memory);
}

ArenaAutoPop :: (arena: *Arena) #expand {
    __mark := arena_get_mark(arena);
    `defer arena_pop_to_mark(arena, __mark);
}

#scope_module

CAPS_VERSION_STRING :: "modules/Arena";

// TODO(jt): @Cleanup Provided by shwa from the Secret Beta discord, but hopefully the language
// gives us a way of doing it without a run directive and we can remove?
align_of :: ($T: Type) -> s64 #expand {
    return #run -> s64 {
        info := type_info(struct { p: u8; t: T; });
        return info.members[1].offset_in_bytes;
    };
}

align :: inline (address: s64, alignment: s64) -> s64 {
    debug_assert(popcount(alignment) == 1, "alignment must be a power of two");
    mask := alignment - 1;
    return (address + mask) & ~mask;
}

align :: inline (pointer: *void, alignment: s64) -> *void {
    return cast(*void, align(cast(s64, pointer), alignment));
}

is_aligned :: inline (address: s64, alignment: s64) -> bool {
    debug_assert(popcount(alignment) == 1, "alignment must be a power of two");
    mask := alignment - 1;
    return address == address & ~mask;
}

is_aligned :: inline (pointer: *void, alignment: s64) -> bool {
    return is_aligned(cast(s64, pointer), alignment);
}

#if DEBUG_ASSERT {
    debug_assert :: (arg: bool, message := "", args: .. Any, loc := #caller_location) #no_debug #expand {
        assert(arg, message, args, loc);
    }
} else {
    debug_assert :: (#discard arg: bool, #discard message := "", #discard args: .. Any, #discard loc := #caller_location) #expand {}
}
