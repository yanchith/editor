#import "Basic";
#import "Random";
#import,file "module.jai";

main :: () {
    basic_usage();
    stable_address();
    stress();
}

basic_usage :: () {
    // TODO(jt): Actually make this basic usage example!

    a: Arena;
    a.procs = make_procs();

    arena_push(*a, 1, 1);
    log("%", a);

    arena_push(*a, 1, 1);
    log("%", a);

    arena_push(*a, 1, 64);
    log("%", a);

    arena_reset(*a);
    log("%", a);

    arena_release(*a);
    log("%", a);
}

stable_address :: () {
    // TODO(jt): Talk about arena_allocate()
}

stress :: () {
    a: Arena;
    a.procs = make_procs();

    mark := arena_get_mark(a);
    for 0..9999 {
        r := random_get_zero_to_one();
        if r < 0.05 {
            arena_pop_to_mark(*a, mark);
        } else if r < 0.2 {
            mark = arena_get_mark(a);
        } else {
            size            := max(1, cast(s64, 65535 * random_get_zero_to_one()));
            alignment_shift := cast(s64, 8 * random_get_zero_to_one());
            alignment       := 1 << alignment_shift;

            arena_push(*a, size, alignment);
        }
    }

    arena_release(*a);
}

#if OS == .WINDOWS {
    make_procs :: () -> Arena_Procs {
        #import "Windows";

        mem_reserve :: (size: s64) -> *void {
            return VirtualAlloc(null, cast(u64, size), MEM_RESERVE, PAGE_READWRITE);
        }

        mem_release :: (pointer: *void, size: s64) {
            VirtualFree(pointer, 0, MEM_RELEASE);
        }

        mem_commit :: (pointer: *void, size: s64) -> bool {
            result := VirtualAlloc(pointer, cast(u64, size), MEM_COMMIT, PAGE_READWRITE);
            return result != null;
        }

        mem_decommit :: (pointer: *void, size: s64) {
            VirtualFree(pointer, cast(u64, size), MEM_DECOMMIT);
        }

        info: SYSTEM_INFO;
        GetSystemInfo(*info);

        return { info.dwPageSize, mem_reserve, mem_release, mem_commit, mem_decommit };
    }
} else #if OS_IS_UNIX {
    make_procs :: () -> Arena_Procs {
        #import "POSIX";

        mem_reserve :: (size: s64) -> *void {
            result := mmap(null, cast(u64, size), PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, 0, 0);
            if result == MAP_FAILED {
                result = null;
            }

            return result;
        }

        mem_release :: (pointer: *void, size: s64) {
            munmap(pointer, cast(u64, size));
        }

        mem_commit :: (pointer: *void, size: s64) -> bool {
            result := mprotect(pointer, cast(u64, size), PROT_READ | PROT_WRITE);
            return result == 0;
        }

        mem_decommit :: (pointer: *void, size: s64) {
            madvise(pointer, cast(u64, size), MADV_DONTNEED);
            mprotect(pointer, cast(u64, size), PROT_NONE);
        }

        page_size := sysconf(_SC_PAGE_SIZE);

        return { page_size, mem_reserve, mem_release, mem_commit, mem_decommit };
    }
}
