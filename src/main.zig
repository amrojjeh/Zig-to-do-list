const std = @import("std");
const cli = @import("cli.zig");
const config = @import("config.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    config.FILE_NAME = try getExeName(&buffer);

    try cli.execute(allocator, args[1..]);
}

fn getExeName(buffer: []u8) ![]const u8 {
    const full_path = try std.fs.selfExePath(buffer);
    const dir_path = try std.fs.selfExeDirPath(buffer[full_path.len..]);
    return buffer[dir_path.len+1..full_path.len-4];
}
