pub const PageTableFlags = packed struct(u10) {
    valid: bool = true,
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    user: bool = false,
    global: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    _rsw: u2 = 3,

    pub const Table = PageTableFlags{};
    pub const Leaf = PageTableFlags{ .read = true, .write = true, .execute = true };
};

pub const PageTableEntry = packed struct(u64) {
    flags: PageTableFlags,
    ppn: u44,
    _reserved: u10 = 0,

    pub inline fn create(flags: PageTableFlags, physical_address: usize) PageTableEntry {
        //        return PageTableEntry{ .flags = flags, .ppn = @intCast(@as(i64, @bitCast(physical_address)) >> 12) };
        return @bitCast(((physical_address >> 12) << 10) | @as(u10, @bitCast(flags)));
    }

    pub inline fn get_addr(self: *PageTableEntry) usize {
        return @as(usize, self.ppn) << 12;
    }
};

pub const PageTable = [512]PageTableEntry;
