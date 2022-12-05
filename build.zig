const std = @import("std");

fn addDeps(exe: anytype) void {
    exe.addPackagePath("range", "./lib/zig-range/src/lib.zig");
}

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    var i: u32 = 1;
    while (i <= 25) : (i += 1) {
        const exe = b.addExecutable(
            b.fmt("day{d:0>2}", .{i}),
            b.fmt("src/day{d:0>2}.zig", .{i}),
        );
        addDeps(exe);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(&exe.install_step.?.step);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(
            b.fmt("run-day{d:0>2}", .{i}),
            b.fmt("Run day {d}", .{i}),
        );
        run_step.dependOn(&run_cmd.step);
    }

    const exe_tests = b.addTest("src/test_all.zig");
    addDeps(exe_tests);
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
