const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const io = std.io;
const os = std.os;
const process = std.process;

// input is a reader
fn depthIncreases(input: anytype) !u16 {
    var raw_buf: [4]u8 = undefined;
    var depth_str = try input.readUntilDelimiter(raw_buf[0..], '\n');

    var last_depth = try fmt.parseInt(u16, depth_str, 10);
    var cur_depth: u16 = 0;
    var increases: u16 = 0;

    while (true) : (last_depth = cur_depth) {
        depth_str = (try input.readUntilDelimiterOrEof(raw_buf[0..], '\n')) orelse break;
        cur_depth = try fmt.parseInt(u16, depth_str, 10);
        if (cur_depth > last_depth) {
            increases += 1;
        }
    }

    return increases;
}

// input is a reader
fn windowedDepthIncreases(input: anytype) !u16 {
    var raw_buf: [4]u8 = undefined;
    var depth_str: []const u8 = undefined;

    var window: [4]u16 = undefined;
    for (window) |_, i| {
        depth_str = try input.readUntilDelimiter(raw_buf[0..], '\n');
        window[i] = try fmt.parseInt(u16, depth_str, 10);
    }

    var increases: u16 = 0;

    while (true) {
        if (window[window.len - 1] > window[0]) {
            increases += 1;
        }

        var i: u2 = 0;
        while (i < window.len - 1) : (i += 1) {
            window[i] = window[i + 1];
        }

        depth_str = (try input.readUntilDelimiterOrEof(raw_buf[0..], '\n')) orelse break; 
        window[window.len - 1] = try fmt.parseInt(u16, depth_str, 10);
    }

    return increases;
}

const test_input_data =
    \\199
    \\200
    \\208
    \\210
    \\200
    \\207
    \\240
    \\269
    \\260
    \\263
;
test "Part 1 example" {
    const test_input = io.fixedBufferStream(test_input_data).reader();

    const result = try depthIncreases(test_input);
    try std.testing.expectEqual(@intCast(u16, 7), result);
}

test "Part 2 example" {
    const test_input = io.fixedBufferStream(test_input_data).reader();

    const result = try windowedDepthIncreases(test_input);
    try std.testing.expectEqual(@intCast(u16, 5), result);
}

pub fn main() anyerror!void {
    const input_file = try fs.cwd().openFile("day1/input.txt", .{});
    defer input_file.close();
    const stdout = io.getStdOut().writer();

    try stdout.print("Part 1 solution: {}\n", .{try depthIncreases(input_file.reader())});
    try input_file.seekTo(0);
    try stdout.print("Part 2 solution: {}\n", .{try windowedDepthIncreases(input_file.reader())});
}
