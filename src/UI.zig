const std = @import("std");

const Layout = @import("Layout.zig");
const Node = @import("Node.zig");
const render = @import("render.zig");
pub const RenderCommand = render.RenderCommand;

const UI = @This();

allocator: std.mem.Allocator,
measure_text_fn: MeasureTextFn,

root: ?Node = null,
stack: std.ArrayList(*Node),
mouse_input: MouseInput = .{ .x = 0, .y = 0 },
keyboard_input: KeyboardInput = .{},
focused_id: ?[]const u8 = null,

prev_interactables: std.StringHashMap(InteractableRect),
curr_interactables: std.StringHashMap(InteractableRect),

pub fn init(allocator: std.mem.Allocator, measure_text_fn: MeasureTextFn) UI {
    return .{
        .allocator = allocator,
        .measure_text_fn = measure_text_fn,
        .stack = std.ArrayList(*Node).empty,
        .prev_interactables = std.StringHashMap(InteractableRect).init(allocator),
        .curr_interactables = std.StringHashMap(InteractableRect).init(allocator),
    };
}

pub fn deinit(self: *UI) void {
    if (self.root) |*root_node| {
        root_node.deinit(self.allocator);
    }
    self.stack.deinit(self.allocator);
    self.prev_interactables.deinit();
    self.curr_interactables.deinit();
}

pub fn setMouseInput(self: *UI, mouse_input: MouseInput) void {
    self.mouse_input = mouse_input;

    const temp = self.prev_interactables;
    self.prev_interactables = self.curr_interactables;
    self.curr_interactables = temp;
    self.curr_interactables.clearRetainingCapacity();
}

pub fn setKeyboardInput(self: *UI, keyboard_input: KeyboardInput) void {
    self.keyboard_input = keyboard_input;

    if (keyboard_input.escape) {
        self.focused_id = null;
    }
}

pub fn beginLayout(self: *UI, opts: struct {
    direction: Node.Direction,
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
                .direction = opts.direction,
                .border = opts.border,
                .child_gap = opts.child_gap,
                .child_alignment = opts.child_alignment,
                .children = std.ArrayList(Node).empty,
            },
        },
    };

    try self.addNode(node);
}

pub fn endLayout(self: *UI) void {
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

pub fn button(self: *UI, id: []const u8, label: []const u8, opts: struct {
    sizing: Node.Sizing = .{},
    self_alignment: ?Node.Alignment = null,
    bg_color: Node.Color = .{ .r = 150, .g = 150, .b = 150, .a = 255 },
    border: ?Node.Border = null,
    corner_radius: i32 = 0,
    padding: Node.Padding = .all(10),
    font_color: Node.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    font_size: i32 = 16,
}) !bool {
    const node = Node{
        .sizing = opts.sizing,
        .self_alignment = opts.self_alignment,
        .bg_color = opts.bg_color,
        .corner_radius = opts.corner_radius,
        .padding = opts.padding,
        .type = .{
            .button = .{
                .id = id,
                .label = label,
                .font_color = opts.font_color,
                .font_size = opts.font_size,
                .border = opts.border,
            },
        },
    };

    _ = try self.addNodeAndGetPointer(node);

    if (self.prev_interactables.get(id)) |rect| {
        if (self.mouse_input.left_pressed) {
            const in_bounds = self.mouse_input.x >= rect.x and
                self.mouse_input.x < rect.x + rect.w and
                self.mouse_input.y >= rect.y and
                self.mouse_input.y < rect.y + rect.h;
            return in_bounds;
        }
    }
    return false;
}

pub fn inputText(self: *UI, id: []const u8, buffer: []u8, len: *usize, opts: struct {
    sizing: Node.Sizing = .{ .width = .{ .fixed = 150 }, .height = .fit },
    self_alignment: ?Node.Alignment = null,
    bg_color: ?Node.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    border: ?Node.Border = .{ .width = 1, .color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } },
    corner_radius: i32 = 0,
    padding: Node.Padding = .{ .top = 5, .bottom = 5, .left = 8, .right = 8 },
    font_color: Node.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
    placeholder_color: Node.Color = .{ .r = 150, .g = 150, .b = 150, .a = 255 },
    placeholder: []const u8 = "",
    font_size: i32 = 16,
}) !bool {
    const is_focused = if (self.focused_id) |fid| std.mem.eql(u8, fid, id) else false;

    const node = Node{
        .sizing = opts.sizing,
        .self_alignment = opts.self_alignment,
        .bg_color = opts.bg_color,
        .corner_radius = opts.corner_radius,
        .padding = opts.padding,
        .type = .{
            .input_text = .{
                .id = id,
                .content = buffer[0..len.*],
                .placeholder = opts.placeholder,
                .focused = is_focused,
                .font_color = opts.font_color,
                .placeholder_color = opts.placeholder_color,
                .font_size = opts.font_size,
                .border = opts.border,
            },
        },
    };

    _ = try self.addNodeAndGetPointer(node);

    var changed = false;

    // Handle click to focus
    if (self.prev_interactables.get(id)) |rect| {
        if (self.mouse_input.left_pressed) {
            const in_bounds = self.mouse_input.x >= rect.x and
                self.mouse_input.x < rect.x + rect.w and
                self.mouse_input.y >= rect.y and
                self.mouse_input.y < rect.y + rect.h;
            if (in_bounds) {
                self.focused_id = id;
            } else if (is_focused) {
                self.focused_id = null;
            }
        }
    }

    // Handle keyboard input if focused
    if (is_focused) {
        // Handle character input
        for (self.keyboard_input.chars) |char| {
            if (len.* < buffer.len) {
                buffer[len.*] = char;
                len.* += 1;
                changed = true;
            }
        }

        // Handle backspace
        if (self.keyboard_input.backspace and len.* > 0) {
            len.* -= 1;
            changed = true;
        }

        // Handle enter - unfocus
        if (self.keyboard_input.enter) {
            self.focused_id = null;
        }
    }

    return changed;
}

pub fn slider(self: *UI, id: []const u8, value: *f32, opts: struct {
    sizing: Node.Sizing = .{ .width = .{ .fixed = 100 }, .height = .{ .fixed = 20 } },
    self_alignment: ?Node.Alignment = null,
    track_color: Node.Color = .{ .r = 80, .g = 80, .b = 80, .a = 255 },
    handle_color: Node.Color = .{ .r = 200, .g = 200, .b = 200, .a = 255 },
    handle_width: i32 = 16,
    corner_radius: i32 = 0,
}) !bool {
    const node = Node{
        .sizing = opts.sizing,
        .self_alignment = opts.self_alignment,
        .corner_radius = opts.corner_radius,
        .type = .{
            .slider = .{
                .id = id,
                .value = value.*,
                .track_color = opts.track_color,
                .handle_color = opts.handle_color,
                .handle_width = opts.handle_width,
            },
        },
    };

    _ = try self.addNodeAndGetPointer(node);

    // Check interaction using previous frame's position
    if (self.prev_interactables.get(id)) |rect| {
        if (self.mouse_input.left_down) {
            const in_bounds = self.mouse_input.x >= rect.x and
                self.mouse_input.x < rect.x + rect.w and
                self.mouse_input.y >= rect.y and
                self.mouse_input.y < rect.y + rect.h;
            if (in_bounds) {
                const track_width = rect.w - opts.handle_width;
                const relative_x = self.mouse_input.x - rect.x - @divTrunc(opts.handle_width, 2);
                const new_value = @as(f32, @floatFromInt(relative_x)) / @as(f32, @floatFromInt(track_width));
                value.* = std.math.clamp(new_value, 0.0, 1.0);
                return true;
            }
        }
    }
    return false;
}

pub fn progressBar(self: *UI, progress: f32, opts: struct {
    sizing: Node.Sizing = .{ .width = .{ .fixed = 100 }, .height = .{ .fixed = 20 } },
    self_alignment: ?Node.Alignment = null,
    bg_color: ?Node.Color = .{ .r = 50, .g = 50, .b = 50, .a = 255 },
    fill_color: Node.Color = .{ .r = 100, .g = 200, .b = 100, .a = 255 },
    border: ?Node.Border = null,
    corner_radius: i32 = 0,
}) !void {
    const node = Node{
        .sizing = opts.sizing,
        .self_alignment = opts.self_alignment,
        .bg_color = opts.bg_color,
        .corner_radius = opts.corner_radius,
        .type = .{
            .progress_bar = .{
                .progress = progress,
                .fill_color = opts.fill_color,
            },
        },
    };

    _ = try self.addNodeAndGetPointer(node);
}

pub fn checkbox(self: *UI, id: []const u8, label: []const u8, checked: *bool, opts: struct {
    self_alignment: ?Node.Alignment = null,
    font_color: Node.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 },
    font_size: i32 = 16,
}) !bool {
    const node = Node{
        .sizing = .{},
        .self_alignment = opts.self_alignment,
        .type = .{
            .checkbox = .{
                .id = id,
                .label = label,
                .checked = checked.*,
                .font_color = opts.font_color,
                .font_size = opts.font_size,
            },
        },
    };

    _ = try self.addNodeAndGetPointer(node);

    if (self.prev_interactables.get(id)) |rect| {
        if (self.mouse_input.left_pressed) {
            const in_bounds = self.mouse_input.x >= rect.x and
                self.mouse_input.x < rect.x + rect.w and
                self.mouse_input.y >= rect.y and
                self.mouse_input.y < rect.y + rect.h;
            if (in_bounds) {
                checked.* = !checked.*;
                return true;
            }
        }
    }
    return false;
}

pub fn computeLayout(self: *UI, window_width: i32, window_height: i32) !void {
    if (self.root) |*root_node| {
        Layout.compute(root_node, 0, 0, window_width, window_height, self.measure_text_fn);
        try self.storeInteractablePositions(root_node);
    }
}

pub fn getRenderCommands(self: *UI) ![]RenderCommand {
    if (self.root) |*root_node| {
        return render.collectRenderCommands(root_node, self.allocator);
    }
    return &[_]RenderCommand{};
}

fn addNode(self: *UI, node: Node) !void {
    _ = try self.addNodeAndGetPointer(node);
}

fn addNodeAndGetPointer(self: *UI, node: Node) !*Node {
    if (self.stack.items.len > 0) {
        const parent = self.stack.items[self.stack.items.len - 1];
        try parent.type.container.children.append(self.allocator, node);
        const added = &parent.type.container.children.items[parent.type.container.children.items.len - 1];

        if (node.type == .container) {
            try self.stack.append(self.allocator, added);
        }
        return added;
    } else {
        self.root = node;
        if (node.type == .container) {
            try self.stack.append(self.allocator, &self.root.?);
        }
        return &self.root.?;
    }
}

fn storeInteractablePositions(self: *UI, node: *Node) !void {
    switch (node.type) {
        .button => |b| {
            try self.curr_interactables.put(b.id, .{
                .x = node.x,
                .y = node.y,
                .w = node.actual_width,
                .h = node.actual_height,
            });
        },
        .checkbox => |c| {
            try self.curr_interactables.put(c.id, .{
                .x = node.x,
                .y = node.y,
                .w = node.actual_width,
                .h = node.actual_height,
            });
        },
        .slider => |s| {
            try self.curr_interactables.put(s.id, .{
                .x = node.x,
                .y = node.y,
                .w = node.actual_width,
                .h = node.actual_height,
            });
        },
        .input_text => |t| {
            try self.curr_interactables.put(t.id, .{
                .x = node.x,
                .y = node.y,
                .w = node.actual_width,
                .h = node.actual_height,
            });
        },
        .container => |cont| {
            for (cont.children.items) |*child| {
                try self.storeInteractablePositions(child);
            }
        },
        else => {},
    }
}

pub const TextMeasurement = struct {
    width: i32,
    height: i32,
};

pub const MeasureTextFn = *const fn (text: []const u8, font_size: i32) TextMeasurement;

pub const MouseInput = struct {
    x: i32,
    y: i32,
    left_pressed: bool = false,
    left_down: bool = false,
    left_released: bool = false,
};

pub const KeyboardInput = struct {
    chars: []const u8 = "",
    backspace: bool = false,
    enter: bool = false,
    escape: bool = false,
};

const InteractableRect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};
