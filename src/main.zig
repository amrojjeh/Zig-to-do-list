const std = @import("std");
const io = @import("io.zig");
const cli = @import("cli.zig");
const parser = @import("parser.zig");
const config = @import("config.zig");
const Todo = @import("todo.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var buffer: [config.MAX_LINE]u8 = undefined;

    const args = try std.process.argsAlloc(allocator);

    const new_task = try parser.parseTask(buffer[0..], args[1..]);

    var todo = Todo.init(allocator);
    defer todo.deinit();

    try todo.add(new_task);

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
