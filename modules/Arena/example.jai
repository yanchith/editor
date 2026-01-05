#import "Basic";
#import "Random";
#import,file "module.jai";

main :: () {
    a: Arena;
    a.procs = make_procs();

    mark := arena_get_mark(a);
    for 0..9999 {
        r := random_get_zero_to_one();
        if r < 0.05 {
            arena_pop_to_mark(*a, mark);
            mark = arena_get_mark(a);
        } else if r < 0.2 {
            mark = arena_get_mark(a);
        } else {
            size            := max(1, cast(s64, 65535 * random_get_zero_to_one()));
            alignment_shift := cast(s64, 8 * random_get_zero_to_one());

            arena_push(*a, size, 1 << alignment_shift);
        }
    }

    log("%", a);

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

#if OS == .WINDOWS {
    make_procs :: () -> Arena_Procs {
        W :: #import "Windows";

        mem_reserve :: (size: s64) -> *void {
            return W.VirtualAlloc(null, cast(u64, size), W.MEM_RESERVE, W.PAGE_READWRITE);
        }

        mem_release :: (pointer: *void, size: s64) {
            W.VirtualFree(pointer, 0, W.MEM_RELEASE);
        }

        mem_commit :: (pointer: *void, size: s64) -> bool {
            result := W.VirtualAlloc(pointer, cast(u64, size), W.MEM_COMMIT, W.PAGE_READWRITE);
            return result != null;
        }

        mem_decommit :: (pointer: *void, size: s64) {
            W.VirtualFree(pointer, cast(u64, size), W.MEM_DECOMMIT);
        }

        info: W.SYSTEM_INFO;
        W.GetSystemInfo(*info);

        return { info.dwPageSize, mem_reserve, mem_release, mem_commit, mem_decommit };
    }
} else #if OS_IS_UNIX {

}
