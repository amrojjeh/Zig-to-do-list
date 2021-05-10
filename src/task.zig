const std = @import("std");
const Date = @import("date.zig");
const config = @import("config.zig");

content: []const u8,
due: ?Date,
completed: bool,

const Self = @This();

pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype
) !void {
    var buffer: [config.MAX_LINE]u8 = undefined;
    try writer.print("{s}", .{self.str(&buffer, true)});
}

pub fn str(self: Self, buffer: []u8, checkmark: bool) ![]u8 {
    const completed_str = blk: {
        if (checkmark) {
            break :blk if (self.completed) "✅ " else "❌ ";
        } else break :blk "";
    };

    return blk: {
        if (self.due) |date| {
            break :blk try std.fmt.bufPrint(buffer, "{s}{s} 📅 {any}", .{completed_str, self.content, date});
        }
        break :blk try std.fmt.bufPrint(buffer, "{s} {s}", .{completed_str, self.content});
    };
}

pub fn hashtags(self: Self, buffer: [][]const u8) ?[][]const u8 {
    var words = std.mem.tokenize(self.content, " ");
    var i: usize = 0;
    while (words.next()) |word| {
        if (isHashtag(word)) {
            buffer[i] = word[1..];
            i += 1;
        }
    }

    if (i == 0) {
        return null;
    }

    return buffer[0..i];
}

fn isHashtag(word: []const u8) bool {
    return word[0] == '#' and word.len > 1;
}

test "task.hashtags" {
    {
        const task = Self {
            .content = "No hashtags :(",
            .due = null,
            .completed = false,
        };

        var buffer: [100][]const u8 = undefined;
        const hashtag_words = task.hashtags(&buffer);
        std.testing.expectEqual(@as(?[][]const u8, null), hashtag_words);
    }

    {
        const task = Self {
            .content = "Some #hashtags and #exams :(",
            .due = null,
            .completed = false,
        };

        var buffer: [100][]const u8 = undefined;
        const hashtag_words = task.hashtags(&buffer);
        var expected = [_][]const u8{"hashtags", "exams"};
        for (expected) |e, i| {
            std.testing.expect(std.mem.eql(u8, e, hashtag_words.?[i]));
        }
    }
}
