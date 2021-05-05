usingnamespace @import("cli_helper.zig");

const std = @import("std");
const io = @import("io.zig");
const config = @import("config.zig");
const parseTask = @import("parser.zig").parseTask;
const Arguments = @import("args.zig");
const Todo = @import("todo.zig");
const util = @import("util.zig");
const Allocator = std.mem.Allocator;


const Command = struct {
    names: []const [:0]const u8,
    commandFn: fn (*Allocator, *Arguments) anyerror!void,
};

const Commands = &[_]Command {
    Command {
        .names = &[_][:0]const u8{"list", "l"},
        .commandFn = list,
    },

    Command {
        .names = &[_][:0]const u8{"remove", "rem", "r", "erase"},
        .commandFn = removeTask,
    },

    Command {
        .names = &[_][:0]const u8{"complete", "comp", "c"},
        .commandFn = completeTask,
    },
};

pub fn execute(alloc: *Allocator, raw_args: [][:0]const u8) !void {
    var args = Arguments {
        .args = raw_args,
    };

    if (args.peek()) |arg| {
        if (arg[0] == '-') {
            try runCommand(alloc, &args);
        } else {
            try addTask(alloc, &args);
        }
    } else {
        try noArgs();
    }
}

fn runCommand(alloc: *Allocator, args: *Arguments) !void {
    const arg = args.peek().?;
    var buffer: [20]u8 = undefined;
    std.mem.copy(u8, &buffer, arg[0..arg.len]);
    const str = buffer[1..arg.len]; // Remove the "-"
    util.toLower(str);
    inline for (Commands) |command| {
        inline for (command.names) |n| {
            if (std.mem.eql(u8, str, n)) {
                try command.commandFn(alloc, args);
                return;
            }
        }
    }
    
    try commandDoesNotExist(arg);
}

fn commandDoesNotExist(commandName: []const u8) !void {
    try printFail("Command {s} does not exist.", .{commandName});
}

fn noArgs() !void {
    try printFail("No arguments passed. Running help command...", .{});
}

fn list(alloc: *Allocator, args: *Arguments) !void {
    const noTasks = struct {
        pub fn noTasks() !void {
            try printNormal("There are no tasks available.", .{});
        }
    }.noTasks;

    const todo = (try io.read(alloc)) orelse {
        try noTasks();
        return;
    }; defer todo.deinit();

    if (util.tailQueueLen(todo.tasks) == 0) {
        try noTasks();
    }

    var it = todo.tasks.first;
    var index: usize = 1;
    while (it) |node| : (it = node.next) {
        try printNormal("{d}. {any}", .{index, node.data});
        index += 1;
    }
}

fn addTask(alloc: *Allocator, args: *Arguments) !void {
    var todo: Todo = (try io.read(alloc)) orelse Todo.init(alloc);
    defer todo.deinit();

    var buffer: [config.MAX_LINE]u8 = undefined;

    const task = parseTask(&buffer, args) catch |err| {
        switch (err) {
            error.InvalidMonth => try printFail("Invalid month.", .{}),
            error.InvalidDay => try printFail("Invalid day.", .{}),
            error.AmbiguousAbbr => try printFail("Month name is ambiguous.", .{}),
            else => try printFail("Something went wrong...", .{}),
        }
        return;
    };
    try todo.add(task);

    try io.save(todo);

    try printSuccess("Added task.", .{});
    try printNormal("{any}", .{task});
}

/// Removes a task. First task is index 1.
fn removeTask(alloc: *Allocator, args: *Arguments) !void {
    _ = args.next(); // Skip the argument
    const number = (try nextArgIndex(usize, args)) orelse return;

    var todo = (try io.read(alloc)) orelse {
        try printFail("Cannot delete tasks. Todo list is empty.", .{});
        return;
    }; defer todo.deinit();

    if (number < 1) {
        try printFail("Index cannot be less than 1.", .{});
        return;
    }

    const removed = todo.remove(number - 1) orelse {
        try printFail("Task does not exist.", .{});
        return;
    }; defer alloc.destroy(removed);

    try printSuccess("Removed task", .{});
    try printNormal("{any}", .{removed.data});

    try io.save(todo);
}

/// Completes a task. Index starts at 1.
fn completeTask(alloc: *Allocator, args: *Arguments) !void {
    _ = args.next(); // Skips the -c argument
    const number = (try nextArgIndex(usize, args)) orelse return;

    var todo = (try io.read(alloc)) orelse {
        try printFail("Could not complete task. Todo list is empty.", .{});
        return;
    }; defer todo.deinit();

    var node = todo.get(number - 1) orelse {
        try printFail("Task does not exist.", .{});
        return;
    };

    node.data.completed = true;
    try printNormal("{s}", .{node.data});

    try io.save(todo);
}
