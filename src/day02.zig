const std = @import("std");

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u32,
    part_2: u32,
} {
    var input = std.ArrayList(struct {
        first: u8,
        second: u8,
    }).init(allocator);
    defer input.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        std.debug.assert(line.len == 3);
        std.debug.assert(line[1] == ' ');
        try input.append(.{
            .first = line[0] - 'A',
            .second = line[2] - 'X',
        });
    }

    var p1_score: u32 = 0;
    for (input.items) |item| {
        const opp = item.first;
        const my = item.second;
        p1_score += my + 1;
        if (opp == my) {
            // tie
            p1_score += 3;
        } else if (my == (opp + 1) % 3) {
            // i win
            p1_score += 6;
        }
    }

    var p2_score: u32 = 0;
    for (input.items) |item| {
        const opp = item.first;
        const result = item.second;
        const my = switch (result) {
            // i lose
            0 => (opp + 2) % 3,
            // i win
            2 => (opp + 1) % 3,
            // tie
            else => opp,
        };

        p2_score += result * 3;
        p2_score += my + 1;
    }

    var result = .{
        .part_1 = p1_score,
        .part_2 = p2_score,
    };
    return result;
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

test "day02" {
    const input =
        \\A Y
        \\B X
        \\C Z
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 15), result.part_1);
    try std.testing.expectEqual(@as(u32, 12), result.part_2);
}
