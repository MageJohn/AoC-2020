const std = @import("std");
const helpers = @import("helpers");

const MAX_INPUT_LEN = 1000;
const MAX_LINE_LEN = "forward X\n".len;

const Step = struct {
    dir: Dir,
    amount: u4,

    const Dir = enum {
        forward,
        down,
        up,
    };
};

const Position = struct {
    horizontal: u32 = 0,
    depth: u32 = 0,
};

fn calculateFinalPosition1(steps: []const Step) Position {
    var pos: Position = .{};
    for (steps) |step| {
        switch (step.dir) {
            .forward => pos.horizontal += step.amount,
            .down => pos.depth += step.amount,
            .up => pos.depth -= step.amount,
        }
    }
    return pos;
}

fn calculateFinalPosition2(steps: []const Step) Position {
    var pos: Position = .{};
    var aim: u32 = 0;
    for (steps) |step| {
        switch (step.dir) {
            .forward => {
                pos.horizontal += step.amount;
                pos.depth += aim * step.amount;
            },
            .down => aim += step.amount,
            .up => aim -= step.amount,
        }
    }
    return pos;
}

inline fn inputToSteps(input: []const u8) []const Step {
    const input_reader = std.io.fixedBufferStream(input).reader();
    var steps: [MAX_INPUT_LEN]Step = undefined;
    var line: [MAX_LINE_LEN]u8 = undefined;
    var index: usize = 0;
    while (input_reader.readUntilDelimiterOrEof(line[0..], '\n') catch unreachable) |raw_step| {
        steps[index] = .{
            .dir = switch (raw_step[0]) {
                'f' => .forward,
                'd' => .down,
                'u' => .up,
                else => unreachable,
            },
            .amount = @intCast(u4, raw_step[raw_step.len - 1] - '0'),
        };
        index += 1;
    }

    return steps[0..index];
}

const example =
    \\forward 5
    \\down 5
    \\forward 8
    \\up 3
    \\down 8
    \\forward 2
;

test "calculateFinalPosition1" {
    const steps = inputToSteps(example);
    const result = calculateFinalPosition1(steps);

    try std.testing.expectEqual(Position{ .horizontal = 15, .depth = 10 }, result);
    try std.testing.expectEqual(@as(u32, 150), result.horizontal * result.depth);
}

test "calculateFinalPosition2" {
    const steps = inputToSteps(example);
    const result = calculateFinalPosition2(steps);

    try std.testing.expectEqual(Position{ .horizontal = 15, .depth = 60 }, result);
    try std.testing.expectEqual(@as(u32, 900), result.horizontal * result.depth);
}

test "inputToSteps" {
    const steps = inputToSteps(example);

    const expected: []const Step = &[6]Step{
        .{ .dir = .forward, .amount = 5 },
        .{ .dir = .down, .amount = 5 },
        .{ .dir = .forward, .amount = 8 },
        .{ .dir = .up, .amount = 3 },
        .{ .dir = .down, .amount = 8 },
        .{ .dir = .forward, .amount = 2 },
    };

    try std.testing.expectEqualSlices(Step, expected, steps);
}

pub fn main() anyerror!void {
    const input = try helpers.readInput("day2/input.txt", MAX_INPUT_LEN * MAX_LINE_LEN);
    const stdout = std.io.getStdOut().writer();

    const steps = inputToSteps(input);

    const final_pos1 = calculateFinalPosition1(steps);
    const final_pos2 = calculateFinalPosition2(steps);

    try stdout.print("Final position (part 1 rules): horizontal = {}, depth = {}\n", .{ final_pos1.horizontal, final_pos1.depth });
    try stdout.print("Part 1 answer: {}\n", .{final_pos1.horizontal * final_pos1.depth});

    try stdout.print("Final position (part 2 rules): horizontal = {}, depth = {}\n", .{ final_pos2.horizontal, final_pos2.depth });
    try stdout.print("Part 2 answer: {}\n", .{final_pos2.horizontal * final_pos2.depth});
}
