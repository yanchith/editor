//
// This arena aims to be simple and minimal. It only does virtual memory reserve, and then
// commits/decommits on the go. You tweak the minimal amount of retained memory to prevent releasing
// all memory back to the OS only to allocate it again.
//
// If we ever need a block-chaining arena (for some platforms? to be careful about memory reservation?),
// we'll do it as a different module with very similar API.
//

#module_parameters(
    ENABLE_DEBUG             := false,
    ENABLE_ASSERTS           := true,
    ENABLE_SANITY_ASSERTS    := false, // Implies ENABLE_ASSERTS
    DEFAULT_ALIGNMENT        := 16,
    DEFAULT_OVERWRITE_MEMORY := false,
    THIS_ALLOCATION_IS_NOT_A_LEAK: (memory: *void) = (memory: *void) #expand { /*No-op*/ }
);

ARENA_DEFAULT_RESERVE_SIZE: s64 : 256 << 20;
ARENA_DEFAULT_COMMIT_SIZE:  s64 :  64 << 10;
ARENA_DEFAULT_RETAIN_SIZE:  s64 :  64 << 10;

arena_allocator :: (arena: *Arena) -> Allocator {
    return { arena_allocator_proc, arena };
}

// The allocator_proc doesn't care about alignment (as of 0.2.0.030, 2 July 2026), but once it
// does, we are ready for it. For now, arena_push defaults alignment to DEFAULT_ALIGNMENT, if it is
// not specified.
arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if #complete mode == {
        case .FREE; {
            // As of beta 0.2.026, Basic.free sets requested_size and old_size to zero. That is
            // completely valid, because general purpose allocators in C land don't get to know
            // old_size and have to deal. However, if we did know old-size, we could could actually
            // reclaim memory here with arena_modify_last_push. Datastructures like dynamic
            // array or hash table could fill in the size, if they wanted to.
            return null;
        }

        case .RESIZE; {
            arena := cast(*Arena, allocator_data);
            assert(arena != null);

            if arena_modify_last_push(arena, old_memory, old_size, requested_size) {
                return old_memory;
            }

            // arena_modify_last_push could have said no to a shrink operation, in which case
            // we don't want to allocate a new spot within the same arena.
            if requested_size <= old_size {
                return old_memory;
            }

            result := arena_push(arena, requested_size);
            // nocheckin _check_alloc hasn't registered the allocation yet, so this crashes. Do our modified thing?
            // THIS_ALLOCATION_IS_NOT_A_LEAK(result);

            if result && old_size {
                memcpy(result, old_memory, old_size);
            }

            return result;
        }

        case .ALLOCATE; {
            arena := cast(*Arena, allocator_data);
            assert(arena != null);

            result := arena_push(arena, requested_size);
            // nocheckin _check_alloc hasn't registered the allocation yet, so this crashes. Do our modified thing?
            // THIS_ALLOCATION_IS_NOT_A_LEAK(result);

            return result;
        }

        case .STARTUP; #through;
        case .SHUTDOWN; {
            return null;
        }

        case .THREAD_START; #through;
        case .THREAD_STOP; {
            assert(false, "Multithreaded access is not supported by arena_allocator_proc.");
            return null;
        }

        case .CREATE_HEAP; #through;
        case .DESTROY_HEAP; {
            assert(false, "Create/Destroy heap are not supported by arena_allocator_proc.");
            return null;
        }

        case .IS_THIS_YOURS; {
            arena := cast(*Arena, allocator_data);
            result := arena_contains(arena, old_memory);

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

Arena_Debug_Procs :: struct {
    on_init:   (arena: *Arena, userdata: *void);
    on_deinit: (arena: *Arena, userdata: *void);

    userdata: *void;
}

Arena :: struct {
    //
    // Arguments given by caller before initialization (arena_init, arena_allocate). At least procs
    // must be set, because they don't have a default. Don't change after init.
    //
    procs: Arena_Procs;
    reserve_size := ARENA_DEFAULT_RESERVE_SIZE;  // How much memory we reserve, aligned to page size. Can't get more.
    commit_size  := ARENA_DEFAULT_COMMIT_SIZE;   // The minimal size that is (de)committed, aligned to page size.
    retain_size  := ARENA_DEFAULT_RETAIN_SIZE;   // The minimal size that is not decommitted once it has been committed, aligned to page size.

    //
    // Internal stuff. Consider read-only.
    //

    memory_start: *void;
    memory_end:   *void;

    allocated: s64;
    committed: s64;

    low_water_mark: s64; // Anything below won't be deallocated. Currently only used to prevent overwriting the arena's own data when resetting/popping.

    #if ENABLE_DEBUG {
        debug_procs: Arena_Debug_Procs;
        debug_label: string;
    }
}

// Allocate a new arena in its own memory and return pointer to itself. This is useful, if you want
// to store the handle to the arena close to where it's being used instead of keeping it alive by
// storing it on the stack above the code that uses it.
arena_new :: (procs: Arena_Procs, reserve_size := ARENA_DEFAULT_RESERVE_SIZE, commit_size := ARENA_DEFAULT_COMMIT_SIZE, retain_size := ARENA_DEFAULT_RETAIN_SIZE, debug_procs: Arena_Debug_Procs = {}, debug_label := "") -> *Arena {
    arena: Arena;
    arena.procs = procs;

    // Aligning happens in arena_init.
    arena.reserve_size = reserve_size;
    arena.commit_size  = commit_size;
    arena.retain_size  = max(size_of(Arena), retain_size);

    arena_init(*arena);

    pointer := arena_push(*arena, Arena);
    pointer.* = arena;

    // So that we don't accidentally deallocate ourselves.
    pointer.low_water_mark = pointer.allocated;

    #if ENABLE_DEBUG {
        // Set debug procs only after init finishes, so that arena_init doesn't fire on_init with the temporary address.
        pointer.debug_procs = debug_procs;
        if debug_procs.on_init {
            debug_procs.on_init(pointer, debug_procs.userdata);
        }
        pointer.debug_label = debug_label;
    }

    return pointer;
}

arena_init :: (arena: *Arena) {
    assert(arena.procs.page_size > 0 && is_power_of_two(arena.procs.page_size));

    given_reserve := arena.reserve_size;
    given_commit  := arena.commit_size;
    given_retain  := arena.retain_size;

    arena.reserve_size = align(max(arena.reserve_size, 1), arena.procs.page_size);
    arena.commit_size  = align(max(arena.commit_size, 1), arena.procs.page_size);
    arena.retain_size  = align(max(arena.retain_size, 1), arena.procs.page_size);

    // Clamp commit and retain size so the caller can control all sizes with just reserve size in
    // simple scenarios. Note that this won't help when the actual allocation pushes the commit size
    // above our reserved range.
    arena.commit_size = min(arena.commit_size, arena.reserve_size);
    arena.retain_size = min(arena.retain_size, arena.reserve_size);

    start := arena.procs.mem_reserve(arena.reserve_size);
    assert(cast(bool, start), "Arena failed to reserve bytes");
    assert(is_aligned(start, arena.procs.page_size));

    arena.memory_start = start;
    arena.memory_end   = arena.memory_start + arena.reserve_size;

    arena.allocated = 0;
    arena.committed = 0;

    arena.low_water_mark = 0;

    #if ENABLE_DEBUG {
        if arena.debug_procs.on_init {
            arena.debug_procs.on_init(arena, arena.debug_procs.userdata);
        }
    }
}

// Release all the memory back to the OS. You don't have to do it, if your program is going to end
// anyway. If the arena was created with arena_allocate, don't use the pointer after.
arena_deinit :: (arena: *Arena) {
    if !arena.memory_start {
        return;
    }

    #if ENABLE_DEBUG {
        if arena.debug_procs.on_deinit {
            arena.debug_procs.on_deinit(arena, arena.debug_procs.userdata);
        }
    }

    // Arena may or may not have been created with arena_allocate. In case it wasn't and it is still
    // accessible after, we clear it to zero and it can be initialized again with arena_init.

    memory_start := arena.memory_start;
    memory_end   := arena.memory_end;

    arena.memory_start = null;
    arena.memory_end   = null;

    arena.allocated = 0;
    arena.committed = 0;

    arena.low_water_mark = 0;

    arena.procs.mem_release(memory_start, memory_end - memory_start);
}

arena_contains :: (arena: Arena, pointer: *void) -> bool {
    return pointer >= arena.memory_start && pointer < arena.memory_start + arena.allocated;
}

// :ArenaPushEmpty
//
// We could allow pushing empty arrays or strings (by retuning a pointer in the executable's memory and
// not modifying the arena at all), but that might cause confusion, because the thing does not
// really live in the arena, and arena_contains/IS_THIS_YOURS would return false for these empty
// allocations. For now we decided not to do it. This means callers need to make sure stuff is not
// empty themselves.

arena_push :: (arena: *Arena, _size: s64, alignment: s64 = DEFAULT_ALIGNMENT) -> *void {
    assert(_size > 0, "Can not push zero size");
    assert(alignment > 0 && is_power_of_two(alignment));

    if !arena.memory_start {
        arena_init(arena);
    }

    pointer := align(arena.memory_start + arena.allocated, alignment);
    padding := cast(s64, pointer) - cast(s64, arena.memory_start + arena.allocated);

    size := padding + _size;

    arena.allocated += size;

    if arena.memory_start + arena.allocated > arena.memory_end {
        assert(false, "Arena ran out of reserved space trying to allocate");
        return null;
    }

    if arena.allocated > arena.committed {
        commit_base := arena.memory_start + arena.committed;
        commit_size := max(align(size, arena.procs.page_size), arena.commit_size);

        // We can get here, if we passed the reserve check above, but rounding up to commit size
        // would take us above the reserved space. We detect this to give a better error message.
        if commit_base + commit_size > arena.memory_end {
            assert(false, "Arena ran out of reserved space trying to commit");
            return null;
        }

        result := arena.procs.mem_commit(commit_base, commit_size);
        if !result {
            assert(false, "Arena failed to commit");
            return null;
        }

        arena.committed += commit_size;
    }

    return pointer;
}

arena_push :: (arena: *Arena, $T: Type, min_alignment := 1) -> *T {
    pointer := arena_push(arena, size_of(T), max(align_of(T), min_alignment));
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

arena_push_array :: (arena: *Arena, $T: Type, count: s64, min_alignment := 1) -> [] T {
    assert(count > 0, "Can not push empty arrays");

    pointer := arena_push(arena, size_of(T) * count, max(align_of(T), min_alignment));
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

arena_push_array :: (arena: *Arena, a: [] $T, min_alignment := 1) -> [] T {
    assert(a.count > 0, "Can not push empty arrays");

    pointer := arena_push(arena, size_of(T) * a.count, max(align_of(T), min_alignment));
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

// TODO(jt): arena_push_print :: (arena: *Arena, format_string: string, args: .. Any), so that
// we don't have to tprint, only to copy into the arena. This won't be super trivial, because sprint/tprint
// use String_Builder under the hood, and we for sure don't want to import that.

arena_push_string :: (arena: *Arena, s: string, min_alignment := 1) -> string {
    assert(s.count > 0, "Can not push empty strings");

    pointer := arena_push(arena, s.count, min_alignment);
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
arena_modify_last_push :: (arena: *Arena, pointer: *void, old_size: s64, new_size: s64, overwrite_memory := DEFAULT_OVERWRITE_MEMORY) -> success: bool {
    if !arena.memory_start {
        arena_init(arena);
    }

    if pointer + old_size != arena.memory_start + arena.allocated {
        // This is not the last allocation. May be a false negative, if we introduced padding after
        // this allocation by pushing and popping something with stronger alignment requirements.
        return false;
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

arena_get_mark :: (arena: Arena) -> Arena_Mark {
    return { arena.allocated };
}

arena_pop_to_mark :: (arena: *Arena, _mark: Arena_Mark, overwrite_memory := DEFAULT_OVERWRITE_MEMORY) {
    if !arena.memory_start {
        arena_init(arena);
    }

    // Make sure we don't deallocate ourselves.
    mark: Arena_Mark;
    mark.allocated = max(_mark.allocated, arena.low_water_mark);

    sanity_assert(arena.allocated >= mark.allocated);
    if overwrite_memory && arena.allocated > mark.allocated {
        STAMP :: 0xcd;
        overwrite_base := arena.memory_start + mark.allocated;
        overwrite_size := arena.allocated - mark.allocated;

        memset(overwrite_base, STAMP, overwrite_size);
    }

    arena.allocated = mark.allocated;

    if arena.committed > arena.retain_size {
        decommit_size := arena.committed - align(arena.allocated, arena.procs.page_size);
        if arena.committed - decommit_size < arena.retain_size {
            decommit_size = arena.committed - arena.retain_size;
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

arena_reset :: inline (arena: *Arena, overwrite_memory := DEFAULT_OVERWRITE_MEMORY) {
    arena_pop_to_mark(arena, { 0 }, overwrite_memory);
}

ArenaPopScope :: (arena: *Arena) #expand {
    __mark := arena_get_mark(arena);
    `defer arena_pop_to(arena, __mark);
}

#scope_file

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

min :: inline (a: s64, b: s64) -> s64 {
    return ifx a < b then a else b;
}

max :: inline (a: s64, b: s64) -> s64 {
    return ifx a > b then a else b;
}

#if ENABLE_SANITY_ASSERTS {
    // Same as assert, this has no args, so that we don't depend on Basic.tprint.
    sanity_assert :: (arg: bool, message := "", loc := #caller_location) #no_debug #expand {
        if !arg && assert_helper(message, loc) then debug_break();
    }
} else {
    sanity_assert :: (#discard arg: bool, #discard message := "", #discard loc := #caller_location) #expand {}
}

#if ENABLE_ASSERTS || ENABLE_SANITY_ASSERTS {
    // Taken from modules/Basic, but we do not support format args, as that would mean we depend on Basic.tprint.
    assert :: (arg: bool, message := "", loc := #caller_location) #no_debug #expand {
        if !arg && assert_helper(message, loc) then debug_break();
    }

    assert_helper :: (message := "", loc := #caller_location) -> bool {
        // Avoid infinite loops.
        if context.handling_assertion_failure {
            return false;
        }

        context.handling_assertion_failure = true;
        should_break := context.assertion_failed(loc, message);
        context.handling_assertion_failure = false;

        return should_break;
    }
} else {
    assert :: (#discard arg: bool, #discard message := "", #discard loc := #caller_location) #expand {}
}
