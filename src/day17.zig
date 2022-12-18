const std = @import("std");

const Simulate = struct {
    const Self = @This();
    const rocks = [_][4]u8{
        .{ 0, 0, 0, 0b1111 },
        .{ 0, 0b010, 0b111, 0b010 },
        .{ 0, 0b100, 0b100, 0b111 },
        .{ 0b1, 0b1, 0b1, 0b1 },
        .{ 0, 0, 0b11, 0b11 },
    };
    map: std.ArrayList(u8),
    nr_rocks: usize,
    curr_rock: struct {
        position: usize,
        shape: [4]u8,
    },
    max_height: usize,

    fn init(allocator: std.mem.Allocator) !Self {
        var s = Self{
            .map = std.ArrayList(u8).init(allocator),
            .nr_rocks = 0,
            .curr_rock = undefined,
            .max_height = 0,
        };
        try s.new_rock();
        return s;
    }

    fn deinit(self: Self) void {
        self.map.deinit();
    }

    fn top(self: Self) usize {
        if (self.map.items.len == 0) return 0;
        var t = self.map.items.len - 1;
        while (t > 0) : (t -= 1) {
            if (self.map.items[t] != 0) return t + 1;
        }
        return t + 1;
    }

    fn ensureHeight(self: *Self, s: usize) !void {
        const old = self.map.items.len;
        if (old <= s) {
            try self.map.resize(s + 1);
            std.mem.set(u8, self.map.items[old..], 0);
        }
    }

    fn new_rock(self: *Self) !void {
        var r = .{
            .position = self.top() + 3 + 3,
            .shape = shift(shift(rocks[self.nr_rocks % rocks.len], '>').?, '>').?,
        };
        try self.ensureHeight(r.position);
        self.curr_rock = r;
        self.nr_rocks += 1;
    }

    fn step(self: *Self, dir: u8) !bool {
        var rk = self.curr_rock;
        if (shift(rk.shape, dir)) |s| {
            if (!self.overlap(s, rk.position)) {
                rk.shape = s;
            }
        }

        if (!self.overlap(rk.shape, rk.position - 1)) {
            rk.position -= 1;
            self.curr_rock = rk;
            return false;
        } else {
            for (rk.shape) |c, idx| {
                self.map.items[rk.position - idx] |= c;
            }
            try self.new_rock();
            return true;
        }
    }

    fn shift(r: [4]u8, dir: u8) ?[4]u8 {
        var tmp = r;
        if (dir == '>') {
            var i: usize = 0;
            while (i < 4) : (i += 1) {
                if ((tmp[i] & @as(u8, 1) << 6) == 0) {
                    tmp[i] <<= 1;
                } else {
                    return null;
                }
            }
        } else {
            var i: usize = 0;
            while (i < 4) : (i += 1) {
                if ((tmp[i] & 1) == 0) {
                    tmp[i] >>= 1;
                } else {
                    return null;
                }
            }
        }
        return tmp;
    }

    fn overlap(self: Self, rk: [4]u8, position: usize) bool {
        if (position < 3) return true;
        for (rk) |c, idx| {
            if (self.map.items[position - idx] & c != 0) {
                return true;
            }
        }
        return false;
    }

    fn dump(self: Self) void {
        var t = self.map.items.len;
        while (t > 0) {
            t -= 1;
            var i: usize = 0;
            while (i < 7) : (i += 1) {
                var ch: u8 = if ((self.map.items[t] >> @intCast(u3, i)) & 1 == 0) '.' else '#';
                for (self.curr_rock.shape) |c, idx| {
                    if (self.curr_rock.position - idx == t) {
                        if ((c >> @intCast(u3, i)) & 1 != 0) {
                            ch = '@';
                            break;
                        }
                    }
                }
                std.debug.print("{c}", .{ch});
            }
            std.debug.print("\n", .{});
        }
    }
};

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: usize,
    part_2: usize,
} {
    var line = (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize))).?;
    defer allocator.free(line);

    var s = try Simulate.init(allocator);
    defer s.deinit();

    var cache = std.AutoHashMap(struct {
        rock: usize,
        line_idx: usize,
        hash: u64,
    }, struct {
        iter: usize,
        height: usize,
    }).init(allocator);
    defer cache.deinit();

    var part_1: usize = 0;
    var part_2: usize = 0;
    var max_iter: usize = 1000000000000;

    var i: usize = 0;
    while (true) : (i += 1) {
        if (try s.step(line[i % line.len])) {
            if (s.nr_rocks - 1 == 2022) {
                part_1 = s.top();
            } else if (s.nr_rocks - 1 == max_iter) {
                part_2 += s.top();
                break;
            } else if (s.nr_rocks < 3000 or s.map.items.len < 31) {
                continue;
            }

            var kv = try cache.getOrPut(.{
                .rock = s.nr_rocks % Simulate.rocks.len,
                .line_idx = i % line.len,
                .hash = std.hash.CityHash64.hash(s.map.items[s.map.items.len - 30 ..]),
            });
            if (kv.found_existing) {
                // found cycle
                var cycle_len = s.nr_rocks - kv.value_ptr.*.iter;
                var cnt = @divFloor((max_iter - s.nr_rocks), cycle_len);
                max_iter -= cnt * cycle_len;
                part_2 += cnt * (s.top() - kv.value_ptr.*.height);
            } else {
                kv.value_ptr.* = .{
                    .iter = s.nr_rocks,
                    .height = s.top(),
                };
            }
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

test "day17" {
    const input =
        \\>>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(3068 == result.part_1);
    try std.testing.expect(1514285714288 == result.part_2);
}
