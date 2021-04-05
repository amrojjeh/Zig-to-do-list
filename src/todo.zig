const std = @import("std");

const Dir = std.fs.Dir;
const File = std.fs.File;
const OpenDirOptions = Dir.OpenDirOptions;
const OpenFlags = File.OpenFlags;
const CreateFlags = File.CreateFlags;
const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

pub const Todo = struct {
    todo_file: File,

    const Self = @This();

    pub fn root(file_name: []const u8) !Self {
        var buffer: [MAX_PATH_BYTES]u8 = undefined;
        const root_path = try std.fs.selfExeDirPath(&buffer);

        var todo_dir = try std.fs.cwd().makeOpenPath(root_path, OpenDirOptions{});
        defer todo_dir.close();

        const todo_file = todo_dir.openFile(file_name, OpenFlags{ .write = true }) catch
            try todo_dir.createFile(file_name, CreateFlags{});

        return Self{
            .todo_file = todo_file,
        };
    }

    pub fn close(self: *Self) void {
        self.todo_file.close();
    }
};
