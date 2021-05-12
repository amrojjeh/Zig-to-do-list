const std = @import("std");

const Lexer = @import("lexer.zig");
const Arguments = @import("args.zig");
const Task = @import("task.zig");
const Date = @import("date.zig");

const testing = std.testing;

const ParseError = Lexer.TokenError || error {
    ExpectedDay,
    ExpectedMonth,
    ExpectedYear,
    MonthDoesNotExist,
    DayOutOfRange,
};

/// Used to parse tasks from the command line argument.
pub fn parseTask(buffer: []u8, args: *Arguments) ParseError!Task {
    var lex = Lexer { .args = args, };

    const content = readContent(buffer, args);

    const due = try root(&lex);

    return Task {
        .content = content,
        .due = due,
        .completed = false,
    };
}

fn root(lex: *Lexer) ParseError!?Date {
    const t = try lex.peek();
    if (t) |val| {
        switch (val) {
            .month_name => return try monthDayFormat(lex),
            else => return ParseError.ExpectedMonth,
        }
    } else return noDueDate(lex);
}

fn noDueDate(lex: *Lexer) ?Date {
    return null;
}

fn monthDayFormat(lex: *Lexer) ParseError!Date {
    const m = try month(lex);
    const d = try day(lex);
    const y = blk: {
        if (try lex.peek()) |y| {
            break :blk try year(lex);
        } else {
            const now = Date.now().flatten();
            const default = try Date.init(now.year(), m, d);
            const useSmartYearAssumption = now.compare(default) > 0; // fancy way of saying increment year by 1            
            break :blk now.year() + if (useSmartYearAssumption) @as(i64, 1) else @as(i64, 0);
        }
    };
    return try Date.init(y, m, d);
}

fn month(lex: *Lexer) ParseError!i64 {
    const t = try lex.next();
    if (t) |val| {
        switch (val) {
            .month_name => |m| return @intCast(i64, @enumToInt(m)),
            else => return ParseError.ExpectedMonth,
        }
    } else return ParseError.ExpectedMonth;
}

fn day(lex: *Lexer) ParseError!i64 {
    const t = try lex.next();
    if (t) |val| {
        switch (val) {
            .number => |n| return n,
            else => return ParseError.ExpectedDay,
        }
    } else return ParseError.ExpectedDay;
}

fn year(lex: *Lexer) ParseError!i64 {
    const t = try lex.next();
    if (t) |val| {
        switch (val) {
            .number => |n| return n,
            else => return ParseError.ExpectedYear
        }
    } else return ParseError.ExpectedYear;
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
