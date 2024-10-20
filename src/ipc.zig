const std = @import("std");
const c = @import("c.zig");

const Manager = @import("manager.zig").Manager;
const ClientList = @import("clients.zig").ClientList;
const Node = ClientList.Node;

// TODO: reorder to make more sense
pub const IPCCommand = enum {
    Close,
    Kill,
    Move,
    Resize,
    Maximize,
    Fullscreen,
    Hide,
    Show,
    SendToWorkspace,
    SwitchWorkspace,
    Quit,
};

pub fn handle(node: ?*Node, data: [5]c_long, manager: *Manager) void {
    switch (data[0]) {
        @intFromEnum(IPCCommand.SwitchWorkspace) => switch_workspace(data[1], manager),
        @intFromEnum(IPCCommand.Quit) => quit(manager),
        else => {},
    }

    if (node) |n| {
        switch (data[0]) {
            @intFromEnum(IPCCommand.Close) => close(n),
            @intFromEnum(IPCCommand.Kill) => kill(n),
            @intFromEnum(IPCCommand.Move) => move(n, data[1], data[2]),
            @intFromEnum(IPCCommand.Resize) => resize(n, data[1], data[2]),
            @intFromEnum(IPCCommand.Maximize) => maximize(n, data[1]),
            @intFromEnum(IPCCommand.Fullscreen) => fullscreen(n, data[1]),
            @intFromEnum(IPCCommand.Hide) => hide(n),
            @intFromEnum(IPCCommand.Show) => show(n),
            @intFromEnum(IPCCommand.SendToWorkspace) => send_to_workspace(n, data[1], manager),
            else => {},
        }
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

fn send_to_workspace(node: *Node, workspace: c_long, manager: *Manager) void {
    manager.send_to_workspace(node, @intCast(workspace));
}

fn switch_workspace(workspace: c_long, manager: *Manager) void {
    manager.switch_workspace(@intCast(workspace));
}

fn quit(manager: *Manager) void {
    manager.quit();
}
