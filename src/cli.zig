usingnamespace @import("util.zig");

const std = @import("std");
const io = @import("io.zig");
const config = @import("config.zig");
const parser = @import("parser.zig");
const Arguments = @import("args.zig");
const Todo = @import("todo.zig");
const Allocator = std.mem.Allocator;

const Styles = struct {
    pub const BOLD = "\x1B[1m";
    pub const FAIL = "\x1B[91m" ++ BOLD;
    pub const SUCCESS = "\x1B[32m" ++ BOLD;
    pub const NORMAL = "\x1B[37m" ++ BOLD;

    pub const STRIKE = "\x1B[9m";

    pub const RESET = "\x1B[0m";
};

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
    toLower(str);
    var commandRan = false;
    inline for (Commands) |command| {
        inline for (command.names) |n| {
            if (std.mem.eql(u8, str, n)) {
                commandRan = true;
                try command.commandFn(alloc, args);
            }
        }
    }
    if (!commandRan) {
        try commandDoesNotExist(arg);
    }
}

fn commandDoesNotExist(commandName: []const u8) !void {
    const out = std.io.getStdOut().writer();
    try out.print("{s}Command {s} does not exist.{s}\n", .{Styles.FAIL, commandName, Styles.RESET});
}

fn noArgs() !void {
    const out = std.io.getStdOut().writer();
    try out.print("{s}No arguments passed. Running help command...{s}\n", .{Styles.FAIL, Styles.RESET});
}

fn list(alloc: *Allocator, args: *Arguments) !void {
    const H = struct {
        pub fn noTasks(out: anytype) !void {
            try out.print("{s}There are no tasks available.{s}\n", .{Styles.SUCCESS, Styles.RESET});
        }
    };
    const out = std.io.getStdOut().writer();

    if (try io.read(alloc)) |todo| {
        defer todo.deinit();
        if (todo.tasks.len() == 0) {
            try H.noTasks(out);
        }
        var it = todo.tasks.first;
        var index: usize = 1;
        while (it) |node| : (it = node.next) {
            try out.print("{s}{d}. {any}{s}\n", .{Styles.NORMAL, index, node.data, Styles.RESET});
            index += 1;
        }
    } else {
        try H.noTasks(out);
    }
}

fn addTask(alloc: *Allocator, args: *Arguments) !void {
    const out = std.io.getStdOut().writer();

    var todo: Todo = undefined;

    if (try io.read(alloc)) |t| {
        todo = t;
    } else {
        todo = Todo.init(alloc);
    }
    defer todo.deinit();

    var buffer: [config.MAX_LINE]u8 = undefined;

    const task = try parser.parseTask(&buffer, args);
    try todo.add(task);

    try io.save(todo);

    try out.print("{s}Added task.{s}\n", .{Styles.SUCCESS, Styles.RESET});
}

/// Removes a task. First task is index 1.
fn removeTask(alloc: *Allocator, args: *Arguments) !void {
    const print = std.io.getStdOut().writer().print;
    _ = args.next(); // Skip the argument
    const str_num = args.next() orelse "1";
    const number = std.fmt.parseInt(usize, str_num, 10) catch |err| {
        try print("{s}{s} is not a number.{s}\n", .{Styles.FAIL, str_num, Styles.RESET});
        return;
    };

    var todo = (try io.read(alloc)) orelse {
        try print("{s}Cannot delete tasks. Todo list is empty.{s}\n", .{Styles.FAIL, Styles.RESET});
        return;
    };

    if (number < 1) {
        try print("{s}Index cannot be less than 1.{s}\n", .{Styles.FAIL, Styles.RESET});
        return;
    }

    const removed = todo.remove(number - 1);

    if (removed) |r| {
        defer alloc.destroy(r);
        try print("{s}{any}{s}\n", .{Styles.SUCCESS, r.data, Styles.RESET});
    }

    try io.save(todo);
}
