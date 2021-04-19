const std = @import("std.zig");
const Todo = @import("todo.zig");

const Allocator = std.mem.Allocator;

const TokenType = enum {
    content, // End is marked by ;
    start_of,
    end_of,
    next,
    iso_date,

    day,
    week,
    month,
    year,
}

const Token = struct {
    value: []const u8,
    token_type: TokenType,
}

pub fn tokenize(alloc: *Allocator, buffer: []const u8) []Token {
    const tokens = std.mem.tokenize(buffer, " ");
    while (tokens.next()) |val| {
        // {x} vs {X} for lowercase and uppwercase zig fmt
    }

}
