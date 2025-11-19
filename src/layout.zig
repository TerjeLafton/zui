const std = @import("std");

const Node = @import("Node.zig");

/// Entry point for laying out a node and its children.
/// This is a recursive function that computes the final position (x, y) and size
/// (actual_width, actual_height) for each node in the UI tree.
///
/// Parameters:
///   - node: The node to layout
///   - x, y: The absolute screen position where this node should be placed
///   - available_width, available_height: The maximum space this node can occupy
///
/// The layout algorithm works in two main phases:
/// 1. Measurement: Determine the actual size each node needs/wants
/// 2. Positioning: Place each node at its final position based on alignment
pub fn layoutNode(node: *Node, x: i32, y: i32, available_width: i32, available_height: i32) void {
    // Set the node's position - this is where the node's top-left corner will be
    node.x = x;
    node.y = y;

    // Only containers need special layout logic; leaf nodes (text, buttons)
    // just need their size set based on their content
    switch (node.type) {
        .container => layoutContainer(node, available_width, available_height),
        else => {},
    }
}

/// Handles layout for container nodes specifically.
/// Containers need to:
/// 1. Calculate their content area (subtracting padding from available space)
/// 2. Layout their children (using direction-specific logic)
/// 3. Calculate their own final size based on their sizing mode
fn layoutContainer(node: *Node, available_width: i32, available_height: i32) void {
    const container = &node.type.container;

    // Calculate the content area - this is the space available for children
    // after subtracting the container's padding
    const content_width = available_width - node.padding.left - node.padding.right;
    const content_height = available_height - node.padding.top - node.padding.bottom;

    // Layout children based on the container's direction
    if (container.direction == .vertical) {
        layoutVertical(node, content_width, content_height);
    } else {
        layoutHorizontal(node, content_width, content_height);
    }

    // Now that children are sized and positioned, calculate this container's final size
    // based on its sizing mode:
    // - .fit: Size to exactly fit the children (plus padding)
    // - .grow: Take all available space
    // - .fixed: Use the specified fixed size
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

/// Layouts children in a vertical stack (top to bottom).
/// This implements a flexbox-like algorithm with three phases:
///
/// Phase 1 - Measurement:
///   - Measure all fixed and fit-sized children
///   - Count up how much height they need
///   - Track the total "grow weight" from children with .grow sizing
///
/// Phase 2 - Growth distribution:
///   - Calculate remaining space after fixed/fit children
///   - Distribute this space among .grow children proportionally by weight
///
/// Phase 3 - Positioning:
///   - Apply main-axis (Y) alignment to the group of children
///   - Apply cross-axis (X) alignment to each individual child
///   - Recursively layout each child
fn layoutVertical(node: *Node, content_width: i32, content_height: i32) void {
    const container = &node.type.container;
    const children = container.children.items;

    // ========== PHASE 1: MEASUREMENT ==========

    // Track how much height is used by fixed and fit-sized children
    var used_height: i32 = 0;

    // Track the sum of all grow weights from children that want to grow
    var total_grow: f32 = 0;

    // Calculate total height taken up by gaps between children
    // If there are N children, there are N-1 gaps between them
    const gap_total = container.child_gap * @as(i32, @intCast(children.len - 1));

    // First pass: measure all children and calculate their heights
    for (children) |*child| {
        switch (child.sizing.height) {
            // Fixed height: child explicitly specifies its height
            .fixed => |h| {
                child.actual_height = h;
                used_height += h;
            },
            // Fit height: child wants to be sized based on its content
            .fit => {
                child.actual_height = measureChildHeight(child);
                used_height += child.actual_height;
            },
            // Grow height: child wants to take up remaining space
            // We don't set actual_height yet - we need to know total remaining space first
            .grow => |weight| {
                total_grow += weight;
            },
        }

        // Also calculate widths now (simpler since cross-axis doesn't affect main-axis)
        child.actual_width = switch (child.sizing.width) {
            .fixed => |w| w,
            .fit => measureChildWidth(child),
            // For vertical containers, a child with grow width takes the full content width
            .grow => content_width,
        };
    }

    // ========== PHASE 2: GROWTH DISTRIBUTION ==========

    // Calculate how much space is left after fixed/fit children and gaps
    const remaining_height = content_height - used_height - gap_total;

    // If there are children that want to grow AND there's space available,
    // distribute the remaining space proportionally by weight
    if (total_grow > 0 and remaining_height > 0) {
        for (children) |*child| {
            if (child.sizing.height == .grow) {
                const weight = child.sizing.height.grow;
                // Give this child its proportional share of remaining space
                // Formula: remaining_space * (child_weight / total_weight)
                child.actual_height = @intFromFloat(@as(f32, @floatFromInt(remaining_height)) * (weight / total_grow));
            }
        }
    }

    // ========== PHASE 3: POSITIONING ==========

    // Calculate the total height of all children (now including grow children)
    var total_children_height: i32 = 0;
    for (children) |*child| {
        total_children_height += child.actual_height;
    }
    total_children_height += gap_total;

    // Start positioning children from the top of the content area
    // This is the main-axis (Y) starting position
    var current_y = node.y + node.padding.top;

    // Apply main-axis (Y) alignment by adjusting the starting Y position
    // This moves the entire group of children together as a unit
    if (container.child_alignment.y == .center) {
        // If there's extra space, center the children by adding half the extra space to the top
        if (content_height > total_children_height) {
            current_y += @divTrunc(content_height - total_children_height, 2);
        }
    } else if (container.child_alignment.y == .end) {
        // If there's extra space, push children to the bottom
        if (content_height > total_children_height) {
            current_y = node.y + node.actual_height - total_children_height - node.padding.bottom;
        }
    }
    // Note: .start alignment is the default - children start at node.y + padding.top

    // Position each child and recursively layout it
    for (children) |*child| {
        // Cross-axis (X) alignment - determines where child sits horizontally
        // Check if child has self_alignment - if so, it overrides the parent's child_alignment
        const align_x = if (child.self_alignment) |self| self.x else container.child_alignment.x;

        child.x = switch (align_x) {
            // .start: align to the left edge of content area
            .start => node.x + node.padding.left,
            // .center: center the child horizontally within content area
            .center => node.x + node.padding.left + @divTrunc(content_width - child.actual_width, 2),
            // .end: align to the right edge of content area
            .end => node.x + content_width + node.padding.left - child.actual_width,
        };

        // Set the child's Y position (this advances down the vertical stack)
        child.y = current_y;

        // Recursively layout this child (and its descendants if it's a container)
        layoutNode(child, child.x, child.y, child.actual_width, child.actual_height);

        // Move down by this child's height plus the gap for the next child
        current_y += child.actual_height + container.child_gap;
    }
}

/// Measures the intrinsic width of a node based on its content.
/// This is used when a node's width sizing mode is .fit
///
/// Returns a rough estimate for each node type:
/// - Text: approximately 10 pixels per character
/// - Button: text width plus padding
/// - Container: arbitrary placeholder (100px)
fn measureChildWidth(child: *Node) i32 {
    return switch (child.type) {
        .text => |t| @as(i32, @intCast(t.content.len)) * 10,
        .button => |b| {
            const text_width = @as(i32, @intCast(b.label.len)) * 10;
            return text_width + child.padding.left + child.padding.right;
        },
        .container => 100,
    };
}

/// Measures the intrinsic height of a node based on its content.
/// This is used when a node's height sizing mode is .fit
///
/// Returns:
/// - Text: font size plus small margin (4px)
/// - Button: text height plus padding
/// - Container: arbitrary placeholder (100px)
fn measureChildHeight(child: *Node) i32 {
    return switch (child.type) {
        .text => |t| t.font_size + 4,
        .button => |b| {
            const text_height = b.font_size + 4;
            return text_height + child.padding.top + child.padding.bottom;
        },
        .container => 100,
    };
}

/// Layouts children in a horizontal row (left to right).
/// This implements a flexbox-like algorithm with three phases:
///
/// Phase 1 - Measurement:
///   - Measure all fixed and fit-sized children
///   - Count up how much width they need
///   - Track the total "grow weight" from children with .grow sizing
///
/// Phase 2 - Growth distribution:
///   - Calculate remaining space after fixed/fit children
///   - Distribute this space among .grow children proportionally by weight
///
/// Phase 3 - Positioning:
///   - Apply main-axis (X) alignment to the group of children
///   - Apply cross-axis (Y) alignment to each individual child
///   - Recursively layout each child
fn layoutHorizontal(node: *Node, content_width: i32, content_height: i32) void {
    const container = &node.type.container;
    const children = container.children.items;

    // ========== PHASE 1: MEASUREMENT ==========

    // Track how much width is used by fixed and fit-sized children
    var used_width: i32 = 0;

    // Track the sum of all grow weights from children that want to grow
    var total_grow: f32 = 0;

    // Calculate total width taken up by gaps between children
    // If there are N children, there are N-1 gaps between them
    const spacing_total = container.child_gap * @as(i32, @intCast(children.len - 1));

    // First pass: measure all children and calculate their widths
    for (children) |*child| {
        switch (child.sizing.width) {
            // Fixed width: child explicitly specifies its width
            .fixed => |w| {
                child.actual_width = w;
                used_width += w;
            },
            // Fit width: child wants to be sized based on its content
            .fit => {
                child.actual_width = measureChildWidth(child);
                used_width += child.actual_width;
            },
            // Grow width: child wants to take up remaining space
            // We don't set actual_width yet - we need to know total remaining space first
            .grow => |weight| {
                total_grow += weight;
            },
        }

        // Also calculate heights now (simpler since cross-axis doesn't affect main-axis)
        child.actual_height = switch (child.sizing.height) {
            .fixed => |h| h,
            .fit => measureChildHeight(child),
            // For horizontal containers, a child with grow height takes the full content height
            .grow => content_height,
        };
    }

    // ========== PHASE 2: GROWTH DISTRIBUTION ==========

    // Calculate how much space is left after fixed/fit children and gaps
    const remaining_width = content_width - used_width - spacing_total;

    // If there are children that want to grow AND there's space available,
    // distribute the remaining space proportionally by weight
    if (total_grow > 0 and remaining_width > 0) {
        for (children) |*child| {
            if (child.sizing.width == .grow) {
                const weight = child.sizing.width.grow;
                // Give this child its proportional share of remaining space
                // Formula: remaining_space * (child_weight / total_weight)
                child.actual_width = @intFromFloat(@as(f32, @floatFromInt(remaining_width)) * (weight / total_grow));
            }
        }
    }

    // ========== PHASE 3: POSITIONING ==========

    // Calculate the total width of all children (now including grow children)
    var total_children_width: i32 = 0;
    for (children) |*child| {
        total_children_width += child.actual_width;
    }
    total_children_width += spacing_total;

    // Start positioning children from the left of the content area
    // This is the main-axis (X) starting position
    var current_x = node.x + node.padding.left;

    // Apply main-axis (X) alignment by adjusting the starting X position
    // This moves the entire group of children together as a unit
    if (container.child_alignment.x == .center) {
        // If there's extra space, center the children by adding half the extra space to the left
        if (content_width > total_children_width) {
            current_x += @divTrunc(content_width - total_children_width, 2);
        }
    } else if (container.child_alignment.x == .end) {
        // If there's extra space, push children to the right
        if (content_width > total_children_width) {
            current_x = node.x + node.actual_width - total_children_width - node.padding.right;
        }
    }
    // Note: .start alignment is the default - children start at node.x + padding.left

    // Position each child and recursively layout it
    for (children) |*child| {
        // Cross-axis (Y) alignment - determines where child sits vertically
        // Check if child has self_alignment - if so, it overrides the parent's child_alignment
        const align_y = if (child.self_alignment) |self| self.y else container.child_alignment.y;

        child.y = switch (align_y) {
            // .start: align to the top edge of content area
            .start => node.y + node.padding.top,
            // .center: center the child vertically within content area
            .center => node.y + node.padding.top + @divTrunc(content_height - child.actual_height, 2),
            // .end: align to the bottom edge of content area
            .end => node.y + content_height + node.padding.top - child.actual_height,
        };

        // Set the child's X position (this advances along the horizontal row)
        child.x = current_x;

        // Recursively layout this child (and its descendants if it's a container)
        layoutNode(child, child.x, child.y, child.actual_width, child.actual_height);

        // Move right by this child's width plus the gap for the next child
        current_x += child.actual_width + container.child_gap;
    }
}

/// Calculates the width needed for a container to fit all its children.
/// - For a vertical container, this is the maximum width of any child (plus padding)
/// - For a horizontal container, this is the sum of all children's widths plus gaps (plus padding)
///
/// This function is called when a container's width sizing mode is .fit
fn calculateFitWidth(node: *Node) i32 {
    if (node.type != .container) return 0;

    const container = &node.type.container;

    if (container.direction == .vertical) {
        // Vertical: width is the widest child
        var max_width: i32 = 0;

        for (container.children.items) |*child| {
            if (child.actual_width > max_width) {
                max_width = child.actual_width;
            }
        }

        return max_width + node.padding.left + node.padding.right;
    } else {
        // Horizontal: width is sum of all children plus gaps
        var total_width: i32 = 0;

        for (container.children.items) |*child| {
            total_width += child.actual_width;
        }

        const gap_total = container.child_gap * @as(i32, @intCast(container.children.items.len -| 1));
        return total_width + gap_total + node.padding.left + node.padding.right;
    }
}

/// Calculates the height needed for a container to fit all its children.
/// - For a vertical container, this is the sum of all children's heights plus gaps (plus padding)
/// - For a horizontal container, this is the maximum height of any child (plus padding)
///
/// This function is called when a container's height sizing mode is .fit
fn calculateFitHeight(node: *Node) i32 {
    if (node.type != .container) return 0;

    const container = &node.type.container;

    if (container.direction == .vertical) {
        // Vertical: height is sum of all children plus gaps
        var total_height: i32 = 0;

        for (container.children.items) |*child| {
            total_height += child.actual_height;
        }

        const gap_total = container.child_gap * @as(i32, @intCast(container.children.items.len -| 1));
        return total_height + gap_total + node.padding.top + node.padding.bottom;
    } else {
        // Horizontal: height is the tallest child
        var max_height: i32 = 0;

        for (container.children.items) |*child| {
            if (child.actual_height > max_height) {
                max_height = child.actual_height;
            }
        }

        return max_height + node.padding.top + node.padding.bottom;
    }
}
