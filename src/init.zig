const pagetable = @import("pagetable.zig");

pub const InitInfo = extern struct {
    pagetable_addr: usize,
    stack_addr: usize,
};

pub const MemoryInfo = extern struct {
    kernel_start: u64,
    kernel_pages: u64,
    virtual_start: u64,
    virtual_diff: u64,
    boot_start: u64,
    table_root: *align(0x1000) pagetable.PageTable,
    start_addr: u64,
};
