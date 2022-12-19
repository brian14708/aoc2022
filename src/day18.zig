const std = @import("std");
const scan = @import("scan.zig").scan;
const Queue = @import("queue.zig").Queue;

fn sortBy(comptime N: usize, comptime T: type, items: [][N]T, idx: [N]usize) void {
    std.sort.sort(
        [N]T,
        items,
        idx,
        struct {
            fn inner(inner_idx: [N]usize, a: [N]T, b: [N]T) bool {
                for (inner_idx) |i| {
                    if (a[i] == b[i]) {
                        continue;
                    }
                    return a[i] < b[i];
                }
                return false;
            }
        }.inner,
    );
}

fn surfaceArea(pts: [][3]i32) i32 {
    if (pts.len == 0) return 0;
    if (pts.len == 1) return 6;
    var result = @intCast(i32, pts.len) * 6;
    sortBy(3, i32, pts, .{ 1, 2, 0 });
    for (pts[0 .. pts.len - 1]) |pt, idx| {
        if (pt[0] == pts[idx + 1][0] - 1 and pt[1] == pts[idx + 1][1] and pt[2] == pts[idx + 1][2]) {
            result -= 2;
        }
    }
    sortBy(3, i32, pts, .{ 0, 2, 1 });
    for (pts[0 .. pts.len - 1]) |pt, idx| {
        if (pt[1] == pts[idx + 1][1] - 1 and pt[0] == pts[idx + 1][0] and pt[2] == pts[idx + 1][2]) {
            result -= 2;
        }
    }
    sortBy(3, i32, pts, .{ 0, 1, 2 });
    for (pts[0 .. pts.len - 1]) |pt, idx| {
        if (pt[2] == (pts[idx + 1][2] - 1) and pt[0] == pts[idx + 1][0] and pt[1] == pts[idx + 1][1]) {
            result -= 2;
        }
    }
    return result;
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var points = std.ArrayList([3]i32).init(allocator);
    defer points.deinit();

    var points_fill = std.AutoHashMap([3]i32, i32).init(allocator);
    defer points_fill.deinit();

    var min: [3]i32 = .{ std.math.maxInt(i32), std.math.maxInt(i32), std.math.maxInt(i32) };
    var max: [3]i32 = .{ std.math.minInt(i32), std.math.minInt(i32), std.math.minInt(i32) };

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var pt: [3]i32 = undefined;
        _ = try scan(line, "{d},{d},{d}", .{ &pt[0], &pt[1], &pt[2] });
        try points.append(pt);
        try points_fill.putNoClobber(pt, 1);
        min = .{
            std.math.min(min[0], pt[0]),
            std.math.min(min[1], pt[1]),
            std.math.min(min[2], pt[2]),
        };
        max = .{
            std.math.max(max[0], pt[0]),
            std.math.max(max[1], pt[1]),
            std.math.max(max[2], pt[2]),
        };
    }
    max = .{ max[0] + 1, max[1], max[2] };

    var part_1 = surfaceArea(points.items);

    var bfs = Queue([3]i32).init(allocator);
    defer bfs.deinit();
    try bfs.add(max);
    while (bfs.len > 0) {
        var top = bfs.remove();
        if (top[0] > max[0] or top[0] < min[0]) continue;
        if (top[1] > max[1] or top[1] < min[1]) continue;
        if (top[2] > max[2] or top[2] < min[2]) continue;
        if (points_fill.get(top) == null) {
            try points_fill.put(top, 2);
            try bfs.add(.{ top[0] - 1, top[1], top[2] });
            try bfs.add(.{ top[0] + 1, top[1], top[2] });
            try bfs.add(.{ top[0], top[1] - 1, top[2] });
            try bfs.add(.{ top[0], top[1] + 1, top[2] });
            try bfs.add(.{ top[0], top[1], top[2] - 1 });
            try bfs.add(.{ top[0], top[1], top[2] + 1 });
        }
    }

    var i = min[0];
    while (i <= max[0]) : (i += 1) {
        var j = min[1];
        while (j <= max[1]) : (j += 1) {
            var k = min[2];
            while (k <= max[2]) : (k += 1) {
                var g = try points_fill.getOrPut(.{ i, j, k });
                if (!g.found_existing) {
                    g.value_ptr.* = 0;
                }
            }
        }
    }

    points.clearRetainingCapacity();
    var it = points_fill.iterator();
    while (it.next()) |p| {
        if (p.value_ptr.* == 0) {
            try points.append(p.key_ptr.*);
        }
    }

    var part_2 = surfaceArea(points.items);

    const result = .{
        .part_1 = part_1,
        .part_2 = part_1 - part_2,
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

test "day18" {
    const input =
        \\2,2,2
        \\1,2,2
        \\3,2,2
        \\2,1,2
        \\2,3,2
        \\2,2,1
        \\2,2,3
        \\2,2,4
        \\2,2,6
        \\1,2,5
        \\3,2,5
        \\2,1,5
        \\2,3,5
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(64 == result.part_1);
    try std.testing.expect(58 == result.part_2);
}
