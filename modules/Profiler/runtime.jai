//
// This file is incomplete. When compiling a profiling build, the metaprogram inserts a few missing pieces of code.
//
// __profiler global varialble is inserted when this module is imported. Also used inside this
// module to detect whether this is a profiling build with #exists.
//
// __init_zone_labels procedure and __PROFILER_ZONE_COUNT constant are inserted when we get a TYPECHECKED_ALL_WE_CAN
// message. The values of these depend on what the metaprogram saw during compilation.

// The programmer invokes this macros in the code. They are replaced by the metaprogram to
// invocations of the actual macro: __ProfileZone.
ProfileZone  :: ($label: string) #expand {}

Profiler_Zone :: struct {
    elapsed_inclusive: u64 #align 32; // Aligned to not straddle cache lines.
    elapsed_exclusive: u64;
    hits: u64;
    // u64 padding, created by #align above. Maybe we can put some useful info here?
}

// Call this to get your labels assigned to zones. You technically don't need to.
profiler_init :: () {
    #if #exists(__profiler) {
        __init_zone_labels();
    }
}

// Call this at the start of the frame.
profiler_start_frame :: () {
    #if #exists(__profiler) {
        memset(__profiler.zones.data, 0, size_of(Profiler_Zone) * __profiler.zones.count);
        __profiler.current_zone_index = 0;
        __profiler.frame_start_time = Basic.current_time_monotonic();
        __profiler.frame_start_tsc = System.read_cpu_counter();
    }
}

// Call this at the end of the frame. Returns the time scale of the counter used.
// TODO(jt): We should probably extract the timestamp frequency out of this function.
profiler_end_frame :: () -> cpu_counter_scale: float64 {
    #if #exists(__profiler) {
        end_tsc := System.read_cpu_counter();
        end_time := Basic.current_time_monotonic();

        elapsed_time := Basic.to_float64_seconds(end_time) - Basic.to_float64_seconds(__profiler.frame_start_time);
        elapsed_tsc := end_tsc - __profiler.frame_start_tsc;

        zone := *__profiler.zones[0];
        zone.elapsed_inclusive += elapsed_tsc;
        zone.elapsed_exclusive += elapsed_tsc;
        zone.hits += 1;

        return cast(float64, elapsed_tsc) / cast(float64, elapsed_time);
    } else {
        return 0;
    }
}

// Get the raw profiling data. You'll likely have to sort and otherwise process it. The timestamp
// frequency is returned from profiler_end_frame. Call profiler_get_zone_labels to get corresponding labels.
profiler_get_zones :: () -> [] Profiler_Zone {
    #if #exists(__profiler) {
        return __profiler.zones;
    } else {
        return .[];
    }
}

profiler_get_zone_labels :: () -> [] string {
    #if #exists(__profiler) {
        return __profiler.zone_labels;
    } else {
        return .[];
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

    // #no_aoc, because some subtracts can overflow. See :Wrapping.
    __ProfileZone :: ($zone_index: s64) #expand #no_aoc {
        parent_zone_index := __profiler.current_zone_index;
        __profiler.current_zone_index = zone_index;

        current_zone := *__profiler.zones[zone_index];
        current_zone_elapsed_inclusive := current_zone.elapsed_inclusive;

        start := System.read_cpu_counter();
        `defer {
            end := System.read_cpu_counter();
            elapsed := end - start;

            current_zone.elapsed_inclusive = current_zone_elapsed_inclusive + elapsed;
            current_zone.elapsed_exclusive += elapsed;
            current_zone.hits += 1;

            parent_zone := *__profiler.zones[parent_zone_index];
            parent_zone.elapsed_exclusive -= elapsed; // We can subtract from parent before we add. :Wrapping

            __profiler.current_zone_index = parent_zone_index;
        }
    }
}

#scope_module

Basic  :: #import "Basic";  // TODO(jt): This is just for getting current time. Copy it here?
System :: #import "System"; // TODO(jt): This is only for read_cpu_counter. Copy it in here?
