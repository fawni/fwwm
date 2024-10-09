const std = @import("std");
const c = @import("c.zig");

const log = std.log.scoped(.layout);

const Child = struct {
    window: c.Window,
    position_x: c_int,
    position_y: c_int,
    window_width: c_int,
    window_height: c_int,
};

pub const Layout = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_screen: *const c.Screen,
    x_root: c.Window,

    screen_width: c_uint,
    screen_height: c_uint,

    children: std.DoublyLinkedList(Child),
    active_node: ?*std.DoublyLinkedList(Child).Node = null,

    normal_color: u32 = 0x909090,
    focus_color: u32 = 0xd895ee,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, root: c.Window) !Self {
        var layout: Self = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_root = root;

        const screen = c.DefaultScreen(@constCast(layout.x_display));

        layout.screen_width = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.screen_height = @intCast(c.XDisplayHeight(@constCast(display), screen));

        layout.children = std.DoublyLinkedList(Child){};
        layout.active_node = null;

        layout.normal_color = 0x909090;
        layout.focus_color = 0xd895ee;

        return layout;
    }

    pub fn onMapRequest(self: *Self, event: *const c.XMapRequestEvent) !void {
        log.debug("mapping a node", .{});
        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);
        _ = c.XMapWindow(@constCast(self.x_display), event.window);
        _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 2);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, self.normal_color);

        const node = try self.addChild(event.window);
        self.focus(node);
    }

    pub fn onUnmapNotify(self: *Self, event: *const c.XUnmapEvent) void {
        log.debug("a node was unmapped", .{});
        if (self.windowToNode(event.window)) |node| {
            self.children.remove(node);
        }

        if (self.active_node) |node| {
            self.active_node = node.prev;
        } else {
            self.active_node = self.children.first;
        }
        self.focus(self.active_node);
    }

    pub fn onDestroyNotify(self: *Self, event: *const c.XDestroyWindowEvent) void {
        log.debug("a node was destroyed", .{});
        if (self.windowToNode(event.window)) |node| {
            self.children.remove(node);
        }

        if (self.active_node) |node| {
            self.active_node = node.prev;
        } else {
            self.active_node = self.children.first;
        }
        self.focus(self.active_node);
    }

    // pub fn onKeyPress(self: *Layout, event: *c.XKeyPressedEvent) !void {
    //     _ = self;
    //     _ = event;
    // }

    // pub fn onCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
    //     _ = self;
    //     _ = event;
    // }

    pub fn addChild(self: *Self, window: c.Window) !*std.DoublyLinkedList(Child).Node {
        log.debug("adding child to managed children", .{});

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), window, &attributes);

        const child = Child{
            .window = window,
            .position_x = attributes.x,
            .position_y = attributes.y,
            .window_width = attributes.width,
            .window_height = attributes.height,
        };

        var node = try self.allocator.create(std.DoublyLinkedList(Child).Node);

        node.data = child;
        self.children.append(node);

        return node;
    }

    pub fn focus(self: *Self, node: ?*std.DoublyLinkedList(Child).Node) void {
        if (self.children.len == 0) return;

        if (self.active_node) |n| {
            _ = c.XSetWindowBorder(@constCast(self.x_display), n.data.window, self.normal_color);
        }
        const target = node orelse self.children.first.?;

        _ = c.XSetInputFocus(
            @constCast(self.x_display),
            target.data.window,
            c.RevertToParent,
            c.CurrentTime,
        );
        _ = c.XRaiseWindow(@constCast(self.x_display), target.data.window);
        _ = c.XSetWindowBorder(@constCast(self.x_display), target.data.window, self.focus_color);

        self.active_node = target;
    }

    fn windowToNode(self: *Self, window: c.Window) ?*std.DoublyLinkedList(Child).Node {
        var next = self.children.first;
        while (next) |node| : (next = node.next) {
            if (node.data.window == window) return node;
        }
        return null;
    }
};
