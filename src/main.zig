const std = @import("std");

const rl = @import("raylib");
const zui = @import("zui");

const rl_render = @import("renderers/raylib.zig");

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
        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        try ui.beginVBox(.{
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
            .sizing = .{
                .height = .{ .grow = 1 },
                .width = .{ .grow = 1 },
            },
        });

        try section(&ui, "Left <--");
        try section(&ui, "Right -->");

        ui.endHBox();

        ui.endVBox();

        ui.computeLayout(screenWidth, screenHeight);

        const commands = try ui.getRenderCommands();
        defer gpa.allocator().free(commands);

        rl_render.render(commands);

        rl.endDrawing();
    }
}

fn section(ui: *zui.UI, text: []const u8) !void {
    try ui.beginVBox(.{
        .sizing = .{
            .width = .{ .grow = 1 },
            .height = .{ .grow = 1 },
        },
        .child_alignment = .{
            .x = .center,
            .y = .center,
        },
    });
    try ui.text(text, .{});
    ui.endVBox();
}
