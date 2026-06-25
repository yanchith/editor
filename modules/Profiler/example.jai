#import "Basic";

// Build this example from project root:  jai ./modules/Profiler/example.jai +Profiler
//
// Otherwise +Profiler won't be visible to the compiler. This could be fixed with -import_dir, but
// currently that parameter resolves way too late to have an effect for plugin initialization.
#import,file "module.jai"()(IMPORT_MODE = .RUNTIME);

main :: () {
    profiler_init();

    for 1..5 {
        profiler_start_frame();
        one_frame();
        time_scale := profiler_end_frame();

        zones, zone_labels := profiler_get_zones(.INCLUSIVE_TIME,, temp);
        if zones.count {
            print("\n\n");
            print("Printing profiling info for % zones:\n", zones.count);

            for zones {
                print(
                    "[%] % hits: %, inclusive: % seconds, exclusive % seconds \n",
                    it_index,
                    temp_right_pad(zone_labels[it_index], 20),
                    formatInt(it.hits, minimum_digits = 6, padding = #char " "),
                    formatFloat(time_scale * it.elapsed_inclusive, width = 10, trailing_width = 6),
                    formatFloat(time_scale * it.elapsed_exclusive, width = 10, trailing_width = 6),
                );
            }
        }

        reset_temporary_storage();
    }
}

one_frame :: () {
    // ProfileZone("one_frame");

    inner1 :: () {
        ProfileZone("inner1");
        print("printing from inner\n");
    }

    // ProfileZone("one_frame part(a)");
    result := f(1, 5);
    for 1..100 {
        result += f(result, 5);
    }

    result += MacroOperation(5, 5);

    // ProfileZone("one_frame part(a1)");
    print("result is %\n", result);
}

MacroOperation :: (a: s32, b: s32) -> s32 #expand {
    ProfileZone("MacroOperation");
    return a + b;
}

f :: (a: float32, b: float32) -> float32 {
    ProfileZone("f");
    result := a;
    for 1..10000 {
        a += b;
        a *= a + b * b * a;
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

temp_right_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, s);

    for s.count..length - 1 {
        append(*builder, " ");
    }

    return builder_to_string(*builder,, temp);
}
