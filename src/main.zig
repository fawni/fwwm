const std = @import("std");

const WM = @import("wm.zig").WM;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var allocator = gpa.allocator();

    var wm = WM.init(&allocator);
    defer wm.deinit();

    try wm.run();
}
