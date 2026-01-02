Platform :: struct {
    vm_page_size:        s64;
    vm_reserve:          (size: s64) -> *void;
    vm_release:          (pointer: *void, size: s64);
    vm_commit:           (pointer: *void, size: s64);
    vm_decommit:         (pointer: *void, size: s64);

    read_file:           (path: string) -> success: bool, data: string;
    write_file:          (path: string, data: string) -> succes: bool;
    delete_file:         (path: string) -> success: bool;
    copy_file:           (source_path: string, dest_path: string) -> success: bool;

    file_exists:         (path: string) -> bool;
    file_is_directory:   (path: string) -> bool;

    make_directory:      (path: string) -> success: bool;
    delete_directory:    (path: string) -> success: bool;
}
