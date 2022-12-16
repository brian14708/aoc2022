const std = @import("std");
const scan = @import("scan.zig").scan;
const range = @import("range").range;

fn StackArray(comptime T: type) type {
    return struct {
        const Self = @This();
        items: []std.ArrayList(T),
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, num: usize) !Self {
            const items = try allocator.alloc(std.ArrayList(T), num);
            for (items) |*item| {
                item.* = std.ArrayList(T).init(allocator);
            }

            return Self{
                .items = items,
                .allocator = allocator,
            };
        }

        fn deinit(self: Self) void {
            for (self.items) |*item| {
                item.deinit();
            }
            self.allocator.free(self.items);
        }

        fn get_top(self: Self, allocator: std.mem.Allocator) !std.ArrayList(T) {
            var top = try std.ArrayList(T).initCapacity(allocator, self.items.len);
            for (self.items) |item| {
                try top.append(item.items[item.items.len - 1]);
            }
            return top;
        }

        fn move(self: *Self, from: usize, to: usize, cnt: usize) !void {
            const left = self.items[from].items.len - cnt;
            try self.items[to].appendSlice(self.items[from].items[left..]);
            try self.items[from].resize(left);
        }

        fn clone(self: Self, allocator: std.mem.Allocator) !Self {
            var new = Self{
                .items = try allocator.alloc(std.ArrayList(T), self.items.len),
                .allocator = allocator,
            };
            for (new.items) |*item, i| {
                item.* = try std.ArrayList(T).initCapacity(allocator, self.items[i].items.len);
                try item.appendSlice(self.items[i].items);
            }
            return new;
        }

        test {
            var s = try StackArray(u8).init(std.testing.allocator, 10);
            defer s.deinit();
        }
    };
}

fn parse_drawing(drawing: []const []const u8, allocator: std.mem.Allocator) !StackArray(u8) {
    var last_line = drawing[drawing.len - 1];

    // number of stacks needed
    var idx: usize = 0;
    var cnt: usize = 0;
    // skip space
    while (idx < last_line.len and last_line[idx] == ' ') : (idx += 1) {}
    while (idx < last_line.len) {
        while (idx < last_line.len and last_line[idx] != ' ') : (idx += 1) {}
        while (idx < last_line.len and last_line[idx] == ' ') : (idx += 1) {}
        cnt += 1;
    }

    var result = try StackArray(u8).init(allocator, cnt);
    idx = drawing.len - 1;
    while (idx != 0) : (idx -= 1) {
        var lidx: usize = 0;
        while (lidx < cnt) : (lidx += 1) {
            if (lidx * 4 + 1 >= drawing[idx - 1].len) {
                break;
            }
            const box = drawing[idx - 1][lidx * 4 + 1];
            if (box != ' ') {
                try result.items[lidx].append(box);
            }
        }
    }
    return result;
}

test {
    const drawing = [_][]const u8{
        "    [D]    ",
        "[N] [C]    ",
        "[Z] [M] [P]",
        " 1   2   3 ",
    };
    var r = try parse_drawing(&drawing, std.testing.allocator);
    defer r.deinit();

    try std.testing.expect(r.items.len == 3);
    try std.testing.expectEqualSlices(u8, "ZN", r.items[0].items);
    try std.testing.expectEqualSlices(u8, "MCD", r.items[1].items);
    try std.testing.expectEqualSlices(u8, "P", r.items[2].items);
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: std.ArrayList(u8),
    part_2: std.ArrayList(u8),

    fn deinit(self: @This()) void {
        self.part_1.deinit();
        self.part_2.deinit();
    }
} {
    var lines = std.ArrayList([]const u8).init(allocator);
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }

    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
        if (line.len == 0) {
            break;
        }
        try lines.append(line);
    }

    var layout_1 = try parse_drawing(lines.items, allocator);
    defer layout_1.deinit();
    var layout_2 = try layout_1.clone(allocator);
    defer layout_2.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var cnt: u32 = undefined;
        var src: u32 = undefined;
        var dst: u32 = undefined;
        _ = try scan(line, "move {d} from {d} to {d}", .{ &cnt, &src, &dst });
        src -= 1;
        dst -= 1;

        try layout_2.move(src, dst, cnt);
        for (range(cnt)) |_| {
            try layout_1.move(src, dst, 1);
        }
    }

    const r = .{
        .part_1 = try layout_1.get_top(allocator),
        .part_2 = try layout_2.get_top(allocator),
    };
    return r;
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin, allocator);
    defer result.deinit();

    try std.fmt.format(stdout, "Part 1: {s}\n", .{result.part_1.items});
    try std.fmt.format(stdout, "Part 2: {s}\n", .{result.part_2.items});
}

test "day05" {
    const input =
        \\    [D]
        \\[N] [C]
        \\[Z] [M] [P]
        \\ 1   2   3
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);
    defer result.deinit();

    try std.testing.expectEqualSlices(u8, "CMZ", result.part_1.items);
    try std.testing.expectEqualSlices(u8, "MCD", result.part_2.items);
}
