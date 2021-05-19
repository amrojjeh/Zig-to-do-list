const std = @import("std");

pub fn enumFieldNames(comptime e: type) [@typeInfo(e).Enum.fields.len][]const u8 {
    const len = @typeInfo(e).Enum.fields.len;
    var names: [len][]const u8 = undefined;
    inline for (@typeInfo(e).Enum.fields) |f, i| {
        names[i] = f.name;
    }
    return names;
}

test "util.enumFieldNames" {
    const e = enum {
        cool,
        amazing,
    };

    const names = comptime enumFieldNames(e);
    std.debug.assert(std.mem.eql(u8, names[0], "cool"));
    std.debug.assert(std.mem.eql(u8, names[1], "amazing"));
}

pub fn unionCreateFieldsWithType(comptime u: type, comptime t: type, comptime val: t) []u {
    const len = @typeInfo(u).Union.fields.len;
    var fields: [len]u = undefined;
    var index: comptime_int = 0;
    inline for (@typeInfo(u).Union.fields) |f, i| {
        if (f.field_type == t) {
            fields[index] = @unionInit(u, f.name, val);
            index += 1;
        }
    }
    return fields[0..index];
}

pub fn eqlNoCase(comptime T: type, a: []const T, b:[]const T) bool {
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a) |item, index| {
        if (toLower(item) != toLower(b[index])) return false;
    }
    return true;
}

pub fn indexOfNoCase(comptime T: type, haystack: []const T, needle: []const T) ?usize {
    var i: usize = 0;
    const end = haystack.len - needle.len;
    while (i <= end) : (i += 1) {
        if (eqlNoCase(T, haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

pub fn Pair(comptime T: type) type {
    return struct {
        a: T,
        b: T,
    };
}

pub fn tailQueueLen(tail_queue: anytype) usize {
    var it = tail_queue.first;
    var i: usize = 0;
    while (it) |node| : ({it = node.next; i += 1;}) {}
    return i;
}

pub fn toLowerStr(buffer: []u8) void {
    for (buffer) |*letter| {    
        letter.* = toLower(letter.*);
    }
}

pub fn toUpperStr(buffer: []u8) void {
    for (buffer) |*letter| {
        letter.* = toUpper(letter.*);
    }
}

pub fn toLower(char: u8) u8 {
    if (isUpper(char)) {
        return char + 32;
    } else return char;
}

pub fn toUpper(char: u8) u8 {
    if (isLower(char)) {
        return char - 32;
    } else return char;
}

pub fn isAlpha(char: u8) bool {
    return isUpper(char) or isLower(char);
}

pub fn isUpper(char: u8) bool {
    return 'A' <= char and char <= 'Z';
}

pub fn isLower(char: u8) bool {
    return 'a' <= char and char <= 'z';
}

test "util.toLower and util.toUpper" {
    const str = "THIS IS A TesT.";
    var buffer: [100]u8 = undefined;
    std.mem.copy(u8, buffer[0..str.len], str);
    toLowerStr(buffer[0..str.len]);
    std.testing.expect(std.mem.eql(u8,"this is a test.", buffer[0..str.len]));
    toUpperStr(buffer[0..str.len]);
    std.testing.expect(std.mem.eql(u8,"THIS IS A TEST.", buffer[0..str.len]));
}
