const std = @import("std");
const scan = @import("scan.zig").scan;

fn find_edge_corner(set: std.AutoHashMap([4]i32, ?[4]i32), pt: [2]i32) ?[4]i32 {
    var it = set.iterator();
    var pt2: [2]i32 = undefined;
    while (it.next()) |entry| {
        if (entry.value_ptr.*) |v| {
            if (v[0] == pt[0] and v[1] == pt[1]) {
                pt2 = .{ entry.key_ptr.*[0], entry.key_ptr.*[1] };
                break;
            } else if (v[2] == pt[0] and v[3] == pt[1]) {
                pt2 = .{ entry.key_ptr.*[2], entry.key_ptr.*[3] };
                break;
            }
        }
    } else return null;

    it = set.iterator();
    var seg3: [4]i32 = undefined;
    while (it.next()) |entry| {
        if (entry.value_ptr.*) |v| {
            if (v[0] == pt2[0] and v[1] == pt2[1]) {
                if (entry.key_ptr.*[0] != pt[0] or entry.key_ptr.*[1] != pt[1]) {
                    seg3 = entry.key_ptr.*;
                    break;
                }
            } else if (v[2] == pt2[0] and v[3] == pt2[1]) {
                if (entry.key_ptr.*[2] != pt[0] or entry.key_ptr.*[3] != pt[1]) {
                    seg3 = .{ entry.key_ptr.*[2], entry.key_ptr.*[3], entry.key_ptr.*[0], entry.key_ptr.*[1] };
                    break;
                }
            }
        }
    } else return null;

    var kit = set.keyIterator();
    while (kit.next()) |kptr| {
        const k = kptr.*;
        if (k[0] == seg3[0] and k[1] == seg3[1] and k[2] != seg3[2] and k[3] != seg3[3]) {
            return k;
        } else if (k[2] == seg3[0] and k[3] == seg3[1] and k[0] != seg3[2] and k[1] != seg3[3]) {
            return [_]i32{ k[2], k[3], k[0], k[1] };
        }
    } else return null;
}

fn index(x: i32, y: i32, rows: usize, cols: usize) usize {
    std.debug.assert(x >= 0 and x < cols);
    std.debug.assert(y >= 0 and y < rows);
    return @intCast(usize, y * @intCast(i32, cols) + x);
}

fn score(x: i32, y: i32, dx: i32, dy: i32) i32 {
    var s: i32 = (y + 1) * 1000 + (x + 1) * 4;
    if (dx == 1 and dy == 0) { // right
        s += 0;
    } else if (dx == 0 and dy == 1) { // down
        s += 1;
    } else if (dx == -1 and dy == 0) { // left
        s += 2;
    } else if (dx == 0 and dy == -1) { // up
        s += 3;
    } else {
        unreachable;
    }
    return s;
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var map = std.ArrayList(u8).init(allocator);
    defer map.deinit();

    const cols: usize = 200;
    var buf: [8192]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            break;
        }
        try map.appendSlice(line);
        try map.appendNTimes(' ', cols - line.len);
    }
    const rows = map.items.len / cols;

    var x: i32 = @intCast(i32, std.mem.indexOfScalar(u8, map.items, '.') orelse unreachable);
    var y: i32 = 0;
    var dx: i32 = 1;
    var dy: i32 = 0;

    var instruction = (try reader.readUntilDelimiterOrEof(&buf, '\n')).?;
    {
        var idx: usize = 0;
        var steps: usize = undefined;
        while (true) {
            idx += try scan(instruction[idx..], "{d}", .{&steps});

            // go steps
            var i: usize = 0;
            while (i < steps) : (i += 1) {
                var tx = x;
                var ty = y;
                var tile: u8 = ' ';
                while (tile == ' ') {
                    tx = @mod(tx + dx, @intCast(i32, cols));
                    ty = @mod(ty + dy, @intCast(i32, rows));
                    tile = map.items[index(tx, ty, rows, cols)];
                }
                if (tile == '#') break;
                x = tx;
                y = ty;
            }

            if (instruction.len == idx) break;
            if (instruction[idx] == 'L') {
                std.mem.swap(i32, &dx, &dy);
                dy *= -1;
            } else if (instruction[idx] == 'R') {
                std.mem.swap(i32, &dx, &dy);
                dx *= -1;
            } else {
                unreachable;
            }
            idx += 1;
        }
    }
    var part_1 = score(x, y, dx, dy);

    var cube_width = @intCast(i32, cols);
    var edges = std.AutoHashMap([4]i32, ?[4]i32).init(allocator);
    defer edges.deinit();
    // build edge pairs
    {
        var i: i32 = 0;
        while (i < rows) : (i += 1) {
            var line = map.items[@intCast(usize, i) * cols .. @intCast(usize, i + 1) * cols];
            cube_width = std.math.min(
                cube_width,
                @intCast(i32, std.mem.lastIndexOfAny(u8, line, &.{ '#', '.' }).? - std.mem.indexOfAny(u8, line, &.{ '#', '.' }).? + 1),
            );
        }

        i = 0;
        while (i < rows) : (i += cube_width) {
            var line = map.items[@intCast(usize, i) * cols .. @intCast(usize, i + 1) * cols];
            var j: i32 = 0;
            while (j < cols) : (j += cube_width) {
                if (line[@intCast(usize, j)] == ' ') continue;
                // top
                try edges.putNoClobber(
                    .{ j, i, j + cube_width - 1, i },
                    if (i > 0 and map.items[index(j, i - 1, rows, cols)] != ' ') .{ j, i - 1, j + cube_width - 1, i - 1 } else null,
                );
                // right
                try edges.putNoClobber(
                    .{ j + cube_width - 1, i, j + cube_width - 1, i + cube_width - 1 },
                    if (j + cube_width < cols and map.items[index(j + cube_width, i, rows, cols)] != ' ') .{ j + cube_width, i, j + cube_width, i + cube_width - 1 } else null,
                );
                // bottom
                try edges.putNoClobber(
                    .{ j, i + cube_width - 1, j + cube_width - 1, i + cube_width - 1 },
                    if (i + cube_width < rows and map.items[index(j, i + cube_width, rows, cols)] != ' ') .{ j, i + cube_width, j + cube_width - 1, i + cube_width } else null,
                );
                // left
                try edges.putNoClobber(
                    .{ j, i, j, i + cube_width - 1 },
                    if (j > 0 and map.items[index(j - 1, i, rows, cols)] != ' ') .{ j - 1, i, j - 1, i + cube_width - 1 } else null,
                );
            }
        }
    }

    // glue all edges
    var found = true;
    while (found) {
        found = false;
        var it = edges.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.* != null) continue;
            const k = e.key_ptr.*;
            if (find_edge_corner(edges, k[0..2].*)) |seg| {
                e.value_ptr.* = seg;
                if (edges.getPtr(seg)) |v| {
                    v.* = k;
                } else if (edges.getPtr(.{ seg[2], seg[3], seg[0], seg[1] })) |v| {
                    v.* = [_]i32{ k[2], k[3], k[0], k[1] };
                } else {
                    unreachable;
                }
                found = true;
                break;
            }
            if (find_edge_corner(edges, k[2..4].*)) |seg| {
                e.value_ptr.* = [_]i32{ seg[2], seg[3], seg[0], seg[1] };
                if (edges.getPtr(seg)) |v| {
                    v.* = [_]i32{ k[2], k[3], k[0], k[1] };
                } else if (edges.getPtr(.{ seg[2], seg[3], seg[0], seg[1] })) |v| {
                    v.* = k;
                } else {
                    unreachable;
                }
                found = true;
                break;
            }
        }
    }

    x = @intCast(i32, std.mem.indexOfScalar(u8, map.items, '.') orelse unreachable);
    y = 0;
    dx = 1;
    dy = 0;
    {
        var idx: usize = 0;
        var steps: usize = undefined;
        while (true) {
            idx += try scan(instruction[idx..], "{d}", .{&steps});

            // go steps
            var i: usize = 0;
            while (i < steps) : (i += 1) {
                var tx = x + dx;
                var ty = y + dy;
                var ndx = dx;
                var ndy = dy;
                if (tx < 0 or tx >= cols or ty < 0 or ty >= rows or map.items[index(tx, ty, rows, cols)] == ' ') {
                    // edge wrap
                    var it = edges.iterator();
                    while (it.next()) |e| {
                        if ((dx == 0 and e.key_ptr.*[1] == y and e.key_ptr.*[3] == y and
                            (e.key_ptr.*[0] <= x and x <= e.key_ptr.*[2])) or
                            (dy == 0 and e.key_ptr.*[0] == x and e.key_ptr.*[2] == x and
                            (e.key_ptr.*[1] <= y and y <= e.key_ptr.*[3])))
                        {
                            const vx = @divExact(e.value_ptr.*.?[2] - e.value_ptr.*.?[0], cube_width - 1);
                            const vy = @divExact(e.value_ptr.*.?[3] - e.value_ptr.*.?[1], cube_width - 1);
                            tx = e.value_ptr.*.?[0] + vx * (x - e.key_ptr.*[0] + y - e.key_ptr.*[1]);
                            ty = e.value_ptr.*.?[1] + vy * (x - e.key_ptr.*[0] + y - e.key_ptr.*[1]);

                            var ox = @divExact(e.key_ptr.*[2] - e.key_ptr.*[0], cube_width - 1);
                            var oy = @divExact(e.key_ptr.*[3] - e.key_ptr.*[1], cube_width - 1);
                            while (ox != vx or oy != vy) {
                                std.mem.swap(i32, &ox, &oy);
                                oy *= -1;
                                std.mem.swap(i32, &ndx, &ndy);
                                ndy *= -1;
                            }
                            break;
                        }
                    }
                }
                const tile = map.items[index(tx, ty, rows, cols)];
                if (tile == '#') break;
                x = tx;
                y = ty;
                dx = ndx;
                dy = ndy;
            }

            if (instruction.len == idx) break;
            if (instruction[idx] == 'L') {
                std.mem.swap(i32, &dx, &dy);
                dy *= -1;
            } else if (instruction[idx] == 'R') {
                std.mem.swap(i32, &dx, &dy);
                dx *= -1;
            } else {
                unreachable;
            }
            idx += 1;
        }
    }

    var part_2 = score(x, y, dx, dy);

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

test "day22" {
    const input = @embedFile("testcase/day22.txt");

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(6032 == result.part_1);
    try std.testing.expect(5031 == result.part_2);
}
