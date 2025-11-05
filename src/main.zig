inline fn csrWrite(comptime csr: []const u8, value: anytype) void {
    _ = asm volatile ("csrw " ++ csr ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

inline fn csrSet(comptime csr: []const u8, value: anytype) void {
    _ = asm volatile ("csrs " ++ csr ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

inline fn csrClear(comptime csr: []const u8, value: anytype) void {
    _ = asm volatile ("csrc " ++ csr ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

inline fn readTime() usize {
    return asm volatile ("rdtime %[ret]"
        : [ret] "=r" (-> usize),
    );
}

const SBI_TIME = 0x54494D45;
const SBI_TIME_SET_TIMER = 0;

const SBI_DBCN = 0x4442434E;
const SBI_DBCN_CONSOLE_WRITE = 0;

inline fn sbiCall1(edid: usize, fid: usize, arg0: anytype) void {
    asm volatile ("ecall"
        :
        : [arg0] "{a0}" (arg0),
          [fid] "{a6}" (fid),
          [edid] "{a7}" (edid),
          // a0 and a1
        : .{ .x10 = true, .x11 = true });
}

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

fn sbiDebugConsoleWrite(text: []const u8) void {
    sbiCall3(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE, text.len, text.ptr, 0);
}

fn sbiSetTimer(value: u64) void {
    sbiCall1(SBI_TIME, SBI_TIME_SET_TIMER, value);
}

export fn _start() linksection(".text.boot") callconv(.naked) void {
    asm volatile (
        \\    la sp, __stack_start
        \\    call entry
        \\1:  wfi
        \\    j 1b
    );
}

fn interrupt_handler() callconv(.{ .riscv64_interrupt = .{ .mode = .supervisor } }) void {
    csrClear("sip", 32);
    sbiSetTimer(readTime() + 10000000);

    sbiDebugConsoleWrite("Timer!\n");
}

export fn entry() void {
    main();
}

fn main() void {
    csrWrite("stvec", &interrupt_handler);
    csrSet("sstatus", 0x2);

    sbiSetTimer(readTime() + 10000);

    csrSet("sie", 0x20);

    sbiDebugConsoleWrite("Hello world!\n");

    while (true) {
        asm volatile ("wfi");
    }
}
