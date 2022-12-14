const std = @import("std");
const Queue = @import("queue.zig").Queue;

const Pos = struct {
    x: i32,
    y: i32,
    val: i32,
    from: u8,

    fn fromIndex(s: usize, cols: usize, _: usize, f: u8) @This() {
        return .{
            .x = @rem(@intCast(i32, s), @intCast(i32, cols)),
            .y = @divFloor(@intCast(i32, s), @intCast(i32, cols)),
            .val = 0,
            .from = f,
        };
    }

    fn toIndex(self: @This(), cols: usize, rows: usize) ?usize {
        if (self.x < 0 or self.y < 0) return null;
        const ux = @intCast(usize, self.x);
        const uy = @intCast(usize, self.y);
        if (ux >= cols or uy >= rows) return null;
        return ux + uy * cols;
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var map = std.ArrayList(u8).init(allocator);
    defer map.deinit();

    var rows: usize = 0;
    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.appendSlice(line);
        rows += 1;
    }
    const cols = @divExact(map.items.len, rows);

    var start: Pos = undefined;
    var end: Pos = undefined;

    if (std.mem.indexOfScalar(u8, map.items, 'S')) |s| {
        start = Pos.fromIndex(s, cols, rows, 'a');
        map.items[s] = 'a';
    }
    if (std.mem.indexOfScalar(u8, map.items, 'E')) |s| {
        end = Pos.fromIndex(s, cols, rows, 'z');
        map.items[s] = 'z';
    }

    var q = Queue(Pos).init(allocator);
    defer q.deinit();
    try q.add(start);

    var visited = std.ArrayList(bool).init(allocator);
    defer visited.deinit();
    try visited.appendNTimes(false, map.items.len);

    var part_1: i32 = -1;
    while (q.len > 0) {
        const s = q.remove();
        if (s.toIndex(cols, rows)) |idx| {
            if (visited.items[idx] or !(map.items[idx] <= s.from + 1)) {
                continue;
            }
            visited.items[idx] = true;
            if (s.x == end.x and s.y == end.y) {
                part_1 = s.val;
                break;
            }

            try q.add(.{ .x = s.x - 1, .y = s.y, .val = s.val + 1, .from = map.items[idx] });
            try q.add(.{ .x = s.x, .y = s.y - 1, .val = s.val + 1, .from = map.items[idx] });
            try q.add(.{ .x = s.x + 1, .y = s.y, .val = s.val + 1, .from = map.items[idx] });
            try q.add(.{ .x = s.x, .y = s.y + 1, .val = s.val + 1, .from = map.items[idx] });
        }
    }

    q.clear();
    try q.add(end);
    std.mem.set(bool, visited.items, false);

    var part_2: i32 = -1;
    while (q.len > 0) {
        const s = q.remove();
        if (s.toIndex(cols, rows)) |idx| {
            if (visited.items[idx] or !(map.items[idx] + 1 >= s.from)) {
                continue;
            }
            visited.items[idx] = true;
            if (map.items[idx] == 'a') {
                part_2 = s.val;
                break;
            }

            try q.add(.{ .x = s.x - 1, .y = s.y, .val = s.val + 1, .from = map.items[idx] });
            try q.add(.{ .x = s.x, .y = s.y - 1, .val = s.val + 1, .from = map.items[idx] });
            try q.add(.{ .x = s.x + 1, .y = s.y, .val = s.val + 1, .from = map.items[idx] });
            try q.add(.{ .x = s.x, .y = s.y + 1, .val = s.val + 1, .from = map.items[idx] });
        }
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

test "day12" {
    const input =
        \\Sabqponm
        \\abcryxxl
        \\accszExk
        \\acctuvwj
        \\abdefghi
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(31 == result.part_1);
    try std.testing.expect(29 == result.part_2);
}
