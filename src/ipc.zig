const std = @import("std");
const c = @import("c.zig");
const clients = @import("clients.zig");
const layout = @import("layout.zig");

const ClientList = clients.ClientList;
const Node = ClientList.Node;

// TODO: order matters so organize accordingly (when we have more commands)
pub const IPCCommand = enum {
    Close,
    Kill,
    Move,
    Resize,
    Maximize,
    Fullscreen,
    Hide,
    Show,
};

pub fn handle(node: *Node, data: [5]c_long) void {
    switch (data[0]) {
        @intFromEnum(IPCCommand.Close) => close(node),
        @intFromEnum(IPCCommand.Kill) => kill(node),
        @intFromEnum(IPCCommand.Move) => move(node, data[1], data[2]),
        @intFromEnum(IPCCommand.Resize) => resize(node, data[1], data[2]),
        @intFromEnum(IPCCommand.Maximize) => maximize(node, data[1]),
        @intFromEnum(IPCCommand.Fullscreen) => fullscreen(node, data[1]),
        @intFromEnum(IPCCommand.Hide) => hide(node),
        @intFromEnum(IPCCommand.Show) => show(node),
        else => {},
    }
}

fn close(node: *Node) void {
    node.data.close();
}

fn kill(node: *Node) void {
    node.data.kill();
}

fn move(node: *Node, x: c_long, y: c_long) void {
    node.data.move(@intCast(x), @intCast(y));
}

fn resize(node: *Node, width: c_long, height: c_long) void {
    node.data.resize(@intCast(width), @intCast(height));
}

fn maximize(node: *Node, data: c_long) void {
    const state = switch (data) {
        0 => false,
        1 => true,
        else => null,
    };

    node.data.maximize(state);
}

fn fullscreen(node: *Node, data: c_long) void {
    const state = switch (data) {
        0 => false,
        1 => true,
        else => null,
    };

    node.data.fullscreen(state);
}

fn hide(node: *Node) void {
    node.data.hide();
}

fn show(node: *Node) void {
    node.data.show();
}
