const std = @import("std");

const rl = @import("raylib");
const zui = @import("zui");

/// Raylib-specific text measurement implementation.
/// Converts text to null-terminated format and uses Raylib's measureText function.
pub fn measureText(text: []const u8, font_size: i32) zui.TextMeasurement {
    // Raylib requires null-terminated strings, so we need to convert
    var buf: [256:0]u8 = undefined;
    const len = @min(text.len, buf.len - 1);
    @memcpy(buf[0..len], text[0..len]);
    buf[len] = 0;

    const width = rl.measureText(buf[0..len :0], font_size);

    return .{
        .width = width,
        .height = font_size,
    };
}

pub fn render(commands: []zui.RenderCommand) void {
    for (commands) |command| {
        switch (command) {
            .rect => |r| {
                const color = rl.Color{ .r = r.color.r, .g = r.color.g, .b = r.color.b, .a = r.color.a };
                const rect = rl.Rectangle{ .x = @floatFromInt(r.x), .y = @floatFromInt(r.y), .width = @floatFromInt(r.w), .height = @floatFromInt(r.h) };

                if (r.corner_radius > 0) {
                    // Convert pixel radius to Raylib's 0.0-1.0 ratio
                    const min_dimension = @min(r.w, r.h);
                    const max_radius = @divTrunc(min_dimension, 2);
                    const clamped_radius = @min(r.corner_radius, max_radius);
                    const roundness = @as(f32, @floatFromInt(clamped_radius)) / @as(f32, @floatFromInt(max_radius));
                    rl.drawRectangleRounded(rect, roundness, 4, color);
                } else {
                    rl.drawRectangle(r.x, r.y, r.w, r.h, color);
                }
            },
            .rect_lines => |r| {
                const color = rl.Color{ .r = r.color.r, .g = r.color.g, .b = r.color.b, .a = r.color.a };
                const rect = rl.Rectangle{ .x = @floatFromInt(r.x), .y = @floatFromInt(r.y), .width = @floatFromInt(r.w), .height = @floatFromInt(r.h) };

                if (r.corner_radius > 0) {
                    // Convert pixel radius to Raylib's 0.0-1.0 ratio
                    const min_dimension = @min(r.w, r.h);
                    const max_radius = @divTrunc(min_dimension, 2);
                    const clamped_radius = @min(r.corner_radius, max_radius);
                    const roundness = @as(f32, @floatFromInt(clamped_radius)) / @as(f32, @floatFromInt(max_radius));
                    rl.drawRectangleRoundedLinesEx(rect, roundness, 0, @floatFromInt(r.thickness), color);
                } else {
                    rl.drawRectangleLinesEx(rect, @floatFromInt(r.thickness), color);
                }
            },
            .text => |t| {
                // Convert to null-terminated string for raylib
                var buf: [256]u8 = undefined;
                const text = std.fmt.bufPrintZ(&buf, "{s}", .{t.content}) catch blk: {
                    // If text is too long, truncate it
                    const len = @min(t.content.len, 255);
                    @memcpy(buf[0..len], t.content[0..len]);
                    buf[len] = 0;
                    break :blk buf[0..len :0];
                };
                const color = rl.Color{ .r = t.color.r, .g = t.color.g, .b = t.color.b, .a = t.color.a };
                rl.drawText(text, t.x, t.y, t.size, color);
            },
        }
    }
}
