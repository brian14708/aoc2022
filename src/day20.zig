const std = @import("std");

const Pair = struct {
    num: i64,
    idx: usize,
};

fn step(data: []Pair, nidx: usize) void {
    var idx: usize = undefined;
    for (data) |v, i| {
        if (v.idx == nidx) {
            idx = i;
            break;
        }
    }

    std.mem.rotate(Pair, data, idx);
    var num = data[0].num;
    var offset = @intCast(usize, @mod(num, @intCast(i64, data.len - 1)));
    std.mem.rotate(Pair, data[1..], offset);
}

fn sum3(mixed: []Pair) i64 {
    for (mixed) |v, i| {
        if (v.num == 0) {
            return mixed[(i + 1000) % mixed.len].num +
                mixed[(i + 2000) % mixed.len].num +
                mixed[(i + 3000) % mixed.len].num;
        }
    }
    unreachable;
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i64,
    part_2: i64,
} {
    var data = std.ArrayList(i64).init(allocator);
    defer data.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try data.append(try std.fmt.parseInt(i64, line, 10));
    }

    var mixed = std.ArrayList(Pair).init(allocator);
    defer mixed.deinit();
    for (data.items) |d, idx| {
        try mixed.append(.{
            .num = d,
            .idx = idx,
        });
    }

    for (data.items) |_, idx| {
        step(mixed.items, idx);
    }

    var part_1 = sum3(mixed.items);

    mixed.clearRetainingCapacity();
    for (data.items) |d, idx| {
        try mixed.append(.{
            .num = d * 811589153,
            .idx = idx,
        });
    }

    var n: usize = 0;
    while (n < 10) : (n += 1) {
        for (data.items) |_, idx| {
            step(mixed.items, idx);
        }
    }

    var part_2 = sum3(mixed.items);

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

test "day20" {
    const input =
        \\1
        \\2
        \\-3
        \\3
        \\-2
        \\0
        \\4
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(3 == result.part_1);
    try std.testing.expect(1623178306 == result.part_2);
}
