File_Info :: struct {
    absolute_path: string;
    size: s64;

    modification_time: Apollo_Time;

    is_symlink:   bool;
    is_directory: bool;
}

Exit_Type :: enum s32 {
    UNSTARTED;
    STILL_RUNNING;
    FAILED_TO_LAUNCH;
    EXITED;
    SIGNALED;
}

Platform :: struct {
    page_size:                       s64;
    mem_reserve:                     (size: s64) -> *void;
    mem_release:                     (pointer: *void, size: s64);
    mem_commit:                      (pointer: *void, size: s64) -> bool;
    mem_decommit:                    (pointer: *void, size: s64);

    get_current_time_monotonic:      () -> Apollo_Time;

    // TODO(jt): Also make a long-running version of this that we can poll for new bytes, exit code, etc.
    run_in_process:                  (args: string, working_directory: string) -> exit_code: s32, exit_type: Exit_Type, output: string, error: string;

    get_absolute_path:               (path: string) -> success: bool, string;

    file_exists:                     (path: string) -> bool;
    file_is_directory:               (path: string) -> bool;
    file_modification_time_and_size: (path: string) -> bool, Apollo_Time, s64;
    read_file:                       (path: string) -> success: bool, [] u8;
    write_file:                      (path: string, data: [] u8) -> success: bool;
    delete_file:                     (path: string) -> success: bool;

    make_directory:                  (path: string) -> success: bool;
    delete_directory:                (path: string) -> success: bool;
    list_directory:                  (path: string, recursive: bool, files: bool, directories: bool) -> [] File_Info;
    watch_directory:                 (path: string) -> success: bool;
    unwatch_directory:               (path: string);

    get_clipboard_text:              () -> string;
    set_clipboard_text:              (text: string);
}
