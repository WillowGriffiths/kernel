const root = @import("root");
const pagetable = @import("pagetable.zig");
const util = @import("util.zig");
const console = @import("console.zig");

const max_nodes = (0x1000 - @sizeOf(MemoryHeader)) / @sizeOf(MemoryNode);

const MemoryHeader = struct {
    next: *MemoryHeader,
    prev: *MemoryHeader,

    fn getNodes(self: *MemoryHeader) *[max_nodes]MemoryNode {
        const self_mathable: [*]MemoryHeader = @ptrCast(self);
        return @ptrCast(self_mathable + @sizeOf(MemoryHeader));
    }
};

const MemoryNodeChildType = enum {
    free,
    child,
    allocated,
};

const MemoryNodeChild = union(MemoryNodeChildType) {
    free: void,
    child: *MemoryNode,
    allocated: void,
};

const MemoryNode = struct {
    valid: bool,
    left: MemoryNodeChild,
    right: MemoryNodeChild,
    up: ?*MemoryNode,
};

const min_allocation = 0x1000;
const ram_start = 0x80000000;
const ram_end = 0x87ffffff;
const virtual_ram_start = 0xffffffd600000000;

var max_order: usize = undefined;
var virtual_diff: usize = undefined;

var alloc_start: usize = undefined;
var root_node: MemoryNodeChild = undefined;
var memory_page: *align(4096) MemoryHeader = undefined;
var root_table: *align(4096) pagetable.PageTable = undefined;

extern const __virtual_end: anyopaque;
extern const __virtual_kernel_start: anyopaque;

pub fn buildInitialTree() void {
    const nodes = memory_page.getNodes();
    for (0..nodes.len) |i| {
        nodes[i].valid = false;
    }

    for (0..max_order) |i| {
        nodes[i].valid = true;

        if (i < max_order - 1) {
            nodes[i].left = .{ .child = &nodes[i + 1] };
        } else {
            nodes[i].left = .allocated;
        }

        nodes[i].right = .free;
        nodes[i + 1].up = &nodes[i];
    }

    root_node = .{ .child = &nodes[0] };
}

const AllocationError = error{
    TooBig,
    FailedToAllocateNode,
    AllocationFailed,
};

fn makeNode() !*MemoryNode {
    // TODO: allocate new memory pages

    const nodes = memory_page.getNodes();
    for (0..nodes.len) |i| {
        if (!nodes[i].valid) {
            nodes[i].valid = true;
            nodes[i].left = .free;
            nodes[i].right = .free;
            return &nodes[i];
        }
    }

    return AllocationError.FailedToAllocateNode;
}

fn makeAllocation(node: *MemoryNodeChild, order: usize, node_order: usize, addr: usize, up: ?*MemoryNode) !?usize {
    if (node_order < order) {
        return null;
    }

    switch (node.*) {
        .free => {
            if (node_order == order) {
                node.* = MemoryNodeChild.allocated;
                return addr;
            }

            node.* = MemoryNodeChild{ .child = try makeNode() };
            node.child.up = up;
            return makeAllocation(node, order, node_order, addr, up);
        },
        .child => {
            if (try makeAllocation(&node.child.left, order, node_order - 1, addr, node.child)) |left| {
                return left;
            } else {
                const child_addr = addr + (@as(usize, 1) << @intCast(node_order - 1)) * min_allocation;
                return makeAllocation(&node.child.right, order, node_order - 1, child_addr, node.child);
            }
        },
        else => {
            return null;
        },
    }
}

pub fn allocSize(size: usize) !*align(0x1000) anyopaque {
    var order: u6 = 0;
    while ((@as(usize, 1) << order) * min_allocation < size) {
        order += 1;

        if (order > max_order) {
            return AllocationError.TooBig;
        }
    }

    const allocation = try makeAllocation(&root_node, order, max_order, alloc_start, null);
    return @ptrFromInt(allocation orelse return AllocationError.AllocationFailed);
}

pub fn alloc(t: type) !*align(0x1000) t {
    const size = @sizeOf(t);

    return @ptrCast(try allocSize(size));
}

const MapError = error{
    AlreadyMapped,
    Unmapped,
};

fn makeTable() !*align(0x1000) pagetable.PageTable {
    const table = try alloc(pagetable.PageTable);
    for (0..table.len) |i| {
        table[i].flags.valid = false;
    }
    return table;
}

fn getVAddr(pa: usize) *anyopaque {
    // Relies on physical memory being mapped to a known place.
    // Early on in initialisation, this is straight after the kernel code.
    // After re-initialising paging, this becomes virtual_ram_start

    return @ptrFromInt(
        pa + virtual_diff,
    );
}

pub fn getPAddr(addr: *const anyopaque) usize {
    const va = @intFromPtr(addr);

    const level2_index = (va >> 30) & 0b111111111;
    const level1_index = (va >> 21) & 0b111111111;
    const level0_index = (va >> 12) & 0b111111111;
    const offset = va & 0xfff;

    const level1_addr = root_table[level2_index].get_addr();
    const level1_table: *pagetable.PageTable = @ptrCast(@alignCast(getVAddr(level1_addr)));

    const level0_addr = level1_table[level1_index].get_addr();
    const level0_table: *pagetable.PageTable = @ptrCast(@alignCast(getVAddr(level0_addr)));

    const base_addr = level0_table[level0_index].get_addr();
    return base_addr + offset;
}

fn map(level2_table: *align(0x1000) pagetable.PageTable, va: usize, pa: usize) !void {
    const level2_index = (va >> 30) & 0b111111111;
    const level1_index = (va >> 21) & 0b111111111;
    const level0_index = (va >> 12) & 0b111111111;

    if (!level2_table[level2_index].flags.valid) {
        const addr = getPAddr(try makeTable());
        level2_table[level2_index] = pagetable.PageTableEntry.create(.Table, addr);
    }

    const level1_table: *pagetable.PageTable = @ptrCast(@alignCast(getVAddr(level2_table[level2_index].get_addr())));

    if (!level1_table[level1_index].flags.valid) {
        const addr = getPAddr(try makeTable());
        level1_table[level1_index] = pagetable.PageTableEntry.create(.Table, addr);
    }

    const level0_table: *pagetable.PageTable = @ptrCast(@alignCast(getVAddr(level1_table[level1_index].get_addr())));
    if (level0_table[level0_index].flags.valid) {
        return MapError.AlreadyMapped;
    }

    level0_table[level0_index] = pagetable.PageTableEntry.create(.Leaf, pa);
}

inline fn fixRef(ref: *anyopaque) *anyopaque {
    return @ptrFromInt(@intFromPtr(ref) - root.memory_info.virtual_diff + virtual_diff);
}

fn fixMemoryTree(node: *MemoryNodeChild) void {
    switch (node.*) {
        .child => {
            node.child = @ptrCast(@alignCast(fixRef(node.child)));

            fixMemoryTree(&node.child.left);
            fixMemoryTree(&node.child.right);
        },
        else => {},
    }
}

fn fixRefs() void {
    virtual_diff = virtual_ram_start - ram_start;

    alloc_start = @intFromPtr(fixRef(@ptrFromInt(alloc_start)));
    root_table = @ptrCast(@alignCast(fixRef(root_table)));
    memory_page = @ptrCast(@alignCast(fixRef(memory_page)));

    fixMemoryTree(&root_node);
}

fn setupPagetables() !void {
    const table = try makeTable();

    const virtual_kernel_start = @intFromPtr(&__virtual_kernel_start);
    for (0..root.memory_info.kernel_pages) |i| {
        const va = virtual_kernel_start + i * 0x1000;
        const pa = root.memory_info.kernel_start + i * 0x1000;

        try map(table, va, pa);
    }

    const ram_pages = (ram_end - ram_start) / 0x1000 + 1;
    for (0..ram_pages) |i| {
        const va = virtual_ram_start + i * 0x1000;
        const pa = ram_start + i * 0x1000;

        if (i >= 200) {
            asm volatile ("nop");
        }

        try map(table, va, pa);
    }

    util.sfenceVma();

    const satp_sv39 = 8 << 60;
    const satp = (getPAddr(table) >> 12) | satp_sv39;

    util.csrWrite("satp", satp);

    util.sfenceVma();

    root_table = table;
    fixRefs();
}

pub fn setupMemory() void {
    virtual_diff = root.memory_info.virtual_diff;
    alloc_start = @intFromPtr(&__virtual_end);
    const alloc_start_physical = alloc_start - root.memory_info.virtual_diff;
    root_table = root.memory_info.table_root;

    var memory_order: u6 = 0;
    while ((@as(usize, 1) << memory_order) * min_allocation + alloc_start_physical < ram_end) {
        memory_order += 1;
    }

    max_order = memory_order;

    memory_page = @ptrFromInt(alloc_start);
    memory_page.* = .{
        .next = memory_page,
        .prev = memory_page,
    };

    buildInitialTree();
    setupPagetables() catch {};
}

pub fn getPagetableAddr() usize {
    return getPAddr(root_table);
}

pub fn setupHartMemory(pagetable_addr: usize) void {
    util.sfenceVma();

    const satp_sv39 = 8 << 60;
    const satp = (pagetable_addr >> 12) | satp_sv39;

    util.csrWrite("satp", satp);

    util.sfenceVma();
}
