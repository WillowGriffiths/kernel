pub inline fn csrWrite(comptime csr: []const u8, value: anytype) void {
    _ = asm volatile ("csrw " ++ csr ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

pub inline fn csrSet(comptime csr: []const u8, value: anytype) void {
    _ = asm volatile ("csrs " ++ csr ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

pub inline fn csrClear(comptime csr: []const u8, value: anytype) void {
    _ = asm volatile ("csrc " ++ csr ++ ", %[value]"
        :
        : [value] "r" (value),
    );
}

pub inline fn csrRead(comptime csr: []const u8) usize {
    return asm volatile ("csrr %[ret]," ++ csr
        : [ret] "=r" (-> usize),
    );
}

pub inline fn readTime() usize {
    return asm volatile ("rdtime %[ret]"
        : [ret] "=r" (-> usize),
    );
}

pub inline fn sfenceVma() void {
    asm volatile ("sfence.vma zero, zero");
}
