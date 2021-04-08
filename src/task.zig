const Date = @import("date.zig");

pub const Task = struct {
    content: []const u8,
    due: Date,
};
