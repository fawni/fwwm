const std = @import("std");
const c = @import("c.zig");

const A = @import("atoms.zig");
const cursors = @import("cursors.zig");

const log = std.log.scoped(.wm);

const Manager = @import("manager.zig").Manager;

pub const WM = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,

    x_display: *c.Display,
    x_root: c.Window,

    ewmh_check: c.Window,

    manager: Manager,

    running: bool,

    pub fn init(allocator: *std.mem.Allocator) Self {
        var wm: Self = undefined;

        wm.allocator = allocator;

        wm.x_display = c.XOpenDisplay(null) orelse std.process.exit(1);
        wm.x_root = c.XDefaultRootWindow(wm.x_display);

        wm.ewmh_check = A.init(wm.x_display, wm.x_root);

        wm.manager = Manager.init(&wm);

        wm.running = true;

        cursors.init(wm.x_display);

        return wm;
    }

    pub fn run(self: *Self) !void {
        log.info("fire walk with me", .{});

        _ = c.XSetErrorHandler(Self.on_error);
        _ = c.XSelectInput(self.x_display, self.x_root, c.StructureNotifyMask |
            c.SubstructureRedirectMask |
            c.SubstructureNotifyMask |
            c.ButtonPressMask |
            c.PointerMotionMask);
        _ = c.XDefineCursor(self.x_display, self.x_root, cursors.normal);

        _ = c.XSync(self.x_display, c.False);

        while (self.running) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(self.x_display, &event);

            switch (event.type) {
                c.ConfigureRequest => self.manager.on_configure_request(&event.xconfigurerequest),
                c.MapRequest => try self.manager.on_map_request(&event.xmaprequest),
                c.UnmapNotify => self.manager.on_unmap_notify(&event.xunmap),
                c.DestroyNotify => self.manager.on_destroy_notify(&event.xdestroywindow),
                c.ButtonPress => try self.manager.on_button_press(&event.xbutton),
                c.EnterNotify => self.manager.on_enter_notify(&event.xcrossing),
                c.LeaveNotify => self.manager.on_leave_notify(&event.xcrossing),
                c.ClientMessage => self.manager.on_client_message(&event.xclient),
                else => {},
            }
        }
    }

    fn on_error(display: ?*c.Display, error_event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const event: *c.XErrorEvent = @ptrCast(error_event);

        if (event.error_code == c.BadWindow or
            (event.request_code == c.X_SetInputFocus and event.error_code == c.BadMatch) or
            (event.request_code == c.X_ConfigureWindow and event.error_code == c.BadMatch) or
            (event.request_code == c.X_GrabButton and event.error_code == c.BadAccess) or
            (event.request_code == c.X_GrabKey and event.error_code == c.BadAccess)) return 0;

        switch (event.error_code) {
            c.BadAccess => {
                log.err("we live inside a dream, but who is the dreamer?", .{});
                std.process.exit(1);
            },
            else => {
                var error_text: [1024]u8 = undefined;
                _ = c.XGetErrorText(display, event.error_code, &error_text, 1024);
                log.err(
                    \\Received X error:
                    \\    Request: {d}
                    \\    Error code: {s} ({d})
                    \\    Resource ID: {d}
                , .{ event.request_code, error_text, event.error_code, event.resourceid });
            },
        }

        return 0;
    }

    pub fn deinit(self: *Self) void {
        var next = self.manager.clients.first;
        while (next) |node| : (next = node.next) {
            self.manager.clients.remove(node);
        }
        self.manager.ewmh_set_client_list();

        _ = c.XUngrabPointer(self.x_display, c.CurrentTime);
        _ = c.XUngrabButton(self.x_display, c.AnyButton, c.AnyModifier, self.x_root);
        _ = c.XUngrabKey(self.x_display, c.AnyKey, c.AnyModifier, self.x_root);

        _ = c.XDeleteProperty(self.x_display, self.x_root, A.net_supported);

        _ = c.XCloseDisplay(self.x_display);
    }
};
