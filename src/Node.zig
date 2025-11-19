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

pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
    try formatNode(self, writer, 0);
}

fn formatNode(node: Node, writer: *std.io.Writer, depth: usize) std.io.Writer.Error!void {
    // Write indent
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        try writer.writeAll("  ");
    }

    switch (node.type) {
        .container => |c| {
            try writer.print("Container({s}, gap={}) [{}x{} at ({},{})]", .{
                @tagName(c.direction),
                c.child_gap,
                node.actual_width,
                node.actual_height,
                node.x,
                node.y,
            });

            if (c.children.items.len > 0) {
                try writer.writeAll(":\n");
                for (c.children.items) |child| {
                    try formatNode(child, writer, depth + 1);
                }
            } else {
                try writer.writeAll(" (empty)\n");
            }
        },
        .text => |t| {
            try writer.print("Text(\"{s}\") [{}x{} at ({},{})]\n", .{
                t.content,
                node.actual_width,
                node.actual_height,
                node.x,
                node.y,
            });
        },
        .button => |b| {
            try writer.print("Button(\"{s}\") [{}x{} at ({},{})]\n", .{
                b.label,
                node.actual_width,
                node.actual_height,
                node.x,
                node.y,
            });
        },
    }
}

const NodeType = union(enum) {
    container: struct {
        direction: enum { vertical, horizontal },
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
        label: []const u8,
        font_color: Color,
        font_size: i32,
    },
};

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
