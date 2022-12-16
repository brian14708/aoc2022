const std = @import("std");
const scan = @import("scan.zig").scan;

fn dist(a: [2]i32, b: [2]i32) i32 {
    return (std.math.absInt(a[0] - b[0]) catch unreachable) + (std.math.absInt(a[1] - b[1]) catch unreachable);
}

fn mergeIntervals(intervals: *std.ArrayList([2]i32)) void {
    std.sort.sort([2]i32, intervals.items, {}, struct {
        fn inner(_: void, a: [2]i32, b: [2]i32) bool {
            if (a[0] == b[0]) return a[1] < b[1];
            return a[0] < b[0];
        }
    }.inner);

    var idx: usize = 0;
    for (intervals.items[1..]) |r| {
        var c = &intervals.items[idx];
        if (r[0] <= c[1] + 1) {
            c[1] = std.math.max(c[1], r[1]);
        } else {
            idx += 1;
            intervals.items[idx] = r;
        }
    }
    intervals.shrinkRetainingCapacity(idx + 1);
}

fn solve(reader: anytype, row: i32, area: i32, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i64,
} {
    const Input = struct {
        sensor: [2]i32,
        beacon: [2]i32,
        radius: i32,

        fn chord(self: @This(), row_at: i32) ?[2]i32 {
            const dy = std.math.absInt(row_at - self.sensor[1]) catch unreachable;
            const dx = self.radius - dy;
            if (dx < 0) return null;
            return [_]i32{ self.sensor[0] - dx, self.sensor[0] + dx };
        }
    };

    var input = std.ArrayList(Input).init(allocator);
    defer input.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var i: Input = undefined;
        _ = try scan(line, "Sensor at x={d}, y={d}: closest beacon is at x={d}, y={d}", .{
            &i.sensor[0],
            &i.sensor[1],
            &i.beacon[0],
            &i.beacon[1],
        });
        i.radius = dist(i.sensor, i.beacon);
        try input.append(i);
    }

    var intervals = std.ArrayList([2]i32).init(allocator);
    defer intervals.deinit();

    var part_1: i32 = 0;
    {
        var beacons = std.ArrayList([2]i32).init(allocator);
        defer beacons.deinit();

        for (input.items) |i| {
            if (i.chord(row)) |ch| {
                try intervals.append(ch);
            }
            if (i.beacon[1] == row) {
                try beacons.append(.{ i.beacon[0], i.beacon[0] });
            }
        }

        mergeIntervals(&intervals);
        for (intervals.items) |s| {
            part_1 += s[1] - s[0] + 1;
        }
        mergeIntervals(&beacons);
        for (beacons.items) |s| {
            part_1 -= s[1] - s[0] + 1;
        }
    }

    var part_2: i64 = 0;
    {
        var y: i32 = 0;
        while (y <= area) : (y += 1) {
            intervals.shrinkRetainingCapacity(0);

            for (input.items) |i| {
                if (i.chord(y)) |ch| {
                    try intervals.append(.{
                        std.math.max(0, ch[0]),
                        std.math.min(area, ch[1]),
                    });
                }
            }
            mergeIntervals(&intervals);
            if (intervals.items.len != 1) {
                part_2 = @intCast(i64, (intervals.items[0][1] + 1)) * 4000000 + y;
                break;
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
    const result = try solve(stdin, 2000000, 4000000, allocator);

    try std.fmt.format(stdout, "Part 1: {}\n", .{result.part_1});
    try std.fmt.format(stdout, "Part 2: {}\n", .{result.part_2});
}

test "day14" {
    const input =
        \\Sensor at x=2, y=18: closest beacon is at x=-2, y=15
        \\Sensor at x=9, y=16: closest beacon is at x=10, y=16
        \\Sensor at x=13, y=2: closest beacon is at x=15, y=3
        \\Sensor at x=12, y=14: closest beacon is at x=10, y=16
        \\Sensor at x=10, y=20: closest beacon is at x=10, y=16
        \\Sensor at x=14, y=17: closest beacon is at x=10, y=16
        \\Sensor at x=8, y=7: closest beacon is at x=2, y=10
        \\Sensor at x=2, y=0: closest beacon is at x=2, y=10
        \\Sensor at x=0, y=11: closest beacon is at x=2, y=10
        \\Sensor at x=20, y=14: closest beacon is at x=25, y=17
        \\Sensor at x=17, y=20: closest beacon is at x=21, y=22
        \\Sensor at x=16, y=7: closest beacon is at x=15, y=3
        \\Sensor at x=14, y=3: closest beacon is at x=15, y=3
        \\Sensor at x=20, y=1: closest beacon is at x=15, y=3
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), 10, 20, std.testing.allocator);

    try std.testing.expect(26 == result.part_1);
    try std.testing.expect(56000011 == result.part_2);
}
