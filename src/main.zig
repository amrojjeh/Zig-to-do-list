const std = @import("std");
const cli = @import("cli.zig");
const config = @import("config.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    config.FILE_NAME = getExeName(args[0]);

    try cli.execute(allocator, args[1..]);
}

fn getExeName(path: []const u8) []const u8 {
    var i: usize = path.len - 1;
    while (i != 0 and path[i] != '\\') : (i -= 1) { }
    return path[i+1..path.len - 4]; // to remove the .exe
}
