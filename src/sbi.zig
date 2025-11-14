const root = @import("root");
const console = @import("console.zig");

const SBI_TIME = 0x54494D45;
const SBI_TIME_SET_TIMER = 0;

const SBI_DBCN = 0x4442434E;
const SBI_DBCN_CONSOLE_WRITE = 0;
const SBI_DBCN_CONSOLE_WRITE_BYTE = 2;

const SBI_SRST = 0x53525354;
const SBI_SRST_SYSTEM_RESET = 0;

const SBI_HSM = 0x48534D;
const SBI_HSM_HART_GET_STATUS = 2;

const SbiError = enum(i64) {
    SBI_SUCCESS = 0,
    SBI_ERR_FAILED = -1,
    SBI_ERR_NOT_SUPPORTED = -2,
    SBI_ERR_INVALID_PARAM = -3,
    SBI_ERR_DENIED = -4,
    SBI_ERR_INVALID_ADDRESS = -5,
    SBI_ERR_ALREADY_AVAILABLE = -6,
    SBI_ERR_ALREADY_STARTED = -7,
    SBI_ERR_ALREADY_STOPPED = -8,
    SBI_ERR_NO_SHMEM = -9,
    SBI_ERR_INVALID_STATE = -10,
    SBI_ERR_BAD_RANGE = -11,
    SBI_ERR_TIMEOUT = -12,
    SBI_ERR_IO = -13,
    SBI_ERR_DENIED_LOCKED = -14,
};

const SbiValue = extern union { value: i64, uvalue: u64 };

inline fn sbiCall5(edid: usize, fid: usize, arg0: anytype, arg1: anytype, arg2: anytype, arg3: anytype, arg4: anytype) SbiValue {
    return @bitCast(asm volatile (
        \\ ecall
        : [ret] "={a1}" (-> u64),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [fid] "{a6}" (fid),
          [edid] "{a7}" (edid),
          // a0 and a1
        : .{ .x10 = true, .x11 = true, .memory = true }));
}

inline fn sbiCall1(edid: usize, fid: usize, arg0: anytype) SbiValue {
    return sbiCall5(edid, fid, arg0, 0, 0, 0, 0);
}

inline fn sbiCall2(edid: usize, fid: usize, arg0: anytype, arg1: anytype) SbiValue {
    return sbiCall5(edid, fid, arg0, arg1, 0, 0, 0);
}

inline fn sbiCall3(edid: usize, fid: usize, arg0: anytype, arg1: anytype, arg2: anytype) SbiValue {
    return sbiCall5(edid, fid, arg0, arg1, arg2, 0, 0);
}

inline fn sbiCall4(edid: usize, fid: usize, arg0: anytype, arg1: anytype, arg2: anytype, arg3: anytype) SbiValue {
    return sbiCall5(edid, fid, arg0, arg1, arg2, arg3, 0);
}

pub fn sbiDebugConsoleWrite(text: []const u8) void {
    _ = sbiCall3(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE, text.len, text.ptr - root.memory_info.virtual_diff, 0x0);
}

pub fn sbiDebugConsoleWriteByte(byte: u8) void {
    _ = sbiCall1(SBI_DBCN, SBI_DBCN_CONSOLE_WRITE_BYTE, byte);
}

pub fn sbiSetTimer(value: u64) void {
    _ = sbiCall1(SBI_TIME, SBI_TIME_SET_TIMER, value);
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
    _ = sbiCall2(SBI_SRST, SBI_SRST_SYSTEM_RESET, reset_type, reset_reason);
}

pub const SbiHartState = enum(u64) {
    Started = 0,
    Stopped = 1,
    StartPending = 2,
    StopPending = 3,
    Suspended = 4,
    SuspendPending = 5,
    ResumePending = 6,
};

pub fn sbiHartGetStatus(hartId: u64) SbiHartState {
    const ret = sbiCall1(SBI_HSM, SBI_HSM_HART_GET_STATUS, hartId);

    return @enumFromInt(ret.uvalue);
}
