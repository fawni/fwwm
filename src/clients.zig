const std = @import("std");
const c = @import("c.zig");

const A = @import("atoms.zig");

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

    prev_x: ?c_int = null,
    prev_y: ?c_int = null,
    prev_width: ?c_int = null,
    prev_height: ?c_int = null,

    screen_width: c_uint,
    screen_height: c_uint,

    border_width: u8,

    // decorated: bool,
    // decoration: c.Window,

    is_maximized: bool = false,
    is_fullscreen: bool = false,

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

    pub fn move_resize(self: *Self, x: c_int, y: c_int, width: c_int, height: c_int) void {
        _ = c.XMoveResizeWindow(self.x_display, self.window, x, y, @intCast(width), @intCast(height));

        self.x = x;
        self.y = y;
        self.width = width;
        self.height = height;
    }

    // TODO: maybe support `_NET_WM_STATE_MAXIMIZED_HORZ` and `_NET_WM_STATE_MAXIMIZED_VERT`.
    // dwm does not support it so it should be fine if we don't.
    pub fn maximize(self: *Self, state: ?bool) void {
        if (state == false or self.is_maximized) {
            self.width = self.prev_width.?;
            self.height = self.prev_height.?;
            self.x = self.prev_x.?;
            self.y = self.prev_y.?;

            _ = c.XMoveResizeWindow(self.x_display, self.window, self.x, self.y, @intCast(self.width), @intCast(self.height));

            self.is_maximized = false;
        } else if (state == true or !self.is_fullscreen) {
            self.prev_width = self.width;
            self.prev_height = self.height;
            self.prev_x = self.x;
            self.prev_y = self.y;

            const new_width: c_uint = @intCast(self.screen_width - 2 * self.border_width);
            const new_height: c_uint = @intCast(self.screen_height - 2 * self.border_width);

            _ = c.XMoveResizeWindow(self.x_display, self.window, 0, 0, new_width, new_height);

            self.width = @intCast(new_width);
            self.height = @intCast(new_height);
            self.x = 0;
            self.y = 0;

            self.is_maximized = true;
        }
    }

    pub fn fullscreen(self: *Self, state: ?bool) void {
        if (state == false or self.is_fullscreen) {
            self.width = self.prev_width.?;
            self.height = self.prev_height.?;
            self.x = self.prev_x.?;
            self.y = self.prev_y.?;

            _ = c.XMoveResizeWindow(self.x_display, self.window, self.x, self.y, @intCast(self.width), @intCast(self.height));
            _ = c.XSetWindowBorderWidth(self.x_display, self.window, self.border_width);

            self.is_fullscreen = false;
            _ = c.XChangeProperty(self.x_display, self.window, A.net_wm_state, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&A.net_wm_state_fullscreen), c.False);
        } else if (state == true or !self.is_fullscreen) {
            self.prev_width = self.width;
            self.prev_height = self.height;
            self.prev_x = self.x;
            self.prev_y = self.y;

            const new_width: c_uint = @intCast(self.screen_width);
            const new_height: c_uint = @intCast(self.screen_height);

            _ = c.XMoveResizeWindow(self.x_display, self.window, 0, 0, new_width, new_height);
            _ = c.XSetWindowBorderWidth(self.x_display, self.window, 0);

            self.width = @intCast(new_width);
            self.height = @intCast(new_height);
            self.x = 0;
            self.y = 0;

            self.is_fullscreen = true;
            _ = c.XChangeProperty(self.x_display, self.window, A.net_wm_state, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&A.net_wm_state_fullscreen), c.True);
        }
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
