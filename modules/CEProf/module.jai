#module_parameters(IMPORT_MODE := Import_Mode.METAPROGRAM) {
    Import_Mode :: enum u8 {
        METAPROGAM :: 0;
        RUNTIME    :: 1;
    }
}

#if IMPORT_MODE == .METAPROGRAM {
    #import "Compiler";


    injected_final_profiling_code := false;
    next_zone_index: s64 = 1; // Zone 0 is reserved for the entire profiling scope (e.g. a frame in an application)

    message :: (p: *Metaprogram_Plugin, message: *Message) {
        if injected_final_profiling_code {
            return;
        }

        if message.kind == {
            case .PHASE; {
                phase_message := cast(*Message_Phase, message);
                phase := phase_message.phase;

                if phase == .TYPECHECKED_ALL_WE_CAN {
                    if !injected_final_profiling_code {

                        injected_final_profiling_code = true;
                    }
                }
            }

            case .TYPECHECKED; {
                assert(!injected_final_profiling_code);
                typechecked_message := cast(*Message_Typechecked, message);

                // XXX: HERE This is not going to work, we need to modify the ZONE index after the
                // macro has been expandedd... or something. Maybe we can do #insert? Or maybe we
                // just replace the macro at the callsite with the actual stuff.
                for * typechecked_message.procedure_bodies {
                    body := it.expression;
                    if body.body_flags & .ALREADY_MODIFIED {
                        continue;
                    }

                    header := body.header;
                    if !(header.procedure_flags & .MACRO) {
                        continue;
                    }

                    // TODO(jt): What if the caller renamed it? We could check for notes instead?
                    if header.name != "ProfileZone" {
                        continue;
                    }

                    // TODO(jt): Check whether the arguments match?

                    if body.block.block_type != .IMPERATIVE {
                        continue;
                    }

                    if body.block.statements.count == 0 {
                        continue;
                    }

                    statement := body.block.sttements[0];
                    if statement.kind != .DECLARATION {
                        continue;
                    }

                    declaration := cast(*Code_Declaration, statement);
                    if !(declaration.flags & .IS_CONSTANT) {
                        continue;
                    }

                    if program_export_name != "ZONE_INDEX" {
                        continue;
                    }

                    declaration.value = next_zone_index;
                    next_zone_index += 1;

                    compiler_modify_procedure(message.workspace, body);
                }
            }
        }
    }
} else {
    System :: #import "System";

    #placeholder ZONE_COUNT;

    Zone :: struct {
        elapsed_inclusive: u64;
        elapsed_exclusive: u64;
        hits: u64;
        _padding: u64; // So that we won't straddle cache lines, but maybe we should shrink the struct instead, or SoA it?
    }

    Profiler :: struct {
        zones:       [ZONE_COUNT] Zone;
        zone_labels: [ZONE_COUNT] string;

        current_zone_index: s64;
    }

    // TODO(jt): Support ProfileFrameBegin/ProfileFrameEnd for the poor people that use a
    // callback-based platform layer? We'd have to store 'start' somewhere globally, instead of
    // sneaking it on the stack.
    ProfileFrame :: () #expand {
        start := System.read_cpu_counter();

        `defer {
            end := System.read_cpu_counter();
            elapsed := end - start; // #wrapping ?

            zone := *__global_profiler.zones[0];
            zone.elapsed_inclusive += elapsed;
            zone.elapsed_exclusive += elapsed;
            zone.hits += 1;
        }
    }

    ProfileZone :: (label: string) #expand {
        ZONE_INDEX :: -1; // This gets patched by the metaprogram.

        parent_zone_index := __global_profiler.current_zone_index;
        __global_profiler.current_zone_index = ZONE_INDEX;

        current_zone := *__global_profiler.zones[ZONE_INDEX];
        current_zone_elapsed_inclusive := current_zone.elapsed_inclusive;

        start := System.read_cpu_counter();
        `defer {
            end := System.read_cpu_counter();
            elapsed := end - start; // #wrapping ?

            current_zone.elapsed_inclusive = current_zone_elapsed_inclusive + elapsed;
            current_zone.elapsed_exclusive += elapsed; // #wrapping ?
            current_zone.hits += 1;

            parent_zone := *__global_profiler.zones[parent_zone_index];
            parent_zone.elapsed_exclusive -= elapsed; // #wrapping ?!!

            __global_profiler.current_zone_index = parent_zone_index;
        }
    }
}
