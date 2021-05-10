const std = @import("std");
const Allocator = std.mem.Allocator;
const Date = @import("date.zig");
const util = @import("util.zig");

pub const Task = @import("task.zig");
pub const Tasks = std.TailQueue(Task);
const Self = @This();

alloc: *Allocator,
tasks: Tasks,

pub fn init(allocator: *Allocator) Self {
    return Self {
        .alloc = allocator,
        .tasks = Tasks{},
    };
}

/// Assumes valid input
pub fn init_str(allocator: *Allocator, buffer: [:0]const u8) !Self {
    const Helpers = struct {
        pub fn getDue(token: []const u8) ?Date {
            const epoch = std.fmt.parseInt(i64, token, 10) catch null;
            if (epoch) |val|
                return Date.epochToDate(val)
            else
                return null;
        }

        pub fn getCompleted(token: []const u8) !bool {
            const val = try std.fmt.parseInt(u8, token, 10);
            return val != 0;
        }
    };

    var todo = init(allocator);
    var lines = std.mem.tokenize(buffer, "\n");
    while (lines.next()) |line| {
        var tokens = std.mem.tokenize(line, "|");
        const content: []const u8 = tokens.next().?;
        const due: ?Date = Helpers.getDue(tokens.next().?);
        const completed: bool = try Helpers.getCompleted(tokens.next().?);
        try todo.add(Task {
            .content = content,
            .due = due,
            .completed = completed,
            });
    }
    return todo;
}

pub fn deinit(self: Self) void {
    var it = self.tasks.first;
    while (it) |node| {
        it = node.next;
        self.alloc.destroy(node);
    }
}

/// Adds a new task based on its due date and completion status.
/// Allocates memory
pub fn add(self: *Self, task: Task) !void {
    const H = struct {
        fn isCompleted(tasks: *Tasks, me: *Tasks.Node) void {
            var it = tasks.first;
            const due_date = me.data.due orelse {
                tasks.append(me);
                return;
            };

            while (it) |node| : (it = node.next) {
                if (node.data.completed and due_date.compare(node.data.due orelse Date {}) > 0) {
                    tasks.insertBefore(node, me);
                    return;
                }
            }
            tasks.append(me);
        }

        fn isNotCompleted(tasks: *Tasks, me: *Tasks.Node) void {
            var it = tasks.first;
            const last_uncompleted_node = while (it) |node| : (it = node.next) {
                if (node.data.completed) break node.prev;
                if (me.data.due != null and me.data.due.?.compare(node.data.due orelse Date {}) > 0) {
                    tasks.insertBefore(node, me);
                    return;
                }
                break node;
            } else {
                tasks.prepend(me);
                return;
            };

            if (last_uncompleted_node) |val| {
                tasks.insertAfter(val, me);
            } else {
                tasks.prepend(me);
            }
        }
    };

    var to_add = try self.alloc.create(Tasks.Node);
    to_add.* = Tasks.Node {
        .data = task,
    };
    
    if (to_add.data.completed) {
        H.isCompleted(&self.tasks, to_add);
    } else {
        H.isNotCompleted(&self.tasks, to_add);
    }
}

/// Removes a node. Index based, starts from 0.
/// deinit will NOT deallocate this memory.
pub fn remove(self: *Self, index: usize) ?*Tasks.Node {
    if (index == 0) {
        return self.tasks.popFirst();
    }

    const node = self.get(index) orelse return null;
    self.tasks.remove(node);
    return node;
}

/// Returns a node based on index given. Starts from 0.
pub fn get(self: *Self, index: usize) ?*Tasks.Node {
    var it = self.tasks.first;
    var i: usize = 0;
    while (it) |node| : (it = node.next) {
        if (i == index) {
            return node;
        }
        i += 1;
    }
    return null;
}

pub fn strAlloc(self: Self, allocator: *Allocator) ![:0]u8 {
    var buf = try allocator.alloc(u8, 100 * self.tasks.len());
    return self.str(buf);
}

pub fn str(self: Self, buffer: []u8) ![:0]u8 {
    var todo_iter = self.tasks.first;
    var i: usize = 0;
    var tail: usize = 0;
    const size = util.tailQueueLen(self.tasks);
    while (i < size) : (i += 1) {
        var line = buffer[tail .. (1+i)*100];
        const task = todo_iter.?.data;

        const completed: i64 = if (task.completed) 1 else 0;
        const printed = blk: {
            if (task.due) |d| {
                break :blk try std.fmt.bufPrint(line, "{s}|{d}|{d}\n", .{task.content, d.dateToEpoch(), completed});
            } else {
                break :blk try std.fmt.bufPrint(line, "{s}|{}|{d}\n", .{task.content, task.due, completed});
            }
        };
        tail = tail + printed.len;
        todo_iter = todo_iter.?.next;
    }

    buffer[tail] = 0;

    return buffer[0..tail:0];
}

test "Basic" {
    const alloc = std.testing.allocator;
    var todo = Self.init(alloc);
    defer todo.deinit();

    try todo.add(Task {
        .content = "Remove me",
        .due = Date {
            .days = 18725 + 30,
            },
        .completed = false,
        });

    try todo.add(Task {
        .content = "Chemistry assignment",
        .due = Date {
            .days = 18725,
            },
        .completed = false,
        });

    try todo.add(Task {
        .content = "Math assignment",
        .due = Date {
            .days = 18725 + 15,
            },
        .completed = true,
        });

    const removed = todo.remove(2);
    defer alloc.destroy(removed.?);

    const string = try todo.strAlloc(alloc);
    defer alloc.free(string);

    const expected = "Math assignment|1619136000|1\nChemistry assignment|1617840000|0\n";
    std.testing.expect(std.mem.eql(u8, string, expected));
}

test "Loading" {
    const alloc = std.testing.allocator;
    const string = "Chemistry assignment|1617840000|0\nMath assignment|1619136000|1\n";
    var result = try init_str(alloc, string);
    defer result.deinit();

    std.testing.expect(std.mem.eql(u8, "Chemistry assignment", result.tasks.first.?.next.?.data.content));
    std.testing.expectEqual(Date { .days = 18725 }, result.tasks.first.?.next.?.data.due.?);
    std.testing.expectEqual(false, result.tasks.first.?.next.?.data.completed);

    std.testing.expect(std.mem.eql(u8, "Math assignment", result.tasks.first.?.data.content));
    std.testing.expectEqual(Date { .days = 18725 + 15}, result.tasks.first.?.data.due.?);
    std.testing.expectEqual(true, result.tasks.first.?.data.completed);
}
