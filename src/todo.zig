const std = @import("std");
const Allocator = std.mem.Allocator;
const Date = @import("date.zig");
const Task = @import("task.zig");

const Self = @This();

pub const Node = struct {
    next: ?*Node,
    current: Task
};

pub const TodoIterator = struct {
    node: ?*const Node,

    pub fn next(self: *TodoIterator) ?*const Node {
        if (self.node) |val| {
            const result = val;
            self.node = val.next;
            return result;
        } else {
            return null;
        }
    }
};

// A linked list can be empty
first_node: ?*Node,
last_node: ?*Node,
size: usize,
alloc: *Allocator,

pub fn init(allocator: *Allocator) Self {
    return Self {
        .first_node = null,
        .last_node = null,
        .size = 0,
        .alloc = allocator,
    };
}

pub fn close(self: *Self) void {
    var it = self.iter();
    while (it.next()) |node| {
        self.alloc.destroy(node);
    } 
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

pub fn add(self: *Self, task: Task) !void {
    var node = try self.alloc.create(Node);
    node.* = Node {
        .next = null,
        .current = task,
    };

    if (self.first_node) |n| {
        self.last_node.?.next = node;
        self.last_node = node;
    } else {
        self.first_node = node;
        self.last_node = node;
    }

    self.size += 1;
}

pub fn iter(self: Self) TodoIterator {
    if (self.size == 0) {
        return TodoIterator {
            .node = null,
        };
    }

    return TodoIterator {
        .node = self.first_node,
    };
}

pub fn str(self: Self, allocator: *Allocator) ![:0]u8 {
    var todo_iter = self.iter();
    var buf = try allocator.alloc(u8, 100 * self.size);
    var i: usize = 0;
    var tail: usize = 0;
    while (i < self.size) : (i += 1) {
        var line = buf[tail .. (1+i)*100];
        const task = todo_iter.next().?.current;
        const completed: i64 = if (task.completed) 1 else 0;
        const printed = try std.fmt.bufPrint(line, "{}|{}|{}\n", .{task.content, task.due.dateToEpoch(), completed});
        tail = tail + printed.len;
    }

    buf[tail] = 0;

    return buf[0..tail:0];
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

    const string = try todo.str(alloc);
    defer alloc.free(string);

    const expected = "Chemistry assignment|1617840000|0\nMath assignment|1619136000|1\n";
    std.testing.expectEqual(expected.len, string.len);
    std.testing.expect(std.mem.eql(u8, string, expected));
}

test "Loading" {
    const alloc = std.testing.allocator;
    const string = "Chemistry assignment|1617840000|0\nMath assignment|1619136000|1\n";
    var result = try init_str(alloc, string);
    defer result.close();

    std.testing.expect(std.mem.eql(u8, "Chemistry assignment", result.first_node.?.current.content));
    std.testing.expectEqual(Date { .days = 18725 }, result.first_node.?.current.due);
    std.testing.expectEqual(false, result.first_node.?.current.completed);

    std.testing.expect(std.mem.eql(u8, "Math assignment", result.last_node.?.current.content));
    std.testing.expectEqual(Date { .days = 18725 + 15}, result.last_node.?.current.due);
    std.testing.expectEqual(true, result.last_node.?.current.completed);
}
