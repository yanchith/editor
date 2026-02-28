#import "Basic";
#import "CEProf"(IMPORT_MODE = .RUNTIME);

main :: () {
    profiler_init();

    for 1..10 {
        frame();
    }

    print("\n\n");
    print("profiling info for % zones:\n", PROFILER_ZONE_COUNT);

    for profiler.zones {
        print("[%] (%)  hits: %, inclusive: %, exclusive % \n", it_index, profiler.zone_labels[it_index], it.hits, it.elapsed_inclusive, it.elapsed_exclusive);
    }

}

frame :: () {
    ProfileFrame();

    //XXX: We can't put it in a block, otherwise th metaprogram doesn't see it. Fix this!
    // {
    ProfileZone("zone");
    result := f(1, 5);

    print("result is %\n", result);
    // }
}

f :: (a: s64, b: s64) -> s64 {
    ProfileZone("f");
    result := a;
    for 1..10 {
        a += b;
        a *= a + b;
    }

    return result;
}
