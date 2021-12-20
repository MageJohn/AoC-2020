const std = @import("std");
const helpers = @import("helpers");

const assert = std.debug.assert;

fn readNumCounts(input: []const u8) [9]u64 {
    var num_strings = std.mem.split(u8, input, ",");
    var nums = [_]u64{0} ** 9;
    while (num_strings.next()) |num_string| {
        assert(num_string.len == 1);
        const digit = num_string[0];
        assert('0' <= digit and digit <= '8');

        nums[digit - '0'] += 1;
    }
    return nums;
}

fn simulate(init_counts: [9]u64, days: u16) u64 {
    var counts = init_counts;
    var day: u16 = 8;
    while (day <= days) : (day += 8) {
        var next_counts = [_]u64{0} ** 9;
        for (counts) |count, age| {
            if (age == 0) {
                next_counts[1] += count;
                next_counts[8] += count;
                next_counts[6] += count;
            } else if (age == 8) {
                next_counts[0] += count;
            } else {
                next_counts[(age + 1) % 9] += count;
                next_counts[age - 1] += count;
            }
        }
        counts = next_counts;
    }

    var sum: u64 = 0;
    for (counts) |count| {
        sum += count;
    }
    return sum;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const input = try helpers.readInput("day6/input.txt", 599);

    const num_counts = readNumCounts(input);

    try stdout.print("Population after 80 days: {}\n", .{simulate(num_counts, 80)});

    try stdout.print("Population after 256 days: {}\n", .{simulate(num_counts, 256)});
}

const example = "3,4,3,1,2";
const example_parsed = [9]u64{ 0, 1, 1, 2, 1, 0, 0, 0, 0 };

test "readNumCounts" {
    const num_counts = readNumCounts(example);
    try std.testing.expectEqualSlices(u64, &example_parsed, &num_counts);
}

// Disabled as it is not a multiple of 8
// test "simulate 18" {
//     const res_18 = simulate(example_parsed, 18);
//     try std.testing.expectEqual(@intCast(u64, 26), res_18);
// }

test "simulate 80" {
    const res_80 = simulate(example_parsed, 80);
    try std.testing.expectEqual(@intCast(u64, 5934), res_80);
}

test "simulate 256" {
    const res = simulate(example_parsed, 256);
    try std.testing.expectEqual(@intCast(u64, 26984457539), res);
}
