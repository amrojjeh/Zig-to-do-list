const std = @import("std");
const Allocator = std.mem.Allocator;
const Task = @import("task.zig");

const Self = @This();

tasks: []Task,
tail: usize = 0,
alloc: *Allocator,

pub fn init(allocator: *Allocator, size: usize) !Self {
    const tasks = try allocator.alloc(Task, size);
    return Self {
        .tasks = tasks,
        .alloc = allocator,
    };
}

pub fn addTask(task: Task) void {
    tasks[tail] = task;
    tail += 1;
}

pub fn close(self: Self) void {
    self.alloc.free(self.tasks);
}
