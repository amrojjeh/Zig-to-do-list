args: []const [:0]const u8,
next_arg: usize = 0,

const Self = @This();

pub fn next(self: *Self) ?[:0]const u8 {
    if (self.isOutOfArgs()) {
        return null;
    }

    self.next_arg += 1;
    return self.args[self.next_arg - 1];
}

pub fn isOutOfArgs(self: Self) bool {
    return self.args.len - self.next_arg <= 0;
}

pub fn peekNext(self: Self) ?[:0]const u8 {
    return self.args[self.next_arg];
}

pub fn len(self: Self) usize {
    return self.args.len;
}
