const std = @import("std");

const Dir = std.fs.Dir;
const File = std.fs.File;
const OpenDirOptions = Dir.OpenDirOptions;
const OpenFlags = File.OpenFlags;
const CreateFlags = File.CreateFlags;

pub const Todo = struct {
    todo_file: File,
    todo_dir: Dir,
    file_name: []const u8,

    const Self = @This();
    pub const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

    pub fn root(file_name: []const u8) !Self {
        var buffer: [MAX_PATH_BYTES]u8 = undefined;
        const root_path = try std.fs.selfExeDirPath(&buffer);

        var todo_dir = try std.fs.cwd().makeOpenPath(root_path, OpenDirOptions{});

        const todo_file = todo_dir.openFile(file_name, OpenFlags{ .write = true }) catch
            try todo_dir.createFile(file_name, CreateFlags{});

        return Self{
            .todo_file = todo_file,
            .todo_dir = todo_dir,
            .file_name = file_name,
        };
    }

    pub fn delete(self: *Self) Dir.DeleteFileError!void {
        try self.todo_dir.deleteFile(self.file_name);
    }

    pub fn close(self: *Self) void {
        self.todo_dir.close();
        self.todo_file.close();
    }
};
