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

        layout.normal_color = 0x909090;
        layout.hover_color = 0x97d0e8;
        layout.focus_color = 0xd895ee;

        layout.border_width = 2;

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

                const old_client_x = node.data.x;
                const old_client_y = node.data.y;
                const old_client_width = node.data.width;
                const old_client_height = node.data.height;

                var e: c.XEvent = undefined;
                while (e.type != c.ButtonRelease) {
                    _ = c.XMaskEvent(self.x_display, c.PointerMotionMask | c.ButtonReleaseMask, &e);
                    // move
                    if (e.xbutton.state & c.Button1Mask != 0) {
                        switch (e.type) {
                            c.MotionNotify => {
                                const new_x = old_client_x + (e.xmotion.x - pointer_x);
                                const new_y = old_client_y + (e.xmotion.y - pointer_y);

                                node.data.move(new_x, new_y);
                            },
                            else => {},
                        }
                    } else if (e.xbutton.state & c.Button3Mask != 0) {
                        // resize
                        // TODO: change position of resize based on the closest corner to the pointer.
                        switch (e.type) {
                            c.MotionNotify => {
                                var new_width = e.xmotion.x - pointer_x + old_client_width;
                                var new_height = e.xmotion.y - pointer_y + old_client_height;
                                if (new_width < 1) new_width = 1;
                                if (new_height < 1) new_height = 1;

                                node.data.resize(@intCast(new_width), @intCast(new_height));
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
        if (event.message_type == A.fwwm_client_event) {
            if (self.node_from_window(@intCast(event.data.l[4]))) |node| {
                ipc.handle(node, event.data.l);

                return;
            }

            if (self.focused_client) |node| {
                ipc.handle(node, event.data.l);
            }
        }
    }

    pub fn add_client(self: *Self, window: c.Window) !*ClientList.Node {
        if (self.node_from_window(window)) |node| return node;
        // log.debug("adding window to managed clients: {}", .{window});

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(self.x_display, window, &attributes);

        const client = Client{
            .x_display = self.x_display,
            .window = window,
            .x = attributes.x,
            .y = attributes.y,
            .width = attributes.width,
            .height = attributes.height,
            .screen_width = self.screen_width,
            .screen_height = self.screen_height,
            .border_width = self.border_width,
        };

        var node = try self.allocator.create(ClientList.Node);

        node.data = client;
        self.clients.append(node);

        return node;
    }

    fn focus(self: *Self, node: ?*ClientList.Node) void {
        if (self.clients.len == 0) return;

        if (node orelse self.clients.last orelse self.clients.first) |target_node| {
            if (self.focused_client == target_node) return;

            target_node.data.focus(self.focus_color);

            if (self.focused_client) |old_node| if (self.node_exists(old_node)) {
                old_node.data.set_border_color(self.normal_color);
            };

            self.focused_client = target_node;
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
