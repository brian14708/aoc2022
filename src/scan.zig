const std = @import("std");

const Pattern = union(enum) {
    constant: struct {
        begin: usize,
        end: usize,
    },
    int: type,
    char: void,
};

pub fn scan(buffer: []const u8, comptime fmt: []const u8, args: anytype) !void {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
    }
    const fields_info = args_type_info.Struct.fields;
    comptime var patterns: [(fields_info.len * 2 + 1)]Pattern = undefined;

    comptime {
        var parts: usize = 1;
        var i: usize = 0;
        inline while (i < fmt.len - 2) : (i += 1) {
            if (fmt[i] == '{' and fmt[i + 2] == '}') {
                parts += 2;
                i += 2;
            }
        }
        if (2 * fields_info.len + 1 != parts) {
            @compileError(std.fmt.comptimePrint("expected to have {} pattern, found {}", .{ (parts - 1) / 2, fields_info.len }));
        }

        var prev: usize = 0;
        var idx: usize = 0;
        i = 0;
        inline while (i < fmt.len - 2) : (i += 1) {
            if (fmt[i] == '{' and fmt[i + 2] == '}') {
                patterns[idx] = .{ .constant = .{ .begin = prev, .end = i } };
                idx += 1;
                switch (fmt[i + 1]) {
                    'd' => switch (fields_info[(idx - 1) / 2].field_type) {
                        *u8 => patterns[idx] = .{ .int = u8 },
                        *i8 => patterns[idx] = .{ .int = i8 },
                        *u32 => patterns[idx] = .{ .int = u32 },
                        *i32 => patterns[idx] = .{ .int = i32 },
                        *u64 => patterns[idx] = .{ .int = u64 },
                        *i64 => patterns[idx] = .{ .int = i64 },
                        else => @compileError("unsupported type"),
                    },
                    'c' => patterns[idx] = .{ .char = {} },
                    else => @compileError("unknown pattern"),
                }
                idx += 1;
                prev = i + 3;
                i += 2;
            }
        }
        std.debug.assert(idx == parts - 1);
        patterns[idx] = .{ .constant = .{ .begin = prev, .end = fmt.len } };
    }

    var buffer_idx: usize = 0;
    inline for (patterns) |p, pidx| {
        switch (p) {
            Pattern.constant => |c| {
                const len = c.end - c.begin;
                if (buffer_idx + len > buffer.len) {
                    return error.InvalidInput;
                }
                if (!std.mem.eql(u8, buffer[buffer_idx .. buffer_idx + len], fmt[c.begin..c.end])) {
                    return error.InvalidInput;
                }
                buffer_idx += len;
            },
            Pattern.int => |ty| {
                var new_idx = buffer_idx;
                var first: bool = true;
                while (new_idx < buffer.len) : (new_idx += 1) {
                    const c = buffer[new_idx];
                    if (first and c == ' ') {
                        continue;
                    }
                    if (first) {
                        if (c == '-') {
                            first = false;
                            continue;
                        }
                    }
                    first = false;
                    if (c < '0' or c > '9') {
                        break;
                    }
                }
                @field(args, fields_info[(pidx - 1) / 2].name).* = try std.fmt.parseInt(ty, buffer[buffer_idx..new_idx], 10);
                buffer_idx = new_idx;
            },
            Pattern.char => |_| {
                if (buffer_idx >= buffer.len) {
                    return error.InvalidInput;
                }
                @field(args, fields_info[(pidx - 1) / 2].name).* = buffer[buffer_idx];
                buffer_idx += 1;
            },
        }
    }
}

test {
    try scan("hello", "hello", .{});
    var x: u32 = undefined;
    var y: i32 = undefined;
    try scan("hello 123", "hello {d}", .{&x});
    try std.testing.expectEqual(@as(u32, 123), x);
    try scan("999 hello -123", "{d} hello {d}", .{
        &x,
        &y,
    });
    try std.testing.expectEqual(@as(u32, 999), x);
    try std.testing.expectEqual(@as(i32, -123), y);
}
