const std = @import("std");
const Date = @import("date.zig");

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
    const completed_str = if (self.completed) "[X]" else "[ ]";
    if (self.due) |date| {
        try writer.print("{s} {s} due {any}", .{completed_str, self.content, date});
    } else {
        try writer.print("{s} {s}", .{completed_str, self.content});
    }
}
