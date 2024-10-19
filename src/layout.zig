const std = @import("std");
const c = @import("c.zig");
const clients = @import("clients.zig");
const ipc = @import("ipc.zig");

const A = @import("atoms.zig");
const C = @import("cursors.zig");
const M = @import("masks.zig");

const log = std.log.scoped(.layout);

const Client = clients.Client;
const ClientList = clients.ClientList;

pub const Layout = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *c.Display,
    x_screen: *c.Screen,
    x_root: c.Window,

    screen_width: c_uint,
    screen_height: c_uint,

    clients: ClientList,
    focused_client: ?*ClientList.Node,

    normal_color: u32,
    hover_color: u32,
    focus_color: u32,

    border_width: u8,

    current_workspace: u32,

    pub fn init(allocator: *std.mem.Allocator, display: *c.Display, root: c.Window) !Self {
        var layout: Self = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_root = root;

        const screen = c.DefaultScreen(layout.x_display);

        layout.screen_width = @intCast(c.XDisplayWidth(display, screen));
        layout.screen_height = @intCast(c.XDisplayHeight(display, screen));

        layout.clients = ClientList{};
        layout.focused_client = null;

        layout.normal_color = 0x303030;
        layout.hover_color = 0x97d0e8;
        layout.focus_color = 0xd895ee;

        layout.border_width = 2;

        layout.set_current_desktop(0);

        return layout;
    }

    pub fn on_configure_request(self: *Self, event: *const c.XConfigureRequestEvent) void {
        var changes: c.XWindowChanges = undefined;

        changes.x = event.x;
        changes.y = event.y;

        changes.width = event.width;
        changes.height = event.height;

        changes.border_width = event.border_width;

        changes.sibling = event.above;
        changes.stack_mode = event.detail;

        _ = c.XConfigureWindow(self.x_display, event.window, @intCast(event.value_mask), &changes);
    }

    pub fn on_map_request(self: *Self, event: *const c.XMapRequestEvent) !void {
        // log.debug("mapping a window: {}", .{event.window});

        _ = c.XSelectInput(self.x_display, event.window, M.MAP_WINDOW_MASK);
        _ = c.XMapWindow(self.x_display, event.window);

        _ = c.XGrabButton(self.x_display, c.Button1, c.AnyModifier, event.window, c.True, M.POINTER_MASK, c.GrabModeSync, c.GrabModeAsync, c.None, c.None);
        _ = c.XGrabButton(self.x_display, c.Button3, c.AnyModifier, event.window, c.True, M.POINTER_MASK, c.GrabModeSync, c.GrabModeAsync, c.None, c.None);

        _ = c.XSetWindowBorderWidth(self.x_display, event.window, self.border_width);

        _ = c.XChangeProperty(self.x_display, event.window, A.net_wm_state, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, null, c.False);

        const node = try self.add_client(event.window);
        self.focus(node);
    }

    pub fn on_unmap_notify(self: *Self, event: *const c.XUnmapEvent) void {
        // log.debug("a window was unmapped: {}", .{event.window});

        if (self.node_from_window(event.window)) |node| {
            if (self.focused_client == node) {
                self.focus(null);
            }
        }
    }

    pub fn on_destroy_notify(self: *Self, event: *const c.XDestroyWindowEvent) void {
        // log.debug("a window was destroyed: {}", .{event.window});

        if (self.node_from_window(event.window)) |node| {
            self.clients.remove(node);

            if (self.focused_client == node) {
                self.focus(null);
            }
        }
    }

    pub fn on_button_press(self: *Self, event: *c.XButtonPressedEvent) !void {
        // log.debug("button pressed", .{});
        const window = event.window;

        if (self.node_from_window(window)) |node| if (node != self.focused_client) self.focus(node);

        // move and resize
        if (self.node_from_window(window)) |node| {
            var pointer_x: c_int = undefined;
            var pointer_y: c_int = undefined;
            var dummy_window: c.Window = undefined;
            var dummy_int: c_int = undefined;
            var dummy_uint: c_uint = undefined;
            _ = c.XQueryPointer(self.x_display, self.x_root, &dummy_window, &dummy_window, &pointer_x, &pointer_y, &dummy_int, &dummy_int, &dummy_uint);

            if (event.state & c.Mod4Mask != 0) {
                self.grab_pointer();

                const old_x = node.data.x;
                const old_y = node.data.y;
                const old_width = node.data.width;
                const old_height = node.data.height;
                const old_x2 = old_x + old_width;
                const old_y2 = old_y + old_height;

                var e: c.XEvent = undefined;
                while (e.type != c.ButtonRelease) {
                    _ = c.XMaskEvent(self.x_display, c.PointerMotionMask | c.ButtonReleaseMask, &e);
                    // move
                    if (e.xbutton.state & c.Button1Mask != 0) {
                        switch (e.type) {
                            c.MotionNotify => {
                                const new_x = old_x + (e.xmotion.x - pointer_x);
                                const new_y = old_y + (e.xmotion.y - pointer_y);

                                node.data.move(new_x, new_y);
                            },
                            else => {},
                        }
                    } else if (e.xbutton.state & c.Button3Mask != 0) {
                        // resize
                        switch (e.type) {
                            c.MotionNotify => {
                                const half_x: c_int = @divTrunc(node.data.x + node.data.width, 2);
                                const half_y: c_int = @divTrunc(node.data.y + node.data.height, 2);

                                const bottom_right_or_center = pointer_x >= half_x and pointer_y >= half_y;
                                const bottom_left = pointer_x < half_x and pointer_y > half_y;
                                const top_right = pointer_x > half_x and pointer_y < half_y;
                                const top_left = pointer_x < half_x and pointer_y < half_y;

                                if (bottom_right_or_center) {
                                    const new_width = @max(e.xmotion.x - pointer_x + old_width, 1);
                                    const new_height = @max(e.xmotion.y - pointer_y + old_height, 1);

                                    node.data.resize(new_width, new_height);
                                } else if (bottom_left) {
                                    const new_x = e.xmotion.x - pointer_x + old_x;

                                    const new_width = @max(old_x2 - new_x, 1);
                                    const new_height = @max(e.xmotion.y - pointer_y + old_height, 1);

                                    node.data.move_resize(new_x, old_y, new_width, new_height);
                                } else if (top_right) {
                                    const new_y = e.xmotion.y - pointer_y + old_y;

                                    const new_width = @max(e.xmotion.x - pointer_x + old_width, 1);
                                    const new_height = @max(old_y2 - new_y, 1);

                                    node.data.move_resize(old_x, new_y, new_width, new_height);
                                } else if (top_left) {
                                    const new_x = e.xmotion.x - pointer_x + old_x;
                                    const new_y = e.xmotion.y - pointer_y + old_y;

                                    const new_width = @max(old_x2 - new_x, 1);
                                    const new_height = @max(old_y2 - new_y, 1);

                                    node.data.move_resize(new_x, new_y, new_width, new_height);
                                }
                            },
                            else => {},
                        }
                    }
                }
                self.ungrab_pointer();
            }
        }
        self.propagate_pointer();
    }

    pub fn on_enter_notify(self: *Self, event: *c.XCrossingEvent) void {
        const node = self.node_from_window(event.window);
        if (node != self.focused_client) _ = c.XSetWindowBorder(self.x_display, event.window, self.hover_color);
    }

    pub fn on_leave_notify(self: *Self, event: *c.XCrossingEvent) void {
        const node = self.node_from_window(event.window);
        if (node != self.focused_client) _ = c.XSetWindowBorder(self.x_display, event.window, self.normal_color);
    }

    pub fn on_client_message(self: *Self, event: *c.XClientMessageEvent) void {
        const data = event.data.l;
        if (event.message_type == A.fwwm_client_event) {
            if (self.node_from_window(@intCast(data[4]))) |node| return ipc.handle(node, data, self);
            if (self.focused_client) |node| ipc.handle(node, data, self);
        } else if (event.message_type == A.net_wm_state) {
            const node = self.node_from_window(event.window) orelse return;

            if (data[1] == A.net_wm_state_fullscreen or data[2] == A.net_wm_state_fullscreen) {
                switch (data[0]) {
                    0 => node.data.fullscreen(false),
                    1 => node.data.fullscreen(true),
                    2 => node.data.fullscreen(null),
                    else => {},
                }
            }
        }
    }

    pub fn add_client(self: *Self, window: c.Window) !*ClientList.Node {
        if (self.node_from_window(window)) |node| return node;

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(self.x_display, window, &attributes);

        const client = Client{
            .x_display = self.x_display,
            .x_root = self.x_root,
            .window = window,
            .x = attributes.x,
            .y = attributes.y,
            .width = attributes.width,
            .height = attributes.height,
            .screen_width = self.screen_width,
            .screen_height = self.screen_height,
            .border_width = self.border_width,
            .focus_color = self.focus_color,
            .workspace = self.current_workspace,
        };

        var node = try self.allocator.create(ClientList.Node);

        node.data = client;
        self.clients.append(node);
        try self.ewmh_set_client_list();
        node.data.send_to_workspace(self.current_workspace);

        return node;
    }

    fn focus(self: *Self, node: ?*ClientList.Node) void {
        if (self.clients.len == 0) return;

        if (node) |target_node| {
            if (self.focused_client == target_node) return;

            target_node.data.focus();

            if (self.focused_client) |old_node| if (self.node_exists(old_node)) {
                old_node.data.set_border_color(self.normal_color);
            };

            self.focused_client = target_node;

            return;
        }

        var next = self.clients.first;
        while (next) |n| : (next = n.next) {
            if (n.data.workspace == self.current_workspace) {
                return self.focus(n);
            }
        }
    }

    pub fn send_to_workspace(self: *Self, node: *ClientList.Node, workspace: u32) void {
        if (!self.node_exists(node)) return;
        if (node.data.workspace == workspace) return;

        if (self.focused_client) |focused_node| if (focused_node == node) self.focus(null);
        node.data.send_to_workspace(workspace);

        if (self.current_workspace != workspace) {
            node.data.hide();
        }
    }

    pub fn switch_workspace(self: *Self, workspace: u32) void {
        if (self.current_workspace == workspace) return;

        self.set_current_desktop(workspace);

        var next = self.clients.first;
        var focused = false;
        while (next) |node| : (next = node.next) {
            if (node.data.workspace != workspace) {
                node.data.hide();
            } else {
                node.data.show();
                if (!focused) node.data.focus();
                focused = true;
            }
        }
    }

    fn grab_pointer(self: *Self) void {
        _ = c.XGrabPointer(self.x_display, self.x_root, c.False, M.POINTER_MASK, c.GrabModeAsync, c.GrabModeAsync, c.None, C.move, c.CurrentTime);
    }

    fn ungrab_pointer(self: *Self) void {
        _ = c.XUngrabPointer(self.x_display, c.CurrentTime);
    }

    // ♡: https://github.com/c00kiemon5ter/monsterwm/issues/12#issuecomment-15343347
    fn propagate_pointer(self: *Self) void {
        _ = c.XAllowEvents(self.x_display, c.ReplayPointer, c.CurrentTime);
        _ = c.XSync(self.x_display, c.False);
    }

    fn ewmh_set_client_list(self: *Self) !void {
        _ = c.XDeleteProperty(self.x_display, self.x_root, A.net_client_list);

        var next = self.clients.first;
        while (next) |node| : (next = node.next) {
            _ = c.XChangeProperty(self.x_display, self.x_root, A.net_client_list, c.XA_WINDOW, c.XA_VISUALID, c.PropModeAppend, @ptrCast(&node.data.window), 1);
        }
    }

    fn set_current_desktop(self: *Self, workspace: u32) void {
        self.current_workspace = workspace;
        self.ewmh_set_current_desktop();
    }

    fn ewmh_set_current_desktop(self: *Self) void {
        _ = c.XChangeProperty(self.x_display, self.x_root, A.net_current_desktop, c.XA_CARDINAL, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&self.current_workspace), 1);
    }

    fn node_from_window(self: *Self, window: c.Window) ?*ClientList.Node {
        if (self.clients.len == 0) return null;

        var next = self.clients.first;
        while (next) |node| : (next = node.next) if (node.data.window == window) return node;

        return null;
    }

    fn node_exists(self: *Self, node: *ClientList.Node) bool {
        if (self.clients.len == 0) return false;

        var next = self.clients.first;
        while (next) |n| : (next = n.next) if (n == node) return true;

        return false;
    }
};
