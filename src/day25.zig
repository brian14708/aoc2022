const std = @import("std");

fn solve(reader: anytype, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var sum: i64 = 0;
    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var num: i64 = 0;
        for (line) |c| {
            num *= 5;
            switch (c) {
                '2' => num += 2,
                '1' => num += 1,
                '0' => num += 0,
                '-' => num += -1,
                '=' => num += -2,
                else => unreachable,
            }
        }
        sum += num;
    }

    var part_1 = std.ArrayList(u8).init(allocator);
    errdefer part_1.deinit();
    while (sum > 0) : (sum = @divExact(sum, 5)) {
        switch (@mod(sum, 5)) {
            0 => try part_1.append('0'),
            1 => {
                try part_1.append('1');
                sum -= 1;
            },
            2 => {
                try part_1.append('2');
                sum -= 2;
            },
            3 => {
                try part_1.append('=');
                sum -= -2;
            },
            4 => {
                try part_1.append('-');
                sum -= -1;
            },
            else => unreachable,
        }
    }
    std.mem.reverse(u8, part_1.items);
    return part_1;
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin, allocator);
    defer result.deinit();

    try std.fmt.format(stdout, "Part 1: {s}\n", .{result.items});
}

test "day25" {
    const input =
        \\1=-0-2
        \\12111
        \\2=0=
        \\21
        \\2=01
        \\111
        \\20012
        \\112
        \\1=-1=
        \\1-12
        \\12
        \\1=
        \\122
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(std.mem.eql(u8, result.items, "2=-1=0"));
}
