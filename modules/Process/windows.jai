#import "Basic";
#import "Windows";
#import "Windows_Utf8";
#import "String";

// @ToDo: Maybe it has security implications to use named pipes? If that's the case, we need to switch to anonymous pipes and create a separate thread for every pipe.
// (Because anonymous pipes support neither overlapped I/O nor WaitFor... functions.
init_named_pipe_pair :: (pipe: *Process.Pipe, is_input: bool) -> success: bool, client_handle: HANDLE = INVALID_HANDLE_VALUE {
    open_mode: u32 = FILE_FLAG_FIRST_PIPE_INSTANCE | FILE_FLAG_OVERLAPPED;
    pipe_mode: u32 = PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_REJECT_REMOTE_CLIENTS;
    if is_input {
        open_mode |= PIPE_ACCESS_OUTBOUND;
        pipe_mode |= PIPE_NOWAIT; // @ToDo: The docs sound like this is discouraged but it makes for a much nicer API for writing for now.
    } else {
        pipe_mode |= PIPE_WAIT;
        open_mode |= PIPE_ACCESS_INBOUND;
    }

    // Try to find a named pipe that isn't used. In theory, we should never clash because we use a new name every time.
    // But who knows. So we're trying until we find one that isn't used.
    //  -rluba, 2022-06-10
    process_id := GetCurrentProcessId();
    pipe_name: string;
    pipe_name_w: *u16;
    while true {
        pipe_index := atomic_add(*next_pipe_index, 1);
        pipe_name = tprint("\\\\.\\pipe\\%_%", process_id, pipe_index);
        pipe_name_w = utf8_to_wide(pipe_name,, allocator=temp);
        pipe.handle = CreateNamedPipeW(pipe_name_w, open_mode, pipe_mode, 1, IO_BUFFER_SIZE, IO_BUFFER_SIZE, 0, null);
        if pipe.handle != INVALID_HANDLE_VALUE  break;

        error_code := GetLastError();
        if error_code != ERROR_PIPE_BUSY {
            error_string := System.get_error_string(error_code);
            log_error("Unable to create a named pipe for %: % %", pipe_name, error_code, error_string);
            deinit(pipe);
            return false;
        }
    }

    // Set the bInheritHandle flag so pipe handles are inherited.
    attr: SECURITY_ATTRIBUTES;
    attr.nLength = size_of(SECURITY_ATTRIBUTES);
    attr.bInheritHandle = xx 1;
    attr.lpSecurityDescriptor = null;

    access_type := cast(u32) ifx is_input then GENERIC_READ else GENERIC_WRITE;
    client_handle := CreateFileW(pipe_name_w, access_type, 0, *attr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if client_handle == INVALID_HANDLE_VALUE {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Unable to open the named pipe for %: % %", pipe_name, error_code, error_string);
        deinit(pipe);
        return false;
    }

    if !is_input {
        event := CreateEventW(null, 0, 0, null);
        if event == null {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Unable to create event for named pipe %: % %", pipe_name, error_code, error_string);
            return false, pipe;
        }

        // We allocate this dynamically because we need to pass a pointer to it to Windows and then the OS writes into it a some random point in the future.
        // If Process contains OVERLAPPED by value, it must never be moved or you get "funny" stack/memory corruption issues.
        pipe.overlapped = New(OVERLAPPED);
        pipe.overlapped.hEvent = event;
    }

    return true, client_handle;
}

create_process :: (process: *Process, args: .. string, working_directory := "", capture_and_return_output := false, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED, kill_process_if_parent_exits := true) -> success: bool {
    startup_info: STARTUPINFOW;
    startup_info.cb = size_of(type_of(startup_info));

    child_input_read:   HANDLE;
    child_output_write: HANDLE;
    child_error_write:  HANDLE;

    if capture_and_return_output {
        success: bool;
        success, child_input_read = init_named_pipe_pair(*process.input, is_input = true);
        success, child_output_write = init_named_pipe_pair(*process.output, is_input = false);
        success, child_error_write = init_named_pipe_pair(*process.error, is_input = false);

        startup_info.dwFlags = STARTF_USESTDHANDLES;
        startup_info.hStdInput = child_input_read;
        startup_info.hStdOutput = child_output_write;
        startup_info.hStdError  = child_error_write;
        // startup_info.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);
        // startup_info.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        // startup_info.hStdError  = GetStdHandle(STD_ERROR_HANDLE);
    }

    defer {
        if capture_and_return_output {
            // Close our copies of the write handles (so that we receive EOF when the child closes them too)
            CloseHandle(child_input_read);
            CloseHandle(child_output_write);
            CloseHandle(child_error_write);
        }
    }

    args_string : string = ---;
    if #complete arg_quoting == {
        case .QUOTE_IF_NEEDED;
            args_string = get_quoted_command_string(args,, temp);
        case .NEVER_QUOTE;
            args_string = join(..args, separator=" ");
    }

    if kill_process_if_parent_exits {
        // Create a "Job Object" so that the process gets cleaned up if the parent process (=we) exits for some reason.
        // If we don't do this, the child might live on.
        process.job_handle = CreateJobObjectA(null, null);
        if !process.job_handle {
            error_value, error_string := System.get_error_value_and_string();
            log_error("Could not create Windows Job Object: % %", error_value, error_string);
            process.job_handle = INVALID_HANDLE_VALUE;
            deinit(process);
            return false;
        }

        job_info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
        job_info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

        success := SetInformationJobObject(process.job_handle, .ExtendedLimitInformation, *job_info, size_of(type_of(job_info)));
        if !success {
            error_value, error_string := System.get_error_value_and_string();
            log_error("Could not configure Windows Job Object: % %", error_value, error_string);
            deinit(process);
            return false;
        }
    }

    // The first argument to CreateProcessW is null, because that is what causes it to
    // search the PATH environment variable to find the thing to run.


    // :ModifiedProcessModule
    //
    // NOTE(jt): We pass in CREATE_NO_WINODW. Otherwise, the process created a window for the console
    // unless it was spawned from a console-subsystem parent process. We are not yet experiencing
    // the issues from the comment below.
    //
    // Do not use CREATE_NO_WINDOW in dwCreationFlags, because if you do, it will mysteriously make the process not inherit
    // console handles. The documentation did not appear to say anything about this, but then again
    // the documentation is contradictory and confusing. Okay, well, if you dig into Process Creation Flags
    // on some other page, it tells you this is not a good idea. Yeah well. Okay.

    creation_flags: Creation_Flags;
    creation_flags |= CREATE_NO_WINDOW;

    success := CreateProcessW(null, utf8_to_wide(args_string,, allocator=temp), null, null, cast(BOOL) 1, creation_flags, null, utf8_to_wide(working_directory,, allocator=temp), *startup_info, *process.info);
    if !success {
        error_value, error_string := System.get_error_value_and_string();
        log_error("While running the command: '%', we were unable to create the process. Error code: %, description: %\n",
                  get_quoted_command_string(args,, temp), error_value, error_string);
        deinit(process);
        return false;
    }

    if kill_process_if_parent_exits {
        success = AssignProcessToJobObject(process.job_handle, process.info.hProcess);
        if !success {
            error_value := GetLastError();

            // Check if the program exited so quickly that we couldn't assign it fast enough:
            already_done := false;
            if error_value == ERROR_ACCESS_DENIED {
                success, result := get_process_result(process, 0);
                if result.type == .EXITED {
                    already_done = true;
                } else {
                    // Very, very rarely it happens that AssignProcessToJobObject() fails because the process has already exited
                    // while at the same time WaitForSingleObject(process_handle, 0) still indicates that the process is running.
                    // So this seems to be a race between Windows APIs. If we checkt GetExitCodeProcess() in that case,
                    // it returns success and the exit code – at least in the one single instance where we had this happen
                    // since I added the GetExitCodeProcess() workaround and logging on 2024-05-16.
                    // I’ll keep the log below in case we ever get a different result.
                    //  -rluba, 2025-02-06
                    STILL_ACTIVE :: 259;
                    code: u32;
                    success := GetExitCodeProcess(process.info.hProcess, *code);
                    if success && code != STILL_ACTIVE {
                        already_done = true;
                    } else {
                        log_error("Assigning process % to Windows Job Object % failed with %, but process result was: %, GetExitCodeProcess result was (%, %)", process.info.hProcess, process.job_handle, error_value, result, success, code);
                    }
                }
            }

            if !already_done {
                error_string := System.get_error_string(error_value);
                log_error("Could not assign process % to Windows Job Object %: % %", process.info.hProcess, process.job_handle, error_value, error_string);
                // We could decide to not fail in this case, but this might leave dangling processes around.
                // The Right Thing(tm) depends on the exact error, so we will make these decisions whenever we discover a new error condition.
                // -rluba 2022-12-06
                deinit(process);
                return false;
            }
        }
    }

    if capture_and_return_output {
        success := issue_read(*process.output);
        if !success {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Couldn't start overlapped IO for standard output: % %", error_code, error_string);
            deinit(process);
            return false;
        }

        success = issue_read(*process.error);
        if !success {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Couldn't start overlapped IO for standard error: % %", error_code, error_string);
            deinit(process);
            return false;
        }
    }

    return true;
}

deinit :: (process: *Process) {
    if process.info.hProcess != INVALID_HANDLE_VALUE {
        CloseHandle(process.info.hProcess);
        process.info.hProcess = INVALID_HANDLE_VALUE;
    }
    if process.info.hThread  != INVALID_HANDLE_VALUE {
        CloseHandle(process.info.hThread);
        process.info.hThread = INVALID_HANDLE_VALUE;
    }

    if process.job_handle != INVALID_HANDLE_VALUE {
        CloseHandle(process.job_handle);
        process.job_handle = INVALID_HANDLE_VALUE;
    }

    deinit(*process.input);
    deinit(*process.output);
    deinit(*process.error);
}

deinit :: (pipe: *Process.Pipe) {
    if pipe.handle != INVALID_HANDLE_VALUE {
        CancelIo(pipe.handle);
        CloseHandle(pipe.handle);
        pipe.handle = INVALID_HANDLE_VALUE;
    }
    if pipe.overlapped  {
        CloseHandle(pipe.overlapped.hEvent);
        free(pipe.overlapped);
        pipe.overlapped = null;
    }
}

write_to_process :: (process: *Process, data: [] u8) -> success: bool, bytes_written: int {
    bytes_written: u32 = ---;
    result := WriteFile(process.input.handle, data.data, cast(u32) data.count, *bytes_written, null);
    return result != 0, bytes_written;
}

read_from_process :: (process: *Process, output_buffer: [] u8, error_buffer: [] u8, timeout_ms := -1) -> success: bool, output_bytes: int, error_bytes: int {
    if process.output.eof && process.error.eof    return false, 0, 0;

    handles: [2] HANDLE = ---;
    num_handles: u32 = 0;

    if !process.output.eof {
        handles[num_handles] = process.output.overlapped.hEvent;
        num_handles += 1;
    }

    if !process.error.eof {
        handles[num_handles] = process.error.overlapped.hEvent;
        num_handles += 1;
    }

    wait_timeout: DWORD = INFINITE;
    if timeout_ms >= 0  wait_timeout = cast(u32) timeout_ms;

    wait_result := WaitForMultipleObjects(num_handles, handles.data, 0, wait_timeout);
    if wait_result >= num_handles && wait_result != WAIT_TIMEOUT {
        log_error("Unable to read command's output.\n");
        return false, 0, 0;
    }

    success := true;
    output_bytes: int;
    error_bytes: int;
    if !process.output.eof {
        read_success: bool;
        read_success, output_bytes = read_pipe(*process.output, output_buffer);
        success &&= read_success;
    }

    if !process.error.eof {
        read_success: bool;
        read_success, error_bytes = read_pipe(*process.error, error_buffer);
        success &&= read_success;
    }

    return success, output_bytes, error_bytes;
}

kill_process :: (process: *Process) -> bool {
    success := TerminateProcess(process.info.hProcess, 1);
    // If it fails and the error is ERROR_ACCESS_DENIED, then the process was already dead, so that's a success!
    if !success && GetLastError() != ERROR_ACCESS_DENIED {
        return false;
    }

    return true;
}

get_process_result :: (process: *Process, timeout_ms := -1) -> success: bool, Process_Result {
    if !process.info.hProcess {
        // Process handle has not yet been set.
        return true, .{type=.UNSTARTED};
    }

    wait_duration: DWORD = INFINITE;
    if timeout_ms >= 0 {
        wait_duration = cast(DWORD) timeout_ms;
    }

    wait_result := WaitForSingleObject(process.info.hProcess, wait_duration);
    if wait_result != 0 {
        return true, .{type = .STILL_RUNNING};
    }

    code: u32;
    success := GetExitCodeProcess(process.info.hProcess, *code);
    if !success {
        error_code := GetLastError();
        log_error("Could not get exit code for process %: % %", process.info.hProcess, error_code, System.get_error_string(error_code));
        return false, .{type = .EXITED, exit_code = -1};
    }

    result: Process_Result;
    result.type = .EXITED;
    result.exit_code = cast,no_check(s32) code;

    return true, result;
}

read_pipe :: (pipe: *Process.Pipe, buffer: [] u8) -> success: bool, bytes_read: int {
    bytes_read: u32;
    bytes_available: u32;
    success := PeekNamedPipe(pipe.handle, null, 0, null, *bytes_available, null) != 0;
    if success && bytes_available {
        success = ReadFile(pipe.handle, buffer.data, cast(u32) buffer.count, *bytes_read, null) != 0;
        if success {
            success = issue_read(pipe);
        }
    }

    if !success {
        if GetLastError() == ERROR_BROKEN_PIPE {
            pipe.eof = true;
            return true, bytes_read; // We can read some bytes even if BROKEN_PIPE, so return those.
        }

        return false, 0;
    }

    return true, bytes_read;
}

#scope_module

Process_Platform :: struct {
    job_handle: HANDLE = INVALID_HANDLE_VALUE;
    info: PROCESS_INFORMATION;
}

Pipe_Platform :: struct {
    handle: HANDLE = INVALID_HANDLE_VALUE;
    overlapped: *OVERLAPPED;
}

#scope_file

issue_read :: (pipe: *Process.Pipe) -> bool {
    result := ReadFile(pipe.handle, null, 0, null, pipe.overlapped); // :ProcessPointers
    if result == 0 && GetLastError() != ERROR_IO_PENDING    return false;

    return true;
}


IO_BUFFER_SIZE :: 4096;
next_pipe_index := 0;

#import "Atomics";
