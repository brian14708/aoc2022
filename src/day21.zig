const std = @import("std");

const Expr = struct {
    dst: [4]u8,
    left: [4]u8,
    right: [4]u8,
    opr: u8,
};

fn eval(e: Expr, state: std.AutoHashMap([4]u8, i64)) ?i64 {
    const left = state.get(e.left) orelse return null;
    const right = state.get(e.right) orelse return null;
    return switch (e.opr) {
        '+' => left + right,
        '-' => left - right,
        '*' => left * right,
        '/' => @divExact(left, right),
        else => unreachable,
    };
}

fn evalAll(expr: *std.ArrayList(Expr), state: *std.AutoHashMap([4]u8, i64)) !void {
    var prev = expr.items.len;
    while (true) {
        var i = expr.items.len;
        while (i > 0) {
            i -= 1;
            if (eval(expr.items[i], state.*)) |v| {
                try state.putNoClobber(expr.items[i].dst, v);
                _ = expr.swapRemove(i);
            }
        }
        if (expr.items.len == prev) {
            break;
        }
        prev = expr.items.len;
    }
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i64,
    part_2: i64,
} {
    var state_input = std.AutoHashMap([4]u8, i64).init(allocator);
    defer state_input.deinit();

    var expr_input = std.ArrayList(Expr).init(allocator);
    defer expr_input.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const dst: [4]u8 = line[0..4].*;
        if (std.fmt.parseInt(i64, line[6..], 10)) |v| {
            try state_input.putNoClobber(dst, v);
        } else |_| {
            const elem = .{
                .dst = dst,
                .left = line[6..10].*,
                .right = line[13..17].*,
                .opr = line[11],
            };
            try expr_input.append(elem);
        }
    }

    var state = try state_input.clone();
    defer state.deinit();
    var expr = @TypeOf(expr_input).init(allocator);
    defer expr.deinit();
    try expr.appendSlice(expr_input.items);

    _ = state.remove("humn".*);
    try evalAll(&expr, &state);

    var target: i64 = undefined;
    var target_state: [4]u8 = undefined;
    for (expr.items) |e, idx| {
        if (std.meta.eql(e.dst, "root".*)) {
            if (state.get(e.left)) |l| {
                target = l;
                target_state = e.right;
            } else {
                target = state.get(e.right).?;
                target_state = e.left;
            }
            _ = expr.swapRemove(idx);
            break;
        }
    }

    outer: while (expr.items.len > 0) {
        for (expr.items) |e, idx| {
            if (std.meta.eql(e.dst, target_state)) {
                var left = state.get(e.left);
                var right = state.get(e.right);
                if (left == null and right == null) {
                    break :outer;
                }
                if (left == null) {
                    target_state = e.left;
                    target = switch (e.opr) {
                        '+' => target - right.?,
                        '-' => target + right.?,
                        '*' => @divExact(target, right.?),
                        '/' => target * right.?,
                        else => unreachable,
                    };
                } else {
                    target_state = e.right;
                    target = switch (e.opr) {
                        '+' => target - left.?,
                        '-' => left.? - target,
                        '*' => @divExact(target, left.?),
                        '/' => @divExact(left.?, target),
                        else => unreachable,
                    };
                }
                _ = expr.swapRemove(idx);
                break;
            }
        }
    }

    try evalAll(&expr_input, &state_input);

    const result = .{
        .part_1 = state_input.get("root".*).?,
        .part_2 = target,
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

test "day21" {
    const input =
        \\root: pppw + sjmn
        \\dbpl: 5
        \\cczh: sllz + lgvd
        \\zczc: 2
        \\ptdq: humn - dvpt
        \\dvpt: 3
        \\lfqf: 4
        \\humn: 5
        \\ljgn: 2
        \\sjmn: drzm * dbpl
        \\sllz: 4
        \\pppw: cczh / lfqf
        \\lgvd: ljgn * ptdq
        \\drzm: hmdt - zczc
        \\hmdt: 32
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(152 == result.part_1);
    try std.testing.expect(301 == result.part_2);
}
