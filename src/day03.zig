const std = @import("std");

fn priority(i: u8) u8 {
    return switch (i) {
        'a'...'z' => i - 'a' + 1,
        'A'...'Z' => i - 'A' + 27,
        else => unreachable,
    };
}

fn solve(reader: anytype) !struct {
    part_1: u32,
    part_2: u32,
} {
    const ElementSet = std.StaticBitSet(64);

    var part_1: u32 = 0;
    var part_2: u32 = 0;

    var line_idx: usize = 0;
    var common_elems = ElementSet.initFull();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var first_half = ElementSet.initEmpty();
        var line_elems = ElementSet.initEmpty();
        var i: usize = 0;
        while (i < line.len / 2) : (i += 1) {
            const p = priority(line[i]);
            first_half.set(p);
            line_elems.set(p);
        }
        while (i < line.len) : (i += 1) {
            const p = priority(line[i]);
            line_elems.set(p);
            if (first_half.isSet(p)) {
                part_1 += p;
                break;
            }
        }
        for (line[i..]) |c| {
            line_elems.set(priority(c));
        }

        line_idx += 1;
        common_elems.setIntersection(line_elems);
        if (line_idx % 3 == 0) {
            part_2 += @intCast(u32, common_elems.findFirstSet().?);
            common_elems = ElementSet.initFull();
        }
    }

    const r = .{
        .part_1 = part_1,
        .part_2 = part_2,
    };
    return r;
}

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin);

    var buf: [4096]u8 = undefined;
    try stdout.writeAll(try std.fmt.bufPrint(&buf, "Part 1: {}\n", .{result.part_1}));
    try stdout.writeAll(try std.fmt.bufPrint(&buf, "Part 2: {}\n", .{result.part_2}));
}

test "day03" {
    const input =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader());
    try std.testing.expectEqual(@as(u8, 2), priority('b'));
    try std.testing.expectEqual(@as(u8, 52), priority('Z'));
    try std.testing.expectEqual(@as(u32, 157), result.part_1);
    try std.testing.expectEqual(@as(u32, 70), result.part_2);
}
