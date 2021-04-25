const std = @import("std");

const Lexer = @import("lexer.zig");
const Arguments = @import("args.zig");
const Task = @import("task.zig");
const Date = @import("date.zig");

const testing = std.testing;

const ParseError = Lexer.TokenError || error {
    MonthMustComeFirst,
    ExpectedDayToken,
};

pub fn parseTask(buffer: []u8, args: *Arguments) ParseError!Task {
    var lex = Lexer { .args = args, };

    const content = readContent(buffer, args);

    var due: ?Date = null;

    try month(&due, &lex);

    return Task {
        .content = content,
        .due = due,
        .completed = false,
    };
}

fn month(due: *?Date, lex: *Lexer) ParseError!void {
    const t = try lex.nextToken();
    if (t) |val| {
        switch (val) {
            .month_name => |m| due.* = try Date.init(Date.now().year(), @intCast(i64, @enumToInt(m)), 1),
            else => return ParseError.MonthMustComeFirst,
        }
    }
    try day(due, lex);
}

fn day(due: *?Date, lex: *Lexer) ParseError!void {
    const t = try lex.nextToken();
    if (t) |val| {
        switch (val) {
            .number => |n| due.* = due.*.?.add(Date {.days = n - 1}),
            else => return ParseError.ExpectedDayToken,
        }
    }
}

/// Content is the task itself, the todo. It can end with a ";", or if there's nothing left
fn readContent(buffer: []u8, args: *Arguments) [:0]u8 {
    var tail: usize = 0; // Points to the first available memory

    while (args.next()) |word| {
        if (std.mem.eql(u8, word, ";")) {
            buffer[tail] = 0;
            return buffer[0..tail:0];
        } else {
            if (tail != 0) {
                buffer[tail] = ' ';
                tail += 1;
            }
            std.mem.copy(u8, buffer[tail..], word);
            tail += word.len;
        }
    }

    buffer[tail] = 0;
    return buffer[0..tail:0];
}

test "parser.readContent" {
    var buffer: [100]u8 = undefined;
    {
        var raw_args = [_][:0]const u8 {"10.1", "Conics", "&", "Calculus", ";", "nice", "extra", "stuff"};
        var args = Arguments {
            .args = raw_args[0..],
        };
        const content = readContent(buffer[0..], &args);
        testing.expect(std.mem.eql(u8, content, "10.1 Conics & Calculus"));
    }

    {
        var raw_args = [_][:0]const u8 {"10.1", "Conics", "&", "Calculus"};
        var args = Arguments {
            .args = raw_args[0..],
        };
        const content = readContent(buffer[0..], &args);
        testing.expect(std.mem.eql(u8, content, "10.1 Conics & Calculus"));
    }

    {
        var raw_args = [_][:0]const u8{};
        var args = Arguments {
            .args = raw_args[0..],
        };
        const content = readContent(buffer[0..], &args);
        testing.expect(std.mem.eql(u8, content, ""));
    }
}

test "parser.parseTask" {
    var buffer: [100]u8 = undefined;
    {
        const raw_args = [_][:0]const u8 {"Conic", "Sections", "exam", ";", "jan", "2"};
        var args = Arguments {
            .args = raw_args[0..],
        };
        const task = try parseTask(buffer[0..], &args);

        testing.expectEqualSlices(u8, "Conic Sections exam", task.content);
        testing.expectEqual(Date {.days = 1,}, task.due.?);
        testing.expectEqual(false, task.completed);
    }
}
