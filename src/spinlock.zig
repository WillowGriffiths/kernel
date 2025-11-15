const std = @import("std");

pub const SpinLock = struct {
    locked: bool = false,

    pub fn acquire(self: *SpinLock) void {
        while (@atomicRmw(bool, &self.locked, .Xchg, true, .acquire) != false) {}
    }

    pub fn release(self: *SpinLock) void {
        @atomicStore(bool, &self.locked, false, .release);
    }
};
