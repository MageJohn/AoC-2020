const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn RBTree(comptime T: type, C: type, comptime order: fn (context: C, a: T, b: T) std.math.Order) type {
    return struct {
        nodes: std.ArrayList(Node),
        keys: std.ArrayList(T),
        root: ?uNodeI = null,
        context: C,

        const Self = @This();
        const uNodeI = usize;
        const Direction = enum(u1) {
            left,
            right,

            fn other(self: Direction) Direction {
                return switch (self) {
                    .left => .right,
                    .right => .left,
                };
            }
        };
        const Node = struct {
            parent: ?uNodeI = null,
            children: [2]?uNodeI = .{ null, null },
            color: enum { red, black } = .red,

            fn child(self: Node, dir: Direction) ?uNodeI {
                return self.children[@enumToInt(dir)];
            }

            fn setChild(self: *Node, dir: Direction, value: ?uNodeI) void {
                self.children[@enumToInt(dir)] = value;
            }
        };

        pub fn init(context: C, allocator: Allocator) Self {
            return .{
                .nodes = std.ArrayList(Node).init(allocator),
                .keys = std.ArrayList(T).init(allocator),
                .context = context,
            };
        }

        pub fn deinit(self: Self) void {
            self.nodes.deinit();
            self.keys.deinit();
        }

        pub fn insert(self: *Self, key: T) !void {
            try self.nodes.append(Node{});
            try self.keys.append(key);

            const nodes = self.nodes.items;
            const keys = self.keys.items;
            const new = nodes.len - 1;

            var cur = self.root orelse {
                self.root = new;
                nodes[new].color = .black;
                return;
            };

            while (true) {
                cur = switch (order(self.context, key, keys[cur])) {
                    .lt => nodes[cur].child(.left) orelse {
                        // leaf found
                        nodes[cur].setChild(.left, new);
                        break;
                    },
                    .gt => nodes[cur].child(.right) orelse {
                        // leaf found
                        nodes[cur].setChild(.right, new);
                        break;
                    },
                    .eq => return error.AlreadyInserted,
                };
            }
            nodes[new].parent = cur;

            // rebalance the tree

            // The idea is to fix the possible red-red violation created by the
            // addition of the new node, while not adding a black violation. In
            // the case where the nodes parent and pibling are both red, locally
            // fixing the violation may create a new violation further up the
            // tree. However, since the problem only moves up the tree and can
            // be fully fixed at the root, the tree can be fully rebalanced in
            // O(log2 n).

            cur = new;
            while (nodes[cur].parent) |parent| {
                // loop invariant: cur always starts as red
                assert(nodes[cur].color == .red);

                if (nodes[parent].color == .black) {
                    // No red-red violation, and since cur is red the black
                    // height hasn't changed. We're good.
                    return;
                }
                // After this, the parent is red and so we have a red-red violation.

                if (nodes[parent].parent) |grandparent| {
                    const parent_dir = self.childDir(parent);

                    // pibling: parents sibling, aka uncle or aunt
                    if (nodes[grandparent].child(parent_dir.other())) |pibling|
                        if (nodes[pibling].color == .red) {
                            // parent red and pibling red.

                            // We can only locally fix the violation in this case.
                            // A rotation doesn't work because it would leave a
                            // red-red violation between the current grandparent
                            // and pibling nodes. Recoloring the parent and pibling to
                            // black and the grandparent to red preserves the black
                            // height from the grandparent and fixes the red-red
                            // violation. However, it might introduce a red-red
                            // violation at the grandparent. Therefore continue the
                            // loop with the grandparent.
                            nodes[parent].color = .black;
                            nodes[pibling].color = .black;
                            nodes[grandparent].color = .red;
                            cur = grandparent;
                            continue;
                        };

                    var p = parent;
                    if (self.childDir(cur) != parent_dir) {
                        // parent (p) red, pibling black, cur is inner
                        // grandchild.

                        // For the next bit to work, the inner child cannot
                        // be red. Therefore we rotate cur to the parent's
                        // position. Afterwards we refer to cur as the
                        // parent.
                        try self.rotate(p, parent_dir);
                        p = cur;
                    }
                    // parent (p) red, pibling black, cur is outer
                    // grandchild.

                    // We can now rotate parent (p) to the grandparent
                    // position. Then we recolor p to black and the
                    // down-rotated grandparent to red, preserving the
                    // black height. If cur were an inner grandchild, it
                    // would become the (now red) grandparent's child and
                    // create a red-red violation.
                    try self.rotate(grandparent, parent_dir.other());
                    nodes[p].color = .black;
                    nodes[grandparent].color = .red;
                    return;
                } else {
                    // The parent is red and the root. Recoloring to black
                    // fixes the red-red violation and increases the black
                    // height of the tree by 1.
                    nodes[parent].color = .black;
                    return;
                }
            }

            // cur is the root, and therefore the tree is valid.
        }

        pub fn remove(self: *Self, key: T) !void {
            const nodes = self.nodes.items;
            const keys = self.keys.items;
            var cur = try self.getI(key);

            if (nodes[cur].child(.left)) |_|
                if (nodes[cur].child(.right)) |_| {
                    // cur has two non-null children. By exchanging with it's
                    // successor, we reduce to the case of 0 or 1 non-null
                    // children.
                    const succ = self.adjacentI(cur, .right).?;

                    const tmp = keys[succ];
                    keys[succ] = keys[cur];
                    keys[cur] = tmp;
                    cur = succ;
                };
            // After this, cur has 0 or 1 non-null children.

            // Clean up the removed node wherever we exit.
            const to_remove = cur;
            defer self.deleteNode(to_remove);

            if (nodes[cur].child(.left) orelse nodes[cur].child(.right)) |child| {
                // cur has a single non-null child.
                // - A single black child of either a red or black node is a
                //   black violation (due to the other null child being
                //   considered black).
                // - A single red child of a red node is a red-red violation
                // - Therefore cur is a black node with a red child. To remove,
                //   replace cur with its child and recolor the child to black.

                if (nodes[cur].parent) |parent| {
                    nodes[parent].setChild(self.childDir(cur), child);
                } else {
                    self.root = child;
                }
                nodes[child].parent = nodes[cur].parent;
                nodes[child].color = .black;
                return;
            }
            // After this, cur has no children.

            if (nodes[cur].color == .red or (if (self.root) |r| r == cur else false)) {
                if (nodes[cur].parent) |parent| {
                    // The node is red, so removing doesn't affect black
                    // height.
                    nodes[parent].setChild(self.childDir(cur), null);
                } else {
                    // The node is the root, so removing it reduces the black
                    // height to 0.
                    self.root = null;
                }
                return;
            }

            // The complex case: a non-root black leaf node.

            // The goal is to remove the node and then fix the resulting black
            // violation. In the case where the parent, the sibling, and the
            // sibling's children are all black, the black violation can only
            // be fixed for the part of the tree rooted at the parent.
            // Afterwards, the problem is moved up one level and algorithm
            // iterates. Because the problem always moves up the tree, it will
            // complete in the worst case when the root is reached, in log2(n)
            // steps.

            var dir = self.childDir(cur);
            nodes[nodes[cur].parent.?].setChild(self.childDir(cur), null);
            // There is now a black violation at the parent.

            while (nodes[cur].parent) |parent| {
                // The sibling must exist, as otherwise there would have been a
                // black violation before cur was removed.
                const sibling = nodes[parent].child(dir.other()).?;
                if (nodes[sibling].color == .black) {
                    // sibkid: child of a sibling, aka niece or nephew

                    if (nodes[sibling].child(dir.other())) |far_sibkid|
                        if (nodes[far_sibkid].color == .red) {
                            // The sibling is black, and the sibling's far
                            // child is red. the parent can be either color.
                            try self.rotate(parent, dir);
                            nodes[sibling].color = nodes[parent].color;
                            nodes[parent].color = .black;
                            nodes[far_sibkid].color = .black;
                            return;
                        };

                    if (nodes[sibling].child(dir)) |near_sibkid|
                        if (nodes[near_sibkid].color == .red) {
                            // Both the sibling and its far child are
                            // considered black, but its near child is red.
                            try self.rotate(sibling, dir.other());
                            nodes[sibling].color = .red;
                            nodes[near_sibkid].color = .black;
                            continue;
                            // Will always enter the case above where the
                            // far_sibkid is red.
                        };

                    if (nodes[parent].color == .red) {
                        // The sibling and both its children are black, but the
                        // parent is red.
                        nodes[sibling].color = .red;
                        nodes[parent].color = .black;
                        return;
                    }

                    // The parent, the sibling, and the siblings children are
                    // all black. This is the main iteration case.
                    nodes[sibling].color = .red;
                    cur = parent;
                    if (nodes[cur].parent) |_| dir = self.childDir(cur);
                } else {
                    // The sibling is red, so the parent and the sibling's
                    // children are all black. After this, will resolve in one
                    // of the non-iteratation cases above.
                    try self.rotate(parent, dir);
                    nodes[parent].color = .red;
                    nodes[sibling].color = .black;
                }
            }

            // cur has no parent, so it is the root. The tree is now balanced.
        }

        pub fn successor(self: Self, key: T) !?T {
            const node_i = try self.getI(key);
            const succ = self.adjacentI(node_i, .right) orelse return null;
            return self.keys.items[succ];
        }

        pub fn predecessor(self: Self, key: T) !?T {
            const node_i = try self.getI(key);
            const pred = self.adjacentI(node_i, .left) orelse return null;
            return self.keys.items[pred];
        }

        fn adjacentI(self: Self, node_i: uNodeI, dir: Direction) ?uNodeI {
            const nodes = self.nodes.items;
            if (nodes[node_i].child(dir)) |forward| {
                var cur = forward;
                while (nodes[cur].child(dir.other())) |back| {
                    cur = back;
                }
                return cur;
            }

            var cur = node_i;
            while (nodes[cur].parent) |parent| {
                if (nodes[parent].child(dir) == cur) {
                    cur = parent;
                } else break;
            }

            return nodes[cur].parent;
        }

        fn rotate(self: *Self, root: uNodeI, dir: Direction) !void {
            const nodes = self.nodes.items;
            const pivot = nodes[root].child(dir.other()) orelse return error.NoPivot;

            // point the parent to the pivot, and the pivot to the parent.
            if (nodes[root].parent) |parent| {
                nodes[parent].setChild(self.childDir(root), pivot);
            } else {
                self.root = pivot;
            }
            nodes[pivot].parent = nodes[root].parent;

            // move the inside child to the other side.
            nodes[root].setChild(dir.other(), nodes[pivot].child(dir));
            if (nodes[root].child(dir.other())) |inside| {
                nodes[inside].parent = root;
            }

            // point the pivot at the root, and the root at the pivot
            nodes[pivot].setChild(dir, root);
            nodes[root].parent = pivot;
        }

        fn getI(self: Self, key: T) !uNodeI {
            var cur_opt = self.root;
            while (cur_opt) |cur| {
                cur_opt = self.nodes.items[cur].child(
                    switch (order(self.context, key, self.keys.items[cur])) {
                        .lt => .left,
                        .gt => .right,
                        .eq => return cur,
                    },
                );
            } else {
                return error.NoSuchKey;
            }
        }

        // Given a node, returns which branch of its parent it is. Asserts that
        // the node has a parent (is not root).
        fn childDir(self: Self, node: uNodeI) Direction {
            const nodes = self.nodes.items;
            const parent = nodes[nodes[node].parent.?];
            return if (parent.child(.left) == node) .left else .right;
        }

        // Assuming the node has already been removed from the tree structure,
        // removes the node from the list of nodes in O(1). It does this with
        // swapRemove, which may change the index of the node at the end of the
        // list. Therefore the nodes which point to that node are updated.
        fn deleteNode(self: *Self, node_i: uNodeI) void {
            _ = self.nodes.swapRemove(node_i);
            _ = self.keys.swapRemove(node_i);

            const nodes = self.nodes.items;
            if (node_i < nodes.len) {
                if (nodes[node_i].child(.left)) |left| {
                    nodes[left].parent = node_i;
                }

                if (nodes[node_i].child(.right)) |right| {
                    nodes[right].parent = node_i;
                }

                if (nodes[node_i].parent) |parent| {
                    nodes[parent].setChild(
                        if (nodes[parent].child(.left) == nodes.len) .left else .right,
                        node_i,
                    );
                } else {
                    assert(self.root.? == nodes.len);
                    self.root = node_i;
                }
            }
        }
    };
}

// Tests

const log_enable = false;
fn log(comptime fmt: []const u8, args: anytype) void {
    if (log_enable) {
        std.debug.print(fmt, args);
    }
}

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectError = std.testing.expectError;
const Tuple = std.meta.Tuple;
const TestRBTree = RBTree(u32, void, testOrder);

fn testOrder(context: void, a: u32, b: u32) std.math.Order {
    _ = context;
    return std.math.order(a, b);
}

fn validateTree(tree: TestRBTree) !void {
    const H = struct {
        const ValidateRet = struct {
            min: ?usize = null,
            max: ?usize = null,
            black_depth: usize = 1,
            count: usize = 0,
        };
        const ValidateError = error{ InvalidBinaryTree, RedRedViolation, BlackViolation };

        fn recursiveValidate(
            t: TestRBTree,
            root: ?TestRBTree.uNodeI,
        ) ValidateError!ValidateRet {
            const nodes = t.nodes.items;
            const keys = t.keys.items;

            if (root) |r| {
                const node = nodes[root.?];
                const key = keys[r];
                const left_i = node.child(.left);
                const right_i = node.child(.right);
                if (node.color == .red and
                    (if (left_i) |li|
                    nodes[li].color == .red
                else if (right_i) |ri|
                    nodes[ri].color == .red
                else
                    false))
                {
                    return error.RedRedViolation;
                }

                const left = try recursiveValidate(t, node.child(.left));
                if (left.max) |lmax| {
                    if (lmax >= key) return error.InvalidBinaryTree;
                }

                const right = try recursiveValidate(t, node.child(.right));
                if (right.min) |rmin| {
                    if (key >= rmin) return error.InvalidBinaryTree;
                }

                if (left.black_depth != right.black_depth) {
                    return error.BlackViolation;
                }

                return ValidateRet{
                    .min = left.min orelse key,
                    .max = right.max orelse key,
                    .black_depth = @boolToInt(node.color == .black) + left.black_depth,
                    .count = 1 + left.count + right.count,
                };
            } else {
                return ValidateRet{};
            }
        }
    };
    const res = try H.recursiveValidate(tree, tree.root);
    try std.testing.expectEqual(tree.nodes.items.len, res.count);
}

fn printTree(tree: *const TestRBTree) void {
    const H = struct {
        fn printInternal(t: *const TestRBTree, maybe_root: ?TestRBTree.uNodeI, space: usize) void {
            const COUNT = 5;
            const root = t.nodes.items[maybe_root orelse return];
            const key = t.keys.items[maybe_root.?];
            if (root.child(.right)) |right| {
                printInternal(t, right, space + 1);
            }

            std.debug.print("\n", .{});
            var i: usize = 0;
            while (i < space) : (i += 1) {
                std.debug.print(" " ** COUNT, .{});
            }
            if (root.color == .red) {
                std.debug.print("\x1b[31m{}\x1b[0m\n", .{key});
            } else {
                std.debug.print("{}\n", .{key});
            }

            if (root.child(.left)) |left| {
                printInternal(t, left, space + 1);
            }
        }
    };
    if (log_enable) {
        std.debug.print("----\n", .{});
        H.printInternal(tree, tree.root, 0);
        std.debug.print("----\n", .{});
    }
}

fn insertRange(tree: *TestRBTree, context: anytype) !void {
    const end = if (context.len == 1) context[0] else context[1];
    var i: u32 = if (context.len == 1) 0 else context[0];
    while (i < end) : (i += 1) {
        try tree.insert(i);
    }
}

fn testRemove(
    comptime setup: fn (tree: *TestRBTree, context: anytype) anyerror!void,
    context: anytype,
    key: u32,
) !void {
    var tree = TestRBTree.init(.{}, test_allocator);
    defer tree.deinit();
    try setup(&tree, context);
    log("Before:\n", .{});
    printTree(&tree);
    log("Removing {}\n", .{key});
    try tree.remove(key);
    printTree(&tree);
    try validateTree(tree);
}

test "RBTree.remove root leaf" {
    try testRemove(insertRange, .{1}, 0);
}

test "RBTree.remove non-root red leaf" {
    try testRemove(insertRange, .{2}, 1);
}

test "RBTree.remove black node with one red child" {
    try testRemove(insertRange, .{2}, 0);
}

test "RBTree.remove black node (non-root) with one red child" {
    try testRemove(insertRange, .{4}, 2);
}

test "RBTree.remove node with two children" {
    try testRemove(insertRange, .{3}, 1);
}

test "RBTree.remove node with black sibling and sibkids, and red parent (case 1)" {
    try testRemove(insertRange, .{8}, 0);
}

test "RBTree.remove node with black sibling and a red far sibkid (case 2)" {
    try testRemove(insertRange, .{4}, 0);
}

test "RBTree.remove node with black sibling and far sibkid, but a red near sibkid (case 3)" {
    const H = struct {
        fn setup(tree: *TestRBTree, context: anytype) !void {
            _ = context;
            try insertRange(tree, .{3});
            try insertRange(tree, .{ 4, 6 });
            try tree.insert(3);
        }
    };
    try testRemove(H.setup, .{}, 5);
}

test "RBTree.remove node with a red sibling (case 4)" {
    const H = struct {
        fn setup(tree: *TestRBTree, context: anytype) !void {
            _ = context;
            try insertRange(tree, .{3});
            try insertRange(tree, .{ 4, 6 });
            try tree.insert(3);
        }
    };
    try testRemove(H.setup, .{}, 0);
}

test "RBTree.remove node which requires iteration, then case 6" {
    try testRemove(insertRange, .{10}, 0);
}

test "RBTree.remove node which requires iteration and changing dir" {
    try testRemove(insertRange, .{10}, 2);
}

test "RBTree.remove node which requires iterating to the root" {
    const H = struct {
        fn setup(tree: *TestRBTree, context: anytype) !void {
            _ = context;
            try insertRange(tree, .{3});
            tree.nodes.items[try tree.getI(0)].color = .black;
            tree.nodes.items[try tree.getI(2)].color = .black;
        }
    };
    try testRemove(H.setup, .{}, 0);
}

fn buildTestTree() !TestRBTree {
    var tree = TestRBTree.init(.{}, test_allocator);
    try tree.insert(8);
    try tree.insert(3);
    try tree.insert(1);
    try tree.insert(6);
    try tree.insert(4);
    try tree.insert(5);
    try tree.insert(7);
    try tree.insert(10);
    try tree.insert(13);
    try tree.insert(14);
    try tree.insert(11);

    return tree;
}

test "RBTree.successor" {
    var tree = try buildTestTree();
    defer tree.deinit();

    const cases = [_]Tuple(&.{ u32, ?u32 }){
        .{ 7, 8 },
        .{ 14, null },
        .{ 13, 14 },
        .{ 6, 7 },
    };

    for (cases) |case| {
        try expectEqual(case[1], try tree.successor(case[0]));
    }

    try expectError(error.NoSuchKey, tree.successor(9));
}

test "RBTree.predecessor" {
    var tree = try buildTestTree();
    defer tree.deinit();

    const cases = [_]Tuple(&.{ u32, ?u32 }){
        .{ 8, 7 },
        .{ 1, null },
        .{ 14, 13 },
        .{ 7, 6 },
    };

    for (cases) |case| {
        try expectEqual(case[1], try tree.predecessor(case[0]));
    }

    try expectError(error.NoSuchKey, tree.predecessor(9));
}

test "RBTree.rotate" {
    const tree1 = try buildTestTree();
    defer tree1.deinit();
    var tree2 = try buildTestTree();
    defer tree2.deinit();

    const cases = [_]Tuple(&.{ TestRBTree.Direction, u32, u32 }){
        .{ .left, 3, 4 },
        .{ .left, 8, 13 },
        .{ .left, 6, 8 },
    };

    inline for (cases) |case| {
        try tree2.rotate(try tree2.getI(case[1]), case[0]);
        try tree2.rotate(try tree2.getI(case[2]), case[0].other());
        try expectEqualSlices(TestRBTree.Node, tree1.nodes.items, tree2.nodes.items);
    }
}
