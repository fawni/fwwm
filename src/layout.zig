const std = @import("std");
const c = @import("c.zig");
const clients = @import("clients.zig");

const log = std.log.scoped(.layout);

const Client = clients.Client;
const ClientList = clients.ClientList;

pub const Layout = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_screen: *const c.Screen,
    x_root: c.Window,

    screen_width: c_uint,
    screen_height: c_uint,

    clients: ClientList,
    active_client: ?*ClientList.Node,

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

        layout.clients = ClientList{};
        layout.active_client = null;

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

        const node = try self.addClient(event.window);
        self.focus(node);
    }

    pub fn onUnmapNotify(self: *Self, event: *const c.XUnmapEvent) void {
        log.debug("a node was unmapped", .{});
        if (self.windowToNode(event.window)) |node| {
            self.clients.remove(node);
        }

        if (self.active_client) |node| {
            self.active_client = node.prev;
        } else {
            self.active_client = self.clients.last;
        }
        self.focus(self.active_client);
    }

    pub fn onDestroyNotify(self: *Self, event: *const c.XDestroyWindowEvent) void {
        log.debug("a node was destroyed", .{});
        if (self.windowToNode(event.window)) |node| {
            self.clients.remove(node);
        }

        if (self.active_client) |node| {
            self.active_client = node.prev;
        } else {
            self.active_client = self.clients.last;
        }
        self.focus(self.active_client);
    }

    pub fn onButtonPress(self: *Layout, event: *c.XButtonPressedEvent) void {
        log.debug("button pressed", .{});
        if (self.windowToNode(event.subwindow)) |node| if (node != self.active_client) {
            self.focus(node);
        };

        // ♡: https://github.com/c00kiemon5ter/monsterwm/issues/12#issuecomment-15343347
        _ = c.XAllowEvents(@constCast(self.x_display), c.ReplayPointer, c.CurrentTime);
        _ = c.XSync(@constCast(self.x_display), c.False);
    }

    pub fn onEnterNotify(self: *Layout, event: *c.XCrossingEvent) void {
        // log.debug("entered a window", .{});
        const node = self.windowToNode(event.window);
        if (node != self.active_client) {
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, self.hover_color);
        }
    }

    pub fn onLeaveNotify(self: *Layout, event: *c.XCrossingEvent) void {
        // log.debug("left a window", .{});
        const node = self.windowToNode(event.window);
        if (node != self.active_client) {
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, self.normal_color);
        }
    }

    pub fn addClient(self: *Self, window: c.Window) !*ClientList.Node {
        log.debug("adding node to managed clients", .{});

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), window, &attributes);

        const client = Client{
            .window = window,
            .position_x = attributes.x,
            .position_y = attributes.y,
            .window_width = attributes.width,
            .window_height = attributes.height,
        };

        var node = try self.allocator.create(ClientList.Node);

        node.data = client;
        self.clients.append(node);

        return node;
    }

    pub fn focus(self: *Self, node: ?*ClientList.Node) void {
        if (self.clients.len == 0) return;

        if (self.active_client) |n| {
            _ = c.XSetWindowBorder(@constCast(self.x_display), n.data.window, self.normal_color);
        }

        const target = node orelse self.clients.last.?;
        _ = c.XSetInputFocus(
            @constCast(self.x_display),
            target.data.window,
            c.RevertToParent,
            c.CurrentTime,
        );
        _ = c.XRaiseWindow(@constCast(self.x_display), target.data.window);
        _ = c.XSetWindowBorder(@constCast(self.x_display), target.data.window, self.focus_color);

        self.active_client = target;
    }

    fn windowToNode(self: *Self, window: c.Window) ?*ClientList.Node {
        var next = self.clients.first;
        while (next) |node| : (next = node.next) {
            if (node.data.window == window) return node;
        }

        return null;
    }
};
