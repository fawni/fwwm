const std = @import("std");
const c = @import("c.zig");

pub var utf8string: c.Atom = undefined;
pub var net_supported: c.Atom = undefined;
pub var net_wm_check: c.Atom = undefined;
pub var net_wm_name: c.Atom = undefined;
// pub var net_active_window: c.Atom = undefined;

pub const Atoms = struct {
    const Self = @This();

    pub fn init(display: *const c.Display, root: c.Window) c.Window {
        const wm_name = "fwwm";

        net_supported = c.XInternAtom(@constCast(display), "UTF8_STRING", c.False);
        net_supported = c.XInternAtom(@constCast(display), "_NET_SUPPORTED", c.False);
        net_wm_check = c.XInternAtom(@constCast(display), "_NET_SUPPORTING_WM_CHECK", c.False);
        net_wm_name = c.XInternAtom(@constCast(display), "_NET_WM_NAME", c.False);

        const check = c.XCreateSimpleWindow(@constCast(display), root, 0, 0, 1, 1, 0, 0, 0);
        const supported_net_atoms = [_]c.Atom{ net_supported, net_wm_check, net_wm_name };

        // FIXME: this is still not correct for some reason.
        _ = c.XChangeProperty(@constCast(display), check, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
        _ = c.XChangeProperty(@constCast(display), check, net_wm_name, utf8string, c.XA_STRING, c.PropModeReplace, wm_name, wm_name.len);
        _ = c.XChangeProperty(@constCast(display), root, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
        _ = c.XChangeProperty(@constCast(display), root, net_supported, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&supported_net_atoms), supported_net_atoms.len);

        return check;
    }
};
