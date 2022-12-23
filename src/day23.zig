const std = @import("std");

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var map = std.AutoHashMap([2]i32, void).init(allocator);
    defer map.deinit();

    var buf: [8192]u8 = undefined;
    var y: i32 = 0;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        for (line) |c, x| {
            if (c == '#') try map.put(.{ @intCast(i32, x), y }, {});
        }
        y -= 1;
    }

    const ProposeValue = struct {
        from: [2]i32,
        is_conflict: bool,
    };
    var propose = std.AutoHashMap([2]i32, ProposeValue).init(allocator);
    defer propose.deinit();
    var order: [4]u8 = .{ 'N', 'S', 'W', 'E' };
    var i: i32 = 0;

    var part_1: i32 = undefined;
    var part_2: i32 = undefined;
    while (true) : (i += 1) {
        propose.clearRetainingCapacity();
        {
            var it = map.iterator();
            while (it.next()) |entry| {
                const src = entry.key_ptr.*;
                var dst = src;

                const neighbor: [8]bool = .{
                    map.contains(.{ src[0] - 1, src[1] + 1 }), // 0 NW
                    map.contains(.{ src[0] + 0, src[1] + 1 }), // 1 N
                    map.contains(.{ src[0] + 1, src[1] + 1 }), // 2 NE
                    map.contains(.{ src[0] - 1, src[1] + 0 }), // 3 W
                    map.contains(.{ src[0] + 1, src[1] + 0 }), // 4 E
                    map.contains(.{ src[0] - 1, src[1] - 1 }), // 5 SW
                    map.contains(.{ src[0] + 0, src[1] - 1 }), // 6 S
                    map.contains(.{ src[0] + 1, src[1] - 1 }), // 7 SE
                };
                if (!std.mem.allEqual(bool, &neighbor, false)) {
                    for (order) |d| {
                        if (d == 'N' and !neighbor[0] and !neighbor[1] and !neighbor[2]) {
                            dst[1] += 1;
                            break;
                        }
                        if (d == 'S' and !neighbor[5] and !neighbor[6] and !neighbor[7]) {
                            dst[1] -= 1;
                            break;
                        }
                        if (d == 'W' and !neighbor[0] and !neighbor[3] and !neighbor[5]) {
                            dst[0] -= 1;
                            break;
                        }
                        if (d == 'E' and !neighbor[2] and !neighbor[4] and !neighbor[7]) {
                            dst[0] += 1;
                            break;
                        }
                    }
                }

                var g = try propose.getOrPut(dst);
                if (g.found_existing) {
                    try propose.put(src, .{ .from = src, .is_conflict = true });
                    g.value_ptr.*.is_conflict = true;
                } else {
                    g.value_ptr.* = .{ .from = src, .is_conflict = false };
                }
            }
        }

        map.clearRetainingCapacity();
        var pit = propose.iterator();
        var move: bool = false;
        while (pit.next()) |p| {
            if (!p.value_ptr.*.is_conflict) {
                if (!std.meta.eql(p.key_ptr.*, p.value_ptr.from)) {
                    move = true;
                }
                try map.put(p.key_ptr.*, {});
            } else {
                try map.put(p.value_ptr.*.from, {});
            }
        }

        var min: [2]i32 = .{ std.math.maxInt(i32), std.math.maxInt(i32) };
        var max: [2]i32 = .{ std.math.minInt(i32), std.math.minInt(i32) };
        {
            var it = map.keyIterator();
            while (it.next()) |pt| {
                min[0] = std.math.min(min[0], pt[0]);
                min[1] = std.math.min(min[1], pt[1]);
                max[0] = std.math.max(max[0], pt[0]);
                max[1] = std.math.max(max[1], pt[1]);
            }
        }

        if (i == 9) {
            part_1 = (max[1] - min[1] + 1) * (max[0] - min[0] + 1) - @intCast(i32, map.count());
        }
        if (!move) {
            part_2 = i + 1;
            break;
        }
        std.mem.rotate(u8, &order, 1);
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

test "day23" {
    const input =
        \\..............
        \\..............
        \\.......#......
        \\.....###.#....
        \\...#...#.#....
        \\....#...##....
        \\...#.###......
        \\...##.#.##....
        \\....#..#......
        \\..............
        \\..............
        \\..............
    ;
    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(110 == result.part_1);
    try std.testing.expect(20 == result.part_2);
}
