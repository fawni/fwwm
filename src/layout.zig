const std = @import("std");
const c = @import("c.zig");
const nodes = @import("nodes.zig");

const log = std.log.scoped(.layout);

const Leaf = nodes.Leaf;
const Leaves = nodes.Leaves;
const Node = nodes.Node;

pub const Layout = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_screen: *const c.Screen,
    x_root: c.Window,

    screen_width: c_uint,
    screen_height: c_uint,

    leaves: Leaves,
    active_node: ?*Node,

    normal_color: u32,
    hover_color: u32,
    focus_color: u32,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, root: c.Window) !Self {
        var layout: Self = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_root = root;

        const screen = c.DefaultScreen(@constCast(layout.x_display));

        layout.screen_width = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.screen_height = @intCast(c.XDisplayHeight(@constCast(display), screen));

        layout.leaves = Leaves{};
        layout.active_node = null;

        layout.normal_color = 0x909090;
        layout.hover_color = 0xee95d2;
        layout.focus_color = 0xd895ee;

        return layout;
    }

    pub fn onConfigureRequest(self: *Self, event: *const c.XConfigureRequestEvent) void {
        var changes: c.XWindowChanges = undefined;

        changes.x = event.x;
        changes.y = event.y;

        changes.width = event.width;
        changes.height = event.height;

        changes.border_width = event.border_width;

        changes.sibling = event.above;
        changes.stack_mode = event.detail;

        _ = c.XConfigureWindow(@constCast(self.x_display), event.window, @intCast(event.value_mask), &changes);
    }

    pub fn onMapRequest(self: *Self, event: *const c.XMapRequestEvent) !void {
        log.debug("mapping a node", .{});
        _ = c.XSelectInput(@constCast(self.x_display), event.window, c.StructureNotifyMask | c.EnterWindowMask | c.LeaveWindowMask | c.FocusChangeMask);

        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);
        _ = c.XMapWindow(@constCast(self.x_display), event.window);

        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, self.normal_color);
        _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 2);

        const node = try self.addNode(event.window);
        self.focus(node);
    }

    pub fn onUnmapNotify(self: *Self, event: *const c.XUnmapEvent) void {
        log.debug("a node was unmapped", .{});
        if (self.windowToNode(event.window)) |node| {
            self.leaves.remove(node);
        }

        if (self.active_node) |node| {
            self.active_node = node.prev;
        } else {
            self.active_node = self.leaves.last;
        }
        self.focus(self.active_node);
    }

    pub fn onDestroyNotify(self: *Self, event: *const c.XDestroyWindowEvent) void {
        log.debug("a node was destroyed", .{});
        if (self.windowToNode(event.window)) |node| {
            self.leaves.remove(node);
        }

        if (self.active_node) |node| {
            self.active_node = node.prev;
        } else {
            self.active_node = self.leaves.last;
        }
        self.focus(self.active_node);
    }

    pub fn onButtonPress(self: *Layout, event: *c.XButtonPressedEvent) void {
        log.debug("button pressed", .{});
        if (self.windowToNode(event.subwindow)) |node| if (node != self.active_node) {
            self.focus(node);
        };

        // ♡: https://github.com/c00kiemon5ter/monsterwm/issues/12#issuecomment-15343347
        _ = c.XAllowEvents(@constCast(self.x_display), c.ReplayPointer, c.CurrentTime);
        _ = c.XSync(@constCast(self.x_display), c.False);
    }

    pub fn onEnterNotify(self: *Layout, event: *c.XCrossingEvent) void {
        // log.debug("entered a window", .{});
        const node = self.windowToNode(event.window);
        if (node != self.active_node) {
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, self.hover_color);
        }
    }

    pub fn onLeaveNotify(self: *Layout, event: *c.XCrossingEvent) void {
        // log.debug("left a window", .{});
        const node = self.windowToNode(event.window);
        if (node != self.active_node) {
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, self.normal_color);
        }
    }

    // pub fn onKeyPress(self: *Layout, event: *c.XKeyPressedEvent) !void {
    //     _ = self;
    //     _ = event;
    // }

    // pub fn onCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
    //     _ = self;
    //     _ = event;
    // }

    pub fn addNode(self: *Self, window: c.Window) !*Node {
        log.debug("adding node to managed leaves", .{});

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), window, &attributes);

        const leaf = Leaf{
            .window = window,
            .position_x = attributes.x,
            .position_y = attributes.y,
            .window_width = attributes.width,
            .window_height = attributes.height,
        };

        var node = try self.allocator.create(Node);

        node.data = leaf;
        self.leaves.append(node);

        return node;
    }

    pub fn focus(self: *Self, node: ?*Node) void {
        if (self.leaves.len == 0) return;

        if (self.active_node) |n| {
            _ = c.XSetWindowBorder(@constCast(self.x_display), n.data.window, self.normal_color);
        }

        const target = node orelse self.leaves.last.?;
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

    fn windowToNode(self: *Self, window: c.Window) ?*Node {
        var next = self.leaves.first;
        while (next) |node| : (next = node.next) {
            if (node.data.window == window) return node;
        }

        return null;
    }
};
