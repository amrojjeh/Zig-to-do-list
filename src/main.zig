const std = @import("std");
const cli = @import("cli.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    try cli.execute(allocator, args[1..]);
}

pub fn help() void {
    std.debug.print(
        \\Welcome to the To-Do List!
        \\=== Examples ===
        \\todo Literature Review : Adds lit review as a task
        \\todo Literature Review due Wednesday: Adds lit review as a task which is due Wednesday
    , .{});
}
