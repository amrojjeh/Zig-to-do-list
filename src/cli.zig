const std = @import("std");
const io = @import("io.zig");
const config = @import("config.zig");
const parseTask = @import("parser.zig").parseTask;
const Arguments = @import("args.zig");
const Todo = @import("todo.zig");
const Date = @import("date.zig");
const util = @import("util.zig");
const Allocator = std.mem.Allocator;

pub const Styles = struct {
    pub const BOLD = "\x1B[1m";
    pub const UNDERLINE = "\x1B[4m";
    pub const FAIL = "\x1B[91m" ++ BOLD;
    pub const SUCCESS = "\x1B[32m" ++ BOLD;
    pub const HASHTAG = "\x1B[36m" ++ BOLD ++ UNDERLINE;
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
        .names = &[_][:0]const u8{"add", "a"},
        .commandFn = addTask,

    },
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

    Command {
        .names = &[_][:0]const u8{"count"},
        .commandFn = countHashtags,
    },

    Command {
        .names = &[_][:0]const u8{"cleareverythingwithoutasking"}, // Clear all tasks, used for debug.
        .commandFn = clearAllTasks,
    },

    Command {
        .names = &[_][:0]const u8{"today"},
        .commandFn = today,
    },
};

pub fn execute(alloc: *Allocator, raw_args: [][:0]const u8) !void {
    var args = Arguments {
        .args = raw_args,
    };

    if (args.peek()) |arg| {
            try runCommand(alloc, &args);
    } else {
        try noArgs();
    }
}

fn runCommand(alloc: *Allocator, args: *Arguments) !void {
    const arg = args.peek().?;
    var buffer: [40]u8 = undefined;
    std.mem.copy(u8, &buffer, arg[0..arg.len]);
    const str = buffer[0..arg.len];
    util.toLowerStr(str);
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
    try printFail("Command {s} does not exist.\n", .{commandName});
}

fn noArgs() !void {
    try printFail("No arguments passed. Running help command...\n", .{});
}

fn list(alloc: *Allocator, args: *Arguments) !void {
    const noTasks = struct {
        pub fn noTasks() !void {
            try printNormal("There are no tasks available.\n", .{});
        }
    }.noTasks;

    var todo = (try io.read(alloc)) orelse {
        try noTasks();
        return;
    }; defer todo.deinit();

    if (util.tailQueueLen(todo.tasks) == 0) {
        try noTasks();
    }

    todo.updateIndicies();

    // Read arguments
    _ = args.next(); // skip -list
    while (args.next()) |a| {
        todo.filterTasks(a);
    }

    var it = todo.tasks.first;
    var index: usize = 1;
    while (it) |node| : (it = node.next) {
        try printNormal("{d}. ", .{node.data.index.?});
        try TaskPrinter.p(node.data, true);
        try newline();
        index += 1;
    }
}

fn addTask(alloc: *Allocator, args: *Arguments) !void {
    var todo: Todo = (try io.read(alloc)) orelse Todo.init(alloc);
    defer todo.deinit();

    var buffer: [config.MAX_LINE]u8 = undefined;

    const task = parseTask(&buffer, args) catch |err| {
        switch (err) {
            error.InvalidDate => try printFail("Invalid date.\n", .{}),
            error.AmbiguousAbbr => try printFail("Month name is ambiguous.\n", .{}),
            else => try printFail("Something went wrong...{any}\n", .{err}),
        }
        return;
    };
    try todo.add(task);

    try io.save(todo);

    try printSuccess("Added task.\n", .{});
    try TaskPrinter.p(task, false);
    try newline();
}

/// Removes a task. First task is index 1.
fn removeTask(alloc: *Allocator, args: *Arguments) !void {
    _ = args.next(); // Skip the argument
    const number = (try nextArgIndex(usize, args)) orelse return;

    var todo = (try io.read(alloc)) orelse {
        try printFail("Cannot delete tasks. Todo list is empty.\n", .{});
        return;
    }; defer todo.deinit();

    if (number < 1) {
        try printFail("Index cannot be less than 1.\n", .{});
        return;
    }

    const removed = todo.remove(number - 1) orelse {
        try printFail("Task does not exist.\n", .{});
        return;
    }; defer alloc.destroy(removed);

    try printSuccess("Removed task\n", .{});
    try TaskPrinter.p(removed.data, true);
    try newline();
    try io.save(todo);
}

/// Completes a task. Index starts at 1.
fn completeTask(alloc: *Allocator, args: *Arguments) !void {
    _ = args.next(); // Skips the -c argument
    const number = (try nextArgIndex(usize, args)) orelse return;

    var todo = (try io.read(alloc)) orelse {
        try printFail("Could not complete task. Todo list is empty.\n", .{});
        return;
    }; defer todo.deinit();

    var node = todo.get(number - 1) orelse {
        try printFail("Task does not exist.\n", .{});
        return;
    };

    node.data.completed = !node.data.completed;
    try TaskPrinter.p(node.data, true);
    try newline();

    try io.save(todo);
}

fn countHashtags(alloc: *Allocator, args: *Arguments) !void {
    var c_names = [_][]u8{undefined} ** config.MAX_LINE;
    var c_counter: [config.MAX_LINE]util.Pair(u64) = undefined;

    var c = Todo.Task.HashtagCounter {
        .names = &c_names,
        .counter = &c_counter,
    };

    const todo = (try io.read(alloc)) orelse {
        try printFail("Todo list is empty.\n", .{});
        return;
    }; defer todo.deinit();

    var hashtag_names: [config.MAX_LINE][]const u8 = undefined;
    var hashtag_counter: [config.MAX_LINE]util.Pair(u64) = undefined;
    var it = todo.tasks.first;
    while (it) |node| : (it = node.next) {
        var tags = node.data.hashtags(&hashtag_names, &hashtag_counter);
        while (tags.next()) |tag| {
            _ = c.add(tag, node.data);
        }
    }

    for (c.names[0..c.len]) |n, i| {
        try print(Styles.HASHTAG, "{s}", .{n});
        try printNormal(": {d} total | {d} uncompleted | {d} completed\n", .{c.counter[i].a + c.counter[i].b, c.counter[i].b, c.counter[i].a});
        alloc.free(n);
    }
}

fn clearAllTasks(alloc: *Allocator, args: *Arguments) !void {
    const todo = Todo.init(alloc);
    defer todo.deinit();
    try io.save(todo);
    try printSuccess("👍 Deleted all tasks.\n", .{});
}

fn today(alloc: *Allocator, args: *Arguments) !void {
    const now = Date.now();
    try printNormal("Today is {s}: {s} {d}, {d}", .{@tagName(now.dayOfWeek()), now.monthName(), now.day(), now.year()});
}

// ======= HELPER FUNCTIONS =======

fn getWriter() std.fs.File.Writer {
    return std.io.getStdOut().writer();
}

fn newline() !void {
    try printNormal("\n", .{});
}

/// Prints a failed statement.
fn printFail(comptime str: []const u8, args: anytype) !void {
    try print(Styles.FAIL, str, args);
}

fn printSuccess(comptime str: []const u8, args: anytype) !void {
    try print(Styles.SUCCESS, str, args);
}

fn printNormal(comptime str: []const u8, args: anytype) !void {
    try print(Styles.NORMAL, str, args);
}

fn print(style: []const u8, comptime str: []const u8, args: anytype) !void {
    const writer = getWriter();
    try writer.print("{s}", .{style});
    try writer.print(str, args);
    try writer.print("{s}", .{Styles.RESET});    
}

fn nextArgIndex(comptime T: type, args: *Arguments) !?T {
    const str_num = args.next() orelse return 1;
    return std.fmt.parseInt(T, str_num, 10) catch |err| blk: {
        try printFail("{s} is not a number.", .{str_num});
        break :blk null;
    };
}


// ======= PRINTING OBJECTS =====

const TaskPrinter = struct {
    pub fn p(task: Todo.Task, checkmark: bool) !void {
        const completed_str = blk: {
            if (checkmark) {
                break :blk if (task.completed) "✅ " else "❌ ";
            } else break :blk "";
        };

        try printNormal("{s}", .{completed_str});
        try pretty_content(task);
        if (task.due) |date| {
            try printNormal("📅 {any}", .{date});
        }
    }

    /// Colors hashtags
    fn pretty_content(task: Todo.Task) !void {
        var words = std.mem.tokenize(task.content, " ");
        while (words.next()) |word| {
            if (Todo.Task.isHashtag(word)) {
                try print(Styles.HASHTAG, "{s}", .{word});
                try printNormal(" ", .{});
            } else {
                try printNormal("{s} ", .{word});
            }
        }
    }
};
