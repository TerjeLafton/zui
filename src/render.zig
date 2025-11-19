const std = @import("std");

const Node = @import("Node.zig");

pub const RenderCommand = union(enum) {
    rect: struct {
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        color: Node.Color,
    },
    text: struct {
        x: i32,
        y: i32,
        content: []const u8,
        size: i32,
        color: Node.Color,
    },
};

pub fn collectRenderCommands(node: *const Node, allocator: std.mem.Allocator) ![]RenderCommand {
    var commands = std.ArrayList(RenderCommand).empty;

    try collectFromNode(node, &commands, allocator);

    return commands.toOwnedSlice(allocator);
}

fn collectFromNode(node: *const Node, commands: *std.ArrayList(RenderCommand), allocator: std.mem.Allocator) !void {
    // Draw background if present
    if (node.bg_color) |bg| {
        try commands.append(allocator, .{
            .rect = .{
                .x = node.x,
                .y = node.y,
                .w = node.actual_width,
                .h = node.actual_height,
                .color = bg,
            },
        });
    }

    // Draw node-specific content
    switch (node.type) {
        .container => |c| {
            // Recursively draw children
            for (c.children.items) |*child| {
                try collectFromNode(child, commands, allocator);
            }
        },
        .text => |t| {
            try commands.append(allocator, .{
                .text = .{
                    .x = node.x,
                    .y = node.y,
                    .content = t.content,
                    .size = t.font_size,
                    .color = t.font_color,
                },
            });
        },
        .button => |b| {
            try commands.append(allocator, .{
                .text = .{
                    .x = node.x + node.padding.left,
                    .y = node.y + node.padding.top,
                    .content = b.label,
                    .size = b.font_size,
                    .color = b.font_color,
                },
            });
        },
    }
}
