const std = @import("std");
const Date = @import("date.zig");
const config = @import("config.zig");
const Styles = @import("cli.zig").Styles;

content: []const u8,
due: ?Date,
completed: bool,

const Self = @This();

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

pub fn isHashtag(word: []const u8) bool {
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
