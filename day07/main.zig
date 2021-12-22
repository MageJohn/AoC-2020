const std = @import("std");
const helpers = @import("helpers");

fn readNums(comptime len: usize, input: []const u8) ![len]f64 {
    var iter = std.mem.split(u8, input, ",");
    var nums: [len]f64 = undefined;
    var i: usize = 0;
    while (iter.next()) |num| : (i += 1) {
        nums[i] = std.fmt.parseFloat(f64, num) catch {
            std.debug.print("{any}\n", .{num});
            return error.InvalidCharacter;
        };
    }

    return nums;
}

fn median(comptime len: usize, nums: [len]f64) f64 {
    var sorted = nums;
    std.sort.sort(f64, &sorted, {}, comptime std.sort.asc(f64));

    return sorted[sorted.len / 2];
}

fn mean(comptime len: usize, nums: [len]f64) f64 {
    var sum: f64 = 0;
    for (nums) |num| sum += num;

    const res = sum / @intToFloat(f64, nums.len);
    return res;
}

fn sumAbsDeviation(nums: []const f64, pos: f64) f64 {
    var sum: f64 = 0;
    for (nums) |num| {
        sum += @fabs(pos - num);
    }
    return sum;
}

fn sumSquaredDeviation(nums: []const f64, pos: f64) f64 {
    var sum: f64 = 0;
    for (nums) |num| {
        const dist = pos - num;
        sum += dist * dist;
    }
    return sum;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const input = try helpers.readInput("day7/input.txt", 1000 * ("xxxx,".len));

    const nums = try readNums(1000, input[0 .. input.len - 1]);

    const med = median(1000, nums);
    const total_fuel_1 = sumAbsDeviation(&nums, med);

    try stdout.print("Total fuel (part 1): {d}\n", .{total_fuel_1});

    const avg = mean(1000, nums);
    const floor_avg = @floor(avg);
    const ceil_avg = @ceil(avg);
    const fuel_a = (sumSquaredDeviation(&nums, floor_avg) + sumAbsDeviation(&nums, floor_avg))/2;
    const fuel_b = (sumSquaredDeviation(&nums, ceil_avg) + sumAbsDeviation(&nums, ceil_avg))/2;
    try stdout.print("Total fuel (part 2): {d}\n", .{@minimum(fuel_a, fuel_b)});
}

const example = "16,1,2,0,4,2,7,1,2,14";
const example_parsed = [_]f64{ 16, 1, 2, 0, 4, 2, 7, 1, 2, 14 };

test "readNums" {
    const nums = try readNums(10, example);
    try std.testing.expectEqualSlices(f64, &example_parsed, &nums);
}

test "median" {
    try std.testing.expectEqual(@floatCast(f64, 2), median(10, example_parsed));
}

test "mean" {
    try std.testing.expectEqual(@floatCast(f64, 4.9), mean(10, example_parsed));
}

test "sumAbsDeviation" {
    try std.testing.expectEqual(@floatCast(f64, 37), sumAbsDeviation(&example_parsed, 2));
}

test "sumSquaredDeviation" {
    try std.testing.expectEqual(@floatCast(f64, 291), sumSquaredDeviation(&example_parsed, 5));
}
