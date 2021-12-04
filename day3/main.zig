const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Parse the list of binary strings as integers of type T. T should be an
/// unsigned integer type. Caller owns returned memory.
fn parseInput(comptime T: type, input: []const u8, allocator: *Allocator) ![]T {
    var nums = std.ArrayList(T).init(allocator);
    var it = std.mem.split(u8, input, "\n");
    while (it.next()) |line| {
        if (line.len == 0) break;
        try nums.append(try std.fmt.parseInt(T, line, 2));
    }
    return nums.toOwnedSlice();
}

/// Algorithm implemented almost exactly as described in the puzzle
/// description. For each bit position tots up the total number of times a 1
/// appeared there. Then for each bit position it takes the count and if it is
/// over half the input then 1 is the most common value and so goes in that bit
/// position; otherwise 0 goes there. Epsilon is calculated later, it's just
/// the bitwise inverse of gamma.
fn calculateGamma(comptime T: type, input: []const T) T {
    const width = @typeInfo(T).Int.bits;
    var bit_counts = [_]u16{0} ** width;

    for (input) |num| {
        comptime var i = 0;
        inline while (i < width) : (i += 1) {
            bit_counts[i] += (num & (1 << i)) >> i;
        }
    }

    var ret: T = 0;
    comptime var i = 0;
    inline while (i < width) : (i += 1) {
        const count = bit_counts[i];
        if (count > input.len / 2) {
            ret |= 1 << i;
        }
    }
    return ret;
}

/// A possibly overengineered solution to part 2 based on partial sorting that
/// completes it in O(1) space and O(b * n) time complexity (where b is the
/// number of bits and n is the length of the input). The time complexity will
/// actually be much better than that because n decreases by, on average, half
/// at every step. 
///
/// Reorders the input array in place.
fn calcO2AndCo2(comptime T: type, input: []T) struct { o2: T, co2: T } {
    const width = @typeInfo(T).Int.bits;
    const BitT = std.math.Log2IntCeil(T);
    const Helpers = struct {
        const Context = struct { bit: BitT };
        fn filter(bit: BitT, nums: []T, comptime bias: u1) T {
            if (nums.len == 1) {
                return nums[0];
            }

            const pivot = partition(bit, nums);
            if (nums.len % 2 == 0 and pivot == nums.len / 2) {
                // pivot is exactly halfway through the array, only possible if
                // the array has an even number of items. There is no most
                // common value.
                if (bias == 1) {
                    // bit criteria is biased towards 1s, which are after the pivot.
                    return filter(bit + 1, nums[pivot..], bias);
                } else {
                    // bit criteria is biased towards 0s, which are before the pivot.
                    return filter(bit + 1, nums[0..pivot], bias);
                }
            } else if (pivot > nums.len / 2) {
                // pivot is over halfway through the array. The most common
                // value is before the pivot.
                if (bias == 1) {
                    // bit criteria is the most common value
                    return filter(bit + 1, nums[0..pivot], bias);
                } else {
                    // bit criteria is the least common value
                    return filter(bit + 1, nums[pivot..], bias);
                }
            } else {
                // pivot is less than halfway through the array. The most
                // common value is after the pivot.
                if (bias == 1) {
                    // bit criteria is the most common value
                    return filter(bit + 1, nums[pivot..], bias);
                } else {
                    // bit criteria is the least common value
                    return filter(bit + 1, nums[0..pivot], bias);
                }
            }
        }
        fn partition(bit: BitT, nums: []T) usize {
            const mask = bitMask(bit);
            var zeros: usize = 0;
            var ones: usize = nums.len;
            while (zeros < ones) {
                if (nums[ones - 1] & mask == 0) {
                    // should be in the zeros
                    swap(nums, zeros, ones - 1);
                    zeros += 1;
                } else {
                    // should be part of the ones
                    ones -= 1;
                }
            }
            return zeros;
        }
        fn swap(nums: []T, i: usize, j: usize) void {
            const tmp = nums[i];
            nums[i] = nums[j];
            nums[j] = tmp;
        }
        fn bitMask(bit: BitT) T {
            return @intCast(T, 1) << (width - bit - 1);
        }
    };

    // partition into candidate values for o2 and co2
    const pivot = Helpers.partition(0, input);
    if (pivot > input.len / 2) {
        return .{
            .o2 = Helpers.filter(1, input[0..pivot], 1),
            .co2 = Helpers.filter(1, input[pivot..], 0),
        };
    } else {
        return .{
            .o2 = Helpers.filter(1, input[pivot..], 1),
            .co2 = Helpers.filter(1, input[0..pivot], 0),
        };
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const input = try std.fs.cwd().readFileAlloc(allocator, "day3/input.txt", 1000 * 13);
    var nums = try parseInput(u12, input, allocator);

    const gamma: u32 = calculateGamma(u12, nums);
    const epsilon = gamma ^ std.math.maxInt(u12);

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Gamma = {}, Epsilon = {}\n", .{ gamma, epsilon });
    try stdout.print("Power consumption: {}\n", .{gamma * epsilon});

    const lifeSupportData = calcO2AndCo2(u12, nums);
    const result: u32 = @intCast(u32, lifeSupportData.o2) * lifeSupportData.co2;

    try stdout.print("Life support rating: {}\n", .{result});
}

const example_raw =
    \\00100
    \\11110
    \\10110
    \\10111
    \\10101
    \\01111
    \\00111
    \\11100
    \\10000
    \\11001
    \\00010
    \\01010
;
const example_parsed = [_]u5{
    0b00100,
    0b11110,
    0b10110,
    0b10111,
    0b10101,
    0b01111,
    0b00111,
    0b11100,
    0b10000,
    0b11001,
    0b00010,
    0b01010,
};

test "parseInput" {
    const parsed = try parseInput(u5, example_raw, std.testing.allocator);
    defer std.testing.allocator.free(parsed);

    try std.testing.expectEqualSlices(u5, example_parsed[0..], parsed);
}

test "calculateGamma" {
    const gamma = calculateGamma(u5, &example_parsed);
    try std.testing.expectEqual(@intCast(u5, 22), gamma);
}

test "calcO2AndCo2" {
    var input: [example_parsed.len]u5 = undefined;
    std.mem.copy(u5, &input, &example_parsed);
    const result = calcO2AndCo2(u5, &input);

    try std.testing.expectEqual(@intCast(u5, 23), result.o2);
    try std.testing.expectEqual(@intCast(u5, 10), result.co2);
}
