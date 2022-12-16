const std = @import("std");
const scan = @import("scan.zig").scan;

const Rope = struct {
    const Self = @This();
    const Position = struct {
        x: i32,
        y: i32,
    };
    head: Position,
    tail: Position,

    fn init() Self {
        return std.mem.zeroes(Self);
    }

    fn move(self: *Self, pos: Position) Position {
        self.head.x += pos.x;
        self.head.y += pos.y;
        self.update();
        return .{
            .x = self.tail.x,
            .y = self.tail.y,
        };
    }

    fn moveTo(self: *Self, pos: Position) Position {
        self.head.x = pos.x;
        self.head.y = pos.y;
        self.update();
        return .{
            .x = self.tail.x,
            .y = self.tail.y,
        };
    }

    fn sign(x: anytype) @TypeOf(x) {
        if (x > 0) return 1;
        if (x == 0) return 0;
        return -1;
    }

    fn update(self: *Self) void {
        var x = self.head.x - self.tail.x;
        var y = self.head.y - self.tail.y;
        if (x == 2 or x == -2 or y == 2 or y == -2) {
            self.tail.x += sign(x);
            self.tail.y += sign(y);
        }
    }

    test {
        var r = Self.init();
        try std.testing.expectEqual(Position{ .x = 0, .y = 0 }, r.move(.{ .x = 0, .y = 1 }));
        try std.testing.expectEqual(Position{ .x = 0, .y = 1 }, r.move(.{ .x = 0, .y = 1 }));
        r = Self.init();
        try std.testing.expectEqual(Position{ .x = 0, .y = 0 }, r.move(.{ .x = 1, .y = 1 }));
        try std.testing.expectEqual(Position{ .x = 1, .y = 1 }, r.move(.{ .x = 0, .y = 1 }));
    }
};

const VisitMap = struct {
    const Self = @This();
    data: std.ArrayList(Rope.Position),

    fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.ArrayList(Rope.Position).init(allocator),
        };
    }

    fn deinit(self: Self) void {
        self.data.deinit();
    }

    fn push(self: *Self, p: Rope.Position) !void {
        for (self.data.items) |it| {
            if (p.x == it.x and p.y == it.y) break;
        } else {
            try self.data.append(p);
        }
    }

    fn count(self: Self) u32 {
        return @intCast(u32, self.data.items.len);
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u32,
    part_2: u32,
} {
    var r = std.ArrayList(Rope).init(allocator);
    defer r.deinit();
    try r.appendNTimes(Rope.init(), 9);

    var first_tail = VisitMap.init(allocator);
    defer first_tail.deinit();
    var chain_tail = VisitMap.init(allocator);
    defer chain_tail.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var ch: u8 = undefined;
        var cnt: i32 = undefined;
        _ = try scan(line, "{c} {d}", .{ &ch, &cnt });
        var dir: Rope.Position = switch (ch) {
            'R' => .{ .x = 1, .y = 0 },
            'L' => .{ .x = -1, .y = 0 },
            'U' => .{ .x = 0, .y = 1 },
            'D' => .{ .x = 0, .y = -1 },
            else => unreachable,
        };

        var i: usize = 0;
        while (i < cnt) : (i += 1) {
            var pos: Rope.Position = dir;
            for (r.items) |*rr, idx| {
                if (idx == 0) {
                    pos = rr.move(pos);
                    try first_tail.push(pos);
                } else {
                    pos = rr.moveTo(pos);
                }
            }
            try chain_tail.push(pos);
        }
    }

    const result = .{
        .part_1 = first_tail.count(),
        .part_2 = chain_tail.count(),
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

test "day09" {
    const input =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(13 == result.part_1);
    try std.testing.expect(1 == result.part_2);
}

test "day09 - large" {
    const input =
        \\R 5
        \\U 8
        \\L 8
        \\D 3
        \\R 17
        \\D 10
        \\L 25
        \\U 20
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(36 == result.part_2);
}
