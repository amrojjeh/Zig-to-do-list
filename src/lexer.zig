const std = @import("std");
const Date = @import("date.zig");
const Arguments = @import("args.zig");
const util = @import("util.zig");

const testing = std.testing;

args: *Arguments,

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
pub fn nextToken(self: Self) TokenError!?Token {
    // A single line can only be 100 characters long
    var buffer: [100]u8 = undefined;
    if (self.args.next()) |arg| {
        if (util.isAlpha(arg[0])) {
            std.mem.copy(u8, buffer[0..], arg);
            util.toLower(buffer[0..arg.len]);
            return Token { .month_name = try Date.nameToMonth(buffer[0..arg.len]) };
        } else {
            return Token { .number = try std.fmt.parseInt(u32, arg, 10) };
        }
    } else return null;
}

test "tokenizer.nextToken" {
    const raw_arguments = [_][:0]const u8{"jan", "02"};
    var args = Arguments {
        .args = raw_arguments[0..],
    };

    var lexer = Self {
        .args = &args,
    };

    const month = try lexer.nextToken();
    const number = try lexer.nextToken();
    testing.expectEqual(Date.Month.January, month.?.month_name);
    testing.expectEqual(@as(u32, 02), number.?.number);
}
