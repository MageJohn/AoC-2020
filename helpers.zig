const std = @import("std");

// Inline means the memory is in the callers stack frame.
pub inline fn readInput(path: []const u8, comptime max_len: usize) ![]const u8 {
    const input_file = try std.fs.cwd().openFile(path, .{});
    defer input_file.close();

    var input: [max_len]u8 = undefined;
    const length = try input_file.readAll(input[0..]);
    return input[0..length];
}
