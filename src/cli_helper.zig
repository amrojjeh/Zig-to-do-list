const std = @import("std");
const Arguments = @import("args.zig");

const Styles = struct {
    pub const BOLD = "\x1B[1m";
    pub const FAIL = "\x1B[91m" ++ BOLD;
    pub const SUCCESS = "\x1B[32m" ++ BOLD;
    pub const NORMAL = "\x1B[37m" ++ BOLD;

    pub const STRIKE = "\x1B[9m";

    pub const RESET = "\x1B[0m";
};

fn getWriter() std.fs.File.Writer {
    return std.io.getStdOut().writer();
}

/// Prints a failed statement. Automatic newline.
pub fn printFail(comptime str: []const u8, args: anytype) !void {
    try print(Styles.FAIL, str, args);
}

pub fn printSuccess(comptime str: []const u8, args: anytype) !void {
    try print(Styles.SUCCESS, str, args);
}

pub fn printNormal(comptime str: []const u8, args: anytype) !void {
    try print(Styles.NORMAL, str, args);
}

fn print(style: []const u8, comptime str: []const u8, args: anytype) !void {
    const writer = getWriter();
    try writer.print("{s}", .{style});
    try writer.print(str, args);
    try writer.print("{s}\n", .{Styles.RESET});    
}

pub fn nextArgIndex(comptime T: type, args: *Arguments) !?T {
    const str_num = args.next() orelse return 1;
    return std.fmt.parseInt(T, str_num, 10) catch |err| blk: {
        try printFail("{s} is not a number.", .{str_num});
        break :blk null;
    };
}

