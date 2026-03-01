#import "Basic";
#import "CEProf"(IMPORT_MODE = .RUNTIME);

main :: () {
    profiler_init();

    for 1..10 {
        frame();
    }

    zones := profiler_get_zones();
    zone_labels := profiler_get_zone_labels();

    print("\n\n");
    print("profiling info for % zones:\n", zones.count);

    for zones {
        print("[%] (%)  hits: %, inclusive: %, exclusive % \n", it_index, zone_labels[it_index], it.hits, it.elapsed_inclusive, it.elapsed_exclusive);
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
