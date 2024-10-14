const c = @import("c.zig");

pub const MOUSE_MASK = c.ButtonPressMask | c.ButtonReleaseMask;
pub const POINTER_MASK = c.PointerMotionMask | MOUSE_MASK;

pub const MAP_WINDOW_MASK = c.EnterWindowMask | c.LeaveWindowMask | c.FocusChangeMask | c.PropertyChangeMask;
