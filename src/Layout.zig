const std = @import("std");

const Node = @import("Node.zig");
const root = @import("root.zig");
const MeasureTextFn = root.MeasureTextFn;

const Layout = @This();

measure_text_fn: MeasureTextFn,

pub fn compute(root_node: *Node, x: i32, y: i32, available_width: i32, available_height: i32, measure_text_fn: MeasureTextFn) void {
    const self = Layout{ .measure_text_fn = measure_text_fn };
    self.layoutNode(root_node, x, y, available_width, available_height);
}

pub fn layoutNode(self: *const Layout, node: *Node, x: i32, y: i32, available_width: i32, available_height: i32) void {
    node.x = x;
    node.y = y;

    switch (node.type) {
        .container => self.layoutContainer(node, available_width, available_height),
        else => {},
    }
}

fn layoutContainer(self: *const Layout, node: *Node, available_width: i32, available_height: i32) void {
    const container = &node.type.container;

    const content_width = available_width - node.padding.left - node.padding.right;
    const content_height = available_height - node.padding.top - node.padding.bottom;

    if (container.direction == .vertical) {
        self.layoutVertical(node, content_width, content_height);
    } else {
        self.layoutHorizontal(node, content_width, content_height);
    }

    node.actual_width = switch (node.sizing.width) {
        .fit => calculateFitWidth(node),
        .grow => available_width,
        .fixed => |w| w,
    };

    node.actual_height = switch (node.sizing.height) {
        .fit => calculateFitHeight(node),
        .grow => available_height,
        .fixed => |h| h,
    };
}

fn layoutVertical(self: *const Layout, node: *Node, content_width: i32, content_height: i32) void {
    const container = &node.type.container;
    const children = container.children.items;

    var used_height: i32 = 0;
    var total_grow: f32 = 0;
    const gap_total = container.child_gap * @as(i32, @intCast(children.len - 1));

    for (children) |*child| {
        switch (child.sizing.height) {
            .fixed => |h| {
                child.actual_height = h;
                used_height += h;
            },
            .fit => {
                child.actual_height = self.measureChildHeight(child);
                used_height += child.actual_height;
            },
            .grow => |weight| {
                total_grow += weight;
            },
        }

        child.actual_width = switch (child.sizing.width) {
            .fixed => |w| w,
            .fit => self.measureChildWidth(child),
            .grow => content_width,
        };
    }

    const remaining_height = content_height - used_height - gap_total;

    if (total_grow > 0 and remaining_height > 0) {
        for (children) |*child| {
            if (child.sizing.height == .grow) {
                const weight = child.sizing.height.grow;
                child.actual_height = @intFromFloat(@as(f32, @floatFromInt(remaining_height)) * (weight / total_grow));
            }
        }
    }

    var total_children_height: i32 = 0;
    for (children) |*child| {
        total_children_height += child.actual_height;
    }
    total_children_height += gap_total;

    var current_y = node.y + node.padding.top;

    if (container.child_alignment.y == .center) {
        if (content_height > total_children_height) {
            current_y += @divTrunc(content_height - total_children_height, 2);
        }
    } else if (container.child_alignment.y == .end) {
        if (content_height > total_children_height) {
            current_y = node.y + node.actual_height - total_children_height - node.padding.bottom;
        }
    }

    for (children) |*child| {
        const align_x = if (child.self_alignment) |self_align| self_align.x else container.child_alignment.x;

        child.x = switch (align_x) {
            .start => node.x + node.padding.left,
            .center => node.x + node.padding.left + @divTrunc(content_width - child.actual_width, 2),
            .end => node.x + content_width + node.padding.left - child.actual_width,
        };

        child.y = current_y;

        self.layoutNode(child, child.x, child.y, child.actual_width, child.actual_height);

        current_y += child.actual_height + container.child_gap;
    }
}

fn layoutHorizontal(self: *const Layout, node: *Node, content_width: i32, content_height: i32) void {
    const container = &node.type.container;
    const children = container.children.items;

    var used_width: i32 = 0;
    var total_grow: f32 = 0;
    const gap_total = container.child_gap * @as(i32, @intCast(children.len - 1));

    for (children) |*child| {
        switch (child.sizing.width) {
            .fixed => |w| {
                child.actual_width = w;
                used_width += w;
            },
            .fit => {
                child.actual_width = self.measureChildWidth(child);
                used_width += child.actual_width;
            },
            .grow => |weight| {
                total_grow += weight;
            },
        }

        child.actual_height = switch (child.sizing.height) {
            .fixed => |h| h,
            .fit => self.measureChildHeight(child),
            .grow => content_height,
        };
    }

    const remaining_width = content_width - used_width - gap_total;

    if (total_grow > 0 and remaining_width > 0) {
        for (children) |*child| {
            if (child.sizing.width == .grow) {
                const weight = child.sizing.width.grow;
                child.actual_width = @intFromFloat(@as(f32, @floatFromInt(remaining_width)) * (weight / total_grow));
            }
        }
    }

    var total_children_width: i32 = 0;
    for (children) |*child| {
        total_children_width += child.actual_width;
    }
    total_children_width += gap_total;

    var current_x = node.x + node.padding.left;

    if (container.child_alignment.x == .center) {
        if (content_width > total_children_width) {
            current_x += @divTrunc(content_width - total_children_width, 2);
        }
    } else if (container.child_alignment.x == .end) {
        if (content_width > total_children_width) {
            current_x = node.x + node.actual_width - total_children_width - node.padding.right;
        }
    }

    for (children) |*child| {
        const align_y = if (child.self_alignment) |self_align| self_align.y else container.child_alignment.y;

        child.y = switch (align_y) {
            .start => node.y + node.padding.top,
            .center => node.y + node.padding.top + @divTrunc(content_height - child.actual_height, 2),
            .end => node.y + content_height + node.padding.top - child.actual_height,
        };

        child.x = current_x;

        self.layoutNode(child, child.x, child.y, child.actual_width, child.actual_height);

        current_x += child.actual_width + container.child_gap;
    }
}

fn measureChildWidth(self: *const Layout, child: *Node) i32 {
    return switch (child.type) {
        .text => |t| self.measure_text_fn(t.content, t.font_size).width,
        .button => |b| {
            const text_width = self.measure_text_fn(b.label, b.font_size).width;
            return text_width + child.padding.left + child.padding.right;
        },
        .checkbox => |c| {
            const text_width = self.measure_text_fn(c.label, c.font_size).width;
            const box_size = c.font_size;
            const gap = 8;
            return box_size + gap + text_width;
        },
        .container => 100,
    };
}

fn measureChildHeight(self: *const Layout, child: *Node) i32 {
    return switch (child.type) {
        .text => |t| self.measure_text_fn(t.content, t.font_size).height,
        .button => |b| {
            const text_height = self.measure_text_fn(b.label, b.font_size).height;
            return text_height + child.padding.top + child.padding.bottom;
        },
        .checkbox => |c| {
            const text_height = self.measure_text_fn(c.label, c.font_size).height;
            const box_size = c.font_size;
            return @max(box_size, text_height);
        },
        .container => 100,
    };
}

fn calculateFitWidth(node: *Node) i32 {
    if (node.type != .container) return 0;

    const container = &node.type.container;

    if (container.direction == .vertical) {
        var max_width: i32 = 0;
        for (container.children.items) |*child| {
            if (child.actual_width > max_width) {
                max_width = child.actual_width;
            }
        }
        return max_width + node.padding.left + node.padding.right;
    } else {
        var total_width: i32 = 0;
        for (container.children.items) |*child| {
            total_width += child.actual_width;
        }
        const gap_total = container.child_gap * @as(i32, @intCast(container.children.items.len -| 1));
        return total_width + gap_total + node.padding.left + node.padding.right;
    }
}

fn calculateFitHeight(node: *Node) i32 {
    if (node.type != .container) return 0;

    const container = &node.type.container;

    if (container.direction == .vertical) {
        var total_height: i32 = 0;
        for (container.children.items) |*child| {
            total_height += child.actual_height;
        }
        const gap_total = container.child_gap * @as(i32, @intCast(container.children.items.len -| 1));
        return total_height + gap_total + node.padding.top + node.padding.bottom;
    } else {
        var max_height: i32 = 0;
        for (container.children.items) |*child| {
            if (child.actual_height > max_height) {
                max_height = child.actual_height;
            }
        }
        return max_height + node.padding.top + node.padding.bottom;
    }
}
