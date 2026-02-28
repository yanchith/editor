#module_parameters(IMPORT_MODE := Import_Mode.METAPROGRAM) {
    Import_Mode :: enum u8 {
        METAPROGRAM :: 0;
        RUNTIME     :: 1;
    }
}

#if IMPORT_MODE == .METAPROGRAM {
    #import "Basic";
    #import "Compiler";

    injected_final_profiling_code := false;
    next_zone_index: s64 = 1; // Zone 0 is reserved for the entire profiling scope (e.g. a frame in an application)

    get_plugin :: () -> *Metaprogram_Plugin {
        p := New(Metaprogram_Plugin);
        p.message = message;

        return p;
    }

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

                for * tc: typechecked_message.procedure_bodies {
                    body := tc.expression;

                    // XXX: HERE Do the deed. Remove the original ProfileZone and replace it with __ProfileZone.
                    new_statements: [..] *Code_Node;
                    defer array_free(new_statements);

                    // TODO(jt): Is this already modified by us? Or anyone? Maybe shouldn't reject here?
                    if body.body_flags & .ALREADY_MODIFIED {
                        continue;
                    }

                    for statement: body.block.statements {
                        if statement.kind != .PROCEDURE_CALL {
                            continue;
                        }

                        call := cast(*Code_Procedure_Call, statement);
                        // TODO(jt): Check resolved_procedure_expression instead?
                        if call.procedure_expression.kind != .IDENT {
                            continue;
                        }

                        procedure_ident := cast(*Code_Ident, call.procedure_expression);
                        // TODO(jt): We shouldn't filter this, because it could have been renamed?
                        if procedure_ident.name != "ProfileZone" {
                            continue;
                        }

                        procedure_declaration := procedure_ident.resolved_declaration;

                        declaration_expression := procedure_declaration.expression;

                        log("XXX: decl % %", procedure_ident.name, declaration_expression.*);
                        // if declaration_expression.kind != .PROCEDURE_HEADER {
                        //     continue;
                        // }
                    }


                    // next_zone_index += 1;
                    // compiler_modify_procedure(message.workspace, body);
                }
            }
        }
    }
} else {
    System :: #import "System"; // TODO(jt): This is only for read_cpu_counter. Copy it in here?

    // XXX: Emit from metaprogram!
    PROFILER_ZONE_COUNT :: 4096;
    __global_profiler: Profiler;

    Profiler_Zone :: struct {
        elapsed_inclusive: u64;
        elapsed_exclusive: u64;
        hits: u64;
        _padding: u64; // So that we won't straddle cache lines, but maybe we should shrink the struct instead, or SoA it?
    }

    Profiler :: struct {
        zones:       [PROFILER_ZONE_COUNT] Profiler_Zone;
        zone_labels: [PROFILER_ZONE_COUNT] string;

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

    // The programmer invokes the ProfileZone macro in the code.
    ProfileZone  :: (#discard label: string) #expand {}

    // The metaprogram replaces ProfileZone invocations with __ProfileZone invocations.
    __ProfileZone :: ($zone_index: s64) #expand {
        parent_zone_index := __global_profiler.current_zone_index;
        __global_profiler.current_zone_index = zone_index;

        current_zone := *__global_profiler.zones[zone_index];
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
