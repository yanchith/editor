File_Info :: struct {
    name: string;
    size: s64;

    modification_time: Apollo_Time;

    is_symlink:   bool;
    is_directory: bool;
}


Platform :: struct {
    page_size:           s64;
    mem_reserve:         (size: s64) -> *void;
    mem_release:         (pointer: *void, size: s64);
    mem_commit:          (pointer: *void, size: s64) -> bool;
    mem_decommit:        (pointer: *void, size: s64);

    get_absolute_path:   (path: string) -> success: bool, string;

    read_file:           (path: string) -> success: bool, [] u8;
    write_file:          (path: string, data: [] u8) -> success: bool;
    delete_file:         (path: string) -> success: bool;

    make_directory:      (path: string) -> success: bool;
    delete_directory:    (path: string) -> success: bool;

    list_files:          (path: string) -> [] File_Info;

    clipboard_get_text:  () -> string;
    clipboard_set_text:  (text: string);
}
