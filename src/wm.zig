const std = @import("std");
const c = @import("c.zig");
const log = std.log.scoped(.wm);

const Layout = @import("layout.zig").Layout;

pub const WM = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_screen: *c.Screen,
    x_root: c.Window,

    layout: Layout,

    pub fn init(allocator: *std.mem.Allocator) !Self {
        var wm: Self = undefined;

        wm.allocator = allocator;

        wm.x_display = c.XOpenDisplay(0) orelse std.process.exit(1);
        wm.x_screen = c.XDefaultScreenOfDisplay(@constCast(wm.x_display));
        wm.x_root = c.XDefaultRootWindow(@constCast(wm.x_display));

        wm.layout = try Layout.init(wm.allocator, wm.x_display, wm.x_root);

        return wm;
    }

    pub fn run(self: *Self) !void {
        log.info("Fire, walk with me.", .{});

        _ = c.XSetErrorHandler(Self.onError);
        _ = c.XSelectInput(@constCast(self.x_display), self.x_root, c.SubstructureRedirectMask | c.SubstructureNotifyMask);
        _ = c.XDefineCursor(@constCast(self.x_display), self.x_root, c.XCreateFontCursor(@constCast(self.x_display), 2));

        for ([_]c_uint{ c.Button1, c.Button3 }) |button| {
            _ = c.XGrabButton(@constCast(self.x_display), button, c.AnyModifier, self.x_root, c.False, c.ButtonPressMask | c.ButtonReleaseMask | c.ButtonMotionMask, c.GrabModeSync, c.GrabModeAsync, c.None, c.None);
        }

        _ = c.XSync(@constCast(self.x_display), c.False);

        while (true) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(@constCast(self.x_display), &event);

            // log.debug("got XEvent: {}", .{event.type});
            switch (event.type) {
                c.ConfigureRequest => self.layout.onConfigureRequest(&event.xconfigurerequest),
                c.MapRequest => try self.layout.onMapRequest(&event.xmaprequest),
                c.UnmapNotify => self.layout.onUnmapNotify(&event.xunmap),
                c.DestroyNotify => self.layout.onDestroyNotify(&event.xdestroywindow),
                c.ButtonPress => self.layout.onButtonPress(&event.xbutton),
                c.EnterNotify => self.layout.onEnterNotify(&event.xcrossing),
                c.LeaveNotify => self.layout.onLeaveNotify(&event.xcrossing),
                // c.KeyPress => try self.layout.onKeyPress(&event.xkey),
                // c.CreateNotify => try self.layout.onCreateNotify(&event.xcreatewindow),
                else => {},
            }
        }
    }

    fn onError(display: ?*c.Display, error_event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const event: *c.XErrorEvent = @ptrCast(error_event);

        var error_text: [1024]u8 = undefined;
        _ = c.XGetErrorText(display, event.error_code, &error_text, 1024);

        log.err("Received X error:\n    Request: {d}\n    Error code: {s} ({d})\n    Resource ID: {d}", .{ event.request_code, error_text, event.error_code, event.resourceid });

        return 0;
    }

    pub fn deinit(self: *const Self) void {
        _ = c.XCloseDisplay(@constCast(self.x_display));
    }
};
