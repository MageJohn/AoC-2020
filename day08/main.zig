const std = @import("std");
const helpers = @import("helpers");

const assert = std.debug.assert;

fn parsePattern(_: void, patt: []const u8) u8 {
    var ret: u8 = 0;
    for (patt) |char| {
        ret |= @intCast(u8, 1) << @intCast(u3, (char - 'a'));
    }
    return ret;
}

const Case = struct {
    patterns: [10]u8,
    output: [4]u8,
};

fn parseInput(input: []const u8, comptime len: usize) [len]Case {
    var line_iter = std.mem.split(u8, input, "\n");
    var cases: [len]Case = undefined;
    var case_i: usize = 0;

    while (line_iter.next()) |line| : (case_i += 1) {
        var part_iter = std.mem.split(u8, line, " | ");

        inline for (std.meta.fields(Case)) |field| {
            var iter = helpers.iterMap(std.mem.split(u8, part_iter.next().?, " "), {}, parsePattern);
            _ = helpers.fillFromIter(u8, &iter, &@field(cases[case_i], field.name));
        }
    }
    return cases;
}

fn countBits(val: u8) u3 {
    return @intCast(u3, (@intCast(u64, val) * 0x200040008001 & 0x111111111111111) % 0xf);
}

fn deduceMapping(patterns: [10]u8) [10]u8 {
    var mapping: [10]u8 = undefined;
    var five_segs: [3]u8 = undefined;
    var five_segs_i: u2 = 0;
    var six_segs: [3]u8 = undefined;
    var six_segs_i: u2 = 0;
    for (patterns) |pattern| {
        switch (countBits(pattern)) {
            2 => mapping[1] = pattern,
            3 => mapping[7] = pattern,
            4 => mapping[4] = pattern,
            5 => {
                five_segs[five_segs_i] = pattern;
                five_segs_i += 1;
            },
            6 => {
                six_segs[six_segs_i] = pattern;
                six_segs_i += 1;
            },
            7 => mapping[8] = pattern,
            else => unreachable,
        }
    }
    assert(five_segs_i == five_segs.len);
    assert(six_segs_i == six_segs.len);

    const one = mapping[1];
    const four = mapping[4];
    for (six_segs) |pattern, i| {
        if (i == 2 or pattern & one != one) {
            mapping[6] = pattern;

            if (six_segs[(i + 1) % 3] & four == four) {
                mapping[9] = six_segs[(i + 1) % 3];
                mapping[0] = six_segs[(i + 2) % 3];
            } else {
                mapping[0] = six_segs[(i + 1) % 3];
                mapping[9] = six_segs[(i + 2) % 3];
            }

            break;
        }
    }

    const six = mapping[6];
    for (five_segs) |pattern, i| {
        if (i == 2 or pattern & six == pattern) {
            mapping[5] = pattern;

            if (five_segs[(i + 1) % 3] & one == one) {
                mapping[3] = five_segs[(i + 1) % 3];
                mapping[2] = five_segs[(i + 2) % 3];
            } else {
                mapping[2] = five_segs[(i + 1) % 3];
                mapping[3] = five_segs[(i + 2) % 3];
            }

            break;
        }
    }

    return mapping;
}

fn countUnambiguousNums(mapping: [10]u8, output: [4]u8) u64 {
    var count: u64 = 0;
    for (output) |digit| {
        inline for (.{ 1, 4, 7, 8 }) |num| {
            count += @boolToInt(digit == mapping[num]);
        }
    }
    return count;
}

fn decodeOutput(mapping: [10]u8, output: [4]u8) u64 {
    var decoded: u64 = 0;
    for (output) |digit_pattern| {
        const digit = std.mem.indexOfScalar(u8, &mapping, digit_pattern).?;
        decoded = (decoded * 10) + digit;
    }
    return decoded;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    const input = try helpers.readInput("day8/input.txt", (61 + 8 * 4) * 200);
    var displays = parseInput(input[0 .. input.len - 1], 200);

    var unambiguous_nums: u64 = 0;
    var sum: u64 = 0;
    for (displays) |*display| {
        const mapping = deduceMapping(display.patterns);
        unambiguous_nums += countUnambiguousNums(mapping, display.output);
        sum += decodeOutput(mapping, display.output);
    }

    try stdout.print("Count of digits 1, 4, 7, and 8: {}\n", .{unambiguous_nums});
    try stdout.print("Sum of decoded ouputs: {}\n", .{sum});
}

const example_single = "acedgfb cdfbe gcdfa fbcad dab cefabd cdfgeb eafb cagedb ab | cdfeb fcadb cdfeb cdbaf";
const example =
    \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
    \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
    \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
    \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
    \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
    \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
    \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
    \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
    \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
    \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce
;

test "parsePattern" {
    const cases = .{
        .{ "ab", 0b0000011 },
        .{ "acedgfb", 0b1111111 },
        .{ "cdfbe", 0b0111110 },
        .{ "dab", 0b0001011 },
    };

    inline for (cases) |case| {
        try std.testing.expectEqual(@intCast(u8, case.@"1"), parsePattern({}, case.@"0"));
    }
}

test "parseInput" {
    const parsed = parseInput(example, 10);
    try std.testing.expectEqual(@intCast(u8, 0b0010010), parsed[0].patterns[0]);
}

test "deduceMapping" {
    const example_parsed = parseInput(example_single, 1)[0];

    const mapping = deduceMapping(example_parsed.patterns);
    try std.testing.expectEqualSlices(
        u8,
        &.{
            0b1011111,
            0b0000011,
            0b1101101,
            0b0101111,
            0b0110011,
            0b0111110,
            0b1111110,
            0b0001011,
            0b1111111,
            0b0111111,
        },
        &mapping,
    );
}

test "countUnambiguousNums" {
    const example_parsed = parseInput(example, 10);

    var count: u64 = 0;
    for (example_parsed) |case| {
        const mapping = deduceMapping(case.patterns);
        count += countUnambiguousNums(mapping, case.output);
    }
    try std.testing.expectEqual(@intCast(u64, 26), count);
}

test "decodeOutput" {
    const parsed = parseInput(example_single, 1)[0];
    const mapping = deduceMapping(parsed.patterns);
    const value = decodeOutput(mapping, parsed.output);
    try std.testing.expectEqual(@intCast(u64, 5353), value);
}

test "decode full example" {
    const parsed = parseInput(example, 10);

    var sum: u64 = 0;
    for (parsed) |case| {
        const mapping = deduceMapping(case.patterns);
        sum += decodeOutput(mapping, case.output);
    }
    try std.testing.expectEqual(@intCast(u64, 61229), sum);
}
