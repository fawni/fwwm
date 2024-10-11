const std = @import("std");
const c = @import("c.zig");

pub const ClientList = std.DoublyLinkedList(Client);

pub const Client = struct {
    window: c.Window,

    // title: []u8,

    position_x: c_int,
    position_y: c_int,
    window_width: c_int,
    window_height: c_int,

    // decorated: bool,
    // decoration: c.Window,
};
