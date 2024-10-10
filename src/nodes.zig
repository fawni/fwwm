const std = @import("std");
const c = @import("c.zig");

pub const Leaves = std.DoublyLinkedList(Leaf);
pub const Node = Leaves.Node;

pub const Leaf = struct {
    window: c.Window,
    position_x: c_int,
    position_y: c_int,
    window_width: c_int,
    window_height: c_int,
};
