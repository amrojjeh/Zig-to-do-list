const std = @import("std");
const Todo = @import("todo.zig").Todo;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    if (args.len == 1) {
        help();
        return;
    }

    for (args) |word| {
        std.debug.print("{}\n", .{word});
    }

    var todo = try Todo.root("todo.todo");
    defer todo.close();
}

pub fn help() void {
    std.debug.print(
        \\Welcome to the To-Do List!
        \\=== Examples ===
        \\todo Literature Review : Adds lit review as a task
        \\todo Literature Review due Wednesday: Adds lit review as a task which is due Wednesday
        , .{});
}
