const std = @import("std");

pub fn main() anyerror!void {
    if (std.os.argv.len != 2) {
        std.log.err("missing argument", .{});
        return;
    }

    const arg = std.mem.span(std.os.argv[1]);
    if (std.mem.eql(u8, arg, "day01")) return @import("day01.zig").main();
    if (std.mem.eql(u8, arg, "day02")) return @import("day02.zig").main();
    if (std.mem.eql(u8, arg, "day03")) return @import("day03.zig").main();
    if (std.mem.eql(u8, arg, "day04")) return @import("day04.zig").main();
    if (std.mem.eql(u8, arg, "day05")) return @import("day05.zig").main();
    if (std.mem.eql(u8, arg, "day06")) return @import("day06.zig").main();
    if (std.mem.eql(u8, arg, "day07")) return @import("day07.zig").main();
    if (std.mem.eql(u8, arg, "day08")) return @import("day08.zig").main();
    if (std.mem.eql(u8, arg, "day09")) return @import("day09.zig").main();
    if (std.mem.eql(u8, arg, "day10")) return @import("day10.zig").main();
    if (std.mem.eql(u8, arg, "day11")) return @import("day11.zig").main();
    if (std.mem.eql(u8, arg, "day12")) return @import("day12.zig").main();
    if (std.mem.eql(u8, arg, "day13")) return @import("day13.zig").main();
    if (std.mem.eql(u8, arg, "day14")) return @import("day14.zig").main();
    if (std.mem.eql(u8, arg, "day15")) return @import("day15.zig").main();
    if (std.mem.eql(u8, arg, "day16")) return @import("day16.zig").main();
    if (std.mem.eql(u8, arg, "day17")) return @import("day17.zig").main();
    if (std.mem.eql(u8, arg, "day18")) return @import("day18.zig").main();
    if (std.mem.eql(u8, arg, "day19")) return @import("day19.zig").main();
    if (std.mem.eql(u8, arg, "day20")) return @import("day20.zig").main();
    if (std.mem.eql(u8, arg, "day21")) return @import("day21.zig").main();
    if (std.mem.eql(u8, arg, "day22")) return @import("day22.zig").main();
    if (std.mem.eql(u8, arg, "day23")) return @import("day23.zig").main();
    if (std.mem.eql(u8, arg, "day24")) return @import("day24.zig").main();
    if (std.mem.eql(u8, arg, "day25")) return @import("day25.zig").main();

    std.log.err("invalid argument: {s}", .{arg});
}
