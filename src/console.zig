const std = @import("std");
const sbi = @import("sbi.zig");
const spinlock = @import("spinlock.zig");

fn writerCallback(_: void, data: []const u8) error{}!usize {
    sbi.sbiDebugConsoleWrite(data);
    return data.len;
}

const writer = std.Io.GenericWriter(void, error{}, writerCallback){ .context = undefined };

var lock = spinlock.SpinLock{};

pub fn print(comptime fmt: []const u8, args: anytype) void {
    lock.acquire();

    writer.print(fmt, args) catch {};

    lock.release();
}
