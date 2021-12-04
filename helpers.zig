const std = @import("std");

/// Reads the input file into an array of size max_len and returns the data as
/// a slice. The function is inlined so the memory is allocated on the callers
/// stack, so does not require an allocator.
pub inline fn readInput(path: []const u8, comptime max_len: usize) ![]const u8 {
    const input_file = try std.fs.cwd().openFile(path, .{});
    defer input_file.close();

    var input: [max_len]u8 = undefined;
    const length = try input_file.readAll(input[0..]);
    return input[0..length];
}
