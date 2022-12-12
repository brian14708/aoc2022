const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();
        head: std.ArrayList(T),
        tail: std.ArrayList(T),
        len: usize,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .head = std.ArrayList(T).init(allocator),
                .tail = std.ArrayList(T).init(allocator),
                .len = 0,
            };
        }

        pub fn deinit(self: Self) void {
            self.head.deinit();
            self.tail.deinit();
        }

        pub fn remove(self: *Self) T {
            std.debug.assert(self.len > 0);
            self.len -= 1;
            if (self.tail.items.len == 0) {
                std.mem.swap(std.ArrayList(T), &self.head, &self.tail);
                std.mem.reverse(T, self.tail.items);
            }
            return self.tail.pop();
        }

        pub fn add(self: *Self, t: T) !void {
            try self.head.append(t);
            self.len += 1;
        }

        pub fn clear(self: *Self) void {
            self.head.shrinkRetainingCapacity(0);
            self.tail.shrinkRetainingCapacity(0);
        }
    };
}
