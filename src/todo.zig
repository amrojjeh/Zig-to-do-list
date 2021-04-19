const std = @import("std");
const Allocator = std.mem.Allocator;
const Date = @import("date.zig");
const Task = @import("task.zig");

const Self = @This();
pub const Tasks = std.SinglyLinkedList(Task);

alloc: *Allocator,
tasks: Tasks,

pub fn init(allocator: *Allocator) Self {
    return Self {
        .alloc = allocator,
        .tasks = Tasks{},
    };
}

pub fn init_str(allocator: *Allocator, buffer: []const u8) !Self {
    var todo = init(allocator);

    var lines = std.mem.tokenize(buffer, "\n");
    while (lines.next()) |line| {
        var content: []const u8 = undefined;
        var due: Date = undefined;
        var completed: bool = undefined;
        var tokens = std.mem.tokenize(line, "|");
        var i: u8 = 0;
        while (tokens.next()) |token| : (i += 1) {
            switch (i) {
                0 => content = token,
                1 => due = Date.epochToDate(try std.fmt.parseInt(i64, token, 10)),
                2 => completed = (try std.fmt.parseInt(u8, token, 10)) == 1,
                else => return error.TooManySplitters,
            }
        }
        try todo.add(Task {
            .content = content,
            .due = due,
            .completed = completed,
            });
    }
    return todo;
}

pub fn close(self: Self) void {
    var it = self.tasks.first;
    while (it) |node| {
        it = node.next;
        self.alloc.destroy(node);
    }
}

/// Adds a new task
/// Allocates memory
pub fn add(self: *Self, task: Task) !void {
    var node = try self.alloc.create(Tasks.Node);
    node.* = Tasks.Node {
        .data = task,
    };
    self.tasks.prepend(node);
}

pub fn strAlloc(self: Self, allocator: *Allocator) ![:0]u8 {
    var buf = try allocator.alloc(u8, 100 * self.tasks.len());
    return self.str(buf);
}

pub fn str(self: Self, buffer: []u8) ![:0]u8 {
    var todo_iter = self.tasks.first;
    var i: usize = 0;
    var tail: usize = 0;
    const size = self.tasks.len();
    while (i < size) : (i += 1) {
        var line = buffer[tail .. (1+i)*100];
        const task = todo_iter.?.data;

        const completed: i64 = if (task.completed) 1 else 0;
        const printed = try std.fmt.bufPrint(line, "{s}|{d}|{d}\n", .{task.content, task.due.dateToEpoch(), completed});
        tail = tail + printed.len;
        todo_iter = todo_iter.?.next;
    }

    buffer[tail] = 0;

    return buffer[0..tail:0];
}

test "Basic" {
    const alloc = std.testing.allocator;
    var todo = Self.init(alloc);
    defer todo.close();

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

    const string = try todo.strAlloc(alloc);
    defer alloc.free(string);

    const expected = "Math assignment|1619136000|1\nChemistry assignment|1617840000|0\n";
    std.testing.expect(std.mem.eql(u8, string, expected));
}

test "Loading" {
    const alloc = std.testing.allocator;
    const string = "Chemistry assignment|1617840000|0\nMath assignment|1619136000|1\n";
    var result = try init_str(alloc, string);
    defer result.close();

    std.testing.expect(std.mem.eql(u8, "Chemistry assignment", result.tasks.first.?.next.?.data.content));
    std.testing.expectEqual(Date { .days = 18725 }, result.tasks.first.?.next.?.data.due);
    std.testing.expectEqual(false, result.tasks.first.?.next.?.data.completed);

    std.testing.expect(std.mem.eql(u8, "Math assignment", result.tasks.first.?.data.content));
    std.testing.expectEqual(Date { .days = 18725 + 15}, result.tasks.first.?.data.due);
    std.testing.expectEqual(true, result.tasks.first.?.data.completed);
}
