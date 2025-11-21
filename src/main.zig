const std = @import("std");

const rl = @import("raylib");
const zui = @import("zui");

const rl_render = @import("renderers/raylib.zig");

var checkbox_checked = false;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    var ui = zui.UI.init(gpa.allocator(), rl_render.measureText);
    defer ui.deinit();

    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "ZUI Testing");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Provide mouse input to UI
        ui.setMouseInput(.{
            .x = rl.getMouseX(),
            .y = rl.getMouseY(),
            .left_pressed = rl.isMouseButtonPressed(.left),
            .left_down = rl.isMouseButtonDown(.left),
            .left_released = rl.isMouseButtonReleased(.left),
        });

        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        try ui.beginVBox(.{
            .border = .{
                .width = 5,
                .color = .{ .r = 0, .g = 0, .b = 0 },
            },
            .padding = .all(25),
            .sizing = .{
                .height = .{ .grow = 1 },
                .width = .{ .grow = 1 },
            },
        });

        try ui.text("HEADER!", .{
            .font_size = 100,
            .self_alignment = .{ .x = .center },
        });

        try ui.beginHBox(.{
            .child_gap = 25,
            .sizing = .{
                .height = .{ .grow = 1 },
                .width = .{ .grow = 1 },
            },
        });

        try section(&ui, "left_btn", "Left <--");
        try section(&ui, "right_btn", "Right -->");

        ui.endHBox();

        ui.endVBox();

        try ui.computeLayout(screenWidth, screenHeight);

        const commands = try ui.getRenderCommands();
        defer gpa.allocator().free(commands);

        rl_render.render(commands);

        rl.endDrawing();
    }
}

fn section(ui: *zui.UI, id: []const u8, text: []const u8) !void {
    try ui.beginVBox(.{
        .border = .{
            .width = 5,
            .color = .{ .r = 0, .g = 0, .b = 0 },
        },
        .corner_radius = 20,
        .padding = .all(20),
        .bg_color = .{ .r = 200, .g = 200, .b = 200, .a = 255 },
        .sizing = .{
            .width = .{ .grow = 1 },
            .height = .{ .grow = 1 },
        },
        .child_alignment = .{
            .x = .center,
            .y = .center,
        },
        .child_gap = 15,
    });
    try ui.text(text, .{ .font_size = 24 });
    if (try ui.checkbox(id, "Enable feature", &checkbox_checked, .{})) {
        std.debug.print("Checkbox toggled: {}\n", .{checkbox_checked});
    }

    ui.endVBox();
}
