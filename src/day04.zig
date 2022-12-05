const std = @import("std");
const scan = @import("scan.zig").scan;

fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        begin: T,
        end: T,

        fn init(begin: T, end: T) Self {
            return .{
                .begin = begin,
                .end = end,
            };
        }

        fn merge(self: Self, other: Self) ?Self {
            if (self.end < other.begin or other.end < self.begin) {
                return null;
            }
            return Self.init(
                std.math.min(self.begin, other.begin),
                std.math.max(self.end, other.end),
            );
        }

        fn eql(self: Self, other: Self) bool {
            return std.meta.eql(self, other);
        }

        test {
            const R = Range(u32);
            const a = R.init(2, 6);
            try std.testing.expectEqual(R.init(2, 6), a.merge(R.init(3, 4)).?);
            try std.testing.expect(null == a.merge(R.init(7, 8)));
        }
    };
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u32,
    part_2: u32,
} {
    const R = Range(u32);
    var ranges = std.ArrayList(struct {
        first: R,
        second: R,
    }).init(allocator);
    defer ranges.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var a: u32 = undefined;
        var b: u32 = undefined;
        var c: u32 = undefined;
        var d: u32 = undefined;
        try scan(line, "{d}-{d},{d}-{d}", .{ &a, &b, &c, &d });
        try ranges.append(.{
            .first = R.init(a, b),
            .second = R.init(c, d),
        });
    }

    var part_1: u32 = 0;
    var part_2: u32 = 0;
    for (ranges.items) |r| {
        var m = R.merge(r.first, r.second);
        if (m) |mm| {
            if (mm.eql(r.first) or mm.eql(r.second)) {
                part_1 += 1;
            }
            part_2 += 1;
        }
    }

    const r = .{
        .part_1 = part_1,
        .part_2 = part_2,
    };
    return r;
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin, allocator);

    try std.fmt.format(stdout, "Part 1: {}\n", .{result.part_1});
    try std.fmt.format(stdout, "Part 2: {}\n", .{result.part_2});
}

test "day04" {
    const input =
        \\2-4,6-8
        \\2-3,4-5
        \\5-7,7-9
        \\2-8,3-7
        \\6-6,4-6
        \\2-6,4-8
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 2), result.part_1);
    try std.testing.expectEqual(@as(u32, 4), result.part_2);
}
