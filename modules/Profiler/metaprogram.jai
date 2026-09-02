#import "Basic";
#import "Compiler";
#import "String";

//
// This metaprogram plugin works with the Default_Metaprogram by supplying the +Profiler argument.
//
// It can also be used from custom metaprograms by importing it in the .METAPROGRAM mode and calling
// message manually in the message loop. The first parameter is optional.
//

Profiler_Plugin :: struct {
    #as using plugin: Metaprogram_Plugin;
    verbose: bool;
}

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Metaprogram_Plugin);

    p.init             = init;  // Only necessary if used from Default_Metaprogram to configure.
    p.before_intercept = null;  // Not needed.
    p.add_source       = null;  // Not needed.
    p.message          = message;
    p.finish           = null;  // Not needed.
    p.shutdown         = null;  // Not needed.

    return p;
}

init :: (p: *Metaprogram_Plugin, options: [] string) -> bool {
    pp := cast(*Profiler_Plugin, p);

    for options {
        if it == {
            case "-verbose";  pp.verbose = true;
            case; {
                log_error("Command line for plugin Profiler: Unknown argument '%'", it);
                return false;
            }
        }
    }

    return true;
}

profiler_final_code_inserted := false;
profiler_import: *Message_Import;
profiler_collected_zone_labels: [..] string;

// You can call message directly from your metaprogram and pass null for p.
message :: (p: *Metaprogram_Plugin, message: *Message) {
    verbose := false;
    if p {
        pp := cast(*Profiler_Plugin, p);
        verbose = pp.verbose;
    }

    if message.kind == {
        case .PHASE; {
            message_phase := cast(*Message_Phase, message);
            phase := message_phase.phase;

            if phase == .TYPECHECKED_ALL_WE_CAN {
                if !profiler_final_code_inserted {
                    // :InsertFinalCode
                    //
                    // This is inserted after all user-level code has been seen, we assigned all
                    // zone labels and counted all the zones. There is also :InsertEarlyCode.

                    zone_count := profiler_collected_zone_labels.count + 1; // +1, because zone 0 is for the entire profiled frame.
                    log("[Profiler] Inserting final code for % zones into Profiler module", zone_count);

                    if profiler_import {
                        sb: String_Builder;
                        sb.allocator = temp;

                        print(*sb, "__PROFILER_ZONE_COUNT :: %;\n", zone_count);
                        print(*sb, "__init_zone_labels :: () {\n");
                        for 0..zone_count - 2 {
                            print(*sb, "    __profiler.zone_labels[%] = \"%\";\n", it + 1, profiler_collected_zone_labels[it]);
                        }
                        print(*sb, "}\n");

                        s := builder_to_string(*sb,, temp);
                        add_build_string(s, profiler_import.workspace, profiler_import);
                    } else {
                        compiler_report("[Profiler] Could not find #import for the Profiler module.");
                    }

                    profiler_final_code_inserted = true;
                }
            }
        }

        case .IMPORT; {
            import_message := cast(*Message_Import, message);

            is_profiler_import := false;

            if import_message.module_name == "Profiler" {
                is_profiler_import = true;
            }

            // Support #import,file "module.jai" for examples inside the profiler module.
            if import_message.module_name == "module.jai" && ends_with(import_message.fully_pathed_filename, "Profiler/module.jai") {
                is_profiler_import = true;
            }

            if is_profiler_import {
                log("[Profiler] Inserting early code into Profiler module");

                // :InsertEarlyCode
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
                // TODO(jt): @CompilerBug We currently instrument each instantiation of the
                // polymorphic/autobaked procedure. This is sort of okay, but even if we wanted to
                // instrument the original procedure, we can't, because the compiler does not send a
                // message with its body. Maybe we should add the generic parameters into label?

                body := tc.expression;

                // We could guard against ALREADY_MODIFIED, but because we only replace our own
                // macros idempotently, it shouldn't matter if we look at the same procedure
                // multiple times.

                new_statements: [..] *Code_Node;
                new_statements.allocator = temp;

                do_modify := maybe_instrument_statements(*new_statements, body.block.statements, verbose);
                if do_modify {
                    body.block.statements = new_statements;
                    compiler_modify_procedure(message.workspace, body);
                }
            }
        }
    }
}

maybe_instrument_statements :: (new_statements: *[..] *Code_Node, statements: [] *Code_Node, verbose: bool) -> instrumented: bool {
    instrumented := false;

    for statement: statements {
        // We can either recurse into a block, or search for a procedure call statement to modify.

        blocks_to_recurse: [..] *Code_Block;
        blocks_to_recurse.allocator = temp;

        if statement.kind == {
            case .BLOCK; {
                block := cast(*Code_Block, statement);
                array_add(*blocks_to_recurse, block);
            }
            case .FOR; {
                for_statement := cast(*Code_For, statement);
                array_add(*blocks_to_recurse, for_statement.block);
            }
            case .WHILE; {
                while_statement := cast(*Code_While, statement);
                if while_statement.block {
                    array_add(*blocks_to_recurse, while_statement.block);
                }
            }
            case .IF; {
                if_statement := cast(*Code_If, statement);
                array_add(*blocks_to_recurse, if_statement.then_block);
                if if_statement.else_block {
                    array_add(*blocks_to_recurse, if_statement.else_block);
                }
            }
            case .CASE; {
                case_statement := cast(*Code_Case, statement);
                array_add(*blocks_to_recurse, case_statement.then_block);
            }
            case .DEFER; {
                defer_statement := cast(*Code_Defer, statement);
                array_add(*blocks_to_recurse, defer_statement.block);
            }
            case .PUSH_CONTEXT; {
                push_context_statement := cast(*Code_Push_Context, statement);
                array_add(*blocks_to_recurse, push_context_statement.block);
            }
        }

        if blocks_to_recurse.count {
            for block: blocks_to_recurse {
                block_new_statements: [..] *Code_Node;
                block_new_statements.allocator = temp;

                block_instrumented := maybe_instrument_statements(*block_new_statements, block.statements, verbose);

                if block_instrumented {
                    block.statements = block_new_statements;
                    instrumented = true;
                }
            }

            array_add(new_statements, statement);
            continue;
        }

        if statement.kind != .PROCEDURE_CALL {
            array_add(new_statements, statement);
            continue;
        }
        call := cast(*Code_Procedure_Call, statement);

        if call.procedure_expression.kind != .IDENT {
            array_add(new_statements, statement);
            continue;
        }
        call_ident := cast(*Code_Ident, call.procedure_expression);

        // @Hack we are doing very little checking before we replace the macro invocation. We used
        // to crawl to the actual header of the called procedure, which can then be matched against.
        // However, if our ProfileZone invocation is inside something that makes it impossible to
        // resolve at the time we see it, e.g. a macro/#insert/for_expansion, we can't reach the
        // actual declaration to check that it is the one in our module.
        //
        // Because I had the need to put profiling zones into for loops with for_expansions, I
        // ripped out the more robust checking code, and we are now instrumenting everything called
        // ProfileZone with exactly one string parameter, whether it is resolved or not. Probably
        // worth documenting this.
        if call_ident.name != "ProfileZone" {
            array_add(new_statements, statement);
            continue;
        }

        invocation_file := call_ident.location.enclosing_load.fully_pathed_filename;
        invocation_line := call_ident.location.l0;
        invocation_char := call_ident.location.c0;

        if profiler_final_code_inserted {
            compiler_report(invocation_file, invocation_line, invocation_char, "Can not instrument. Final profiling code has already been added. This is either a bug in the +Profiler metaprogram plugin, or in the compiler.");
        }

        call_arguments := call.arguments_unsorted;
        if call_arguments.count != 1 {
            log("[Profiler] Skipping invalid zone at %:%", invocation_file, invocation_line);
            array_add(new_statements, statement);
            continue;
        }

        if call_arguments[0].expression.kind != .LITERAL {
            log("[Profiler] Skipping invalid zone at %:%", invocation_file, invocation_line);
            array_add(new_statements, statement);
            continue;
        }
        argument_literal := cast(*Code_Literal, call_arguments[0].expression);

        if argument_literal.value_type != .STRING {
            log("[Profiler] Skipping invalid zone at %:%", invocation_file, invocation_line);
            array_add(new_statements, statement);
            continue;
        }

        zone_index := profiler_collected_zone_labels.count + 1; // +1, because zone 0 is the entire profiled frame.
        array_add(*profiler_collected_zone_labels, argument_literal._string);

        if verbose {
            log("[Profiler] Instrumenting zone %", argument_literal._string);
        }
        s := tprint("__ProfileZone(%);", zone_index);

        literal := New(Code_Literal,, temp);
        literal.value_type = .STRING;
        literal.values._string = s;
        insert := New(Code_Directive_Insert,, temp);
        insert.expression = literal;
        insert.location = call.location;

        instrumented = true;
        array_add(new_statements, insert);
    }

    return instrumented;
}
