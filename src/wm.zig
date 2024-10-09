const std = @import("std");
const c = @import("c.zig");

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

        // _ = c.XSelectInput(@constCast(wm.x_display), wm.x_root, c.SubstructureRedirectMask);

        return wm;
    }

    pub fn run(self: *Self) !void {
        // std.debug.print("Through the darkness of future past, the magician longs to see. One chants out between two worlds.\nFire, walk with me.\n", .{});

        _ = c.XSetErrorHandler(Self.onError);
        _ = c.XSelectInput(@constCast(self.x_display), self.x_root, c.SubstructureRedirectMask | c.SubstructureNotifyMask);
        _ = c.XDefineCursor(@constCast(self.x_display), self.x_root, c.XCreateFontCursor(@constCast(self.x_display), 2));

        _ = c.XSync(@constCast(self.x_display), 0);

        while (true) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(@constCast(self.x_display), &event);

            // std.debug.print("{}\n", .{event.type});
            switch (event.type) {
                c.CreateNotify => try self.layout.onCreateNotify(&event.xcreatewindow),
                c.MapRequest => try self.layout.onMapRequest(&event.xmaprequest),
                // c.UnmapNotify => self.layout.onUnmapNotify(&event.xunmap),
                // c.DestroyNotify => try self.layout.onDestroyNotify(&event.xdestroywindow),
                c.KeyPress => try self.layout.onKeyPress(&event.xkey),
                // c.ButtonPress => try self.layout.onButtonPress(@constCast(&event.xbutton)),
                else => {},
            }
        }
    }

    fn onError(_: ?*c.Display, event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const e: *c.XErrorEvent = @ptrCast(event);

        std.debug.print("error: {}\n", .{e.type});

        // switch (e.type) {
        //     else => {},
        // }

        return 0;
    }

    pub fn deinit(self: *const Self) void {
        _ = c.XCloseDisplay(@constCast(self.x_display));
    }
};
