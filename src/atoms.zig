const std = @import("std");
const c = @import("c.zig");

const log = std.log.scoped(.atoms);

pub var utf8string: c.Atom = undefined;
pub var net_supported: c.Atom = undefined;
pub var net_wm_check: c.Atom = undefined;
pub var net_wm_name: c.Atom = undefined;

pub const Atoms = struct {
    const Self = @This();

    pub fn init(display: *const c.Display, root: c.Window) c.Window {
        const WM_NAME = "fwwm";
        const check = c.XCreateSimpleWindow(@constCast(display), root, 0, 0, 1, 1, 0, 0, 0);

        utf8string = c.XInternAtom(@constCast(display), "UTF8_STRING", c.False);
        net_supported = c.XInternAtom(@constCast(display), "_NET_SUPPORTED", c.False);
        net_wm_check = c.XInternAtom(@constCast(display), "_NET_SUPPORTING_WM_CHECK", c.False);
        net_wm_name = c.XInternAtom(@constCast(display), "_NET_WM_NAME", c.False);

        const net_atoms = [_]c.Atom{
            net_supported,
            net_wm_check,
            net_wm_name,
        };

        _ = c.XChangeProperty(@constCast(display), check, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
        _ = c.XChangeProperty(@constCast(display), check, net_wm_name, utf8string, c.XA_CURSOR, c.PropModeReplace, WM_NAME, WM_NAME.len);
        _ = c.XChangeProperty(@constCast(display), root, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
        _ = c.XChangeProperty(@constCast(display), root, net_supported, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&net_atoms), net_atoms.len);

        return check;
    }
};