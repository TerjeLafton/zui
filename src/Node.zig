const std = @import("std");

const Node = @This();

sizing: Sizing = .{},
padding: Padding = .{},
self_alignment: ?Alignment = null,

x: i32 = 0,
y: i32 = 0,
actual_width: i32 = 0,
actual_height: i32 = 0,

bg_color: ?Color = null,
corner_radius: i32 = 0,

type: NodeType,

pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
    switch (self.type) {
        .container => |*container| {
            for (container.children.items) |*child| {
                child.deinit(allocator);
            }
            container.children.deinit(allocator);
        },
        else => {},
    }
}

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

pub const SizeMode = union(enum) {
    fit: void,
    grow: f32,
    fixed: i32,
};

pub const Sizing = struct {
    width: SizeMode = .fit,
    height: SizeMode = .fit,
};

pub const Border = struct {
    width: i32 = 0,
    color: Color = Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
};

pub const Alignment = struct {
    x: AlignMode = .start,
    y: AlignMode = .start,
};

pub const AlignMode = enum {
    start,
    center,
    end,
};

pub const Padding = struct {
    top: i32 = 0,
    bottom: i32 = 0,
    left: i32 = 0,
    right: i32 = 0,

    pub fn all(value: i32) Padding {
        return Padding{
            .top = value,
            .bottom = value,
            .left = value,
            .right = value,
        };
    }

    pub fn x(value: i32) Padding {
        return Padding{
            .left = value,
            .right = value,
        };
    }

    pub fn y(value: i32) Padding {
        return Padding{
            .top = value,
            .bottom = value,
        };
    }

    pub fn only(comptime direction: enum { top, bottom, left, right }, value: i32) Padding {
        return switch (direction) {
            .top => Padding{ .top = value },
            .bottom => Padding{ .bottom = value },
            .left => Padding{ .left = value },
            .right => Padding{ .right = value },
        };
    }
};

const NodeType = union(enum) {
    container: struct {
        direction: enum { vertical, horizontal },
        border: ?Border = null,
        child_gap: i32,
        child_alignment: Alignment = .{},
        children: std.ArrayList(Node),
    },

    text: struct {
        content: []const u8,
        font_color: Color,
        font_size: i32,
    },

    button: struct {
        id: []const u8,
        label: []const u8,
        font_color: Color,
        font_size: i32,
        border: ?Border = null,
    },

    checkbox: struct {
        id: []const u8,
        label: []const u8,
        checked: bool,
        font_color: Color,
        font_size: i32,
    },
};
