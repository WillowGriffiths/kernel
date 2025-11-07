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

extern const __virtual_start: anyopaque;
var diff: u64 = undefined;

fn sbiDebugConsoleWrite(text: []const u8) void {
    sbiCall3(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE, text.len, text.ptr - diff, 0x0);
}

fn sbiSetTimer(value: u64) void {
    sbiCall1(SBI_TIME, SBI_TIME_SET_TIMER, value);
}

fn interrupt_handler() align(4) callconv(.{ .riscv64_interrupt = .{ .mode = .supervisor } }) void {
    csrClear("sip", 32);
    sbiSetTimer(readTime() + 10000000);

    sbiDebugConsoleWrite("Timer!\n");
}

fn enableInterrupts() void {
    csrWrite("stvec", @intFromPtr(&interrupt_handler));
    csrSet("sstatus", 0x2);
}

fn enableTimer() void {
    sbiSetTimer(readTime() + 10000);
    csrSet("sie", 0x20);
}

export fn main(kernel_start: u64) noreturn {
    diff = @intFromPtr(&__virtual_start) - kernel_start;

    enableInterrupts();
    enableTimer();

    sbiDebugConsoleWrite("waiting for interrupts...\n");
    while (true) {
        asm volatile ("wfi");
    }
}
