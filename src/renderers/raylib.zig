const std = @import("std");

const rl = @import("raylib");
const zui = @import("zui");

pub fn render(commands: []zui.RenderCommand) void {
    for (commands) |command| {
        switch (command) {
            .rect => |r| {
                const color = rl.Color{
                    .r = r.color.r,
                    .g = r.color.g,
                    .b = r.color.b,
                    .a = r.color.a,
                };
                rl.drawRectangle(r.x, r.y, r.w, r.h, color);
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
                const color = rl.Color{
                    .r = t.color.r,
                    .g = t.color.g,
                    .b = t.color.b,
                    .a = t.color.a,
                };
                rl.drawText(text, t.x, t.y, t.size, color);
            },
        }
    }
}
