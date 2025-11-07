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
        \\ la a0,__kernel_start
        \\ lui a1,%hi(main)
        \\ jalr ra,%lo(main)(a1)
    );
}

const SBI_DBCN = 0x4442434E;
const SBI_DBCN_CONSOLE_WRITE = 0;
const SBI_DBCN_CONSOLE_WRITE_BYTE = 2;

inline fn sbiCall3(edid: usize, fid: usize, arg0: anytype, arg1: anytype, arg2: anytype) void {
    asm volatile ("ecall"
        :
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [fid] "{a6}" (fid),
          [edid] "{a7}" (edid),
          // a0 and a1
        : .{ .x10 = true, .x11 = true });
}

inline fn sbiCall1(edid: usize, fid: usize, arg0: anytype) void {
    asm volatile ("ecall"
        :
        : [arg0] "{a0}" (arg0),
          [fid] "{a6}" (fid),
          [edid] "{a7}" (edid),
          // a0 and a1
        : .{ .x10 = true, .x11 = true });
}

inline fn sbiDebugConsoleWrite(text: []const u8) void {
    sbiCall3(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE, text.len, text.ptr, 0);
}

inline fn sbiDebugConsoleWriteByte(byte: u8) void {
    sbiCall1(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE_BYTE, byte);
}

fn printNum(num: anytype) void {
    @setRuntimeSafety(false);

    const chars = [16]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };

    sbiDebugConsoleWrite("0x");

    if (num != 0) {
        var val = num;
        var to_print: [16]u8 = undefined;
        var digits: usize = 0;

        while (val > 0) {
            const last_digit = val & 0xf;
            to_print[digits] = chars[last_digit];
            digits += 1;
            val >>= 4;
        }

        while (digits > 0) {
            sbiDebugConsoleWriteByte(to_print[digits - 1]);
            digits -= 1;
        }
    } else {
        sbiDebugConsoleWriteByte('0');
    }

    sbiDebugConsoleWriteByte('\n');
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
    const kernel_end = @intFromPtr(&__kernel_end);

    const virtual_start = getFarAddr("__virtual_start");

    const kernel_pages = (kernel_end - kernel_start) / 4096 + 1;

    const level_2_index = virtual_start >> 30 & 0b111111111;
    const level_1_index = virtual_start >> 21 & 0b111111111;

    __boot_page_tables[0][level_2_index] = pagetable.PageTableEntry.create(.Table, @intFromPtr(&__boot_page_tables[3]));
    __boot_page_tables[3][level_1_index] = pagetable.PageTableEntry.create(.Table, @intFromPtr(&__boot_page_tables[4]));

    for (0..kernel_pages) |i| {
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
}
