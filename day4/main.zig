const std = @import("std");
const Allocator = std.mem.Allocator;

const Board = [5][5]u8;

const MarkableBoard = struct {
    board: *const Board,
    marked: [5][5]bool = [_][5]bool{[_]bool{false} ** 5} ** 5,

    const Self = @This();

    fn hasWon(self: *const Self) bool {
        var col_wins = [_]bool{true} ** 5;
        for (self.marked) |row| {
            var row_win = true;
            for (row) |mark, i| {
                col_wins[i] = col_wins[i] and mark;
                row_win = row_win and mark;
            }
            if (row_win) return true;
        }
        for (col_wins) |col_win| {
            if (col_win) return true;
        }
        return false;
    }

    fn call(self: *Self, called: u8) void {
        for (self.board) |row, i| {
            for (row) |num, j| {
                if (num == called) {
                    self.marked[i][j] = true;
                    return;
                }
            }
        }
        return;
    }

    fn calcScore(self: *const Self, last_called: u8) u32 {
        var sum_unmarked: u32 = 0;
        for (self.board) |row, i| {
            for (row) |num, j| {
                if (!self.marked[i][j]) {
                    sum_unmarked += num;
                }
            }
        }
        return sum_unmarked * last_called;
    }
};

const ParseInputResult = struct { nums: []const u8, boards: []Board };

fn parseInput(input: []const u8, allocator: *Allocator) !ParseInputResult {
    var iter = std.mem.split(u8, input, "\n\n");

    const nums_line = iter.next() orelse unreachable;
    const nums = try parseNums(nums_line, allocator);

    var boards = std.ArrayList(Board).init(allocator);
    while (iter.next()) |board_lines| {
        try boards.append(try parseBoard(board_lines));
    }

    return ParseInputResult{ .nums = nums, .boards = boards.toOwnedSlice() };
}

fn parseNums(nums_line: []const u8, allocator: *Allocator) ![]u8 {
    var iter = std.mem.split(u8, nums_line, ",");
    var nums = std.ArrayList(u8).init(allocator);
    while (iter.next()) |num| {
        try nums.append(try std.fmt.parseUnsigned(u8, num, 10));
    }
    return nums.toOwnedSlice();
}

fn parseBoard(board_lines: []const u8) !Board {
    var row_iter = std.mem.split(u8, board_lines, "\n");
    var board: Board = undefined;
    var i: u8 = 0;
    while (row_iter.next()) |row| : (i += 1) {
        if (row.len == 0) break;
        var j: u8 = 0;
        while (j < 5) : (j += 1) {
            const _j = j * 3;
            const num = if (row[_j] == ' ') row[_j + 1 .. _j + 2] else row[_j .. _j + 2];
            board[i][j] = try std.fmt.parseUnsigned(u8, num, 10);
        }
    }
    return board;
}

fn findBestBoardScore(
    nums: []const u8,
    boards: []const Board,
    allocator: *Allocator,
) !u32 {
    const markable_boards = init: {
        var list = try std.ArrayList(MarkableBoard).initCapacity(allocator, boards.len);
        for (boards) |*board| {
            list.appendAssumeCapacity(.{ .board = board });
        }
        break :init list.toOwnedSlice();
    };
    defer allocator.free(markable_boards);
    for (nums[0..5]) |num| {
        for (markable_boards) |*board| {
            board.call(num);
        }
    }
    for (markable_boards) |board| {
        if (board.hasWon()) {
            return board.calcScore(nums[4]);
        }
    }
    for (nums[5..]) |num| {
        for (markable_boards) |*board| {
            board.call(num);
            if (board.hasWon()) {
                return board.calcScore(num);
            }
        }
    }
    unreachable;
}

fn findWorstBoardScore(nums: []const u8, boards: []const Board) !u32 {
    var longestTimeToWin: u32 = 0;
    var worstBoard: MarkableBoard = undefined;
    var worstBoardLastCalled: u8 = 0;
    for (boards) |*board| {
        var mboard = MarkableBoard{ .board = board };
        var timeToWin: u32 = 0;
        var i: usize = 0;
        while (true) : ({
            timeToWin += 1;
            i += 1;
        }) {
            mboard.call(nums[i]);
            if (mboard.hasWon()) break;
        }
        if (timeToWin > longestTimeToWin) {
            longestTimeToWin = timeToWin;
            worstBoard = mboard;            
            worstBoardLastCalled = nums[i];
        }
    }
    return worstBoard.calcScore(worstBoardLastCalled);
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const input = try std.fs.cwd().readFileAlloc(allocator, "day4/input.txt", 10000);

    const parsed = try parseInput(input, allocator);
    const nums = parsed.nums;
    const boards = parsed.boards;

    const stdout = std.io.getStdOut().writer();

    const best_score = try findBestBoardScore(nums, boards, allocator);

    try stdout.print("The best board has score {}\n", .{best_score});

    const worst_score = try findWorstBoardScore(nums, boards);

    try stdout.print("The best board has score {}", .{worst_score});
}

const ex_nums =
    \\7,4,9,5,11,17,23,2,0,14,21,24,10,16,13,6,15,25,12,22,18,20,8,19,3,26,1
;
const ex_nums_parsed = [_]u8{ 7, 4, 9, 5, 11, 17, 23, 2, 0, 14, 21, 24, 10, 16, 13, 6, 15, 25, 12, 22, 18, 20, 8, 19, 3, 26, 1 };

const ex_board1 =
    \\22 13 17 11  0
    \\ 8  2 23  4 24
    \\21  9 14 16  7
    \\ 6 10  3 18  5
    \\ 1 12 20 15 19
;
const ex_board1_parsed = [5][5]u8{
    .{ 22, 13, 17, 11, 0 },
    .{ 8, 2, 23, 4, 24 },
    .{ 21, 9, 14, 16, 7 },
    .{ 6, 10, 3, 18, 5 },
    .{ 1, 12, 20, 15, 19 },
};

const ex_board2 =
    \\ 3 15  0  2 22
    \\ 9 18 13 17  5
    \\19  8  7 25 23
    \\20 11 10 24  4
    \\14 21 16 12  6
;
const ex_board2_parsed = [5][5]u8{
    .{ 3, 15, 0, 2, 22 },
    .{ 9, 18, 13, 17, 5 },
    .{ 19, 8, 7, 25, 23 },
    .{ 20, 11, 10, 24, 4 },
    .{ 14, 21, 16, 12, 6 },
};

const ex_board3 =
    \\14 21 17 24  4
    \\10 16 15  9 19
    \\18  8 23 26 20
    \\22 11 13  6  5
    \\ 2  0 12  3  7
;
const ex_board3_parsed = [5][5]u8{
    .{ 14, 21, 17, 24, 4 },
    .{ 10, 16, 15, 9, 19 },
    .{ 18, 8, 23, 26, 20 },
    .{ 22, 11, 13, 6, 5 },
    .{ 2, 0, 12, 3, 7 },
};

const example = ex_nums ++ "\n\n" ++ ex_board1 ++ "\n\n" ++ ex_board2 ++ "\n\n" ++ ex_board3;

const ex_boards = [_]Board{
    ex_board1_parsed,
    ex_board2_parsed,
    ex_board3_parsed,
};

const test_allocator = std.testing.allocator;

test "parseNums" {
    const result = try parseNums(ex_nums, test_allocator);
    defer test_allocator.free(result);

    try std.testing.expectEqualSlices(u8, result, &ex_nums_parsed);
}

test "parseBoard" {
    const result = try parseBoard(ex_board1);
    const expected = ex_board1_parsed;

    try std.testing.expectEqualSlices([5]u8, &expected, &result);
}

test "parseInput" {
    const result = try parseInput(example, test_allocator);
    defer test_allocator.free(result.nums);
    defer test_allocator.free(result.boards);

    try std.testing.expectEqualSlices(u8, &ex_nums_parsed, result.nums);
    try std.testing.expectEqualSlices(Board, &ex_boards, result.boards);
}

test "findBestBoardScore" {
    const best_board_score = try findBestBoardScore(
        &ex_nums_parsed,
        &ex_boards,
        test_allocator,
    );
    try std.testing.expectEqual(@intCast(u32, 4512), best_board_score);
}

test "findWorstBoardScore" {
    const worst_board_score = try findWorstBoardScore(
        &ex_nums_parsed,
        &ex_boards,
    );
    try std.testing.expectEqual(@intCast(u32, 1924), worst_board_score);
}
