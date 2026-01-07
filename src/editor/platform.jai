Platform :: struct {
    page_size:           s64;
    mem_reserve:         (size: s64) -> *void;
    mem_release:         (pointer: *void, size: s64);
    mem_commit:          (pointer: *void, size: s64) -> bool;
    mem_decommit:        (pointer: *void, size: s64);

    read_file:           (path: string) -> success: bool, data: [] u8;
    write_file:          (path: string, data: [] u8) -> succes: bool;
    delete_file:         (path: string) -> success: bool;
    copy_file:           (source_path: string, dest_path: string) -> success: bool;

    file_exists:         (path: string) -> bool;
    file_is_directory:   (path: string) -> bool;

    make_directory:      (path: string) -> success: bool;
    delete_directory:    (path: string) -> success: bool;
}
