const std = @import("std");
const Todo = @import("todo.zig");

const Dir = std.fs.Dir;
const File = std.fs.File;
const OpenDirOptions = Dir.OpenDirOptions;
const CreateFlags = File.CreateFlags;

pub const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

pub fn getRootDir() !Dir {
    var buffer: [MAX_PATH_BYTES]u8 = undefined;
    const root_path = try std.fs.selfExeDirPath(&buffer);
    return try std.fs.cwd().makeOpenPath(root_path, OpenDirOptions{});
}

pub fn save(file_name: []const u8, todo: Todo) !void {
    var dir = try getRootDir();
    const file = try dir.createFile(file_name, CreateFlags{});
    _ = try file.write("Amazing test this is");
}

// TODO: reader. Should return Todo
pub fn read() void {
}

pub fn delete(file_name: []const u8, self: Self) Dir.DeleteFileError!void {
    var dir = try getRootDir();
    try dir.deleteFile(file_name);
}
