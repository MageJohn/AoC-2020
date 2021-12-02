const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const cwd = std.fs.cwd();

    comptime var i = 1;
    inline while (i <= 25) : (i += 1) {
        const day_num: []const u8 = &(if (i < 10) .{'0' + i} else .{ '0' + @divTrunc(i, 10), '0' + @rem(i, 10) });
        const day_str = "day" ++ day_num;
        if (cwd.access(day_str, .{})) |_| {
            const exe = b.addExecutable(day_str, day_str ++ "/main.zig");
            exe.setTarget(target);
            exe.setBuildMode(mode);
            exe.install();

            const run_cmd = exe.run();
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step(day_str, "Run day " ++ day_num);
            run_step.dependOn(&run_cmd.step);

            const exe_tests = b.addTest(day_str ++ "/main.zig");
            exe_tests.setBuildMode(mode);

            const test_step = b.step(day_str++"-test", "Run unit tests for day " ++ day_num);
            test_step.dependOn(&exe_tests.step);
        } else |_| {}
    }
}
