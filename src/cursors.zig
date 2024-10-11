const c = @import("c.zig");

pub var normal: c.Cursor = undefined;
pub var move: c.Cursor = undefined;

pub const Cursors = struct {
    const Self = @This();

    pub fn init(display: *c.Display) void {
        normal = c.XCreateFontCursor(display, c.XC_left_ptr);
        move = c.XCreateFontCursor(display, c.XC_crosshair);
    }
};
