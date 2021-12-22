const std = @import("std");
const Allocator = std.mem.Allocator;

const RBTree = @import("./red_black_tree.zig").RBTree;

const uCoord = u16;

const Point = struct {
    x: uCoord,
    y: uCoord,

    fn read(buf: []const u8) !Point {
        var iter = std.mem.split(u8, buf, ",");
        return Point{
            .x = try std.fmt.parseUnsigned(
                uCoord,
                iter.next() orelse return error.InvalidPoint,
                10,
            ),
            .y = try std.fmt.parseUnsigned(
                uCoord,
                iter.next() orelse return error.InvalidPoint,
                10,
            ),
        };
    }

    fn hasCommonCoord(self: *const LineSeg) bool {
        return self.start.x == self.end.x or self.start.y == self.end.y;
    }

    pub fn format(value: *const Point, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try std.fmt.formatIntValue(value.x, fmt, options, writer);
        try writer.writeAll(",");
        try std.fmt.formatIntValue(value.y, fmt, options, writer);
    }
};

const LineSeg = struct {
    start: Point,
    end: Point,

    fn read(buf: []const u8) !LineSeg {
        var iter = std.mem.split(u8, buf, " -> ");
        return LineSeg{
            .start = try Point.read(iter.next() orelse return error.InvalidLine),
            .end = try Point.read(iter.next() orelse return error.InvalidLine),
        };
    }

    pub fn format(value: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try value.start.format(fmt, options, writer);
        try writer.writeAll(" -> ");
        try value.end.format(fmt, options, writer);
    }
};

const EventQueue = struct {
    list: std.ArrayList(SweepEvent),

    const Self = @This();
    const SweepEvent = struct {
        pos: Point,
        type: union(enum) {
            seg_start: *LineSeg,
            seg_end: *LineSeg,
            intersection: *LineSeg,
        },

        fn lt(self: *const SweepEvent, other: *const SweepEvent) bool {
            return switch (std.math.order(self.pos.x, other.pos.x)) {
                .lt => true,
                .gt => false,
                .eq => self.pos.y < other.pos.y,
            };
        }

        pub fn format(value: *const SweepEvent, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try value.pos.format(fmt, options, writer);
        }
    };

    fn init(allocator: *Allocator) EventQueue {
        return .{
            .list = std.ArrayList(SweepEvent).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        return self.list.deinit();
    }

    fn insert(self: *Self, event: SweepEvent) !void {
        try self.list.append(event);

        const items = self.list.items;
        var cur = items.len - 1;
        while (cur > 0 and items[cur].lt(&items[parentOf(cur)])) {
            const tmp = items[parentOf(cur)];
            items[parentOf(cur)] = items[cur];
            items[cur] = tmp;
            cur = parentOf(cur);
        }
    }

    fn extract(self: *Self) ?SweepEvent {
        if (self.items.len == 0) return null;

        const ret = self.list.swapRemove(0);

        const items = self.list.items;
        var cur: usize = 0;
        while (true) {
            const left = 2 * cur + 1;
            const right = 2 * cur + 2;
            var smallest = cur;

            if (left < items.len and items[left].lt(&items[smallest])) {
                smallest = left;
            }

            if (right < items.len and items[right].lt(&items[smallest])) {
                smallest = right;
            }

            if (smallest != cur) {
                const tmp = items[smallest];
                items[smallest] = items[cur];
                items[cur] = tmp;
                cur = smallest;
            } else return ret;
        }
    }

    fn parentOf(i: usize) usize {
        return (i - 1) / 2;
    }
};

fn sweepLine(segs: []const LineSeg, allocator: *Allocator) u32 {
    const State = struct {
        
    };

    const q = EventQueue.init(allocator);
    const t = RBTree(LineSeg, );
    for (segs) |*seg| {
        try q.insert(.{ .pos = seg.start, .type = .{ .seg_start = seg } });
        try q.insert(.{ .pos = seg.end, .type = .{ .seg_end = seg } });
    }

    while (q.extract()) |event| {
        switch (event.type) {
            .seg_start => |seg| {},
            .seg_end => |seg| {},
            .intersection => |seg| {},
        }
    }
}

fn readInput(input: []const u8, allocator: *Allocator) ![]LineSeg {
    var iter = std.mem.split(u8, input, "\n");
    var lines = std.ArrayList(LineSeg).init(allocator);
    while (iter.next()) |linebuf| {
        try lines.append(try LineSeg.read(linebuf));
    }
    return lines.toOwnedSlice();
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    const stdout = std.io.getStdOut().writer();

    const raw_input = try std.fs.cwd().readFileAlloc(allocator, "day5/input.txt", 10000);
    const lines = readInput(raw_input, allocator);
    _ = lines;
    _ = stdout;
}

const example =
    \\0,9 -> 5,9
    \\8,0 -> 0,8
    \\9,4 -> 3,4
    \\2,2 -> 2,1
    \\7,0 -> 7,4
    \\6,4 -> 2,0
    \\0,9 -> 2,9
    \\3,4 -> 1,4
    \\0,0 -> 8,8
    \\5,5 -> 8,2
;

const test_allocator = std.testing.allocator;

test "Point.read" {
    try std.testing.expectEqual(
        Point{ .x = 0, .y = 9 },
        try Point.read("0,9"),
    );
}

test "LineSeg.read" {
    try std.testing.expectEqual(
        LineSeg{
            .start = Point{ .x = 0, .y = 9 },
            .end = Point{ .x = 5, .y = 9 },
        },
        try LineSeg.read("0,9 -> 5,9"),
    );
}

test "readInput" {
    const result = try readInput(
        \\0,9 -> 5,9
        \\8,0 -> 0,8
    ,
        std.testing.allocator,
    );
    defer test_allocator.free(result);
    try std.testing.expectEqualSlices(
        LineSeg,
        &[2]LineSeg{
            LineSeg{ .start = Point{ .x = 0, .y = 9 }, .end = Point{ .x = 5, .y = 9 } },
            LineSeg{ .start = Point{ .x = 8, .y = 0 }, .end = Point{ .x = 0, .y = 8 } },
        },
        result,
    );
}

test "EventQueue" {
    var q = EventQueue.init(test_allocator);
    defer q.deinit();

    const events = [_]EventQueue.SweepEvent{
        .{ .pos = .{ .x = 0, .y = 0 }, .type = .intersection },
        .{ .pos = .{ .x = 1, .y = 0 }, .type = .intersection },
        .{ .pos = .{ .x = 2, .y = 0 }, .type = .intersection },
        .{ .pos = .{ .x = 2, .y = 1 }, .type = .intersection },
    };

    try q.insert(events[3]);
    try q.insert(events[2]);
    try q.insert(events[1]);
    try q.insert(events[0]);

    try std.testing.expectEqual(events[0], q.extract());
    try std.testing.expectEqual(events[1], q.extract());
    try std.testing.expectEqual(events[2], q.extract());
    try std.testing.expectEqual(events[3], q.extract());
}
