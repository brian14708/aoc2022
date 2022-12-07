const std = @import("std");
const scan = @import("scan.zig").scan;

const Entry = union(enum) {
    dir: *FileSystem,
    file: u32,
};

const FileSystem = struct {
    sub: std.StringHashMap(Entry),
    allocator: std.mem.Allocator,
    parent: ?*FileSystem,
    size: ?u32,

    fn init(parent: ?*FileSystem, allocator: std.mem.Allocator) @This() {
        return .{
            .sub = std.StringHashMap(Entry).init(allocator),
            .allocator = allocator,
            .parent = parent,
            .size = null,
        };
    }

    fn deinit(self: *@This()) void {
        var it = self.sub.iterator();
        while (it.next()) |kv| {
            switch (kv.value_ptr.*) {
                .dir => |d| {
                    d.deinit();
                    self.allocator.destroy(d);
                },
                .file => {},
            }
            self.allocator.free(kv.key_ptr.*);
        }
        self.sub.deinit();
    }

    fn addFile(self: *@This(), name: []const u8, size: u32) !void {
        if (self.size != null) {
            var parent: ?*FileSystem = self;
            while (parent) |p| {
                p.size = null;
                parent = p.parent;
            }
        }
        try self.sub.putNoClobber(try self.allocator.dupe(u8, name), .{ .file = size });
    }

    fn cd(self: *@This(), dir: []const u8) !*FileSystem {
        if (dir.len == 0) {
            return self;
        }
        if (self.sub.get(dir)) |d| {
            switch (d) {
                .dir => |dd| return dd,
                .file => unreachable,
            }
        } else {
            var d = try self.allocator.create(@This());
            d.* = @This().init(self, self.allocator);
            try self.sub.putNoClobber(try self.allocator.dupe(u8, dir), .{ .dir = d });
            return d;
        }
    }

    fn total_size(self: *@This()) u32 {
        if (self.size) |s| {
            return s;
        }
        var total: u32 = 0;
        var it = self.sub.valueIterator();
        while (it.next()) |i| {
            switch (i.*) {
                .dir => |d| total += d.total_size(),
                .file => |s| total += s,
            }
        }
        self.size = total;
        return total;
    }

    fn dfs(self: *@This(), f: fn (*FileSystem) bool, allocator: std.mem.Allocator) !std.ArrayList(*FileSystem) {
        var result = std.ArrayList(*FileSystem).init(allocator);
        errdefer result.deinit();
        try self._dfs(f, &result);
        return result;
    }

    fn _dfs(self: *@This(), f: fn (*FileSystem) bool, r: *std.ArrayList(*FileSystem)) anyerror!void {
        if (f(self)) {
            try r.append(self);
        }

        var it = self.sub.valueIterator();
        while (it.next()) |v| {
            switch (v.*) {
                .dir => |d| try d._dfs(f, r),
                .file => {},
            }
        }
    }
};

fn has_prefix(comptime prefix: []const u8, target: []const u8) bool {
    if (target.len <= prefix.len) {
        return false;
    }
    return std.mem.eql(u8, prefix, target[0..prefix.len]);
}

fn popd(arr: *std.ArrayList(u8)) void {
    if (std.mem.lastIndexOfScalar(u8, arr.items, '/')) |s| {
        if (s == 0) {
            arr.shrinkRetainingCapacity(1);
        } else {
            arr.shrinkRetainingCapacity(s - 1);
        }
    }
    return;
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: u32,
    part_2: u32,
} {
    var fs = FileSystem.init(null, allocator);
    defer fs.deinit();

    var curr = &fs;

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (has_prefix("$ cd ", line)) {
            var dir = line[5..];
            if (std.mem.eql(u8, "..", dir)) {
                curr = curr.parent.?;
            } else if (dir[0] == '/') {
                curr = try fs.cd(dir[1..]);
            } else {
                curr = try curr.cd(dir);
            }
        } else if (has_prefix("$ ", line)) {
            // skip commands
        } else {
            var it = std.mem.split(u8, line, " ");
            if (std.fmt.parseInt(u32, it.next().?, 10)) |s| {
                try curr.addFile(it.next().?, s);
            } else |_| {
                // dir
                _ = try curr.cd(it.next().?);
            }
        }
    }

    var dirs = try fs.dfs(always(*FileSystem), allocator);
    defer dirs.deinit();
    std.sort.sort(*FileSystem, dirs.items, {}, struct {
        fn lambda(_: void, a: *FileSystem, b: *FileSystem) bool {
            return a.total_size() > b.total_size();
        }
    }.lambda);

    var part_1: u32 = 0;
    var part_2: u32 = 0;
    for (dirs.items) |d| {
        if (d.total_size() <= 100000) {
            part_1 += d.total_size();
        }
        if (70000000 - (fs.total_size() - d.total_size()) >= 30000000) {
            part_2 = d.total_size();
        }
    }

    const r = .{
        .part_1 = part_1,
        .part_2 = part_2,
    };
    return r;
}

fn always(comptime T: type) fn (T) bool {
    return struct {
        fn lambda(_: T) bool {
            return true;
        }
    }.lambda;
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin, allocator);

    try std.fmt.format(stdout, "Part 1: {}\n", .{result.part_1});
    try std.fmt.format(stdout, "Part 2: {}\n", .{result.part_2});
}

test "day06" {
    const input =
        \\$ cd /
        \\$ ls
        \\dir a
        \\14848514 b.txt
        \\8504156 c.dat
        \\dir d
        \\$ cd a
        \\$ ls
        \\dir e
        \\29116 f
        \\2557 g
        \\62596 h.lst
        \\$ cd e
        \\$ ls
        \\584 i
        \\$ cd ..
        \\$ cd ..
        \\$ cd d
        \\$ ls
        \\4060174 j
        \\8033020 d.log
        \\5626152 d.ext
        \\7214296 k
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(95437 == result.part_1);
    try std.testing.expect(24933642 == result.part_2);
}
