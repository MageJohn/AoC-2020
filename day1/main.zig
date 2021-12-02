const std = @import("std");
const fmt = std.fmt;
const fs = std.fs;
const io = std.io;
const os = std.os;
const process = std.process;

fn InputIterator(comptime T: type) type {
    return struct {
        input: T,
        fn next(self: *const InputIterator(T)) !?u16 {
            var raw_buf: [4]u8 = undefined;
            const str = (try self.input.readUntilDelimiterOrEof(raw_buf[0..], '\n')) orelse return null;
            return try fmt.parseInt(u16, str, 10);
        }
    };
}

fn inputIterator(input: anytype) InputIterator(@TypeOf(input)) {
    return .{ .input = input };
}

// input is a reader
fn depthIncreases(input: anytype) !u16 {
    const input_iter = inputIterator(input);

    var last_depth = (try input_iter.next()) orelse unreachable;
    var increases: u16 = 0;

    while (try input_iter.next()) |cur_depth| {
        if (cur_depth > last_depth) {
            increases += 1;
        }
        last_depth = cur_depth;
    }

    return increases;
}

// input is a reader
fn windowedDepthIncreases(input: anytype) !u16 {
    const input_iter = inputIterator(input);

    var window: [4]u16 = undefined;
    for (window) |_, i| {
        window[i] = (try input_iter.next()) orelse unreachable;
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

        window[window.len - 1] = (try input_iter.next()) orelse break;
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
    try std.testing.expectEqual(
        @intCast(u16, 7),
        try depthIncreases(test_input),
    );
}

test "Part 2 example" {
    const test_input = io.fixedBufferStream(test_input_data).reader();
    try std.testing.expectEqual(
        @intCast(u16, 5),
        try windowedDepthIncreases(test_input),
    );
}

test "InputIterator" {
    const data =
        \\199
        \\200
    ;
    const iter = inputIterator(io.fixedBufferStream(data).reader());
    try std.testing.expectEqual(@as(?u16, 199), try iter.next());
    try std.testing.expectEqual(@as(?u16, 200), try iter.next());
    try std.testing.expectEqual(@as(?u16, null), try iter.next());
}

pub fn main() anyerror!void {
    const input_file = try fs.cwd().openFile("day1/input.txt", .{});
    defer input_file.close();
    const reader = io.bufferedReader(input_file.reader()).reader();
    const stdout = io.getStdOut().writer();

    try stdout.print("Part 1 solution: {}\n", .{try depthIncreases(reader)});
    try input_file.seekTo(0);
    try stdout.print("Part 2 solution: {}\n", .{try windowedDepthIncreases(reader)});
}
