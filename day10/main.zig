const std = @import("std");
const helpers = @import("helpers");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const max_line_len = 109;
const max_lines = 100;
var input_buf: [(max_line_len + 1) * max_lines]u8 = undefined;

const InvalidCharacter = struct {
    actual: u8,
    expected: u8,

    fn score(self: @This()) u64 {
        return switch (self.actual) {
            ')' => 3,
            ']' => 57,
            '}' => 1197,
            '>' => 25137,
            else => unreachable,
        };
    }
};

const IncompleteLine = struct {
    completion: []const u8,
};

const LineParseResult = union(enum) {
    invalid_char: InvalidCharacter,
    incomplete_line: IncompleteLine,
    valid: void,
};

fn parseLine(allocator: Allocator, line: []const u8) !LineParseResult {
    var stack: [max_line_len]u8 = undefined;
    var sp: usize = 0;
    for (line) |char| {
        switch (char) {
            '(', '[', '{', '<' => {
                stack[sp] = char;
                sp += 1;
            },
            ')', ']', '}', '>' => {
                if (sp == 0) unreachable;
                if (closeBracket(stack[sp - 1]) != char) {
                    return LineParseResult{ .invalid_char = .{
                        .actual = char,
                        .expected = closeBracket(stack[sp - 1]),
                    } };
                } else {
                    sp -= 1;
                }
            },
            else => unreachable,
        }
    }

    if (sp == 0) {
        return LineParseResult{ .valid = {} };
    } else {
        var completion = try allocator.alloc(u8, sp);
        while (sp > 0) {
            completion[completion.len - sp] = closeBracket(stack[sp - 1]);
            sp -= 1;
        }

        return LineParseResult{ .incomplete_line = .{
            .completion = completion,
        } };
    }
}

fn closeBracket(char: u8) u8 {
    return switch (char) {
        '(' => ')',
        '[' => ']',
        '{' => '}',
        '<' => '>',
        else => unreachable,
    };
}

const ParseScores = struct {
    corrupted: u64,
    completions: u64,
};

fn parseCode(input: []const u8) !ParseScores {
    var buf: [max_line_len]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);

    var parse_iter = helpers.iterMap(std.mem.split(u8, input, "\n"), fba.allocator(), parseLine);
    var corrupted_score: u64 = 0;
    var completion_scores: [max_lines]u64 = undefined;
    var cs_end: usize = 0;

    while (parse_iter.next()) |parse_result| {
        if (parse_result) |result| {
            switch (result) {
                .invalid_char => |invalid_char| corrupted_score += invalid_char.score(),
                .incomplete_line => |incomplete_line| {
                    completion_scores[cs_end] = completionScore(incomplete_line.completion);
                    cs_end += 1;
                },
                else => {},
            }
        } else |err| return err;
        fba.reset();
    }

    std.sort.sort(u64, completion_scores[0..cs_end], {}, comptime std.sort.asc(u64));
    return ParseScores{
        .corrupted = corrupted_score,
        .completions = completion_scores[cs_end / 2],
    };
}

fn completionScore(completion: []const u8) u64 {
    var score: u64 = 0;
    for (completion) |char| {
        score *= 5;
        score += switch (char) {
            ')' => @intCast(u64, 1),
            ']' => 2,
            '}' => 3,
            '>' => 4,
            else => unreachable,
        };
    }
    return score;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const input = try std.fs.cwd().readFile("day10/input.txt", &input_buf);

    const result = try parseCode(input);

    try stdout.print("Syntax error score from illegal characters: {}\n", .{result.corrupted});

    try stdout.print("Middle completion score: {}\n", .{result.completions});
}

test "parse corrupted lines" {
    const cases = .{
        .{ "{([(<{}[<>[]}>{[]{[(<()>", ']', '}' },
        .{ "[[<[([]))<([[{}[[()]]]", ']', ')' },
        .{ "[{[{({}]{}}([{[{{{}}([]", ')', ']' },
        .{ "[<(<(<(<{}))><([]([]()", '>', ')' },
        .{ "<{([([[(<>()){}]>(<<{{", ']', '>' },
    };

    inline for (cases) |case| {
        const result = try parseLine(std.testing.allocator, case[0]);
        try std.testing.expectEqual(
            LineParseResult{ .invalid_char = InvalidCharacter{
                .actual = case[2],
                .expected = case[1],
            } },
            result,
        );
    }
}

test "parse incomplete lines" {
    const cases = .{
        .{ "[({(<(())[]>[[{[]{<()<>>", "}}]])})]" },
        .{ "[(()[<>])]({[<{<<[]>>(", ")}>]})" },
        .{ "(((({<>}<{<{<>}{[]{[]{}", "}}>}>))))" },
        .{ "{<[[]]>}<{[{[{[]{()[[[]", "]]}}]}]}>" },
        .{ "<{([{{}}[<[[[<>{}]]]>[]]", "])}>" },
    };

    inline for (cases) |case| {
        const result = try parseLine(std.testing.allocator, case[0]);
        defer std.testing.allocator.free(result.incomplete_line.completion);
        try std.testing.expectEqualSlices(u8, case[1], result.incomplete_line.completion);
    }
}

test "parseCode" {
    const example =
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
    ;

    const result = try parseCode(example);
    try std.testing.expectEqual(@intCast(u64, 26397), result.corrupted);
    try std.testing.expectEqual(@intCast(u64, 288957), result.completions);
}
