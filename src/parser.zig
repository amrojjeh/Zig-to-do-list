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
    ExpectedNext,
    ExpectedThis,
    ExpectedDuration,
    MonthDoesNotExist,
    DayOutOfRange,
};

/// Used to parse tasks from the command line argument.
pub fn parseTask(buffer: []u8, timezone: Date.Timezone, args: *Arguments) ParseError!Task {
    var lex = Lexer { .args = args, };

    const content = readContent(buffer, args);

    const due = try root(&lex, timezone);

    return Task {
        .content = content,
        .due = due,
        .completed = false,
    };
}

fn root(lex: *Lexer, timezone: Date.Timezone) ParseError!?Date {
    const t = try lex.peek();
    if (t) |val| {
        return switch (val) {
            .month_name => try monthDayFormat(lex, timezone),
            .this => try this(lex),
            .next => try next(lex),
            .tomorrow => tomorrow(),
            .today => today(),
            else => ParseError.ExpectedMonth,
        };
    } else return noDueDate(lex);
}

fn noDueDate(lex: *Lexer) ?Date {
    return null;
}

fn this(lex: *Lexer) ParseError!Date {
    _ = (try lex.next()) orelse return ParseError.ExpectedThis;
    const t = try lex.next();
    if (t) |val| {
        return switch (val) {
            .week => getThisWeek(Date.DayOfWeek.saturday, Date.now()),
            .month => getThisMonth(Date.now()),
            .week_day_name => |d| getThisWeek(d, Date.now()),
            else => ParseError.ExpectedDuration,
        };
    } else return ParseError.ExpectedThis;
}

fn next(lex: *Lexer) ParseError!Date {
    _ = (try lex.next()) orelse return ParseError.ExpectedNext;
    const t = try lex.next();
    if (t) |val| {
        return switch (val) {
            .week => getNextWeek(Date.DayOfWeek.saturday, Date.now()),
            .month => getNextMonth(Date.now()),
            .week_day_name => |d| getThisWeek(d, Date.now()),
            else => ParseError.ExpectedDuration,
        };
    } else return ParseError.ExpectedNext;
}

fn getNextWeek(w: Date.DayOfWeek, date: Date) Date {
    const endOfThisWeek = getThisWeek(w, date);
    return endOfThisWeek.add(Date {.days = 7});
}

fn getNextMonth(date: Date) Date {
    return getThisMonth(getThisMonth(date));
}

fn getDayDifference(start: Date.DayOfWeek, end: Date.DayOfWeek) u32 {
    const start_n = @intCast(u32, @enumToInt(start));
    const end_n = @intCast(u32, @enumToInt(end));
    if (start_n >= end_n) {
        return 7 - (std.math.max(start_n, end_n) - std.math.min(start_n, end_n));
    }
    return end_n - start_n;
}

fn getThisWeek(w: Date.DayOfWeek, date: Date) Date {
    const diff = getDayDifference(date.dayOfWeek(), w);
    return date.add(Date {.days = diff});
}

fn getThisMonth(date: Date) Date {
    const t = date.day();
    const month_num = date.month();
    const days_in_month = date.yearMonths()[month_num];
    return date.add(Date {.days = 1 + days_in_month - t});
}

fn tomorrow() Date {
    return Date.now().add(Date {.days = 1}).flatten();
}

fn today() Date {
    return Date.now().flatten();
}

fn monthDayFormat(lex: *Lexer, timezone: Date.Timezone) ParseError!Date {
    const m = try month(lex);
    const d = try day(lex);
    const y = blk: {
        if (try lex.peek()) |y| {
            break :blk try year(lex);
        } else {
            const now = Date.now().flatten();
            const default = try Date.init(now.year(), m, d);
            const useSmartYearAssumption = now.compare(default) > 0; // fancy way of saying increment year by 1            
            break :blk now.year() + if (useSmartYearAssumption) @as(u32, 1) else @as(u32, 0);
        }
    };
    // When user enters may 26, it's implied that it's may 26 00:00:00 CST (or any other timezone).
    // So, we must convert it to UTC, so that the formatting doesn't screw up.
    return (try Date.init(y, m, d)).toUtc(timezone);
}

fn month(lex: *Lexer) ParseError!u32 {
    const t = try lex.next();
    if (t) |val| {
        switch (val) {
            .month_name => |m| return @intCast(u32, @enumToInt(m)),
            else => return ParseError.ExpectedMonth,
        }
    } else return ParseError.ExpectedMonth;
}

fn day(lex: *Lexer) ParseError!u32 {
    const t = try lex.next();
    if (t) |val| {
        switch (val) {
            .number => |n| return n - 1,
            else => return ParseError.ExpectedDay,
        }
    } else return ParseError.ExpectedDay;
}

fn year(lex: *Lexer) ParseError!u32 {
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
