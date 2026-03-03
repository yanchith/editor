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

    profiler_final_code_inserted := false;
    profiler_import: *Message_Import;
    profiler_colleted_zone_labels: [..] string;

    message :: (p: *Metaprogram_Plugin, message: *Message) {
        if message.kind == {
            case .PHASE; {
                message_phase := cast(*Message_Phase, message);
                phase := message_phase.phase;

                if phase == .TYPECHECKED_ALL_WE_CAN {
                    log("[Profiler] Received TYPECHECKED_ALL_WE_CAN (num_things = %)", message_phase.num_items_waiting_to_typecheck);
                    if !profiler_final_code_inserted {
                        // :InsertFinalCode
                        //
                        // This is inserted after all user-level code has been seen, we assigned all
                        // zone labels and counted all the zones. There is also :InsertFirstCode.

                        zone_count := profiler_colleted_zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.
                        log("[Profiler] Inserting final code for % zones.", zone_count);

                        if profiler_import {
                            sb: String_Builder;
                            sb.allocator = temp;

                            print(*sb, "__PROFILER_ZONE_COUNT :: %;\n", zone_count);
                            print(*sb, "__init_zone_labels :: () {\n");
                            print(*sb, "    __profiler.zone_labels[0] = \"FRAME\";\n");
                            for 0..zone_count - 2 {
                                print(*sb, "    __profiler.zone_labels[%] = \"%\";\n", it + 1, profiler_colleted_zone_labels[it]);
                            }
                            print(*sb, "}\n");

                            s := builder_to_string(*sb,, temp);
                            add_build_string(s, message.workspace, profiler_import);
                        } else {
                            compiler_report("[Profiler] Could not find #import for the Profiler module.");
                        }

                        profiler_final_code_inserted = true;
                    }
                }
            }

            case .IMPORT; {
                import_message := cast(*Message_Import, message);

                if import_message.module_name == "Profiler" {
                    log("[Profiler] Inserting early code");

                    // :InsertFirstCode
                    //
                    // This code tells the runtime-imported part of the module that we are going to
                    // be profiling. The module checks #exists(__profiler), so we insert it the
                    // first thing when we see the module being imported. (Hopefully this is early
                    // enough and #exists at least waits for being blocked.)
                    add_build_string("__profiler: __Profiler;\n", message.workspace, import_message);
                    profiler_import = import_message;
                }
            }

            case .TYPECHECKED; {
                message_typechecked := cast(*Message_Typechecked, message);

                for tc: message_typechecked.procedure_bodies {
                    body := tc.expression;

                    // We could guard against ALREADY_MODIFIED, but because we replace the macros we
                    // invoke, it shouldn't matter if we look at the same procedure multiple times.

                    // TODO(jt): We also need to recurse into anything that could have a block,
                    // otherwise we won't instrument nested calls.

                    do_modify := false;

                    new_statements: [..] *Code_Node;

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

                        invocation_file := call_ident.location.enclosing_load.fully_pathed_filename;
                        invocation_line := call_ident.location.l0;
                        invocation_char := call_ident.location.c0;

                        if header.name == {
                            case "ProfileFrame"; {
                                if profiler_final_code_inserted {
                                    compiler_report(invocation_file, invocation_line, invocation_char, "Can not instrument. Final profiling code has already been added. This is either a bug in the +Profiler metaprogram plugin, or in the compiler.");
                                }

                                log("[Profiler] Instrumenting ProfileFrame");

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
                                    log("[Profiler] Skipping invalid ProfileZone at %:%", invocation_file, invocation_line);
                                    array_add(*new_statements, statement);
                                    continue;
                                }

                                if call_arguments[0].expression.kind != .LITERAL {
                                    log("[Profiler] Skipping invalid ProfileZone at %:%", invocation_file, invocation_line);
                                    array_add(*new_statements, statement);
                                    continue;
                                }
                                argument_literal := cast(*Code_Literal, call_arguments[0].expression);

                                if argument_literal.value_type != .STRING {
                                    log("[Profiler] Skipping invalid ProfileZone at %:%", invocation_file, invocation_line);
                                    array_add(*new_statements, statement);
                                    continue;
                                }

                                if profiler_final_code_inserted {
                                    compiler_report(invocation_file, invocation_line, invocation_char, "Can not instrument. Final profiling code has already been added. This is either a bug in the +Profiler metaprogram plugin, or in the compiler.");
                                }

                                zone_index := profiler_colleted_zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.
                                array_add(*profiler_colleted_zone_labels, argument_literal._string);

                                log("[Profiler] Instrumenting ProfileZone(\"%\")", argument_literal._string);
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
                        // XXX: Actually modifying the procedure changes something (timing?
                        // synchronization?) and we get a TYPECHECKED_ALL_WE_CAN while there are
                        // still things possible to typecheck. This causes us to not see all the
                        // zones before adding the final profiling code.
                        //
                        // Comment out this line to see the timing issue disappear.
                        compiler_modify_procedure(message.workspace, body);
                    }
                }
            }
        }
    }
} else {
    // The programmer invokes these macros in the code. They are replaced by the metaprogram to
    // invocations of the actual macros: __ProfileFrame and __ProfileZone.
    ProfileFrame :: () #expand {}
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

    // Get the raw profiling data. You'll likely have to sort or otherwise process it. Call
    // profiler_get_zone_labels to get corresponding labels.
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
        }

        __ProfileFrame :: () #expand {
            start := System.read_cpu_counter();

            `defer {
                end := System.read_cpu_counter();
                elapsed := end - start;

                zone := *__profiler.zones[0];
                zone.elapsed_inclusive += elapsed;
                zone.elapsed_exclusive += elapsed;
                zone.hits += 1;
            }
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

    System :: #import "System"; // TODO(jt): This is only for read_cpu_counter. Copy it in here?
}
