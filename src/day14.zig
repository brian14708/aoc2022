const std = @import("std");
const scan = @import("scan.zig").scan;

const Sandbox = struct {
    const Self = @This();
    bbox: [4]i16,
    data: std.ArrayList(u8),

    fn init(bbox: [4]i16, allocator: std.mem.Allocator) !Self {
        var data = std.ArrayList(u8).init(allocator);
        errdefer data.deinit();
        try data.resize(@intCast(usize, bbox[2] - bbox[0]) * @intCast(usize, bbox[3] - bbox[1]));
        std.mem.set(u8, data.items, 0);
        return Self{
            .bbox = bbox,
            .data = data,
        };
    }

    fn deinit(self: Self) void {
        self.data.deinit();
    }

    fn sign(v: i16) i16 {
        if (v > 0) return 1;
        if (v == 0) return 0;
        return -1;
    }

    fn setSegment(self: *Self, seg: [4]i16) void {
        const dx = sign(seg[2] - seg[0]);
        const dy = sign(seg[3] - seg[1]);

        var x = seg[0];
        var y = seg[1];
        while (x != seg[2] or y != seg[3]) {
            self.data.items[self.pos(x, y).?] = 1;
            x += dx;
            y += dy;
        }
        self.data.items[self.pos(x, y).?] = 1;
    }

    fn addSand(self: *Self, pi: [2]i16) ?[2]i16 {
        var p = pi;
        var curr = self.pos(p[0], p[1]).?;
        if (self.data.items[curr] != 0) {
            return null;
        }

        while (true) {
            if (self.pos(p[0], p[1] + 1)) |idx| {
                if (self.data.items[idx] == 0) {
                    p[1] += 1;
                    curr = idx;
                    continue;
                }
            } else {
                return null;
            }

            if (self.pos(p[0] - 1, p[1] + 1)) |idx| {
                if (self.data.items[idx] == 0) {
                    p[0] -= 1;
                    p[1] += 1;
                    curr = idx;
                    continue;
                }
            } else {
                unreachable;
            }

            if (self.pos(p[0] + 1, p[1] + 1)) |idx| {
                if (self.data.items[idx] == 0) {
                    p[0] += 1;
                    p[1] += 1;
                    curr = idx;
                    continue;
                }
            } else {
                unreachable;
            }

            self.data.items[curr] = 2;
            return p;
        }
    }

    fn pos(self: Self, x: i16, y: i16) ?usize {
        if (x < self.bbox[0] or x >= self.bbox[2]) {
            return null;
        }
        if (y < self.bbox[1] or y >= self.bbox[3]) {
            return null;
        }

        return @intCast(usize, x - self.bbox[0]) +
            @intCast(usize, y - self.bbox[1]) *
            @intCast(usize, self.bbox[2] - self.bbox[0]);
    }

    fn dump(self: Self) void {
        const w = @intCast(usize, self.bbox[2] - self.bbox[0]);
        const h = @intCast(usize, self.bbox[3] - self.bbox[1]);
        var j: usize = 0;
        while (j < h) : (j += 1) {
            var i: usize = 0;
            while (i < w) : (i += 1) {
                switch (self.data.items[j * w + i]) {
                    0 => std.debug.print(".", .{}),
                    1 => std.debug.print("#", .{}),
                    2 => std.debug.print("o", .{}),
                    else => std.debug.print("x", .{}),
                }
            }
            std.debug.print("\n", .{});
        }
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var segments = std.ArrayList([4]i16).init(allocator);
    defer segments.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var ptr = line;
        var prev: ?[2]i16 = null;
        while (true) {
            const end = std.mem.indexOfScalar(u8, ptr, ' ') orelse ptr.len;
            var coord: [2]i16 = undefined;
            try scan(ptr[0..end], "{d},{d}", .{ &coord[0], &coord[1] });
            if (prev) |p| {
                try segments.append(.{ p[0], p[1], coord[0], coord[1] });
            }
            if (end == ptr.len) {
                break;
            }
            prev = coord;
            ptr = ptr[end + 4 ..];
        }
    }

    var bbox = [_]i16{ std.math.maxInt(i16), std.math.maxInt(i16), 0, 0 };
    for (segments.items) |s| {
        bbox[0] = std.math.min(bbox[0], std.math.min(s[0], s[2]));
        bbox[1] = std.math.min(bbox[1], std.math.min(s[1], s[3]));
        bbox[2] = std.math.max(bbox[2], std.math.max(s[0], s[2]));
        bbox[3] = std.math.max(bbox[3], std.math.max(s[1], s[3]));
    }
    const origin = [_]i16{ 500, 0 };
    // include origin and pad 1
    bbox[0] = std.math.min(bbox[0], origin[0]) - 1;
    bbox[1] = std.math.min(bbox[1], origin[1]) - 1;
    bbox[2] = std.math.max(bbox[2], origin[0]) + 3;
    bbox[3] = std.math.max(bbox[3], origin[1]) + 3;

    // pad to avoid horizontal overflow
    const h = bbox[3] - bbox[1];
    bbox[0] = std.math.min(bbox[0], origin[0] - (h - 1));
    bbox[2] = std.math.max(bbox[2], origin[0] + (h - 1) + 1);

    var part_1: i32 = 0;
    var part_2: i32 = 0;
    {
        var sb = try Sandbox.init(bbox, allocator);
        defer sb.deinit();
        for (segments.items) |s| {
            sb.setSegment(s);
        }

        while (sb.addSand(origin)) |_| {
            part_1 += 1;
        }

        sb.setSegment(.{
            bbox[0],
            bbox[3] - 1,
            bbox[2] - 1,
            bbox[3] - 1,
        });

        while (sb.addSand(origin)) |_| {
            part_2 += 1;
        }
    }

    const result = .{
        .part_1 = part_1,
        .part_2 = part_1 + part_2,
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

test "day14" {
    const input =
        \\498,4 -> 498,6 -> 496,6
        \\503,4 -> 502,4 -> 502,9 -> 494,9
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(24 == result.part_1);
    try std.testing.expect(93 == result.part_2);
}
