const std = @import("std");

const Node = union(enum) {
    const Self = @This();
    val: i32,
    array: std.ArrayList(Node),

    fn parse(allocator: std.mem.Allocator, line: []const u8) !Self {
        var len: usize = undefined;
        return try _parse(allocator, line, &len);
    }

    fn _parse(allocator: std.mem.Allocator, line: []const u8, out_len: *usize) anyerror!Self {
        if (line[0] != '[') {
            // parse int
            var r: i32 = 0;
            var idx: usize = 0;
            while (line[idx] >= '0' and line[idx] <= '9') : (idx += 1) {
                r = r * 10 + (line[idx] - '0');
            }

            out_len.* = idx;
            const o: Self = .{ .val = r };
            return o;
        }

        var r = std.ArrayList(Node).init(allocator);
        errdefer r.deinit();
        var idx: usize = 1;
        while (line[idx] != ']') {
            var len: usize = undefined;
            try r.append(try _parse(allocator, line[idx..], &len));
            idx += len;

            while (line[idx] == ',' or line[idx] == ' ') : (idx += 1) {}
        }

        const o: Self = .{ .array = r };
        out_len.* = idx + 1;
        return o;
    }

    fn deinit(self: @This()) void {
        switch (self) {
            .array => |a| {
                for (a.items) |i| {
                    i.deinit();
                }
                a.deinit();
            },
            else => {},
        }
    }

    fn compare(self: Self, other: Self) std.math.Order {
        switch (self) {
            .val => |i| return other.compareScalar(i).invert(),
            .array => |a| {
                switch (other) {
                    .val => |i| return self.compareScalar(i),
                    .array => |b| {
                        var idx: usize = 0;
                        while (idx < a.items.len and idx < b.items.len) : (idx += 1) {
                            const cmp = a.items[idx].compare(b.items[idx]);
                            if (cmp != .eq) return cmp;
                        }
                        if (a.items[idx..].len > 0) return .gt;
                        if (b.items[idx..].len > 0) return .lt;
                        return .eq;
                    },
                }
            },
        }
    }

    fn compareScalar(self: Self, v: i32) std.math.Order {
        switch (self) {
            .val => |i| return std.math.order(i, v),
            .array => |a| {
                if (a.items.len == 0) return .lt;
                const ret = a.items[0].compareScalar(v);
                if (a.items.len == 1 or ret != .eq) return ret;
                return .gt;
            },
        }
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var all = std.ArrayList(Node).init(allocator);
    defer {
        (Node{ .array = all }).deinit();
    }

    var part_1: i32 = 0;
    {
        var buf: [4096]u8 = undefined;
        var idx: usize = 0;
        while (true) : (idx += 1) {
            if (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                const a = try Node.parse(allocator, line);
                try all.append(a);
                const b = try Node.parse(allocator, (try reader.readUntilDelimiterOrEof(&buf, '\n')).?);
                try all.append(b);
                _ = try reader.readUntilDelimiterOrEof(&buf, '\n');
                if (a.compare(b) == .lt) {
                    part_1 += @intCast(i32, idx) + 1;
                }
            } else {
                break;
            }
        }
    }

    var part_2: i32 = undefined;
    {
        const decoder_a = try Node.parse(allocator, "[[2]]");
        defer decoder_a.deinit();
        const decoder_b = try Node.parse(allocator, "[[6]]");
        defer decoder_b.deinit();

        var a: i32 = if (decoder_b.compare(decoder_a) == .lt) 1 else 0;
        var b: i32 = if (decoder_a.compare(decoder_b) == .lt) 1 else 0;
        for (all.items) |i| {
            if (i.compare(decoder_a) == .lt) a += 1;
            if (i.compare(decoder_b) == .lt) b += 1;
        }
        part_2 = (a + 1) * (b + 1);
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

test "day13" {
    const input =
        \\[1,1,3,1,1]
        \\[1,1,5,1,1]
        \\
        \\[[1],[2,3,4]]
        \\[[1],4]
        \\
        \\[9]
        \\[[8,7,6]]
        \\
        \\[[4,4],4,4]
        \\[[4,4],4,4,4]
        \\
        \\[7,7,7,7]
        \\[7,7,7]
        \\
        \\[]
        \\[3]
        \\
        \\[[[]]]
        \\[[]]
        \\
        \\[1,[2,[3,[4,[5,6,7]]]],8,9]
        \\[1,[2,[3,[4,[5,6,0]]]],8,9]
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(13 == result.part_1);
    try std.testing.expect(140 == result.part_2);
}
