const std = @import("std");
const scan = @import("scan.zig").scan;
const Queue = @import("queue.zig").Queue;

const Node = struct {
    const Self = @This();
    const DPair = struct {
        node: *Self,
        dist: i32,
    };

    id: u16,
    rate: i32,
    next: std.ArrayList(DPair),

    fn init(allocator: std.mem.Allocator) !*Self {
        var s = try allocator.create(Self);
        s.* = .{
            .id = std.math.maxInt(u16),
            .rate = -1,
            .next = std.ArrayList(DPair).init(allocator),
        };
        return s;
    }

    fn deinit(self: *Self) void {
        const allocator = self.next.allocator;
        self.next.deinit();
        allocator.destroy(self);
    }
};

fn getNode(graph: *std.AutoHashMap([2]u8, *Node), name: [2]u8, allocator: std.mem.Allocator) !*Node {
    var entry: *Node = undefined;
    if (graph.get(name)) |v| {
        entry = v;
    } else {
        entry = try Node.init(allocator);
        errdefer entry.deinit();
        entry.id = @intCast(u16, graph.count());
        try graph.put(name, entry);
    }
    return entry;
}

const DistQueue = Queue(struct {
    n: *Node,
    dist: i32,
});

fn dist(a: *Node, b: *Node, q: *DistQueue) !i32 {
    q.clear();

    try q.add(.{ .n = a, .dist = 0 });
    while (true) {
        const d = q.remove();
        if (d.n == b) return d.dist;
        for (d.n.next.items) |n| {
            try q.add(.{ .n = n.node, .dist = d.dist + n.dist });
        }
    }
}

const DFSCache = std.AutoHashMap(struct {
    t: i32,
    n: u16,
    curr: i32,
    mask: u64,
}, i32);

const ResultStore = std.AutoHashMap(u64, i32);

fn dfs(
    cache: *DFSCache,
    n: *Node,
    t: i32,
    curr: i32,
    result: ?*ResultStore,
    on_valves: u64,
) anyerror!i32 {
    if (t <= 0) {
        if (result) |c| {
            var gop = try c.getOrPut(on_valves);
            gop.value_ptr.* = if (gop.found_existing) std.math.max(gop.value_ptr.*, curr) else curr;
        }
        return curr;
    }

    const on: bool = (on_valves & @as(u64, 1) <<| @intCast(u64, n.id) == 0);
    const key = .{ .n = n.id, .t = t, .curr = curr, .mask = on_valves };
    if (cache.get(key)) |v| return v;

    var v: i32 = std.math.minInt(i32);
    if (n.rate != 0 and on) {
        for (n.next.items) |nn| {
            v = std.math.max(v, try dfs(
                cache,
                nn.node,
                t - nn.dist - 1,
                curr + (t - 1) * n.rate,
                result,
                on_valves | @as(u64, 1) <<| @intCast(u64, n.id),
            ));
        }
    }
    for (n.next.items) |nn| {
        v = std.math.max(v, try dfs(cache, nn.node, t - nn.dist, curr, result, on_valves));
    }

    try cache.putNoClobber(key, v);
    return v;
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var graph = std.AutoHashMap([2]u8, *Node).init(allocator);
    var simp_graph = std.AutoHashMap([2]u8, *Node).init(allocator);

    defer {
        var it = graph.iterator();
        while (it.next()) |v| {
            v.value_ptr.*.deinit();
        }
        graph.deinit();

        it = simp_graph.iterator();
        while (it.next()) |v| {
            v.value_ptr.*.deinit();
        }
        simp_graph.deinit();
    }

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var name: [2]u8 = undefined;
        var rate: i32 = undefined;
        const rest = line[try scan(line, "Valve {c}{c} has flow rate={d}; ", .{ &name[0], &name[1], &rate })..];

        var entry: *Node = try getNode(&graph, name, allocator);
        entry.rate = rate;

        if (rate != 0 or (name[0] == 'A' and name[1] == 'A')) {
            var n = try getNode(&simp_graph, name, allocator);
            n.rate = rate;
        }

        if (scan(rest, "tunnel leads to valve {c}{c}", .{ &name[0], &name[1] })) |_| {
            const dst: *Node = try getNode(&graph, name, allocator);
            try entry.next.append(.{
                .node = dst,
                .dist = 1,
            });
        } else |_| {
            var it = std.mem.split(u8, rest[23..], ", ");
            while (it.next()) |n| {
                const dst: *Node = try getNode(&graph, .{ n[0], n[1] }, allocator);
                try entry.next.append(.{
                    .node = dst,
                    .dist = 1,
                });
            }
        }
    }

    {
        var q = DistQueue.init(allocator);
        defer q.deinit();

        var it = simp_graph.iterator();
        while (it.next()) |a| {
            var it2 = simp_graph.iterator();
            while (it2.next()) |b| {
                if (std.mem.eql(u8, &a.key_ptr.*, &b.key_ptr.*)) continue;
                const d = try dist(graph.get(a.key_ptr.*).?, graph.get(b.key_ptr.*).?, &q);
                try a.value_ptr.*.next.append(.{ .node = b.value_ptr.*, .dist = d });
            }
        }
    }

    var cache = DFSCache.init(allocator);
    defer cache.deinit();

    var part_1: i32 = 0;
    {
        part_1 = try dfs(&cache, simp_graph.get(.{ 'A', 'A' }).?, 30, 0, null, 0);
    }
    var part_2: i32 = 0;
    {
        cache.clearRetainingCapacity();

        var result = ResultStore.init(allocator);
        defer result.deinit();
        _ = try dfs(&cache, simp_graph.get(.{ 'A', 'A' }).?, 26, 0, &result, 0);

        var it = result.iterator();
        while (it.next()) |a| {
            var it2 = result.iterator();
            while (it2.next()) |b| {
                if (a.key_ptr.* & b.key_ptr.* == 0) {
                    part_2 = std.math.max(a.value_ptr.* + b.value_ptr.*, part_2);
                }
            }
        }
    }

    const result = .{
        .part_1 = part_1,
        .part_2 = part_2,
    };
    return result;
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin, allocator);

    try std.fmt.format(stdout, "Part 1: {}\n", .{result.part_1});
    try std.fmt.format(stdout, "Part 2: {}\n", .{result.part_2});
}

test "day16" {
    const input =
        \\Valve AA has flow rate=0; tunnels lead to valves DD, II, BB
        \\Valve BB has flow rate=13; tunnels lead to valves CC, AA
        \\Valve CC has flow rate=2; tunnels lead to valves DD, BB
        \\Valve DD has flow rate=20; tunnels lead to valves CC, AA, EE
        \\Valve EE has flow rate=3; tunnels lead to valves FF, DD
        \\Valve FF has flow rate=0; tunnels lead to valves EE, GG
        \\Valve GG has flow rate=0; tunnels lead to valves FF, HH
        \\Valve HH has flow rate=22; tunnel leads to valve GG
        \\Valve II has flow rate=0; tunnels lead to valves AA, JJ
        \\Valve JJ has flow rate=21; tunnel leads to valve II
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(1651 == result.part_1);
    try std.testing.expect(1707 == result.part_2);
}
