const std = @import("std");
const Date = @import("date.zig");
const config = @import("config.zig");

content: []const u8,
due: ?Date,
completed: bool,

const Self = @This();

pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype
) !void {
    var buffer: [config.MAX_LINE]u8 = undefined;
    try writer.print("{s}", .{self.str(&buffer, true)});
}

pub fn str(self: Self, buffer: []u8, checkmark: bool) ![]u8 {
    const completed_str = blk: {
        if (checkmark) {
            break :blk if (self.completed) "✅ " else "❌ ";
        } else break :blk "";
    };

    return blk: {
        if (self.due) |date| {
            break :blk try std.fmt.bufPrint(buffer, "{s}{s} 📅 {any}", .{completed_str, self.content, date});
        }
        break :blk try std.fmt.bufPrint(buffer, "{s} {s}", .{completed_str, self.content});
    };
}
