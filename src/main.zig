const util = @import("util.zig");
const sbi = @import("sbi.zig");
const pagetable = @import("pagetable.zig");
const memory = @import("memory.zig");
const console = @import("console.zig");
const init = @import("init.zig");

pub export var memory_info: init.MemoryInfo = undefined;

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

comptime {
    asm (
        \\.globl secondaryMain
        \\.type secondaryMain,@function
        \\secondaryMain:
        \\   // enable paging with the pagetable address stored in a0 
        \\   srli t0, a0, 12
        \\
        \\   li t1, 8
        \\   slli t1, t1, 60
        \\
        \\   or t0, t0, t1
        \\   
        \\   csrw satp, t0
        \\
        \\   sfence.vma zero, zero
        \\
        \\   mv sp,a1
        \\   mv a0,x0
        \\
        \\   call main
    );
}

const harts = 4;

fn initHarts() void {
    const stacks_size = 4096 * 8 * (harts - 1);
    const stacks: *[harts - 1][4096 * 8]u8 = @ptrCast(memory.allocSize(stacks_size) catch @trap());

    var init_infos: *[harts - 1]init.InitInfo = @ptrCast(memory.allocSize(@sizeOf(init.InitInfo) * (harts - 1)) catch @trap());
    for (0..harts - 1) |i| {
        init_infos[i].pagetable_addr = memory.getPagetableAddr();
        init_infos[i].stack_addr = @intFromPtr(&stacks[i]);
    }

    console.print("Boot Hart: {}\n", .{hartId()});

    for (0..harts) |i| {
        if (i != hartId()) {
            const info_index = if (i <= hartId()) i else i - 1;
            const info_addr = memory.getPAddr(&init_infos[info_index]);

            sbi.sbiHartStart(i, memory_info.start_addr, info_addr);
        }
    }
}

export fn main(boot_hart: bool) noreturn {
    enableInterrupts();

    if (boot_hart) {
        memory.setupMemory();
        initHarts();

        enableTimer();

        console.print("shutting down in 5 seconds...\n", .{});
    } else {
        console.print("hello from hart {}!\n", .{hartId()});
    }

    while (true) {
        asm volatile ("wfi");
    }
}
