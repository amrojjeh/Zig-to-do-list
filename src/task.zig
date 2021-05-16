const std = @import("std");
const Date = @import("date.zig");
const config = @import("config.zig");
const util = @import("util.zig");
const Styles = @import("cli.zig").Styles;

content: []const u8,
due: ?Date,
completed: bool,
index: ?usize = null,

const Self = @This();

/// The higher the number, the less "urgent" the task is
pub fn compare(self: Self, other: Self) i64 {
    // If this isn't completed but the other is, then this is higher value
    if (!self.completed and other.completed) {
        return -1;
    } else if (self.completed and !other.completed) {
        return 1;
    }

    // .completed is now assumed to be the same

    // Tasks without due dates should be ranked higher than ones with dates
    if (self.due) |d| {
        if (other.due) |d2| {
            return d.compare(d2);
        }
        return -1;
    }

    // self.due must equal null

    if (other.due != null) {
        return 1;
    }

    return 0;
}

pub const HashtagCounter = struct {
    names: [][]const u8,
    counter: []util.Pair(u64),
    len: usize = 0,

    // Returns true if it made a new entry.
    pub fn add(self: *HashtagCounter, name: []const u8, task: Self) bool {
        for (self.names[0..self.len]) |n, i| {
            if (util.eqlNoCase(u8, n, name)) {
                if (task.completed) {
                    self.counter[i].a += 1;
                } else self.counter[i].b += 1;
                return false;
            }
        }

        self.names[self.len] = name;
        self.counter[self.len] = util.Pair(u64) {
            .a = if (task.completed) 1 else 0,
            .b = if (task.completed) 0 else 1,
        };
        self.len += 1;
        return true;
    }
};

pub const HashtagIterator = struct {
    words: std.mem.TokenIterator,
    counter: HashtagCounter,
    task: Self,

    pub fn next(self: *HashtagIterator) ?[]const u8 {
        while (self.words.next()) |w| {
            if (isHashtag(w)) {
                if (self.counter.add(w, self.task)) {
                    return w;
                } else return self.next();
            }
        }
        return null;
    }
};

/// Returns an iterator of hashtags. Does not produce duplicates.
pub fn hashtags(self: Self, name_buffer: [][]const u8, counter: []util.Pair(u64)) HashtagIterator {
    return HashtagIterator {
        .words = std.mem.tokenize(self.content, " "),
        .counter = HashtagCounter {
            .names = name_buffer,
            .counter = counter,
        },
        .task = self,
    };
}

pub fn isHashtag(word: []const u8) bool {
    return word[0] == '#' and word.len > 1;
}


test "task.compare not completed" {
    { // Two equal dates
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 15),
            .completed = false,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 15),
            .completed = false,
        };

        std.testing.expectEqual(@as(i64, 0), a.compare(b));
    }

    { // a is more urgent than b
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 15),
            .completed = false,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 16),
            .completed = false,
        };

        std.testing.expect(a.compare(b) < 0);
    }

    { // a is less urgent than b
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 17),
            .completed = false,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 15),
            .completed = false,
        };

        std.testing.expect(a.compare(b) > 0);
    }
}

test "task.compare completed" {
    { // Two equal dates
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 15),
            .completed = true,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 15),
            .completed = true,
        };

        std.testing.expectEqual(@as(i64, 0), a.compare(b));
    }

    { // a is more urgent than b
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 15),
            .completed = true,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 16),
            .completed = true,
        };

        std.testing.expect(a.compare(b) < 0);
    }

    { // a is less urgent than b
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 17),
            .completed = true,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 15),
            .completed = true,
        };

        std.testing.expect(a.compare(b) > 0);
    }
}

test "test.compare completed & not completed" {
    { // Equal dates - a is less urgent than b
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 15),
            .completed = true,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 15),
            .completed = false,
        };

        std.testing.expect(a.compare(b) > 0);
    }

    { // a is more urgent than b, but a is completed
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 15),
            .completed = true,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 16),
            .completed = false,
        };

        std.testing.expect(a.compare(b) > 0);
    }

    { // a is less urgent than b, and a is completed
        const a = Self {
            .content = "a",
            .due = try Date.init(2021, 4, 17),
            .completed = true,
        };

        const b = Self {
            .content = "b",
            .due = try Date.init(2021, 4, 15),
            .completed = false,
        };

        std.testing.expect(a.compare(b) > 0);
    }

    { // Case test
        const a = Self {
            .content = "Chemistry #exam",
            .due = try Date.init(2021, 4, 30),
            .completed = false,
        };

        const b = Self {
            .content = "book a vacation",
            .due = try Date.init(2021, 4, 16),
            .completed = true,
        };

        std.testing.expect(a.compare(b) < 0);
    }
}
