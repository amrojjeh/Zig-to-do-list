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

    pub const RESET = "\x1B[0m";
};

pub fn execute(alloc: *Allocator, raw_args: [][:0]const u8) !void {
    var args = Arguments {
        .args = raw_args,
    };

    if (args.peek()) |arg| {
        var buffer: [20]u8 = undefined;
        std.mem.copy(u8, buffer[0..], arg[0..arg.len + 1]);
        const str = buffer[0..arg.len:0];
        toLower(str);
        if (std.mem.eql(u8, str, "list")) {
            try list(alloc, &args);
        } else {
            try addTask(alloc, &args);
        }
    }
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
        while (it) |node| : (it = node.next) {
            try out.print("{any}\n", .{node.data});
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
