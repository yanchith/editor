// This arena aims to be simple and minimal. It only does virtual memory reserve, and then
// commits/decommits on the go. You tweak the minimal amount of retained memory to prevent releasing
// all memory back to the OS only to allocate it again.
//
// The following may be added eventually, if they are actually needed:
//
// - Block chaining and releasing blocks. We'd only need this if we can't use virtual memory or decommit doesn't work for some reason.
// - User-given first block.
//

#module_parameters()(SANITY := true); // TODO(jt): Eventually default this to false, once we are confident.

ARENA_DEFAULT_RESERVE_SIZE: s64 : 256 << 20;
ARENA_DEFAULT_COMMIT_SIZE:  s64 :  64 << 10;
ARENA_DEFAULT_KEEP_SIZE:    s64 :  32 << 20;

arena_allocator :: (arena: *Arena) -> Allocator {
    return { arena_allocator_proc, arena };
}

// TODO(jt): Should we be caring about alignment? Our old Rust arena certainly does care, but maybe
// there is no underlying/hardware reason to care and it was all just LLVM crap?
arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .FREE; {
            // NOTE(jt): As of 0.2.026, Basic.free sets requested_size and old_size to zero. That is
            // completely valid, because general purpose allocators in C land don't get to know
            // old_size and have to deal. However, if we did know old-size, we could could actually
            // reclaim memory here with arena_maybe_modify_last_push. Datastructures like dynamic array or
            // hash table could fill in the size, if they wanted to.
            return null;
        }

        case .RESIZE; {
            arena := cast(*Arena, allocator_data);
            assert(arena != null);

            if arena_maybe_modify_last_push(arena, old_memory, old_size, requested_size) {
                return old_memory;
            }

            // arena_maybe_modify_last_push could have said no to a shrink operation, in which case
            // we don't want to allocate a new spot within the same arena.
            if requested_size <= old_size {
                return old_memory;
            }

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

        case .STARTUP; #through;
        case .SHUTDOWN; {
            return null;
        }

        case .THREAD_START; #through;
        case .THREAD_STOP; {
            assert(false, "Multithreaded access is not supported by arena_allocator_proc.\n");
            return null;
        }

        case .CREATE_HEAP; #through;
        case .DESTROY_HEAP; {
            assert(false, "Create/Destroy heap are not supported by arena_allocator_proc\n");
            return null;
        }

        case .IS_THIS_YOURS; {
            arena := cast(*Arena, allocator_data);
            result := arena_is_this_yours(arena, old_memory);

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
    // Things given by the caller before arena_init as arguments to arena_allocate. At least procs must be set, because they don't have a default. Don't change them after init.
    procs: Arena_Procs;
    reserve_size := ARENA_DEFAULT_RESERVE_SIZE; // How much memory we reserve, aligned to page size. Can't get more.
    commit_size  := ARENA_DEFAULT_COMMIT_SIZE;  // The minimal size that is committed, aligned to page size.
    keep_size    := ARENA_DEFAULT_KEEP_SIZE;    // The minimal size that is not decommitted once it has been committed, aligned to page size.

    // Internal stuff. Don't write to these yourself.

    memory_start: *void;
    memory_end:   *void;

    allocated: s64;
    committed: s64;
}

// Allocate a new arena in its own memory and return pointer to itself. This is useful, if you want
// to store the handle to the arena close to where it's being used instead of keeping it alive by
// storing it on the stack above the code that uses it, but you don't have to use it this way.
//
// This routine tweaks the arena's keep_size so that it never overwrites its own data.
arena_allocate :: (procs: Arena_Procs, reserve_size := ARENA_DEFAULT_RESERVE_SIZE, commit_size := ARENA_DEFAULT_COMMIT_SIZE, keep_size := ARENA_DEFAULT_KEEP_SIZE) -> *Arena {
    arena: Arena;
    arena.procs = procs;

    // Aligning happens in arena_init.
    arena.reserve_size = reserve_size;
    arena.commit_size  = commit_size;
    arena.keep_size    = max(size_of(Arena), keep_size);

    arena_init(*arena);

    pointer := arena_push(*arena, Arena);
    pointer.* = arena;

    return pointer;
}

arena_init :: (arena: *Arena) {
    assert(arena.procs.page_size > 0 && is_power_of_two(arena.procs.page_size));

    given_reserve := arena.reserve_size;
    given_commit  := arena.commit_size;
    given_keep    := arena.keep_size;

    arena.reserve_size = align(max(arena.reserve_size, 1), arena.procs.page_size);
    arena.commit_size  = align(max(arena.commit_size, 1), arena.procs.page_size);
    arena.keep_size    = align(max(arena.keep_size, 1), arena.procs.page_size);

    // Clamp commit and keep size so the caller can control all three sizes with just reserve size
    // in simple scenarios. Note that this won't help when the actual allocation pushes the commit
    // size above our reserved range.
    arena.commit_size = min(arena.commit_size, arena.reserve_size);
    arena.keep_size   = min(arena.keep_size, arena.reserve_size);

    if given_reserve != arena.reserve_size || given_commit != arena.commit_size || given_keep != arena.keep_size {
        log_error(
            "Arena sizes modified: RESERVE % -> %; COMMIT % -> %; KEEP % -> %;",
            given_reserve, arena.reserve_size,
            given_commit, arena.commit_size,
            given_keep, arena.keep_size,
        );
    }

    start := arena.procs.mem_reserve(arena.reserve_size);
    assert(is_aligned(start, arena.procs.page_size));
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

    // Store on the side, because if the arena was created with arena_allocate, we can't access
    // these after mem_release.
    memory_start := arena.memory_start;
    memory_end   := arena.memory_end;

    arena.memory_start = null;
    arena.memory_end   = null;

    arena.allocated = 0;
    arena.committed = 0;

    arena.procs.mem_release(memory_start, memory_end - memory_start);
}

arena_get_mark :: (arena: Arena) -> Arena_Mark {
    return { arena.allocated };
}

arena_is_this_yours :: (arena: Arena, pointer: *void) -> bool {
    return pointer >= arena.memory_start && pointer < arena.memory_start + arena.allocated;
}

arena_push :: (arena: *Arena, _size: s64, alignment: s64 = 16) -> *void {
    assert(_size > 0);
    assert(alignment > 0 && is_power_of_two(alignment));

    if !arena.memory_start {
        arena_init(arena);
    }

    pointer := align(arena.memory_start + arena.allocated, alignment);
    padding := cast(s64, pointer) - cast(s64, arena.memory_start + arena.allocated);

    size := padding + _size;

    arena.allocated += size;

    if arena.memory_start + arena.allocated > arena.memory_end {
        // Nothing we can do here. We return null so that the user notices the error sooner.
        log_error("Arena ran out of reserved space allocating % bytes", size);
        return null;
    }

    if arena.allocated > arena.committed {
        commit_base := arena.memory_start + arena.committed;
        commit_size := max(align(size, arena.procs.page_size), arena.commit_size);

        // We can get here, if we passed the reserve check above, but rounding up to commit size
        // would take us above the reserved space. We detect this to give a better error message.
        if commit_base + commit_size > arena.memory_end {
            log_error("Arena ran out of reserved space committing % bytes", commit_size);
            return null;
        }

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

arena_push :: (arena: *Arena, $T: Type) -> *T {
    pointer := arena_push(arena, size_of(T), align_of(T));
    if pointer == null {
        return null;
    }

    initializer :: initializer_of(T);
    #if initializer {
        initializer(pointer);
    } else {
        memset(pointer, 0, size_of(T));
    }

    return pointer;
}

arena_push_array :: (arena: *Arena, $T: Type, count: s64) -> [] T {
    assert(count > 0, "Can not push empty arrays");

    pointer := arena_push(arena, size_of(T) * count, align_of(T));
    if pointer == null {
        result: [] T;
        return result;
    }

    result: [] T;
    result.count = count;
    result.data = pointer;

    initializer :: initializer_of(T);
    #if initializer {
        for * result {
            initializer(it);
        }
    } else {
        memset(result.data, 0, size_of(T) * result.count);
    }

    return result;
}

arena_push_array :: (arena: *Arena, a: [] $T) -> [] T {
    assert(a.count > 0, "Can not push empty arrays");

    pointer := arena_push(arena, size_of(T) * a.count, align_of(T));
    if pointer == null {
        result: [] T;
        return result;
    }

    memcpy(pointer, a.data, size_of(T) * a.count);

    result: [] T;
    result.count = a.count;
    result.data = pointer;

    return result;
}

arena_push_string :: (arena: *Arena, s: string) -> string {
    assert(s.count > 0, "Can not push empty strings");

    pointer := arena_push(arena, s.count, 1);
    if pointer == null {
        result: string;
        return result;
    }

    memcpy(pointer, s.data, s.count);

    result: string;
    result.count = s.count;
    result.data = pointer;

    return result;
}

// Tries to modify the last allocation in the arena. Can only succeed if the allocation is the last
// allocation. (And even then it sometimes won't because of alignment of subsequent allocations, but
// it is guaranteed to succeed if you just made the last allocation right now). Speaking of
// alignment, you can't change it here.
arena_maybe_modify_last_push :: (arena: *Arena, pointer: *void, old_size: s64, new_size: s64, overwrite_memory := false) -> success: bool {
    if !arena.memory_start {
        arena_init(arena);
    }

    if pointer + old_size != arena.memory_start + arena.allocated {
        return false; // This is not the last allocation. (May be a false negative.)
    }

    if old_size < new_size {
        additional_size := new_size - old_size;
        result := arena_push(arena, additional_size, 1);
        return  result != null;
    } else if old_size > new_size {
        mark := arena.allocated - (old_size - new_size);
        arena_pop_to_mark(arena, { mark }, overwrite_memory);
        return true;
    } else {
        return true;
    }
}

arena_pop_to_mark :: (arena: *Arena, mark: Arena_Mark, overwrite_memory := false) {
    if !arena.memory_start {
        arena_init(arena);
    }

    sanity_assert(arena.allocated >= mark.allocated);
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
            sanity_assert(is_aligned(decommit_size, arena.procs.page_size));
            decommit_base := arena.memory_start + arena.committed - decommit_size;
            sanity_assert(is_aligned(decommit_base, arena.procs.page_size));

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

#scope_file

// TODO(jt): @Cleanup We could copy over the few things we use from basic and ditch the import.
Basic  :: #import "Basic";

assert    :: Basic.assert;
min       :: Basic.min;
max       :: Basic.max;
log_error :: Basic.log_error;

CAPS_VERSION_STRING :: "modules/Arena";

// TODO(jt): @Cleanup Provided by shwa (Joshua Manton) from the Secret Beta discord, but hopefully
// the language gives us a way of doing it without a run directive and we can remove?
align_of :: ($T: Type) -> s64 #expand {
    return #run -> s64 {
        info := type_info(struct { p: u8; t: T; });
        return info.members[1].offset_in_bytes;
    };
}

align :: inline (address: s64, alignment: s64) -> s64 {
    sanity_assert(alignment > 0 && is_power_of_two(alignment));
    mask := alignment - 1;
    return (address + mask) & ~mask;
}

align :: inline (pointer: *void, alignment: s64) -> *void {
    return cast(*void, align(cast(s64, pointer), alignment));
}

is_aligned :: inline (address: s64, alignment: s64) -> bool {
    sanity_assert(alignment > 0 && is_power_of_two(alignment));
    mask := alignment - 1;
    return address == address & ~mask;
}

is_aligned :: inline (pointer: *void, alignment: s64) -> bool {
    return is_aligned(cast(s64, pointer), alignment);
}

is_power_of_two :: inline (value: s64) -> bool {
    return value & (value - 1) == 0;
}

#if SANITY {
    sanity_assert :: (arg: bool, message := "", args: .. Any, loc := #caller_location) #no_debug #expand {
        assert(arg, message, args, loc);
    }
} else {
    sanity_assert :: (#discard arg: bool, #discard message := "", #discard args: .. Any, #discard loc := #caller_location) #expand {}
}
