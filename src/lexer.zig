const std = @import("std");
const Date = @import("date.zig");
const Arguments = @import("args.zig");
const util = @import("util.zig");
const config = @import("config.zig");

const testing = std.testing;

args: *Arguments,
next_token: ?Token = null,

const Self = @This();

const TokenType = enum {
    // next_keyword,
    // year_keyword,
    // month_keyword,
    // week_keyword,
    // day_keyword,

    month_name,
    number,

    // ADD ALL DAY NAMES,
    // ADD ALL MONTHS,
};

const Token = union(TokenType) {
    month_name: Date.Month,
    number: u32,
};

pub const TokenError = Date.DateError || std.fmt.ParseIntError;

/// Parses what comes after the content
pub fn peek(self: *Self) TokenError!?Token {
    var buffer: [config.MAX_LINE]u8 = undefined;
    if (self.args.peek()) |arg| {
        if (util.isAlpha(arg[0])) {
            std.mem.copy(u8, buffer[0..], arg);
            util.toLower(buffer[0..arg.len]);
            self.next_token = Token { .month_name = try Date.nameToMonth(buffer[0..arg.len]) };
        } else {
            self.next_token = Token { .number = try std.fmt.parseInt(u32, arg, 10) };
        }
    } else self.next_token = null;
    return self.next_token;
}

/// Parses what comes after the content
pub fn next(self: *Self) TokenError!?Token {
    const token = self.next_token orelse try self.peek();
    _ = self.args.next();
    self.next_token = null;
    return token;
}

test "tokenizer.next" {
    const raw_arguments = [_][:0]const u8{"jan", "02"};
    var args = Arguments {
        .args = raw_arguments[0..],
    };

    var lexer = Self {
        .args = &args,
    };

    const month = try lexer.next();
    const number = try lexer.next();
    testing.expectEqual(Date.Month.January, month.?.month_name);
    testing.expectEqual(@as(u32, 02), number.?.number);
}
