const std = @import("std");

const Layout = @import("Layout.zig");
const Node = @import("Node.zig");
const render = @import("render.zig");
pub const RenderCommand = render.RenderCommand;

/// Result of measuring text dimensions
pub const TextMeasurement = struct {
    width: i32,
    height: i32,
};

/// Function signature for text measurement callback.
/// The user must provide an implementation based on their renderer (Raylib, SDL, etc.)
pub const MeasureTextFn = *const fn (text: []const u8, font_size: i32) TextMeasurement;

pub const UI = struct {
    allocator: std.mem.Allocator,
    measure_text_fn: MeasureTextFn,

    root: ?Node = null,
    stack: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator, measure_text_fn: MeasureTextFn) UI {
        return .{
            .allocator = allocator,
            .measure_text_fn = measure_text_fn,
            .stack = std.ArrayList(*Node).empty,
        };
    }

    pub fn deinit(self: *UI) void {
        if (self.root) |*root_node| {
            root_node.deinit(self.allocator);
        }
        self.stack.deinit(self.allocator);
    }

    pub fn beginVBox(self: *UI, opts: struct {
        sizing: Node.Sizing = .{},
        border: ?Node.Border = null,
        corner_radius: i32 = 0,
        self_alignment: ?Node.Alignment = null,
        child_alignment: Node.Alignment = .{},
        child_gap: i32 = 0,
        padding: Node.Padding = .all(0),
        bg_color: ?Node.Color = null,
    }) !void {
        const node = Node{
            .sizing = opts.sizing,
            .self_alignment = opts.self_alignment,
            .padding = opts.padding,
            .bg_color = opts.bg_color,
            .corner_radius = opts.corner_radius,
            .type = .{
                .container = .{
                    .direction = .vertical,
                    .border = opts.border,
                    .child_gap = opts.child_gap,
                    .child_alignment = opts.child_alignment,
                    .children = std.ArrayList(Node).empty,
                },
            },
        };

        try self.addNode(node);
    }

    pub fn beginHBox(self: *UI, opts: struct {
        sizing: Node.Sizing = .{},
        border: ?Node.Border = null,
        corner_radius: i32 = 0,
        self_alignment: ?Node.Alignment = null,
        child_alignment: Node.Alignment = .{},
        child_gap: i32 = 0,
        padding: Node.Padding = .all(0),
        bg_color: ?Node.Color = null,
    }) !void {
        const node = Node{
            .sizing = opts.sizing,
            .self_alignment = opts.self_alignment,
            .padding = opts.padding,
            .bg_color = opts.bg_color,
            .corner_radius = opts.corner_radius,
            .type = .{
                .container = .{
                    .direction = .horizontal,
                    .border = opts.border,
                    .child_gap = opts.child_gap,
                    .child_alignment = opts.child_alignment,
                    .children = std.ArrayList(Node).empty,
                },
            },
        };
        try self.addNode(node);
    }

    pub fn endVBox(self: *UI) void {
        _ = self.stack.pop();
    }

    pub fn endHBox(self: *UI) void {
        _ = self.stack.pop();
    }

    pub fn text(self: *UI, content: []const u8, opts: struct {
        self_alignment: ?Node.Alignment = null,
        font_color: Node.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
        font_size: i32 = 16,
    }) !void {
        const node = Node{
            .sizing = .{},
            .self_alignment = opts.self_alignment,
            .type = .{
                .text = .{
                    .content = content,
                    .font_color = opts.font_color,
                    .font_size = opts.font_size,
                },
            },
        };

        try self.addNode(node);
    }

    pub fn button(self: *UI, label: []const u8, opts: struct {
        sizing: Node.Sizing = .{},
        self_alignment: ?Node.Alignment = null,
        bg_normal: Node.Color = .{ .r = 150, .g = 150, .b = 150, .a = 255 },
        font_color: Node.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
        font_size: i32 = 16,
    }) !void {
        const node = Node{
            .sizing = opts.sizing,
            .self_alignment = opts.self_alignment,
            .bg_color = opts.bg_normal,
            .padding = .all(10),
            .type = .{
                .button = .{
                    .label = label,
                    .font_color = opts.font_color,
                    .font_size = opts.font_size,
                },
            },
        };

        try self.addNode(node);
    }

    fn addNode(self: *UI, node: Node) !void {
        if (self.stack.items.len > 0) {
            const parent = self.stack.items[self.stack.items.len - 1];
            try parent.type.container.children.append(self.allocator, node);

            if (node.type == .container) {
                const added = &parent.type.container.children.items[parent.type.container.children.items.len - 1];
                try self.stack.append(self.allocator, added);
            }
        } else {
            self.root = node;
            if (node.type == .container) {
                try self.stack.append(self.allocator, &self.root.?);
            }
        }
    }

    pub fn computeLayout(self: *UI, window_width: i32, window_height: i32) void {
        if (self.root) |*root| {
            Layout.compute(root, 0, 0, window_width, window_height, self.measure_text_fn);
        }
    }

    pub fn getRenderCommands(self: *UI) ![]RenderCommand {
        if (self.root) |*root| {
            return render.collectRenderCommands(root, self.allocator);
        }
        return &[_]RenderCommand{};
    }

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        try writer.writeAll("UI {\n");
        if (self.root) |root| {
            try formatNodeAtDepth(root, writer, 1);
        } else {
            try writer.writeAll("  (no root)\n");
        }
        try writer.writeAll("}\n");
    }

    fn formatNodeAtDepth(node: Node, writer: *std.io.Writer, depth: usize) std.io.Writer.Error!void {
        // Write indent
        var i: usize = 0;
        while (i < depth) : (i += 1) {
            try writer.writeAll("  ");
        }

        switch (node.type) {
            .container => |c| {
                try writer.print("Container({s}, spacing={}) [{}x{} at ({},{})]", .{
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
                        try formatNodeAtDepth(child, writer, depth + 1);
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
};
