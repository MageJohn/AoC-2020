const std = @import("std");
const helpers = @import("helpers");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Pos = struct {
    row: u8,
    col: u8,
};

fn parseInput(input: []const u8, comptime rows: usize, comptime cols: usize) [rows][cols]u8 {
    var map: [rows][cols]u8 = undefined;
    var line_iter = std.mem.split(u8, input, "\n");
    var row: usize = 0;
    while (line_iter.next()) |line| : (row += 1) {
        if (line.len == 0) break;
        assert(line.len == cols);

        for (line) |digit, col| {
            assert('0' <= digit and digit <= '9');
            map[row][col] = digit - '0';
        }
    }
    assert(row == rows);
    return map;
}

fn LowPointIter(comptime rows: u8, comptime cols: u8) type {
    return struct {
        map: *const [rows][cols]u8,
        row: u8 = 0,
        col: u8 = 0,

        const Self = @This();

        fn next(self: *Self) ?Pos {
            while (self.row < rows) : (self.row += 1) {
                while (self.col < cols) : (self.col += 1) {
                    const row = self.row;
                    const col = self.col;
                    var is_local_low = true;
                    if (col > 0)
                        is_local_low = is_local_low and self.map[row][col - 1] > self.map[row][col];
                    if (col < cols - 1)
                        is_local_low = is_local_low and self.map[row][col + 1] > self.map[row][col];

                    if (is_local_low) {
                        var is_low = true;

                        if (row > 0)
                            is_low = is_low and self.map[row - 1][col] > self.map[row][col];
                        if (row < rows - 1)
                            is_low = is_low and self.map[row + 1][col] > self.map[row][col];

                        if (is_low) {
                            self.col += 1;
                            return Pos{ .row = row, .col = col };
                        }
                    }
                }
                self.col = 0;
            }
            return null;
        }
    };
}

fn basinSize(comptime rows: u8, comptime cols: u8, map: [rows][cols]u8, low_point: Pos) u64 {
    var filled: [rows][cols]bool = .{.{false} ** cols} ** rows;
    var stack: [@intCast(usize, rows) * cols]Pos = undefined;
    var sp: usize = 1;
    var size: u64 = 0;

    stack[0] = low_point;

    while (sp > 0) {
        const pos = stack[sp - 1];
        sp -= 1;
        if (map[pos.row][pos.col] == 9 or filled[pos.row][pos.col]) {
            continue;
        }

        filled[pos.row][pos.col] = true;
        size += 1;

        if (0 < pos.row) {
            stack[sp] = .{ .row = pos.row - 1, .col = pos.col };
            sp += 1;
        }
        if (pos.row < rows - 1) {
            stack[sp] = .{ .row = pos.row + 1, .col = pos.col };
            sp += 1;
        }
        if (0 < pos.col) {
            stack[sp] = .{ .row = pos.row, .col = pos.col - 1 };
            sp += 1;
        }
        if (pos.col < cols - 1) {
            stack[sp] = .{ .row = pos.row, .col = pos.col + 1 };
            sp += 1;
        }
    }

    return size;
}

fn desc(a: u64, b: u64) std.math.Order {
    return std.math.order(a, b).invert();
}

// modifies the input for simplicity
fn biggestThreeProduct(sizes: []u64) u64 {
    var void_buf = [0]u8{};
    const fba = std.heap.FixedBufferAllocator.init(&void_buf).allocator();
    var q = std.PriorityQueue(u64, desc).fromOwnedSlice(fba, sizes);
    return q.remove() * q.remove() * q.remove();
}

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();

    const input = try helpers.readInput("day9/input.txt", (100 + 1) * 100);

    const map = parseInput(input, 100, 100);
    var low_point_iter = LowPointIter(100, 100){ .map = &map };
    var risk_sum: u64 = 0;
    var basin_sizes: [256]u64 = undefined;
    var count: u8 = 0;

    while (low_point_iter.next()) |p| : (count += 1) {
        risk_sum += map[p.row][p.col] + 1;
        basin_sizes[count] = basinSize(100, 100, map, p);
    }

    try stdout.print("Sum of low point risk levels: {}\n", .{risk_sum});

    try stdout.print("Product of biggest 3 basin sizes: {}\n", .{biggestThreeProduct(basin_sizes[0..count])});
}

const example =
    \\2199943210
    \\3987894921
    \\9856789892
    \\8767896789
    \\9899965678
;
const example_parsed = [5][10]u8{
    .{ 2, 1, 9, 9, 9, 4, 3, 2, 1, 0 },
    .{ 3, 9, 8, 7, 8, 9, 4, 9, 2, 1 },
    .{ 9, 8, 5, 6, 7, 8, 9, 8, 9, 2 },
    .{ 8, 7, 6, 7, 8, 9, 6, 7, 8, 9 },
    .{ 9, 8, 9, 9, 9, 6, 5, 6, 7, 8 },
};

test "parseInput" {
    const actual = parseInput(example, 5, 10);
    for (example_parsed) |parsed_line, i| {
        try std.testing.expectEqualSlices(u8, &parsed_line, &actual[i]);
    }
}

test "LowPointIter" {
    var iter = LowPointIter(5, 10){ .map = &example_parsed };

    inline for (.{ .{ 0, 1 }, .{ 0, 9 }, .{ 2, 2 }, .{ 4, 6 } }) |pos| {
        const low_point = iter.next() orelse return error.IncorrectNumberOfLowPoints;
        try std.testing.expectEqual(@intCast(u8, pos[0]), low_point.row);
        try std.testing.expectEqual(@intCast(u8, pos[1]), low_point.col);
    }
}

test "basinSize" {
    try std.testing.expectEqual(@intCast(u64, 3), basinSize(5, 10, example_parsed, .{ .row = 0, .col = 0 }));
    try std.testing.expectEqual(@intCast(u64, 9), basinSize(5, 10, example_parsed, .{ .row = 0, .col = 9 }));
    try std.testing.expectEqual(@intCast(u64, 14), basinSize(5, 10, example_parsed, .{ .row = 2, .col = 2 }));
    try std.testing.expectEqual(@intCast(u64, 9), basinSize(5, 10, example_parsed, .{ .row = 4, .col = 6 }));
}
