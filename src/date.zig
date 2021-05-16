const std = @import("std");
const util = @import("util.zig");
const time = std.time;
const testing = std.testing;

// Default would be read as 1970-01-01T00:00:00Z
days: i64 = 0,
hours: i64 = 0,
minutes: i64 = 0,
seconds: i64 = 0,

const Self = @This();
const leap_year_months = [_]i64{31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
const normal_year_months = [_]i64{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

pub const Month = enum {
    january,
    february,
    march,
    april,
    may,
    june,
    july,
    august,
    september,
    october,
    november,
    december,
};

pub const DayOfWeek = enum {
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
};

pub fn nameToMonth(name: []const u8) DateError!?Month {
    const names_full = comptime util.enumFieldNames(Month);
    if (name.len < 3) return DateError.AmbiguousAbbr;
    inline for (names_full) |month_name, index| {
        if (std.mem.startsWith(u8, month_name, name)) {
            return @intToEnum(Month, @intCast(u4, index));
        }
    }
    return null;
}

pub fn nameToDayOfWeek(name: []const u8) DateError!?DayOfWeek {
    const names_full = comptime util.enumFieldNames(DayOfWeek);
    if (name.len == 1 and (name[0] == 's' or name[1] == 't')) {
        return DateError.AmbiguousAbbr;
    }
    inline for (names_full) |day_name, index| {
        if (std.mem.startsWith(u8, day_name, name)) {
            return @intToEnum(DayOfWeek, @intCast(u4, index));
        }
    }
    return null;
}

pub const DateError = error {
    AmbiguousAbbr,
    InvalidDate,
};

/// m = 0 = January
/// d = 0 = 1st
pub fn init(y: u32, m: u32, d: u32) DateError!Self {
    if (m > 11) {
        return DateError.InvalidDate;
    }
    const months = if (isLeapYear(y)) leap_year_months else normal_year_months;

    if (d > months[m]) {
        return DateError.InvalidDate;
    }

    const days = @floatToInt(i64, @ceil(365.24 * @intToFloat(f64, (y - 1970)))) + if (m == 0) d else d + sum(months[0..m]);

    return Self {
        .days = days,
    };
}

/// Get the current date
pub fn now() Self {
    return epochToDate(time.timestamp());
}

/// Convert epoch to date
pub fn epochToDate(unix_time: i64) Self {
    const seconds_since_epoch: f64 = @intToFloat(f64, unix_time);
    const seconds_since_last_day = @rem(seconds_since_epoch, time.s_per_day);
    const minutes_since_last_day = seconds_since_last_day / 60;
    const hours_since_last_day = minutes_since_last_day / 60;

    const days_since_epoch = @floatToInt(i64, seconds_since_epoch / time.s_per_day);
    const hours = @floatToInt(i64, hours_since_last_day);
    const minutes = @floatToInt(i64, minutes_since_last_day) - hours * 60;
    const seconds = @floatToInt(i64, seconds_since_last_day) - hours * 3600 - minutes * 60;

    return Self {
        .days = days_since_epoch,
        .hours = hours,
        .minutes = minutes,
        .seconds = seconds,
    };
}

/// Return the same time but without hours, minutes, or seconds
/// Assumes the date is normalized
pub fn flatten(self: Self) Self {
    return Self {
        .days = self.days,
        .hours = 0,
        .minutes = 0,
        .seconds = 0,
    };
}

/// Convert date to epoch time
pub fn dateToEpoch(self: Self) i64 {
    const days = @intCast(i64, self.days);
    const hours = @intCast(i64, self.hours);
    const minutes = @intCast(i64, self.minutes);
    const seconds = @intCast(i64, self.seconds);

    return days * time.s_per_day + hours * time.s_per_hour + minutes * time.s_per_min + seconds;
}

/// If it's divisible by 4, then it's a leap year
/// Unless it's divisible by 100
/// Unless it's divisible by 400
pub fn isLeapYear(y: i64) bool {
    if (@rem(y, 4) == 0) {
        if (@rem(y, 100) == 0) {
            return @rem(y, 400) == 0;
        }
        return true;
    }
    return false;
}

/// Checks if the date falls under a leap year
pub fn isLeap(self: Self) bool {
    return isLeapYear(self.year());
}

/// Returns a slice of all the days in each month
pub fn yearMonths(self: Self) []const i64 {
    return if (self.isLeap()) leap_year_months[0..] else normal_year_months[0..];
}

/// Assumes normalized date
pub fn dayOfYear(self: Self) i64 {
    return self.days - self.dayToLastYear();
}

fn dayToLastYear(self: Self) i64 {
    return @floatToInt(i64, @intToFloat(f64, self.year() - 1970) * 365.24);
}

/// Get the year
/// 0 is 1 BC
/// Assumes normalized date
pub fn year(self: Self) u32 {
    return @floatToInt(u32, @divTrunc(@intToFloat(f64, self.days), 365.24)) + 1970;
}

/// Assumes normalized date
pub fn month(self: Self) usize {
    const months = self.yearMonths();
    const m = indexBeforeSumExceedsValue(self.dayOfYear(), months);

    return @intCast(usize, m); 
}

/// Assumes normalized date
/// Returns 1 if it's January 1st
pub fn day(self: Self) i64 {
    const index = self.month();
    return self.days - sum(self.yearMonths()[0..index]) - self.dayToLastYear();
}

/// Assumes normalized date
pub fn dayOfWeek(self: Self) DayOfWeek {
    // Epoch time is on a Thursday morning!
    // (I used this: https://www.timeanddate.com/date/weekday.html)

    return @intToEnum(DayOfWeek, @intCast(u3, @rem(3 + self.days, 7)));
}

/// Returns the name of the month
pub fn monthName(self: Self) []const u8 {
    return @tagName(@intToEnum(Month, @intCast(u4, self.month())));
}

/// Obviously not for adding dates.
/// Rather, it's to add a duration to date.
/// Example: add an hour for one hour later
/// or add 7 days for a week later
pub fn add(self: Self, other: Self) Self {
    const result = Self {
        .days = self.days + other.days,
        .hours = self.hours + other.hours,
        .minutes = self.minutes + other.minutes,
        .seconds = self.seconds + other.seconds,
    };

    return result.normalize();
}

/// Normalizes a date, so that all values are within their range
pub fn normalize(self: Self) Self {
    var days = self.days;
    var hours = self.hours;
    var minutes = self.minutes;
    var seconds = self.seconds;

    if (seconds > 59 or seconds < 0) {
        minutes += @divFloor(seconds, 60);
        seconds = @rem(seconds, 60);
        if (seconds < 0)
            seconds = 60 + seconds;
    }

    if (minutes > 59 or minutes < 0) {
        hours += @divFloor(minutes, 60);
        minutes = @rem(minutes, 60);
        if (minutes < 0)
            minutes = 60 + minutes;
    }

    if (hours > 23 or hours < 0) {
        days += @divFloor(hours, 24);
        hours = @rem(hours, 24);
        if (hours < 0)
            hours = 24 + hours;
    }

    return Self {
        .days = days,
        .hours = hours,
        .minutes = minutes,
        .seconds = seconds,
    };
}

/// Handles timezones
pub fn utc(self: Self, hours: i64, minutes: i64) Self {
    return self.add(Self {
        .hours = hours,
        .minutes = minutes,
        });
}

/// If result > 0, then self > other, aka later
/// if result == 0, then self == other, aka same
/// else, result < other, aka sooner
pub fn compare(self: Self, other: Self) i64 {
    return self.dateToEpoch() - other.dateToEpoch();
}

pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype
) !void {
    try writer.print("{s}: {s} {d}, {d}", .{@tagName(self.dayOfWeek()), self.monthName(), self.day(), self.year()});
}

fn indexBeforeSumExceedsValue(val: i64, list: []const i64) usize {
    var s: i64 = 0;
    for (list) |v, i| {
        s += v;
        if (s >= val) {
            return i;
        }
    }
    return list.len - 1;
}

fn sum(list: []const i64) i64 {
    var s: i64 = 0;
    for (list) |val, i| {
        s += val;
    }
    return s;
}

test "date.monthName" {
    const date = Self {
        .days = 18725,
        .hours = 13,
        .minutes = 44,
        .seconds = 08,
    };

    testing.expectEqualSlices(u8, "april", date.monthName());
}

test "date.nameToMonth" {
    const name = "sept";
    testing.expectEqual(Month.september, (try nameToMonth(name)).?);
}

test "date.init" {
    {
        const date = try init(1970, 0, 0);
        const expected = Self {};
        testing.expectEqual(expected, date);
    }

    {
        const date = try init(1970, 1, 1);
        const expected = Self { .days = 31 + 1 };
        testing.expectEqual(expected, date);
    }

    {
        testing.expectError(DateError.InvalidDate, init(1970, 12, 2));
        // testing.expectError(DateError.InvalidDate, init(1970, -1, 2));
        testing.expectError(DateError.InvalidDate, init(1970, 1, 31));
        // testing.expectError(DateError.InvalidDate, init(1970, 1, -1));
    }
}

test "date.Sum" {
    const list = [_]i64{1, 2, 3, 4, 5};
    const wow = sum(list[0..1]);
    testing.expectEqual(wow, 1);
}

test "date.Index before sum exceeds value" {
    const list = [_]i64{1, 2, 3, 4, 5};
    testing.expectEqual(@as(usize, 1), indexBeforeSumExceedsValue(2, list[0..]));
}

test "date.Epoch To Date" {
    const epoch: i64 = 1617889448;
    const date = epochToDate(epoch);

    const expectedDate = Self {
        .days = 18725,
        .hours = 13,
        .minutes = 44,
        .seconds = 08,
    };

    testing.expectEqual(expectedDate, date);
}

test "date.Normalize" {
    {
        const date = Self {
            .days = 18725,
            .hours = 25,
        };

        const normalized = date.normalize();
        const expected_date = Self {
            .days = 18725 + 1,
            .hours = 1,
        };

        testing.expectEqual(expected_date, normalized);
    }
    {
        const date = Self {
            .days = 18725,
            .hours = -1,
        };

        const normalized = date.normalize();
        const expected_date = Self {
            .days = 18725 - 1,
            .hours = 23,
        };

        testing.expectEqual(expected_date, normalized);
    }
}

test "date.Date to epoch" {
    const date = Self {
        .days = 18725,
        .hours = 13,
        .minutes = 44,
        .seconds = 08,
    };
    const expectedEpoch: i64 = 1617889448;
    testing.expectEqual(expectedEpoch, date.dateToEpoch());
}

test "date.Adding date" {
    const date = Self {
        .days = 18725,
        .hours = 13,
        .minutes = 44,
        .seconds = 08,
    };

    const duration = Self {
        .days = 6,
        .hours = 25,
    };

    const result = date.add(duration);

    const expected = Self {
        .days = 18725 + 7,
        .hours = 13 + 1,
        .minutes = 44,
        .seconds = 08,
    };

    testing.expectEqual(expected, result);
}

test "date.Get year, month, and day" {
    const date = Self {
        .days = 18726,
        .hours = 13,
        .minutes = 44,
        .seconds = 08,
    };

    testing.expectEqual(@as(i64, 2021), date.year());
    testing.expectEqual(@as(usize, 3), date.month());
    testing.expectEqual(@as(i64, 9), date.day());
    testing.expectEqual(Month.april, @intToEnum(Month, @intCast(u4, date.month())));
}

test "date.Timezones" {
    const date = Self {
        .days = 18726,
        .hours = 1,
    };

    // No daylight savings
    const cst_time = date.utc(-6, 0);
    const expected_date = Self {
        .days = 18726 - 1,
        .hours = 19,
    };

    testing.expectEqual(expected_date, cst_time);
    testing.expectEqual(@as(i64, 2021), cst_time.year());
    testing.expectEqual(@as(usize, 3), cst_time.month());
    testing.expectEqual(@as(i64, 8), cst_time.day());
}
