// XXX: HERE Do this!

#module_parameters () (DEBUG_ASSERT := true);

// TODO(jt): @Cleanup We could copy over the few things we use from these.
#import "Basic";          // For assert
#import "Bit_Operations"; // For popcount

// Unlike the Rust code that this is loosely based on, this arena aims to be simple and minimal. The
// Rust code was about 1100 lines. Admittedly, there's documentation, unsafe crap, and other things
// in there, but 1100 lines is a lot.
//
// In here, we want to have the following features, and not much else:
//
// - Virtual Memory with committing pages as needed.
// - Block chaining and releasing blocks.
//
// The following may be added eventually, if they are actually needed, and we still have complexity budget left.
//
// - Decommit pages as needed. The problem is that this does nothing on Linux/macOS, so it is not a reliable way of releasing memory back to the OS.
// - Deallocation pop, if last allocation.
// - Realloc in-place push.
// - Realloc in-place pop, if last allocation.
// - User-given first block.
//

ARENA_DEFAULT_RESERVE_SIZE : s64 : 256 << 20;
ARENA_DEFAULT_COMMIT_SIZE  : s64 :  32 << 10;

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
    mem_commit:   (pointer: *void, size: s64) -> bool;
}

Arena :: struct {
    procs: Arena_Procs = UNINITIALIZED_PROCS;

    reserve_size := ARENA_DEFAULT_RESERVE_SIZE; // The minimal block size that is reserved. Also the size that is retained upon reset.
    commit_size  := ARENA_DEFAULT_COMMIT_SIZE;  // The minimal size that is committed within a block.

    current_block: *Arena_Block_Header;
}

arena_init :: (arena: *Arena, procs: Arena_Procs, reserve_size: s64 = ARENA_DEFAULT_RESERVE_SIZE, commit_size: s64 = ARENA_DEFAULT_COMMIT_SIZE) {
    assert(popcount(procs.page_size) == 1, "page_size must be a power of two");
    // TODO(jt): Should we assert some more things here?

    arena.procs = procs;
    arena.reserve_size = align(reserve_size, page_size);
    arena.commit_size = align(commit_size, page_size);
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
    __mark := arena_get_mark(arena);
    `defer arena_pop_to_mark(arena, __mark);
}

#scope_module

CAPS_VERSION_STRING :: "modules/Arena";

Arena_Block_Header :: struct {
    start: *void;
    end:   *void;

    allocated: *void;
    committed: *void;

    size_before_this_block: s64;
    previous_block: *Arena_Block_Header;
}

align :: (address: s64, align: s64) {
    debug_assert(popcount(align) == 1, "align must be a power of two");
    mask := align - 1;
    return (address + mask) & ~mask;
}

is_aligned :: (address: s64, align: s64) {
    debug_assert(popcount(align) == 1, "align must be a power of two");
    mask := align - 1;
    return address == address & !mask;
}

#if DEBUG_ASSERT {
    debug_assert :: (arg: bool, message := "", args: .. Any, loc := #caller_location) #no_debug #expand {
        assert(arg, message, args, loc);
    }
} else {
    debug_assert :: (#discard arg: bool, #discard message := "", #discard args: .. Any, #discard loc := #caller_location) #expand {}
}

UNINITIALIZED_PROCS   :: Arena_Procs.{ 0, uninitialized_reserve, uninitialized_release, uninitialized_commit };
uninitialized_reserve :: (size: s64) -> *void { assert(false, "arena_init must be called before use"); return null; }
uninitialized_release :: (pointer: *void, size: s64) { assert(false, "arena_init must be called before use"); }
uninitialized_commit  :: (pointer: *void, size: s64) -> bool { assert(false, "arena_init must be called before use"); return false; }
