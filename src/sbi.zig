const root = @import("root");
const console = @import("console.zig");

const SBI_TIME = 0x54494D45;
const SBI_TIME_SET_TIMER = 0;

const SBI_DBCN = 0x4442434E;
const SBI_DBCN_CONSOLE_WRITE = 0;
const SBI_DBCN_CONSOLE_WRITE_BYTE = 2;

const SBI_SRST = 0x53525354;
const SBI_SRST_SYSTEM_RESET = 0;

inline fn sbiCall1(edid: usize, fid: usize, arg0: anytype) void {
    asm volatile ("ecall"
        :
        : [arg0] "{a0}" (arg0),
          [fid] "{a6}" (fid),
          [edid] "{a7}" (edid),
          // a0 and a1
        : .{ .x10 = true, .x11 = true });
}

inline fn sbiCall2(edid: usize, fid: usize, arg0: anytype, arg1: anytype) void {
    asm volatile ("ecall"
        :
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
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

pub fn sbiDebugConsoleWrite(text: []const u8) void {
    sbiCall3(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE, text.len, text.ptr - root.memory_info.virtual_diff, 0x0);
}

pub fn sbiDebugConsoleWriteByte(byte: u8) void {
    sbiCall1(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE_BYTE, byte);
}

pub fn sbiSetTimer(value: u64) void {
    sbiCall1(SBI_TIME, SBI_TIME_SET_TIMER, value);
}

pub const SbiSrstResetType = enum(u32) {
    Shutdown = 0,
    ColdReboot = 1,
    WarmReboot = 2,
};

pub const SbiSrstResetReason = enum(u32) {
    NoReason = 0,
    SystemFailure = 1,
};
pub fn sbiSystemReset(reset_type: SbiSrstResetType, reset_reason: SbiSrstResetReason) void {
    sbiCall2(SBI_SRST, SBI_SRST_SYSTEM_RESET, reset_type, reset_reason);
}
