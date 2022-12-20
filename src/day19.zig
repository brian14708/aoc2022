const std = @import("std");
const scan = @import("scan.zig").scan;
const Queue = @import("queue.zig").Queue;

const Blueprint = struct {
    ore_ore: i16,
    clay_ore: i16,
    obsidian_ore: i16,
    obsidian_clay: i16,
    geode_ore: i16,
    geode_obsidian: i16,
};

const State = struct {
    ore: i16,
    clay: i16,
    obsidian: i16,
    geode: i16,
};

const BFSState = struct {
    t: i16,
    ores: State,
    robots: State,
};

fn build(allocator: std.mem.Allocator, t: i16, b: Blueprint, ores: State, robots: State) !i16 {
    var bfs = Queue(BFSState).init(allocator);
    defer bfs.deinit();

    var seen = std.AutoHashMap(BFSState, void).init(allocator);
    defer seen.deinit();

    const max_ore_per_timestep = std.math.max(std.math.max(b.geode_ore, b.obsidian_ore), std.math.max(b.ore_ore, b.clay_ore));

    try bfs.add(.{
        .t = 0,
        .ores = ores,
        .robots = robots,
    });

    var best: i16 = std.math.minInt(i16) + 1;
    while (true) {
        var curr = bfs.remove();
        if (curr.t > t) {
            return best;
        }
        if (seen.contains(curr)) continue;
        if (curr.ores.geode < best - 1) continue;

        best = std.math.max(best, curr.ores.geode);
        try seen.put(curr, {});

        if (curr.ores.ore >= b.geode_ore and curr.ores.obsidian >= b.geode_obsidian) {
            try bfs.add(.{
                .t = curr.t + 1,
                .ores = .{
                    .ore = curr.ores.ore + curr.robots.ore - b.geode_ore,
                    .clay = curr.ores.clay + curr.robots.clay,
                    .obsidian = curr.ores.obsidian + curr.robots.obsidian - b.geode_obsidian,
                    .geode = curr.ores.geode + curr.robots.geode,
                },
                .robots = .{
                    .ore = curr.robots.ore,
                    .clay = curr.robots.clay,
                    .obsidian = curr.robots.obsidian,
                    .geode = curr.robots.geode + 1,
                },
            });
            continue;
        }

        try bfs.add(.{
            .t = curr.t + 1,
            .ores = .{
                .ore = curr.ores.ore + curr.robots.ore,
                .clay = curr.ores.clay + curr.robots.clay,
                .obsidian = curr.ores.obsidian + curr.robots.obsidian,
                .geode = curr.ores.geode + curr.robots.geode,
            },
            .robots = curr.robots,
        });

        if (curr.robots.obsidian < b.geode_obsidian) {
            if (curr.ores.ore >= b.obsidian_ore and curr.ores.clay >= b.obsidian_clay) {
                try bfs.add(.{
                    .t = curr.t + 1,
                    .ores = .{
                        .ore = curr.ores.ore + curr.robots.ore - b.obsidian_ore,
                        .clay = curr.ores.clay + curr.robots.clay - b.obsidian_clay,
                        .obsidian = curr.ores.obsidian + curr.robots.obsidian,
                        .geode = curr.ores.geode + curr.robots.geode,
                    },
                    .robots = .{
                        .ore = curr.robots.ore,
                        .clay = curr.robots.clay,
                        .obsidian = curr.robots.obsidian + 1,
                        .geode = curr.robots.geode,
                    },
                });
            }
        }
        if (curr.robots.clay < b.obsidian_clay) {
            if (curr.ores.ore >= b.clay_ore) {
                try bfs.add(.{
                    .t = curr.t + 1,
                    .ores = .{
                        .ore = curr.ores.ore + curr.robots.ore - b.clay_ore,
                        .clay = curr.ores.clay + curr.robots.clay,
                        .obsidian = curr.ores.obsidian + curr.robots.obsidian,
                        .geode = curr.ores.geode + curr.robots.geode,
                    },
                    .robots = .{
                        .ore = curr.robots.ore,
                        .clay = curr.robots.clay + 1,
                        .obsidian = curr.robots.obsidian,
                        .geode = curr.robots.geode,
                    },
                });
            }
        }
        if (curr.robots.ore < max_ore_per_timestep) {
            if (curr.ores.ore >= b.ore_ore) {
                try bfs.add(.{
                    .t = curr.t + 1,
                    .ores = .{
                        .ore = curr.ores.ore + curr.robots.ore - b.ore_ore,
                        .clay = curr.ores.clay + curr.robots.clay,
                        .obsidian = curr.ores.obsidian + curr.robots.obsidian,
                        .geode = curr.ores.geode + curr.robots.geode,
                    },
                    .robots = .{
                        .ore = curr.robots.ore + 1,
                        .clay = curr.robots.clay,
                        .obsidian = curr.robots.obsidian,
                        .geode = curr.robots.geode,
                    },
                });
            }
        }
    }
}

fn solve(reader: anytype, allocator: std.mem.Allocator) !struct {
    part_1: i32,
    part_2: i32,
} {
    var data = std.ArrayList(Blueprint).init(allocator);
    defer data.deinit();

    var buf: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var tmp: Blueprint = undefined;
        var id: i16 = undefined;
        _ = try scan(
            line,
            "Blueprint {d}: Each ore robot costs {d} ore. Each clay robot costs {d} ore. Each obsidian robot costs {d} ore and {d} clay. Each geode robot costs {d} ore and {d} obsidian.",
            .{
                &id,                 &tmp.ore_ore,       &tmp.clay_ore,
                &tmp.obsidian_ore,   &tmp.obsidian_clay, &tmp.geode_ore,
                &tmp.geode_obsidian,
            },
        );
        try data.append(tmp);
    }

    var part_1: i32 = 0;
    for (data.items) |b, idx| {
        part_1 += @intCast(i32, idx + 1) * try build(allocator, 24, b, std.mem.zeroes(State), .{
            .ore = 1,
            .clay = 0,
            .obsidian = 0,
            .geode = 0,
        });
    }

    var part_2: i32 = 1;
    if (data.items.len >= 3) {
        data.shrinkRetainingCapacity(3);
    }
    for (data.items) |b| {
        part_2 *= try build(allocator, 32, b, std.mem.zeroes(State), .{
            .ore = 1,
            .clay = 0,
            .obsidian = 0,
            .geode = 0,
        });
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

test "day19" {
    const input =
        \\Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 2 ore. Each obsidian robot costs 3 ore and 14 clay. Each geode robot costs 2 ore and 7 obsidian.
        \\Blueprint 2: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 8 clay. Each geode robot costs 3 ore and 12 obsidian.
    ;

    var buffer = std.io.fixedBufferStream(input);
    const result = try solve(buffer.reader(), std.testing.allocator);

    try std.testing.expect(33 == result.part_1);
    try std.testing.expect(62 * 56 == result.part_2);
}
