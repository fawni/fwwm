const std = @import("std");
const c = @import("c.zig");

const log = std.log.scoped(.atoms);

pub var utf8string: c.Atom = undefined;
pub var net_supported: c.Atom = undefined;
pub var net_wm_check: c.Atom = undefined;
pub var net_active_window: c.Atom = undefined;
pub var net_wm_name: c.Atom = undefined;
pub var net_wm_state: c.Atom = undefined;
pub var net_wm_state_fullscreen: c.Atom = undefined;
pub var net_wm_state_hidden: c.Atom = undefined;

pub var fwwm_client_event: c.Atom = undefined;

const Self = @This();

pub fn init(display: *c.Display, root: c.Window) c.Window {
    const WM_NAME = "fwwm";
    const check = c.XCreateSimpleWindow(display, root, 0, 0, 1, 1, 0, 0, 0);

    utf8string = c.XInternAtom(display, "UTF8_STRING", c.False);

    net_supported = c.XInternAtom(display, "_NET_SUPPORTED", c.False);
    net_wm_check = c.XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", c.False);
    net_wm_name = c.XInternAtom(display, "_NET_WM_NAME", c.False);
    net_active_window = c.XInternAtom(display, "_NET_ACTIVE_WINDOW", c.False);
    net_wm_state = c.XInternAtom(display, "_NET_WM_STATE", c.False);
    net_wm_state_fullscreen = c.XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", c.False);
    net_wm_state_hidden = c.XInternAtom(display, "_NET_WM_STATE_HIDDEN", c.False);

    fwwm_client_event = c.XInternAtom(display, "FWWM_CHERRY_EVENT", c.False);

    const net_atoms = [_]c.Atom{
        net_supported,
        net_wm_check,
        net_wm_name,
        net_active_window,
        net_wm_state,
        net_wm_state_fullscreen,
        net_wm_state_hidden,
    };

    _ = c.XChangeProperty(display, check, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
    _ = c.XChangeProperty(display, check, net_wm_name, utf8string, c.XA_CURSOR, c.PropModeReplace, WM_NAME, WM_NAME.len);
    _ = c.XChangeProperty(display, root, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
    _ = c.XChangeProperty(display, root, net_supported, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&net_atoms), net_atoms.len);

    return check;
}
