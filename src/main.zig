const util = @import("util.zig");
const sbi = @import("sbi.zig");
const pagetable = @import("pagetable.zig");
const memory = @import("memory.zig");
const console = @import("console.zig");

pub export var memory_info: pagetable.MemoryInfo = undefined;

var seconds: usize = 5;

fn interrupt_handler() align(4) callconv(.{ .riscv64_interrupt = .{ .mode = .supervisor } }) void {
    const sip = util.csrRead("sip");

    if ((sip >> 5) & 1 == 1) {
        seconds -= 1;
        if (seconds > 0) {
            console.print("{} seconds remaining\n", .{seconds});
        } else {
            console.print("shutting down...\n", .{});

            sbi.sbiSystemReset(.Shutdown, .NoReason);
        }

        util.csrClear("sip", 32);
        sbi.sbiSetTimer(util.readTime() + 10000000);
    } else {
        util.csrClear("sie", 0x20);
        util.csrClear("sip", 0x2);

        console.print("Unknown interrupt encountered: 0b{b}! stopping.\n", .{sip});

        sbi.sbiSystemReset(.Shutdown, .SystemFailure);

        // if the shutdown fails
        while (true) {
            asm volatile ("wfi");
        }
    }
}

fn enableInterrupts() void {
    util.csrWrite("stvec", @intFromPtr(&interrupt_handler));
    util.csrSet("sstatus", 0x2);
}

fn enableTimer() void {
    sbi.sbiSetTimer(util.readTime() + 10000000);
    util.csrSet("sie", 0x20);
}

fn hartId() u64 {
    return asm volatile ("mv %[ret],tp"
        : [ret] "=r" (-> u64),
    );
}

export fn main() noreturn {
    enableInterrupts();
    enableTimer();

    memory.setupMemory();

    const harts = 4;

    for (0..harts) |i| {
        console.print("Hart {}: {}\n", .{ i, sbi.sbiHartGetStatus(i) });
    }

    console.print("Current Hart: {}\n", .{hartId()});

    console.print("shutting down in 5 seconds...\n", .{});
    while (true) {
        asm volatile ("wfi");
    }
}
