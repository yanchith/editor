#import "Basic";

// Build this example from project root:  jai ./modules/Profiler/example.jai +Profiler
//
// Otherwise +Profiler won't be visible to the compiler. This could be fixed with -import_dir, but
// currently that parameter resolves way too late to have an effect for plugin initialization.
#import,file "module.jai"()(IMPORT_MODE = .RUNTIME);

main :: () {
    // Call profiler_init at the start of your program
    profiler_init();

    for 1..5 {
        // Start each profiling cycle (like a frame in a video game) with profiler_start_frame
        profiler_start_frame();

        // Call your stuff
        frame();

        // Call profiler_end_frame at the end of the repetitive code you want to profile. This gives
        // you the scale with which to multiply the timing data in the profiling zones.
        time_scale := profiler_end_frame();

        // Get the zones from the profiler and display them however you like. Here, we just print
        // them to the console, but you can do graphical stuff.
        zones, zone_labels := profiler_get_zones(.INCLUSIVE_TIME,, temp);

        if zones.count { // If we hadn't passed +Profiler, there would be zero zones, and we wouldn't print anything.
            print("\n\n");
            print("Printing profiling info for frame %:\n", it);

            for zones {
                print(
                    "[%] % hits: %, inclusive: % seconds, exclusive % seconds\n",
                    it_index,
                    right_pad(zone_labels[it_index], 20),
                    formatInt(it.hits, minimum_digits = 6, padding = #char " "),
                    formatFloat(time_scale * it.elapsed_inclusive, width = 10, trailing_width = 6),
                    formatFloat(time_scale * it.elapsed_exclusive, width = 10, trailing_width = 6),
                );
            }
        }

        reset_temporary_storage();
    }
}

frame :: () {
    x := part_1();
    part_2(x);

    {
        ProfileZone("part_3");
        sum := 0;
        for x {
            sum += it;
        }
    }
}

part_1 :: () -> [..] s64 {
    ProfileZone("part_1");
    x: [..] s64;
    x.allocator = temp;

    for 0..9999 {
        array_add(*x, it);
    }

    return x;
}

part_2 :: (x: [] s64) {
    ProfileZone("part_2");

    {
        ProfileZone("part_2 section_a");
        for * x {
            it.* = fib(it.*);
        }
    }

    {
        ProfileZone("part_2 section_b");
        for * x {
            it.* = it.* * it.*;
        }
    }
}

fib :: (n: s64) -> s64 {
    ProfileZone("fib");

    if n <= 0  return 0;
    if n == 1  return 1;

    n -= 2;
    a := 0;
    b := 1;

    while n > 0 {
        t := b;
        b = a + b;
        a = t;

        n -= 1;
    }

    return b;
}

right_pad :: (s: string, length: s64) -> string {
    builder: String_Builder;
    builder.allocator = temp;

    append(*builder, s);

    for s.count..length - 1 {
        append(*builder, " ");
    }

    return builder_to_string(*builder,, temp);
}
