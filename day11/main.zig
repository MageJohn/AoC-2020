const std = @import("std");

const assert = std.debug.assert;

var input_buf: [(10 + 1) * 10]u8 = undefined;

const Grid = [10][10]u8;

const Pos = packed struct {
    row: u4,
    col: u4,
};

fn step(grid: *Grid) u8 {
    var stack: [100]Pos = undefined;
    var sp: usize = 0;

    for (grid) |_, row| {
        for (grid[row]) |_, col| {
            grid[row][col] += 1;
            if (grid[row][col] > 9) {
                stack[sp] = .{ .row = @intCast(u4, row), .col = @intCast(u4, col) };
                sp += 1;
            }
        }
    }

    var flashes: u8 = 0;
    while (sp > 0) {
        sp -= 1;
        const pos = stack[sp];

        grid[pos.row][pos.col] = 0;
        flashes += 1;
        inline for ([_]i4{ -1, 0, 1 }) |delta_r| {
            const row = @bitCast(u4, @bitCast(i4, pos.row) +% delta_r);
            if (0 <= row and row < 10) {
                inline for ([_]i4{ -1, 0, 1 }) |delta_c| {
                    if (delta_r == 0 and delta_c == 0) continue;

                    const col = @bitCast(u4, @bitCast(i4, pos.col) +% delta_c);
                    if ((0 <= col and col < 10) and
                        (0 < grid[row][col] and grid[row][col] <= 9))
                    {
                        grid[row][col] += 1;
                        if (grid[row][col] > 9) {
                            stack[sp] = .{ .row = row, .col = col };
                            sp += 1;
                        }
                    }
                }
            }
        }
    }
    return flashes;
}

fn simulateSteps(in_grid: Grid, steps: usize) u16 {
    var grid = in_grid;
    var flashes: u16 = 0;
    var s: usize = 0;

    while (s < steps) : (s += 1) {
        flashes += step(&grid);
    }

    return flashes;
}

fn simulateUntilAllFlash(in_grid: Grid) usize {
    var grid = in_grid;
    var s: usize = 0;
    var flashes: u8 = 0;

    while (flashes != 100) : (s += 1) {
        flashes = step(&grid);
    }

    return s;
}

fn parseInput(input: []const u8) Grid {
    var grid: Grid = undefined;
    var line_iter = std.mem.split(u8, input, "\n");
    var row: usize = 0;

    while (line_iter.next()) |line| : (row += 1) {
        if (line.len == 0) break;
        for (line) |char, col| {
            assert('0' <= char and char <= '9');
            grid[row][col] = char - '0';
        }
    }

    assert(row == 10);
    return grid;
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const input = try std.fs.cwd().readFile("day11/input.txt", &input_buf);

    const grid = parseInput(input);

    const flashes = simulateSteps(grid, 100);
    try stdout.print("After 100 steps, there have been a total of {} flashes\n", .{flashes});

    try stdout.print("The octopuses all flash on step {}\n", .{simulateUntilAllFlash(grid)});
}

const example =
    \\5483143223
    \\2745854711
    \\5264556173
    \\6141336146
    \\6357385478
    \\4167524645
    \\2176841721
    \\6882881134
    \\4846848554
    \\5283751526
;
test "simulateSteps 10" {
    const grid = parseInput(example);
    const flashes = simulateSteps(grid, 10);
    try std.testing.expectEqual(@intCast(u16, 204), flashes);
}

test "simulateUntilAllFlash" {
    const grid = parseInput(example);
    const s = simulateUntilAllFlash(grid);
    try std.testing.expectEqual(@intCast(usize, 195), s);
}
