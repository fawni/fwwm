const std = @import("std");
const c = @import("c.zig");

const log = std.log.scoped(.atoms);

pub var utf8string: c.Atom = undefined;
pub var net_supported: c.Atom = undefined;
pub var net_wm_check: c.Atom = undefined;
pub var net_wm_name: c.Atom = undefined;
pub var net_client_list: c.Atom = undefined;
pub var net_active_window: c.Atom = undefined;
pub var net_current_desktop: c.Atom = undefined;
pub var net_number_of_desktops: c.Atom = undefined;
pub var net_wm_desktop: c.Atom = undefined;
pub var net_wm_state: c.Atom = undefined;
pub var net_wm_state_fullscreen: c.Atom = undefined;
pub var net_wm_state_hidden: c.Atom = undefined;
pub var net_wm_window_type: c.Atom = undefined;
pub var net_wm_window_type_desktop: c.Atom = undefined;
pub var net_wm_window_type_dock: c.Atom = undefined;
pub var net_wm_window_type_toolbar: c.Atom = undefined;
pub var net_wm_window_type_utility: c.Atom = undefined;
pub var net_wm_window_type_dialog: c.Atom = undefined;
pub var net_wm_window_type_menu: c.Atom = undefined;
pub var net_wm_window_type_notification: c.Atom = undefined;

pub var fwwm_client_event: c.Atom = undefined;

const Self = @This();

pub fn init(display: *c.Display, root: c.Window) c.Window {
    const WM_NAME = "fwwm";

    const check = c.XCreateSimpleWindow(display, root, 0, 0, 1, 1, 0, 0, 0);

    utf8string = c.XInternAtom(display, "UTF8_STRING", c.False);

    net_supported = c.XInternAtom(display, "_NET_SUPPORTED", c.False);
    net_wm_check = c.XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", c.False);
    net_wm_name = c.XInternAtom(display, "_NET_WM_NAME", c.False);
    net_client_list = c.XInternAtom(display, "_NET_CLIENT_LIST", c.False);
    net_active_window = c.XInternAtom(display, "_NET_ACTIVE_WINDOW", c.False);
    net_current_desktop = c.XInternAtom(display, "_NET_CURRENT_DESKTOP", c.False);
    net_number_of_desktops = c.XInternAtom(display, "_NET_NUMBER_OF_DESKTOPS", c.False);
    net_wm_desktop = c.XInternAtom(display, "_NET_WM_DESKTOP", c.False);
    net_wm_state = c.XInternAtom(display, "_NET_WM_STATE", c.False);
    net_wm_state_fullscreen = c.XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", c.False);
    net_wm_state_hidden = c.XInternAtom(display, "_NET_WM_STATE_HIDDEN", c.False);
    net_wm_window_type = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE", c.False);
    net_wm_window_type_desktop = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_DESKTOP", c.False);
    net_wm_window_type_dock = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_DOCK", c.False);
    net_wm_window_type_toolbar = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_TOOLBAR", c.False);
    net_wm_window_type_utility = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_UTILITY", c.False);
    net_wm_window_type_dialog = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_DIALOG", c.False);
    net_wm_window_type_menu = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_MENU", c.False);
    net_wm_window_type_notification = c.XInternAtom(display, "_NET_WM_WINDOW_TYPE_NOTIFICATION", c.False);

    fwwm_client_event = c.XInternAtom(display, "FWWM_CHERRY_EVENT", c.False);

    const net_atoms = [_]c.Atom{
        net_supported,
        net_wm_check,
        net_wm_name,
        net_client_list,
        net_active_window,
        net_current_desktop,
        net_number_of_desktops,
        net_wm_desktop,
        net_wm_state,
        net_wm_state_fullscreen,
        net_wm_state_hidden,
        net_wm_window_type,
        net_number_of_desktops,
        net_wm_window_type_dock,
        net_wm_window_type_toolbar,
        net_wm_window_type_utility,
        net_wm_window_type_dialog,
        net_wm_window_type_menu,
        net_wm_window_type_notification,
    };

    _ = c.XChangeProperty(display, check, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
    _ = c.XChangeProperty(display, check, net_wm_name, utf8string, c.XA_CURSOR, c.PropModeReplace, WM_NAME, WM_NAME.len);
    _ = c.XChangeProperty(display, root, net_wm_check, c.XA_WINDOW, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&check), 1);
    _ = c.XChangeProperty(display, root, net_supported, c.XA_ATOM, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&net_atoms), net_atoms.len);

    const workspaces: c_long = 10;
    _ = c.XChangeProperty(display, root, net_number_of_desktops, c.XA_CARDINAL, c.XA_VISUALID, c.PropModeReplace, @ptrCast(&workspaces), 1);

    return check;
}
