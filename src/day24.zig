const std = @import("std");
const Queue = @import("queue.zig").Queue;

const Blizzard = struct {
    position: [2]i32,
    velocity: [2]i2,
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var blizzards = std.ArrayList(Blizzard).init(allocator);
    defer blizzards.deinit();

    var rows: i32 = 0;
    var cols: i32 = 0;

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line[2] == '#') continue;
        for (line[1 .. line.len - 1]) |c, i| {
            if (c == '.') continue;
            try blizzards.append(.{
                .position = [_]i32{ @intCast(i32, i), rows },
                .velocity = switch (c) {
                    '^' => [_]i2{ 0, -1 },
                    'v' => [_]i2{ 0, 1 },
                    '>' => [_]i2{ 1, 0 },
                    '<' => [_]i2{ -1, 0 },
                    else => unreachable,
                },
            });
        }
        rows += 1;
        cols = @intCast(i32, line.len) - 2;
    }

    var part_1: i32 = std.math.maxInt(i32);
    var part_2: i32 = undefined;
    {
        const BFSState = struct {
            position: [2]i32,
            t: i32,
            reach_end: [2]bool,
        };
        var bfs = Queue(BFSState).init(allocator);
        defer bfs.deinit();

        var visited = std.AutoHashMap(BFSState, void).init(allocator);
        defer visited.deinit();

        var bmap = std.AutoHashMap([2]i32, void).init(allocator);
        defer bmap.deinit();

        try bfs.add(.{ .position = [_]i32{ 0, -1 }, .t = 0, .reach_end = .{ false, false } });

        var t: i32 = -1;
        while (bfs.len > 0) {
            var s = bfs.remove();

            if (visited.contains(s)) continue;
            try visited.putNoClobber(s, {});
            if (s.t != t) {
                t = s.t;
                visited.clearRetainingCapacity();
                bmap.clearRetainingCapacity();

                for (blizzards.items) |b| {
                    try bmap.put(.{
                        @mod(b.position[0] + t * b.velocity[0], cols),
                        @mod(b.position[1] + t * b.velocity[1], rows),
                    }, {});
                }
            }

            if (s.position[1] == -1) {
                try bfs.add(.{ .position = s.position, .t = s.t + 1, .reach_end = s.reach_end });
                try bfs.add(.{ .position = [_]i32{ s.position[0], s.position[1] + 1 }, .t = s.t + 1, .reach_end = s.reach_end });
            } else if (s.position[1] == rows) {
                part_1 = std.math.min(part_1, s.t);
                try bfs.add(.{ .position = s.position, .t = s.t + 1, .reach_end = s.reach_end });
                try bfs.add(.{ .position = [_]i32{ s.position[0], s.position[1] - 1 }, .t = s.t + 1, .reach_end = s.reach_end });
            } else if (!bmap.contains(s.position)) {
                if (s.position[0] == cols - 1 and s.position[1] == rows - 1) {
                    if (s.reach_end[0] == false) {
                        // first goal
                        try bfs.add(.{ .position = [_]i32{ s.position[0], s.position[1] + 1 }, .t = s.t + 1, .reach_end = .{ true, false } });
                    }
                    if (s.reach_end[1] == true) {
                        // third exit
                        part_2 = s.t + 1;
                        break;
                    }
                }
                if (s.position[0] == 0 and s.position[1] == 0 and s.reach_end[0] == true) {
                    // second goal
                    try bfs.add(.{ .position = [_]i32{ s.position[0], s.position[1] - 1 }, .t = s.t + 1, .reach_end = .{ true, true } });
                }

                try bfs.add(.{ .position = s.position, .t = s.t + 1, .reach_end = s.reach_end });
                if (s.position[0] < cols - 1) try bfs.add(.{ .position = [_]i32{ s.position[0] + 1, s.position[1] }, .t = s.t + 1, .reach_end = s.reach_end });
                if (s.position[0] > 0) try bfs.add(.{ .position = [_]i32{ s.position[0] - 1, s.position[1] }, .t = s.t + 1, .reach_end = s.reach_end });
                if (s.position[1] < rows - 1) try bfs.add(.{ .position = [_]i32{ s.position[0], s.position[1] + 1 }, .t = s.t + 1, .reach_end = s.reach_end });
                if (s.position[1] > 0) try bfs.add(.{ .position = [_]i32{ s.position[0], s.position[1] - 1 }, .t = s.t + 1, .reach_end = s.reach_end });
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

test "day24" {
    const input =
        \\#.######
        \\#>>.<^<#
        \\#.<..<<#
        \\#>v.><>#
        \\#<^v^^>#
        \\######.#
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(18 == result.part_1);
    try std.testing.expect(54 == result.part_2);
}
