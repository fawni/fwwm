const std = @import("std");

const WM = @import("wm.zig").WM;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var wm: WM = try WM.init(@constCast(&allocator));
    defer wm.deinit();

    try wm.run();
}
