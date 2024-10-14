const std = @import("std");
const c = @import("c.zig");
const C = @import("cursors.zig");

const log = std.log.scoped(.wm);

const Layout = @import("layout.zig").Layout;
const Atoms = @import("atoms.zig").Atoms;

pub const WM = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *c.Display,
    x_screen: *c.Screen,
    x_root: c.Window,

    ewmh_check: c.Window,

    layout: Layout,

    pub fn init(allocator: *std.mem.Allocator) !Self {
        var wm: Self = undefined;

        wm.allocator = allocator;

        wm.x_display = c.XOpenDisplay(0) orelse std.process.exit(1);
        wm.x_screen = c.XDefaultScreenOfDisplay(wm.x_display);
        wm.x_root = c.XDefaultRootWindow(wm.x_display);

        wm.layout = try Layout.init(wm.allocator, wm.x_display, wm.x_root);
        wm.ewmh_check = Atoms.init(wm.x_display, wm.x_root);

        C.init(wm.x_display);

        return wm;
    }

    pub fn run(self: *Self) !void {
        log.info("fire walk with me", .{});

        _ = c.XSetErrorHandler(Self.on_error);
        _ = c.XSelectInput(self.x_display, self.x_root, c.StructureNotifyMask | c.SubstructureRedirectMask | c.SubstructureNotifyMask | c.ButtonPressMask | c.PointerMotionMask);
        _ = c.XDefineCursor(self.x_display, self.x_root, C.normal);

        _ = c.XSync(self.x_display, c.False);

        while (true) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(self.x_display, &event);

            switch (event.type) {
                c.ConfigureRequest => self.layout.on_configure_request(&event.xconfigurerequest),
                c.MapRequest => try self.layout.on_map_request(&event.xmaprequest),
                c.UnmapNotify => self.layout.on_unmap_notify(&event.xunmap),
                c.DestroyNotify => self.layout.on_destroy_notify(&event.xdestroywindow),
                c.ButtonPress => try self.layout.on_button_press(&event.xbutton),
                c.EnterNotify => self.layout.on_enter_notify(&event.xcrossing),
                c.LeaveNotify => self.layout.on_leave_notify(&event.xcrossing),
                else => {},
            }
        }
    }

    fn on_error(display: ?*c.Display, error_event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const event: *c.XErrorEvent = @ptrCast(error_event);

        switch (event.error_code) {
            c.BadAccess => {
                log.err("we live inside a dream, but who is the dreamer?", .{});
                std.process.exit(1);
            },
            else => {
                var error_text: [1024]u8 = undefined;
                _ = c.XGetErrorText(display, event.error_code, &error_text, 1024);
                log.err("Received X error:\n    Request: {d}\n    Error code: {s} ({d})\n    Resource ID: {d}", .{ event.request_code, error_text, event.error_code, event.resourceid });
            },
        }

        return 0;
    }

    pub fn deinit(self: *const Self) void {
        _ = c.XCloseDisplay(self.x_display);
    }
};
