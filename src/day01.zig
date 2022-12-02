const std = @import("std");

fn sum(comptime T: type, list: []T) T {
    var total: T = 0;
    for (list) |item| {
        total += item;
    }
    return total;
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u32,
    part_2: u32,
} {
    const T: type = u32;

    var lst = std.ArrayList(T).init(allocator);
    defer lst.deinit();

    var buf: [4096]u8 = undefined;
    try lst.append(0);
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            try lst.append(0);
        } else {
            const num = try std.fmt.parseInt(T, line, 10);
            lst.items[lst.items.len - 1] += num;
        }
    }
    std.sort.sort(T, lst.items, {}, comptime std.sort.desc(T));
    if (lst.items.len < 3) {
        return error.InvalidInput;
    }
    const r = .{
        .part_1 = lst.items[0],
        .part_2 = sum(T, lst.items[0..3]),
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

test "day01" {
    const input =
        \\1000
        \\2000
        \\3000
        \\
        \\4000
        \\
        \\5000
        \\6000
        \\
        \\7000
        \\8000
        \\9000
        \\
        \\10000
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 24000), result.part_1);
    try std.testing.expectEqual(@as(u32, 45000), result.part_2);
}
