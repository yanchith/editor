#import "Basic";
#import "Profiler"(IMPORT_MODE = .RUNTIME);

main :: () {
    profiler_init();

    for 1..10 {
        one_frame();
    }

    zones := profiler_get_zones();
    zone_labels := profiler_get_zone_labels();

    print("\n\n");
    if zones.count {
        print("Printing profiling info for % zones:\n", zones.count);

        for zones {
            print("[%] (%)  hits: %, inclusive: %, exclusive % \n", it_index, zone_labels[it_index], it.hits, it.elapsed_inclusive, it.elapsed_exclusive);
        }
    } else {
        print("No profiling info available.\n");
    }
}

one_frame :: () {
    ProfileFrame();
    // XXX: Uncomment this line to for the compiler to send the messages in the expected order.
    // ProfileZone("one_frame");

    inner1 :: () {
        ProfileZone("inner1");
        print("printing from inner\n");
    }

    ProfileZone("one_frame part(a)");
    result := f(1, 5);
    ProfileZone("one_frame part(a1)");
    print("result is %\n", result);
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


g :: () {
    ProfileZone("g");
    inner2 :: () {
        ProfileZone("inner2");
        print("printing from inner\n");
    }

    result := f(1, 5);
    ProfileZone("g part(a)");
    print("result is %\n", result);
}
