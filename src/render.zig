const std = @import("std");

const Node = @import("Node.zig");

pub const RenderCommand = union(enum) {
    rect: struct { x: i32, y: i32, w: i32, h: i32, corner_radius: i32, color: Node.Color },
    rect_lines: struct { x: i32, y: i32, w: i32, h: i32, thickness: i32, corner_radius: i32, color: Node.Color },
    text: struct { x: i32, y: i32, content: []const u8, size: i32, color: Node.Color },
    line: struct { x1: i32, y1: i32, x2: i32, y2: i32, thickness: i32, color: Node.Color },
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
                .corner_radius = node.corner_radius,
                .color = bg,
            },
        });
    }

    // Draw node-specific content
    switch (node.type) {
        .container => |c| {
            if (c.border) |border| {
                try commands.append(allocator, .{
                    .rect_lines = .{
                        .x = node.x,
                        .y = node.y,
                        .w = node.actual_width,
                        .h = node.actual_height,
                        .thickness = border.width,
                        .corner_radius = node.corner_radius,
                        .color = border.color,
                    },
                });
            }

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
        .checkbox => |c| {
            const box_size = c.font_size;
            const gap = 8;

            // Draw checkbox box outline
            try commands.append(allocator, .{
                .rect_lines = .{
                    .x = node.x,
                    .y = node.y,
                    .w = box_size,
                    .h = box_size,
                    .thickness = 2,
                    .corner_radius = 2,
                    .color = c.font_color,
                },
            });

            // Draw checkmark if checked
            if (c.checked) {
                // Draw two lines forming a checkmark
                const padding = 3;
                const x1 = node.x + padding;
                const y1 = node.y + @divTrunc(box_size, 2);
                const x2 = node.x + @divTrunc(box_size, 3);
                const y2 = node.y + box_size - padding;
                const x3 = node.x + box_size - padding;
                const y3 = node.y + padding;

                try commands.append(allocator, .{
                    .line = .{ .x1 = x1, .y1 = y1, .x2 = x2, .y2 = y2, .thickness = 2, .color = c.font_color },
                });
                try commands.append(allocator, .{
                    .line = .{ .x1 = x2, .y1 = y2, .x2 = x3, .y2 = y3, .thickness = 2, .color = c.font_color },
                });
            }

            // Draw label
            try commands.append(allocator, .{
                .text = .{
                    .x = node.x + box_size + gap,
                    .y = node.y,
                    .content = c.label,
                    .size = c.font_size,
                    .color = c.font_color,
                },
            });
        },
    }
}
