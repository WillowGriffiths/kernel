const util = @import("util.zig");
const sbi = @import("sbi.zig");

extern const __virtual_start: anyopaque;
pub var diff: u64 = undefined;

fn interrupt_handler() align(4) callconv(.{ .riscv64_interrupt = .{ .mode = .supervisor } }) void {
    util.csrClear("sip", 32);
    sbi.sbiSetTimer(util.readTime() + 10000000);

    sbi.sbiDebugConsoleWrite("Timer!\n");
}

fn enableInterrupts() void {
    util.csrWrite("stvec", @intFromPtr(&interrupt_handler));
    util.csrSet("sstatus", 0x2);
}

fn enableTimer() void {
    sbi.sbiSetTimer(util.readTime() + 10000);
    util.csrSet("sie", 0x20);
}

export fn main(kernel_start: u64) noreturn {
    diff = @intFromPtr(&__virtual_start) - kernel_start;

    enableInterrupts();
    enableTimer();

    sbi.sbiDebugConsoleWrite("waiting for interrupts...\n");
    while (true) {
        asm volatile ("wfi");
    }
}
