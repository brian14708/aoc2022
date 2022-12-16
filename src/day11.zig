const std = @import("std");
const scan = @import("scan.zig").scan;

const Monkey = struct {
    const Self = @This();
    const Expr = struct {
        left: ?u64,
        opr: u8,
        right: ?u64,

        fn eval(self: @This(), v: u64) u64 {
            const l = self.left orelse v;
            const r = self.right orelse v;
            return switch (self.opr) {
                '+' => l + r,
                '*' => l * r,
                else => unreachable,
            };
        }
    };

    items: std.ArrayList(u64),
    orig: std.ArrayList(u64),
    expr: Expr,
    rule: struct {
        divisible: u64,
        true_branch: usize,
        false_branch: usize,
    },

    fn init(allocator: std.mem.Allocator, reader: anytype) !?Self {
        var s: Self = .{
            .items = std.ArrayList(u64).init(allocator),
            .orig = std.ArrayList(u64).init(allocator),
            .expr = undefined,
            .rule = undefined,
        };
        errdefer s.deinit();

        // Monkey
        var buf: [4096]u8 = undefined;
        var line = try reader.readUntilDelimiterOrEof(&buf, '\n');
        if (line == null) {
            return null;
        }
        {
            // Starting items
            line = try reader.readUntilDelimiterOrEof(&buf, '\n');
            var it = std.mem.split(u8, line.?[18..], ", ");
            while (it.next()) |x| {
                try s.items.append(try std.fmt.parseInt(u64, x, 10));
            }
        }
        {
            // Operation
            line = try reader.readUntilDelimiterOrEof(&buf, '\n');
            var it = std.mem.split(u8, line.?[19..], " ");
            s.expr.left = std.fmt.parseInt(u64, it.next().?, 10) catch null;
            s.expr.opr = it.next().?[0];
            s.expr.right = std.fmt.parseInt(u64, it.next().?, 10) catch null;
        }
        {
            // Test
            line = try reader.readUntilDelimiterOrEof(&buf, '\n');
            _ = try scan(line.?, "  Test: divisible by {d}", .{&s.rule.divisible});
            line = try reader.readUntilDelimiterOrEof(&buf, '\n');
            _ = try scan(line.?, "    If true: throw to monkey {d}", .{&s.rule.true_branch});
            line = try reader.readUntilDelimiterOrEof(&buf, '\n');
            _ = try scan(line.?, "    If false: throw to monkey {d}", .{&s.rule.false_branch});
        }
        // NL
        _ = reader.readUntilDelimiterOrEof(&buf, '\n') catch null;

        try s.orig.appendSlice(s.items.items);
        return s;
    }

    fn reset(self: *Self) !void {
        self.items.shrinkRetainingCapacity(0);
        try self.items.appendSlice(self.orig.items);
    }

    fn deinit(self: Self) void {
        self.items.deinit();
        self.orig.deinit();
    }

    fn step(self: *Self, c: []Monkey, comptime div: u64, rem: u64) !usize {
        const sz = self.items.items.len;
        for (self.items.items) |o| {
            const v = @rem(@divFloor(self.expr.eval(o), div), rem);
            if (@rem(v, self.rule.divisible) == 0) {
                try c[self.rule.true_branch].items.append(v);
            } else {
                try c[self.rule.false_branch].items.append(v);
            }
        }
        self.items.shrinkRetainingCapacity(0);
        return sz;
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u64,
    part_2: u64,
} {
    var monkeys = std.ArrayList(Monkey).init(allocator);
    var inspect = std.ArrayList(usize).init(allocator);
    defer {
        for (monkeys.items) |m| {
            m.deinit();
        }
        monkeys.deinit();
        inspect.deinit();
    }

    var rem: u64 = 1;
    while (try Monkey.init(allocator, reader)) |m| {
        rem *= m.rule.divisible;

        try monkeys.append(m);
        try inspect.append(0);
    }

    var round: usize = 0;
    while (round < 20) : (round += 1) {
        for (monkeys.items) |*m, idx| {
            inspect.items[idx] += try m.step(monkeys.items, 3, rem);
        }
    }

    std.sort.sort(usize, inspect.items, {}, comptime std.sort.desc(usize));
    const part_1 = @intCast(u64, inspect.items[0] * inspect.items[1]);

    std.mem.set(usize, inspect.items, 0);
    for (monkeys.items) |*m| {
        try m.reset();
    }

    round = 0;
    while (round < 10000) : (round += 1) {
        for (monkeys.items) |*m, idx| {
            inspect.items[idx] +=
                try m.step(monkeys.items, 1, rem);
        }
    }

    std.sort.sort(usize, inspect.items, {}, comptime std.sort.desc(usize));
    const part_2 = @intCast(u64, inspect.items[0] * inspect.items[1]);

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

test "day11" {
    const input = @embedFile("testcase/day11.txt");

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(10605 == result.part_1);
    try std.testing.expect(2713310158 == result.part_2);
}
