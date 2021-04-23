const std = @import("std");
const testing = std.testing;

pub fn toLower(buffer: []u8) void {
    for (buffer) |*letter| {    
        if (isUpper(letter.*)) {
            letter.* = letter.* + 32;
        }
    }
}

pub fn toUpper(buffer: []u8) void {
    for (buffer) |*letter| {
        if (isLower(letter.*)) {
            letter.* = letter.* - 32;
        }
    }
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
    buffer[str.len] = 0;
    toLower(buffer[0..str.len]);
    testing.expect(std.mem.eql(u8,"this is a test.", buffer[0..str.len:0]));
    toUpper(buffer[0..str.len]);
    testing.expect(std.mem.eql(u8,"THIS IS A TEST.", buffer[0..str.len:0]));
}
