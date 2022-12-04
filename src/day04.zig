const std = @import("std");

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

        fn initStr(str: []const u8) !Self {
            const idx = std.mem.indexOf(u8, str, "-") orelse return error.InvalidInput;
            return Self.init(
                try std.fmt.parseInt(T, str[0..idx], 10),
                try std.fmt.parseInt(T, str[idx + 1 ..], 10),
            );
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
            try std.testing.expectEqual(try R.initStr("2-8"), a.merge(R.init(3, 8)).?);
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
        var parts = std.mem.split(u8, line, ",");
        try ranges.append(.{
            .first = try R.initStr(parts.next() orelse return error.InvalidInput),
            .second = try R.initStr(parts.next() orelse return error.InvalidInput),
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

    var buf: [4096]u8 = undefined;
    try stdout.writeAll(try std.fmt.bufPrint(&buf, "Part 1: {}\n", .{result.part_1}));
    try stdout.writeAll(try std.fmt.bufPrint(&buf, "Part 2: {}\n", .{result.part_2}));
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
