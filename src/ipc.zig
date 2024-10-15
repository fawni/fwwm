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
};

pub fn handle(node: *Node, data: [5]c_long) void {
    switch (data[0]) {
        @intFromEnum(IPCCommand.Close) => close(node),
        @intFromEnum(IPCCommand.Kill) => kill(node),
        @intFromEnum(IPCCommand.Move) => move(node, data[1], data[2]),
        @intFromEnum(IPCCommand.Resize) => resize(node, data[1], data[2]),
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
