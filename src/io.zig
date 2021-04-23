const std = @import("std");
const config = @import("config.zig");
const Todo = @import("todo.zig");

const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const File = std.fs.File;
const OpenDirOptions = Dir.OpenDirOptions;
const OpenFlags = File.OpenFlags;
const CreateFlags = File.CreateFlags;

pub const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

pub fn getRootDir() !Dir {
    var buffer: [MAX_PATH_BYTES]u8 = undefined;
    const root_path = try std.fs.selfExeDirPath(&buffer);
    return try std.fs.cwd().makeOpenPath(root_path, OpenDirOptions{});
}

/// Save Todo to a file
pub fn save(todo: Todo) !void {
    var dir = try getRootDir();
    const file = try dir.createFile(config.FILE_NAME, CreateFlags{});
    var buffer: [config.MAX_LINE * 100]u8 = undefined;
    var string = try todo.str(buffer[0..]);
    _ = try file.write(string);
}

/// Parse Todo from file. Returns a null Todo if file is not found.
pub fn read(allocator: *Allocator) !?Todo {
    var buffer = try allocator.alloc(u8, config.MAX_LINE * 100);
    var dir = try getRootDir();
    const file = dir.openFile(config.FILE_NAME, OpenFlags {}) catch return null;
    const tail = try file.reader().read(buffer);
    buffer[tail] = 0;
    return try Todo.init_str(allocator, buffer[0..tail:0]);
}

pub fn delete(self: Self) Dir.DeleteFileError!void {
    var dir = try getRootDir();
    try dir.deleteFile(config.FILE_NAME);
}
