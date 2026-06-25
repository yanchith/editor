//
// This file is not the complete profiling source code. When compiling a profiling build, the
// metaprogram inserts a few missing pieces:
//
// The __profiler global variable is inserted when this module is imported. It is used inside this
// module to detect whether this is a profiling build with #exists.
//
// The __init_zone_labels procedure and __PROFILER_ZONE_COUNT constant are inserted when the
// metaprogram gets a TYPECHECKED_ALL_WE_CAN message. The values of these depend on what it saw
// during compilation.
//
// WARNING: The profiler is not thread-safe. Don't profile the same profiling zone from multiple threads.
//

// Call this at the top of each block of code you want to profile. It is replaced by the metaprogram
// to invocations of the actual macro: __ProfileZone.
ProfileZone :: ($label: string) #expand {}

// The zone is 32 bytes and is also aligned to 32 bytes to not straddle cache lines. You always get
// two per cache line.
#assert size_of(Profiler_Zone) == 32;
Profiler_Zone :: struct {
    elapsed_inclusive: u64 #align 32;
    elapsed_exclusive: u64;
    hits: u64;
    // u64 padding; Created by #align above. Maybe we can put some useful info here?
}

// Call this to get your labels assigned to zones.
profiler_init :: () {
    #if #exists(__profiler) {
        __init_zone_labels();
    }
}

// Call this at the start of the frame or the section of code you want to profile.
profiler_start_frame :: (label := "frame") {
    #if #exists(__profiler) {
        __profiler.zone_labels[0] = label;

        memset(__profiler.zones.data, 0, size_of(Profiler_Zone) * __profiler.zones.count);
        __profiler.current_zone_index = 0;
        __profiler.frame_start_time = Basic.current_time_monotonic();
        __profiler.frame_start_tsc = System.read_cpu_counter();
    }
}

// Call this at the end of the frame or the section of code you want to profile. Returns time scale
// (1 / frequency) of the counter used.
profiler_end_frame :: () -> cpu_counter_scale: float64 {
    #if #exists(__profiler) {
        end_tsc := System.read_cpu_counter();
        end_time := Basic.current_time_monotonic();

        elapsed_time := Basic.to_float64_seconds(end_time) - Basic.to_float64_seconds(__profiler.frame_start_time);

        elapsed_tsc: u64 = ---;
        #no_aoc {
            // #no_aoc, because currently System.read_cpu_counter() goes to clock_gettime on
            // UNIX (which can go back in time?). The following subtraction can underflow
            // because of that.
            //
            // Perhaps we could remove the #no_aoc once we are sure about our time measuring
            // methods, but maybe it's fine.
            elapsed_tsc = end_tsc - __profiler.frame_start_tsc;
        }

        zone := *__profiler.zones[0];
        #no_aoc {
            // #no_aoc, because if elapsed underflows, it can cause overflows here.
            zone.elapsed_inclusive += elapsed_tsc;
            zone.elapsed_exclusive += elapsed_tsc;
            zone.hits += 1;
        }

        return cast(float64, elapsed_time) / cast(float64, elapsed_tsc);
    } else {
        return 0;
    }
}

Sort_Mode :: enum {
    INCLUSIVE_TIME;
    EXCLUSIVE_TIME;
    HITS;
}

// Get sorted profiling data. You'll have to scale it by the time scale obtained from
// profiler_end_frame. The resulting arrays are allocated with context.allocator if in profiling
// builds and in static storage otherwise. Pass in temporary allocator if you don't want to care.
profiler_get_zones :: (sort_mode: Sort_Mode) -> [] Profiler_Zone, [] string {
    #if #exists(__profiler) {
        get :: (zone: Profiler_Zone, sort_mode: Sort_Mode) -> u64 {
            if #complete sort_mode == {
                case .INCLUSIVE_TIME;  return zone.elapsed_inclusive;
                case .EXCLUSIVE_TIME;  return zone.elapsed_exclusive;
                case .HITS;            return zone.hits;
            }

            return zone.elapsed_inclusive;
        }

        zones := Basic.array_copy(__profiler.zones);
        zone_labels := Basic.array_copy(__profiler.zone_labels);

        // @Speed Yes, this is bubble sort. We use it to sort two arrays arrays at once. We could do
        // a modified version of quicksort to do that, but let's see if it becomes a problem first.
        swapped := true;
        while swapped {
            swapped = false;

            for i: 1..zones.count - 1 {
                i0 := i - 1;
                i1 := i;

                v0 := get(zones[i0], sort_mode);
                v1 := get(zones[i1], sort_mode);

                if v0 < v1 { // V0 less than V1, because we want the largest zones first.
                    Basic.swap(*zones[i0], *zones[i1]);
                    Basic.swap(*zone_labels[i0], *zone_labels[i1]);
                    swapped = true;
                }
            }
        }

        return zones, zone_labels;
    } else {
        return .[], .[];
    }
}

#if #exists(__profiler) {
    __Profiler :: struct {
        // Labels are stored out of band, because we don't need to touch them them when
        // profiling and they would increase the zone size to 40 bytes.
        zones:       [__PROFILER_ZONE_COUNT] Profiler_Zone;
        zone_labels: [__PROFILER_ZONE_COUNT] string;

        current_zone_index: s64;

        frame_start_time: Basic.Apollo_Time;
        frame_start_tsc:  u64;
    }

    __ProfileZone :: ($zone_index: s64) #expand {
        parent_zone_index := __profiler.current_zone_index;
        __profiler.current_zone_index = zone_index;

        current_zone := *__profiler.zones[zone_index];
        current_zone_elapsed_inclusive := current_zone.elapsed_inclusive;

        start := System.read_cpu_counter();
        `defer {
            end := System.read_cpu_counter();

            elapsed: u64 = ---;
            #no_aoc {
                // #no_aoc, because currently System.read_cpu_counter() goes to clock_gettime on
                // UNIX (which can go back in time?). The following subtraction can underflow
                // because of that.
                //
                // Perhaps we could remove the #no_aoc once we are sure about our time measuring
                // methods, but maybe it's fine.
                elapsed = end - start;
            }

            #no_aoc {
                // #no_aoc, because if elapsed underflows, it can cause overflows here.
                current_zone.elapsed_inclusive = current_zone_elapsed_inclusive + elapsed;
                current_zone.elapsed_exclusive += elapsed;
                current_zone.hits += 1;
            }

            parent_zone := *__profiler.zones[parent_zone_index];
            #no_aoc {
                // #no_aoc, because we subtract from parent before we add. This is expected.
                parent_zone.elapsed_exclusive -= elapsed;
            }

            __profiler.current_zone_index = parent_zone_index;
        }
    }
}

#scope_module

// TODO(jt): Both of these imports could get removed:
//
// modules/Basic imports a few helpers for which we could have our own version here. It also
// includes time retrieval and conversion to float64.
//
// modules/System is imported only for read_cpu_counter. Copy it in here? We also need a
// better timer for arm macOS: "mrs {t}, cntvct_el0". Can we do it with #bytes?
Basic  :: #import "Basic";
System :: #import "System";
