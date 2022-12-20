const std = @import("std");
const scan = @import("scan.zig").scan;

fn VM(comptime nr_regs: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        const Instruction = union(enum) {
            noop: void,
            add: struct {
                reg: u8,
                val: T,
            },
        };

        instructions: std.ArrayList(Instruction),
        registers: [nr_regs]T,
        cycle: usize,
        pc: usize,
        wait: usize,

        fn init(allocator: std.mem.Allocator) Self {
            return .{
                .instructions = std.ArrayList(Instruction).init(allocator),
                .registers = std.mem.zeroes([nr_regs]T),
                .cycle = 1,
                .pc = 0,
                .wait = 0,
            };
        }

        fn reset(self: *Self) void {
            self.registers = std.mem.zeroes([nr_regs]T);
            self.cycle = 1;
            self.pc = 0;
            self.wait = 0;
        }

        fn deinit(self: Self) void {
            self.instructions.deinit();
        }

        fn appendInstruction(self: *Self, ins: []const u8) !void {
            var reg: u8 = undefined;
            var val: T = undefined;
            if (scan(ins, "add{c} {d}", .{ &reg, &val })) |_| {
                return self.instructions.append(.{
                    .add = .{
                        .reg = reg - 'x',
                        .val = val,
                    },
                });
            } else |_| {}
            if (std.mem.eql(u8, ins, "noop")) {
                return self.instructions.append(.noop);
            }
            return error.InvalidInstruction;
        }

        fn setRegister(self: *Self, reg: u8, val: T) void {
            self.registers[reg - 'x'] = val;
        }

        fn getRegister(self: *Self, reg: u8) T {
            return self.registers[reg - 'x'];
        }

        fn step(self: *Self) ?void {
            self.cycle += 1;
            if (self.pc >= self.instructions.items.len) {
                return null;
            }

            const ins = self.instructions.items[self.pc];
            const time_to_execute: usize = switch (ins) {
                .noop => 1,
                .add => 2,
            };

            if (self.wait + 1 != time_to_execute) {
                self.wait += 1;
                return;
            }

            switch (ins) {
                .noop => {},
                .add => |a| self.registers[a.reg] += a.val,
            }
            self.wait = 0;
            self.pc += 1;
            return;
        }

        test {
            var vm = VM(1, i32).init(std.testing.allocator);
            defer vm.deinit();

            vm.setRegister('x', 1);
            try vm.appendInstruction("noop");
            try vm.appendInstruction("addx 3");
            try vm.appendInstruction("addx -5");
            while (vm.step()) |_| {}
            try std.testing.expect(-1 == vm.getRegister('x'));
        }
    };
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: std.ArrayList(u8),

    fn deinit(self: @This()) void {
        self.part_2.deinit();
    }
} {
    var vm = VM(1, i32).init(allocator);
    defer vm.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try vm.appendInstruction(line);
    }

    var part_1: i32 = 0;
    {
        vm.setRegister('x', 1);
        while (true) {
            if ((vm.cycle + 20) % 40 == 0) {
                part_1 += vm.getRegister('x') * @intCast(i32, vm.cycle);
            }
            if (vm.step() == null) break;
        }
    }

    var output = std.ArrayList(u8).init(allocator);
    {
        vm.reset();
        vm.setRegister('x', 1);

        const lines = 6;
        const width = 40;

        while (output.items.len != (width + 1) * lines - 1) {
            const pos = vm.getRegister('x');
            const crt = (vm.cycle - 1) % width;
            if (crt == 0 and output.items.len != 0) {
                try output.append('\n');
            }
            try output.append(if (pos == crt or pos + 1 == crt or pos - 1 == crt) '#' else '.');
            _ = vm.step();
        }
    }

    const result = .{
        .part_1 = part_1,
        .part_2 = output,
    };
    return result;
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const result = try solve(stdin, allocator);
    defer result.deinit();

    try std.fmt.format(stdout, "Part 1: {}\n", .{result.part_1});
    try std.fmt.format(stdout, "Part 2:\n{s}\n", .{result.part_2.items});
}

test "day10" {
    const input = @embedFile("testcase/day10.txt");

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);
    defer result.deinit();

    try std.testing.expect(13140 == result.part_1);
    try std.testing.expectEqual(@as(?usize, null), std.mem.indexOfDiff(u8, result.part_2.items,
        \\##..##..##..##..##..##..##..##..##..##..
        \\###...###...###...###...###...###...###.
        \\####....####....####....####....####....
        \\#####.....#####.....#####.....#####.....
        \\######......######......######......####
        \\#######.......#######.......#######.....
    ));
}
