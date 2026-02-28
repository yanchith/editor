#module_parameters(IMPORT_MODE := Import_Mode.METAPROGRAM) {
    Import_Mode :: enum u8 {
        METAPROGRAM :: 0;
        RUNTIME     :: 1;
    }
}

#if IMPORT_MODE == .METAPROGRAM {
    #import "Basic";
    #import "Compiler";

    get_plugin :: () -> *Metaprogram_Plugin {
        p := New(Metaprogram_Plugin);
        p.message = message;

        return p;
    }

    finalized := false;
    zone_labels: [..] string;

    message :: (p: *Metaprogram_Plugin, message: *Message) {
        if finalized {
            return;
        }

        if message.kind == {
            case .PHASE; {
                phase_message := cast(*Message_Phase, message);
                phase := phase_message.phase;

                if phase == .TYPECHECKED_ALL_WE_CAN {
                    if !finalized {
                        zone_count := zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.

                        log("[CEProf] Collected % zones", zone_count);

                        // TODO(jt): @Cleanup We only import the profiler here so that we can do the poke with the final zone count. Is there a better way?
                        s := tprint("__CEProf :: #import \"CEProf\"(IMPORT_MODE = .RUNTIME);PROFILER_ZONE_COUNT :: %; #poke_name __CEProf PROFILER_ZONE_COUNT;", zone_count);
                        add_build_string(s, message.workspace);

                        finalized = true;
                    }
                }
            }

            case .TYPECHECKED; {
                typechecked_message := cast(*Message_Typechecked, message);

                for * tc: typechecked_message.procedure_bodies {
                    body := tc.expression;

                    // TODO(jt): Is this already modified by us? Or anyone? Maybe shouldn't reject here?
                    if body.body_flags & .ALREADY_MODIFIED {
                        continue;
                    }

                    do_modify := false;

                    new_statements: [..] *Code_Node;
                    new_statements.allocator = temp;

                    for statement: body.block.statements {
                        if statement.kind != .PROCEDURE_CALL {
                            array_add(*new_statements, statement);
                            continue;
                        }
                        call := cast(*Code_Procedure_Call, statement);

                        // TODO(jt): Check resolved_procedure_expression instead?
                        if call.procedure_expression.kind != .IDENT {
                            array_add(*new_statements, statement);
                            continue;
                        }
                        call_ident := cast(*Code_Ident, call.procedure_expression);

                        if call_ident.resolved_declaration.expression.kind != .PROCEDURE_HEADER {
                            array_add(*new_statements, statement);
                            continue;
                        }
                        header := cast(*Code_Procedure_Header, call_ident.resolved_declaration.expression);

                        // TODO(jt): We could get to the filename and import of the profiling
                        // functions to check that they are really from this module.

                        if header.name == {
                            case "ProfileFrame"; {
                                log("[CEProf] Instrumenting ProfileFrame %:%", call_ident.location.enclosing_load.fully_pathed_filename, call_ident.location.l0);

                                literal := New(Code_Literal,, temp);
                                literal.value_type = .STRING;
                                literal.values._string = "__ProfileFrame();";
                                insert := New(Code_Directive_Insert,, temp);
                                insert.expression = literal;
                                insert.location = body.location;

                                do_modify = true;
                                array_add(*new_statements, insert);
                            }

                            case "ProfileZone"; {
                                call_arguments := call.arguments_unsorted;
                                if call_arguments.count != 1 {
                                    log("[CEProf] Skipping invalid ProfileZone %:%");
                                    array_add(*new_statements, statement);
                                    continue;
                                }

                                if call_arguments[0].expression.kind != .LITERAL {
                                    log("[CEProf] Skipping invalid ProfileZone %:%");
                                    array_add(*new_statements, statement);
                                    continue;
                                }
                                argument_literal := cast(*Code_Literal, call_arguments[0].expression);

                                if argument_literal.value_type != .STRING {
                                    log("[CEProf] Skipping invalid ProfileZone %:%");
                                    array_add(*new_statements, statement);
                                    continue;
                                }

                                zone_index := zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.
                                array_add(*zone_labels, argument_literal._string);

                                log("[CEProf] Instrumenting ProfileZone(\"%\") %:%", argument_literal._string, call_ident.location.enclosing_load.fully_pathed_filename, call_ident.location.l0);
                                s := tprint("__ProfileZone(%);", zone_index);

                                literal := New(Code_Literal,, temp);
                                literal.value_type = .STRING;
                                literal.values._string = s;
                                insert := New(Code_Directive_Insert,, temp);
                                insert.expression = literal;
                                insert.location = body.location;

                                do_modify = true;
                                array_add(*new_statements, insert);
                            }

                            case; {
                                array_add(*new_statements, statement);
                            }
                        }
                    }

                    if do_modify {
                        body.block.statements = new_statements;
                        compiler_modify_procedure(message.workspace, body);
                    }
                }
            }
        }
    }
} else {
    // The programmer invokes these macros in the code. They are replaced by the metaprogram to
    // invocations of the actual macros: __ProfileFrame and __ProfileZone.
    ProfileFrame :: () #expand { /* Generated by the metaprogram */ }
    ProfileZone  :: ($label: string) #expand { /* Generated by the metaprogram */ }

    __ProfileFrame :: () #expand {
        start := System.read_cpu_counter();

        `defer {
            end := System.read_cpu_counter();
            elapsed := end - start; // #wrapping ?

            zone := *profiler.zones[0];
            zone.elapsed_inclusive += elapsed;
            zone.elapsed_exclusive += elapsed;
            zone.hits += 1;
        }
    }

    // The metaprogram replaces ProfileZone invocations with __ProfileZone invocations.
    __ProfileZone :: ($zone_index: s64) #expand {
        parent_zone_index := profiler.current_zone_index;
        profiler.current_zone_index = zone_index;

        current_zone := *profiler.zones[zone_index];
        current_zone_elapsed_inclusive := current_zone.elapsed_inclusive;

        start := System.read_cpu_counter();
        `defer {
            end := System.read_cpu_counter();
            elapsed := end - start; // #wrapping ?

            current_zone.elapsed_inclusive = current_zone_elapsed_inclusive + elapsed;
            current_zone.elapsed_exclusive += elapsed; // #wrapping ?
            current_zone.hits += 1;

            parent_zone := *profiler.zones[parent_zone_index];
            parent_zone.elapsed_exclusive -= elapsed; // #wrapping ?!!

            profiler.current_zone_index = parent_zone_index;
        }

    }

    #scope_module

    System :: #import "System"; // TODO(jt): This is only for read_cpu_counter. Copy it in here?

    #placeholder PROFILER_ZONE_COUNT; // XXX: We need to inject this "somehow".

    profiler: Profiler;

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
}
