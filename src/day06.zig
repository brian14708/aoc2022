const std = @import("std");

fn first_n_nodup(comptime N: usize, arr: []const u8) ?usize {
    var i: usize = 0;
    outer: while (i <= arr.len - N) {
        comptime var j: usize = N - 1;
        inline while (j != 0) : (j -= 1) {
            if (std.mem.lastIndexOfScalar(u8, arr[i .. i + j], arr[i + j])) |k| {
                i += k + 1;
                continue :outer;
            }
        }
        return i;
    }
    return null;
}

test "first_n_nodup" {
    try std.testing.expect(0 == first_n_nodup(4, "abcd").?);
    try std.testing.expect(1 == first_n_nodup(4, "aabcd").?);
    try std.testing.expect(2 == first_n_nodup(4, "aabacd").?);
    try std.testing.expect(5 == first_n_nodup(4, "aaaaaabcd").?);
    try std.testing.expect(7 == 4 + first_n_nodup(4, "mjqjpqmgbljsphdztnvjfqwrcgsmlb").?);
    try std.testing.expect(5 == 4 + first_n_nodup(4, "bvwbjplbgvbhsrlpgdmjqwftvncz").?);
    try std.testing.expect(6 == 4 + first_n_nodup(4, "nppdvjthqldpwncqszvftbrmjlhg").?);
    try std.testing.expect(10 == 4 + first_n_nodup(4, "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg").?);
    try std.testing.expect(11 == 4 + first_n_nodup(4, "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw").?);

    try std.testing.expect(19 == 14 + first_n_nodup(14, "mjqjpqmgbljsphdztnvjfqwrcgsmlb").?);
    try std.testing.expect(23 == 14 + first_n_nodup(14, "bvwbjplbgvbhsrlpgdmjqwftvncz").?);
    try std.testing.expect(23 == 14 + first_n_nodup(14, "nppdvjthqldpwncqszvftbrmjlhg").?);
    try std.testing.expect(29 == 14 + first_n_nodup(14, "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg").?);
    try std.testing.expect(26 == 14 + first_n_nodup(14, "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw").?);
}

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf: [4096]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try std.fmt.format(stdout, "Part 1: {d}\n", .{first_n_nodup(4, line).? + 4});
        try std.fmt.format(stdout, "Part 2: {d}\n", .{first_n_nodup(14, line).? + 14});
    }
}
