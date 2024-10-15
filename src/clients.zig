const std = @import("std");
const c = @import("c.zig");

const log = std.log.scoped(.clients);

pub const ClientList = std.DoublyLinkedList(Client);

pub const Client = struct {
    const Self = @This();

    x_display: *c.Display,

    window: c.Window,

    // title: []u8,

    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,

    // decorated: bool,
    // decoration: c.Window,

    // fullscreen: bool,

    // workspace: u8,

    pub fn move(self: *Self, x: c_int, y: c_int) void {
        _ = c.XMoveWindow(self.x_display, self.window, x, y);
        self.x = x;
        self.y = y;
    }

    pub fn resize(self: *Self, width: c_uint, height: c_uint) void {
        _ = c.XResizeWindow(self.x_display, self.window, width, height);
        self.width = @intCast(width);
        self.height = @intCast(height);
    }

    pub fn raise(self: *Self) void {
        _ = c.XRaiseWindow(self.x_display, self.window);
    }

    pub fn set_border_color(self: *Self, color: u32) void {
        _ = c.XSetWindowBorder(self.x_display, self.window, color);
    }

    pub fn set_border_width(self: *Self, width: c_uint) void {
        _ = c.XSetWindowBorderWidth(self.x_display, self.window, width);
    }

    pub fn focus(self: *Self, color: u32) void {
        self.raise();
        self.set_input();
        self.set_border_color(color);
    }

    pub fn set_input(self: *Self) void {
        _ = c.XSetInputFocus(self.x_display, self.window, c.RevertToParent, c.CurrentTime);
    }

    pub fn close(self: *Self) void {
        _ = c.XDestroyWindow(self.x_display, self.window);
    }

    pub fn kill(self: *Self) void {
        _ = c.XKillClient(self.x_display, self.window);
    }
};
