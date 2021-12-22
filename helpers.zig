const std = @import("std");

const ReadInputError = std.fs.File.OpenError || std.fs.File.ReadError;

/// Reads the input file into an array of size max_len and returns the data as
/// a slice. The function is inlined so the memory is allocated on the callers
/// stack, so does not require an allocator.
pub inline fn readInput(path: []const u8, comptime max_len: usize) ReadInputError![]const u8 {
    const input_file = try std.fs.cwd().openFile(path, .{});
    defer input_file.close();

    var input: [max_len]u8 = undefined;
    const length = try input_file.readAll(input[0..]);
    return input[0..length];
}

// Fills the passed slice with values from the iterator. The iterator should be
// an object with a next() method returning values of type T. If the iterator
// is exhausted before the slice is full, the returned slice may be shorter
// than the passed one. If the slice is filled, the iterator may not be
// exhausted.
pub fn fillFromIter(comptime T: type, iter: anytype, slice: []T) []T {
    var i: usize = 0;
    while (iter.next()) |val| : (i += 1) {
        slice[i] = val;
    }
    return slice[0..i];
}

test "fillFromIter" {
    const Iter = struct {
        i: u8 = 5,
        fn next(self: *@This()) ?u8 {
            return if (self.i > 0) blk: {
                self.i -= 1;
                break :blk self.i;
            } else null;
        }
    };
    var iter = Iter{};
    var buf: [5]u8 = undefined;
    const slice = fillFromIter(u8, &iter, buf[0..]);
    try std.testing.expectEqualSlices(u8, &.{4, 3, 2, 1, 0}, slice);
}

pub fn iterMap(iter: anytype, func: anytype) IterMap(
    @TypeOf(iter),
    @typeInfo(std.meta.declarationInfo(@TypeOf(iter), "next").data.Fn.return_type).Optional.child,
    @typeInfo(@TypeOf(func)).Fn.return_type.?,
) {
    return .{
        .iter = iter,
        .func = func,
    };
}

pub fn IterMap(comptime Context: type, comptime In: type, comptime Out: type) type {
    return struct {
        iter: Context,
        func: fn (val: In) Out,

        pub fn next(self: *@This()) ?Out {
            return if (self.iter.next()) |in|
                self.func(in)
            else
                null;
        }
    };
}

test "iterMap" {
    const H = struct {
        fn parseDigit(d: []const u8) u4 {
            std.debug.assert(d.len == 1);
            return @intCast(u4, d[0] - '0');
        }
    };
    var iter = std.mem.split(u8, "1 2 3 4 5 6 7 8 9", " ");
    var mapped_iter = iterMap(iter, H.parseDigit);

    var expected: u4 = 1;
    while (mapped_iter.next()) |n| : (expected += 1) {
        try std.testing.expectEqual(expected, n);
    }
}
