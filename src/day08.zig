const std = @import("std");
const range = @import("range").range;

const Stack = struct {
    const Self = @This();
    const StackType = std.ArrayList(struct {
        idx: u32,
        val: u8,
    });

    stack: StackType,
    idx: u32,
    prev: u8,

    fn init(allocator: std.mem.Allocator) Self {
        return .{
            .stack = StackType.init(allocator),
            .prev = 0,
            .idx = 0,
        };
    }

    fn deinit(self: Self) void {
        self.stack.deinit();
    }

    fn reset(self: *Self, sz: usize) !void {
        self.stack.shrinkRetainingCapacity(0);
        try self.stack.ensureTotalCapacity(sz);
        self.prev = 0;
        self.idx = 0;
    }

    fn push(self: *Self, val: u8) u32 {
        defer {
            self.idx += 1;
            self.prev = val;
        }
        if (self.prev >= val) {
            self.stack.appendAssumeCapacity(.{
                .idx = self.idx - 1,
                .val = self.prev,
            });
            return 1;
        } else {
            while (self.stack.items.len > 0 and self.stack.items[self.stack.items.len - 1].val < val) {
                self.stack.shrinkRetainingCapacity(self.stack.items.len - 1);
            }
            if (self.stack.items.len == 0) {
                return self.idx;
            } else {
                return self.idx - self.stack.items[self.stack.items.len - 1].idx;
            }
        }
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u32,
    part_2: u32,
} {
    var map = std.ArrayList(u8).init(allocator);
    defer map.deinit();

    var rows: usize = 0;
    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.appendSlice(line);
        rows += 1;
    }
    var cols: usize = map.items.len / rows;

    var is_visible = std.ArrayList(bool).init(allocator);
    defer is_visible.deinit();

    try is_visible.resize(map.items.len);
    std.mem.set(bool, is_visible.items, false);

    var scenic = std.ArrayList(u32).init(allocator);
    defer scenic.deinit();
    try scenic.resize(map.items.len);
    std.mem.set(u32, scenic.items, 1);

    var s = Stack.init(allocator);
    defer s.deinit();

    for (range(rows)) |_, i| {
        var max: usize = 0;
        try s.reset(cols);
        for (range(cols)) |_, j| {
            const idx = i * cols + j;
            const curr = map.items[idx];
            if (curr > max) {
                is_visible.items[idx] = true;
                max = curr;
            }
            scenic.items[idx] *= s.push(curr);
        }

        max = 0;
        try s.reset(cols);
        for (range(cols)) |_, j| {
            const idx = i * cols + (cols - j - 1);
            const curr = map.items[idx];
            if (curr > max) {
                is_visible.items[idx] = true;
                max = curr;
            }
            scenic.items[idx] *= s.push(curr);
        }
    }

    for (range(cols)) |_, j| {
        var max: usize = 0;
        try s.reset(rows);
        for (range(rows)) |_, i| {
            const idx = i * cols + j;
            const curr = map.items[idx];
            if (curr > max) {
                is_visible.items[idx] = true;
                max = curr;
            }
            scenic.items[idx] *= s.push(curr);
        }

        max = 0;
        try s.reset(rows);
        for (range(rows)) |_, i| {
            const idx = (rows - i - 1) * cols + j;
            const curr = map.items[idx];
            if (curr > max) {
                is_visible.items[idx] = true;
                max = curr;
            }
            scenic.items[idx] *= s.push(curr);
        }
    }

    var part_1: u32 = 0;
    for (is_visible.items) |it| {
        if (it) part_1 += 1;
    }

    var part_2: u32 = 0;
    for (scenic.items) |it| {
        if (it > part_2) part_2 = it;
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

test "day07" {
    const input =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(21 == result.part_1);
    try std.testing.expect(8 == result.part_2);
}
