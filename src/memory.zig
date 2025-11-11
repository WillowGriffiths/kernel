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

var root_table: *align(4096) pagetable.PageTable = undefined;
var max_order: usize = undefined;
var alloc_start: usize = undefined;
var root_node: MemoryNodeChild = undefined;
var memory_page: *align(4096) MemoryHeader = undefined;

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

pub fn alloc(t: type) !*t {
    const size = @sizeOf(t);

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

pub fn setupMemory() void {
    alloc_start = root.memory_info.virtual_start + 0x1000 * root.memory_info.kernel_pages;
    const alloc_start_physical = alloc_start - root.memory_info.virtual_diff;

    console.print("{x}\n", .{alloc_start_physical});

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

    for (0..5) |_| {
        const addr = alloc([3]pagetable.PageTable) catch |err| {
            console.print("got an error: {}", .{err});
            return;
        };

        console.print("addr: {x}\n", .{@intFromPtr(addr)});
    }
}
