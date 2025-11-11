const pagetable = @import("pagetable.zig");

extern const __boot_start: anyopaque;
extern const __boot_end: anyopaque;

extern const __kernel_start: anyopaque;
extern const __kernel_end: anyopaque;

extern var __boot_page_tables: [5]pagetable.PageTable;

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, __boot_stack_start
        \\ call init_pagetables
        \\
        \\ lui sp,%hi(__stack_start)
        \\ addi sp,sp,%lo(__stack_start)
        \\
        \\ lui a1,%hi(main)
        \\ jalr ra,%lo(main)(a1)
    );
}

fn init_boot_pagetables() void {
    @setRuntimeSafety(false);

    const boot_start = @intFromPtr(&__boot_start);
    const boot_end = @intFromPtr(&__boot_end);

    const boot_pages = (boot_end - boot_start) / 4096 + 1;

    const identity_level_2_index = boot_start >> 30 & 0b111111111;
    const identity_level_1_index = boot_start >> 21 & 0b111111111;

    __boot_page_tables[0][identity_level_2_index] = pagetable.PageTableEntry.create(.Table, @intFromPtr(&__boot_page_tables[1]));
    __boot_page_tables[1][identity_level_1_index] = pagetable.PageTableEntry.create(.Table, @intFromPtr(&__boot_page_tables[2]));

    for (0..boot_pages) |i| {
        const pa = boot_start + i * 0x1000;
        const level_0_index = (pa >> 12) & 0b111111111;

        __boot_page_tables[2][level_0_index] = pagetable.PageTableEntry.create(.Leaf, pa);
    }
}

inline fn getFarAddr(comptime addr: []const u8) usize {
    return asm volatile ("lui %[ret],%hi(" ++ addr ++ ")\n" ++
            "addi %[ret],%[ret],%%lo(" ++ addr ++ ")"
        : [ret] "={a0}" (-> usize),
    );
}

fn init_kernel_pagetables() void {
    @setRuntimeSafety(false);

    const kernel_start = @intFromPtr(&__kernel_start);

    const virtual_start = getFarAddr("__virtual_start");

    const level_2_index = virtual_start >> 30 & 0b111111111;
    const level_1_index = virtual_start >> 21 & 0b111111111;

    __boot_page_tables[0][level_2_index] = pagetable.PageTableEntry.create(.Table, @intFromPtr(&__boot_page_tables[3]));
    __boot_page_tables[3][level_1_index] = pagetable.PageTableEntry.create(.Table, @intFromPtr(&__boot_page_tables[4]));

    for (0..512) |i| {
        const pa = kernel_start + i * 0x1000;
        const va = virtual_start + i * 0x1000;
        const level_0_index = (va >> 12) & 0b111111111;

        __boot_page_tables[4][level_0_index] = pagetable.PageTableEntry.create(.Leaf, pa);
    }
}

export fn init_pagetables() void {
    @setRuntimeSafety(false);

    for (0..5) |i| {
        for (0..512) |j| {
            __boot_page_tables[i][j] = pagetable.PageTableEntry.create(.{ .valid = false }, 0);
        }
    }

    init_boot_pagetables();
    init_kernel_pagetables();

    asm volatile ("sfence.vma zero, zero");

    const satp_sv39 = 8 << 60;
    const satp = (@intFromPtr(&__boot_page_tables[0]) >> 12) | satp_sv39;

    asm volatile ("csrw satp, %[address]"
        :
        : [address] "r" (satp),
    );

    asm volatile ("sfence.vma zero, zero");

    const kernel_start = @intFromPtr(&__kernel_start);
    const kernel_end = @intFromPtr(&__kernel_end);
    const virtual_start = getFarAddr("__virtual_start");
    const kernel_pages = (kernel_end - kernel_start) / 4096 + 1;

    const memory_info: *volatile pagetable.MemoryInfo = @ptrFromInt(getFarAddr("memory_info"));
    memory_info.* = .{
        .virtual_start = virtual_start,
        .kernel_start = kernel_start,
        .kernel_pages = kernel_pages,
        .virtual_diff = virtual_start - kernel_start,
        .table_root = &__boot_page_tables[0],
    };
}
