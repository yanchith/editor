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

    profiler_instrumentation_finalized := false;
    profiler_import_message: *Message_Import;
    profiler_zone_labels: [..] string;

    message :: (p: *Metaprogram_Plugin, message: *Message) {
        if profiler_instrumentation_finalized {
            return;
        }

        if message.kind == {
            case .PHASE; {
                phase_message := cast(*Message_Phase, message);
                phase := phase_message.phase;

                if phase == .TYPECHECKED_ALL_WE_CAN {
                    if !profiler_instrumentation_finalized {
                        zone_count := profiler_zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.
                        log("[Profiler] Collected % zones", zone_count);

                        if profiler_import_message {
                            sb: String_Builder;
                            sb.allocator = temp;

                            print(*sb, "PROFILER_ZONE_COUNT :: %;\n", zone_count);
                            print(*sb, "__init_zone_labels :: () {\n");
                            print(*sb, "    __profiler.zone_labels[0] = \"MAIN\";\n");
                            for 0..zone_count - 2 {
                                print(*sb, "    __profiler.zone_labels[%] = \"%\";\n", it + 1, profiler_zone_labels[it]);
                            }
                            print(*sb, "}\n");

                            s := builder_to_string(*sb,, temp);
                            add_build_string(s, message.workspace, profiler_import_message);
                        } else {
                            compiler_report("[Profiler] Could not find #import for the Profiler module.");
                        }

                        profiler_instrumentation_finalized = true;
                    }
                }
            }

            case .IMPORT; {
                import_message := cast(*Message_Import, message);

                if import_message.module_name == "Profiler" {
                    add_build_string(RUNTIME_TO_INSERT_EARLY, message.workspace, import_message);
                    profiler_import_message = import_message;
                }
            }

            case .TYPECHECKED; {
                typechecked_message := cast(*Message_Typechecked, message);

                for * tc: typechecked_message.procedure_bodies {
                    body := tc.expression;

                    // We could guard against ALREDY_MODIFIED, but because we replace the macros we
                    // invoke, it shouldn't matter if we look at the same procedure multiple times.

                    // XXX: We need to recurse into anything that could have a block:
                    // block/if/else/for/while/defer/cast-arguments/function-call-arguments/declarations.
                    // Otherwise we won't instrument those calls.
                    //
                    // While Typechecked::subexpressions maybe gives us everything flattened, we
                    // still need to submit a new procedure body at the end, so maybe there's no way
                    // around recursing manually, replacing block bodies containing our profiling
                    // functions.
                    //
                    // XXX: Uncommenting this log causes us to miss zones! Why? (We also sometimes
                    // miss zones with it commented out as well.)
                    //
                    // log("XXX procedure % (% subexpressions)", body.header.name, tc.subexpressions.count);

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

                        if call_ident.resolved_declaration.expression == null {
                            array_add(*new_statements, statement);
                            continue;
                        }

                        if call_ident.resolved_declaration.expression.kind != .PROCEDURE_HEADER {
                            array_add(*new_statements, statement);
                            continue;
                        }
                        header := cast(*Code_Procedure_Header, call_ident.resolved_declaration.expression);

                        // TODO(jt): We should also get the filename and import of the profiling
                        // functions to check that they are really from this module, instead of just
                        // checking if they are ProfileFrame/ProfileZone shaped.

                        if header.name == {
                            case "ProfileFrame"; {
                                log("[Profiler] Instrumenting ProfileFrame %:%", call_ident.location.enclosing_load.fully_pathed_filename, call_ident.location.l0);

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
                                    log("[Profiler] Skipping invalid ProfileZone %:%");
                                    array_add(*new_statements, statement);
                                    continue;
                                }

                                if call_arguments[0].expression.kind != .LITERAL {
                                    log("[Profiler] Skipping invalid ProfileZone %:%");
                                    array_add(*new_statements, statement);
                                    continue;
                                }
                                argument_literal := cast(*Code_Literal, call_arguments[0].expression);

                                if argument_literal.value_type != .STRING {
                                    log("[Profiler] Skipping invalid ProfileZone %:%");
                                    array_add(*new_statements, statement);
                                    continue;
                                }

                                zone_index := profiler_zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.
                                array_add(*profiler_zone_labels, argument_literal._string);

                                log("[Profiler] Instrumenting ProfileZone(\"%\") %:%", argument_literal._string, call_ident.location.enclosing_load.fully_pathed_filename, call_ident.location.l0);
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

    RUNTIME_TO_INSERT_EARLY :: #string DONE
    __profiler: Profiler;

    Profiler :: struct {
        zones:       [PROFILER_ZONE_COUNT] Profiler_Zone;
        zone_labels: [PROFILER_ZONE_COUNT] string;

        current_zone_index: s64;
    }
    DONE;
} else {
    // The programmer invokes these macros in the code. They are replaced by the metaprogram to
    // invocations of the actual macros: __ProfileFrame and __ProfileZone.
    ProfileFrame :: () #expand {}
    ProfileZone  :: ($label: string) #expand {}

    // This macro currently relies on being eliminated if not called, but we could just move it to
    // the generated code section.
    __ProfileFrame :: () #expand {
        start := System.read_cpu_counter();

        `defer {
            end := System.read_cpu_counter();
            elapsed := end - start; // #wrapping ?

            zone := *__profiler.zones[0];
            zone.elapsed_inclusive += elapsed;
            zone.elapsed_exclusive += elapsed;
            zone.hits += 1;
        }
    }

    // This macro currently relies on being eliminated if not called, but we could just move it to
    // the generated code section.
    //
    // The macro is #no_aoc, because some subtracts can overflow. See :wrapping.
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
            parent_zone.elapsed_exclusive -= elapsed; // :wrapping We can subtract from parent before add.

            __profiler.current_zone_index = parent_zone_index;
        }

    }

    Profiler_Zone :: struct {
        elapsed_inclusive: u64 #align 32; // Aligned to not straddle cache lines.
        elapsed_exclusive: u64;
        hits: u64;
        // u64 padding, created by #align above. Maybe we can put some useful info here?
    }

    // Call this to get your labels assigned to zones.
    profiler_init :: () {
        #if #exists(__profiler) {
            __init_zone_labels();
        }
    }

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

    #scope_module

    System :: #import "System"; // TODO(jt): This is only for read_cpu_counter. Copy it in here?
}
