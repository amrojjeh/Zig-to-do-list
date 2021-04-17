const std = @import("std");
const io = @import("io.zig");
const Todo = @import("todo.zig");
const DateAndTime = @import("date.zig");
const assert = std.debug.assert;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    for (args) |word| {
        std.debug.print("{}\n", .{word});
    }

    _ = DateAndTime.now();

    const todo = try Todo.init(allocator, 2);
    defer todo.close();

    try io.save("todo.todo", todo);
}

pub fn help() void {
    std.debug.print(
        \\Welcome to the To-Do List!
        \\=== Examples ===
        \\todo Literature Review : Adds lit review as a task
        \\todo Literature Review due Wednesday: Adds lit review as a task which is due Wednesday
    , .{});
}
