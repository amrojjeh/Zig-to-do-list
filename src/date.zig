const std = @import("std");
const time = std.time;
const testing = std.testing;

year: ?u32 = null,
month: ?u32 = null,
day: ?u32 = null,
hour: ?u32 = null,
minute: ?u32 = null,
second: ?u32 = null,

const Self = @This();
const leap_year_months = [_]u32{31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
const normal_year_months = [_]u32{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

pub fn now() Self {
    return epochToDate(time.timestamp());
}

pub fn epochToDate(unix_time: i64) Self {
    const seconds_since_epoch: f64 = @intToFloat(f64, unix_time);
    const seconds_since_last_day = @rem(seconds_since_epoch, time.s_per_day);
    const minutes_since_last_day = seconds_since_last_day / 60;
    const hours_since_last_day = minutes_since_last_day / 60;

    const days_since_epoch = seconds_since_epoch / time.s_per_day;
    const years_since_epoch = @divTrunc(seconds_since_epoch, 31556926.0);
    const days_since_last_year = days_since_epoch - years_since_epoch * 365.24;

    const day_and_month = dayOfYearToDate(@floatToInt(u32, days_since_last_year), isLeapYear(@floatToInt(u32, years_since_epoch + 1970)));

    const year = @floatToInt(u32, years_since_epoch + 1970);
    const month = day_and_month.month;
    const day = day_and_month.day;
    const hour = @floatToInt(u32, hours_since_last_day);
    const minute = @floatToInt(u32, minutes_since_last_day) - hour * 60;
    const second = @floatToInt(u32, seconds_since_last_day) - hour * 3600 - minute * 60;
    return Self {
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
        .second = second,
    };
}

pub fn dayOfYearToDate(day_of_year: u32, is_leap: bool) Self {
    const months = if (is_leap) leap_year_months else normal_year_months;
    const month = @intCast(u32, indexBeforeSumExceedsValue(day_of_year, months[0..]) + 1);
    return Self {
        .month = month,
        .day = day_of_year - sum(months[0..month - 1]),
    };
}

/// If it's divisible by 4, then it's a leap year
/// Unless it's divisible by 100
/// Unless it's divisible by 400
pub fn isLeapYear(year: u32) bool {
    if (@rem(year, 4) == 0) {
        if (@rem(year, 100) == 0) {
            return @rem(year, 400) == 0;
        }
        return true;
    }
    return false;
}

pub fn isLeap(self: *Self) bool {
    return isLeapYear(self.year);
}

fn indexBeforeSumExceedsValue(val: u32, list: []const u32) usize {
    var s: u32 = 0;
    for (list) |v, i| {
        s += v;
        if (s >= val) {
            return i;
        }
    }
    return list.len - 1;
}

fn sum(list: []const u32) u32 {
    var s: u32 = 0;
    for (list) |val, i| {
        s += val;
    }
    return s;
}

test "Sum" {
    const list = [_]u32{1, 2, 3, 4, 5};
    const wow = sum(list[0..1]);
    testing.expectEqual(wow, 1);
}

test "Index before sum exceeds value" {
    const list = [_]u32{1, 2, 3, 4, 5};
    testing.expectEqual(@as(usize, 1), indexBeforeSumExceedsValue(2, list[0..]));
}

test "Day of year to date" {
    const date = dayOfYearToDate(30, false);
    testing.expectEqual(@as(u32, 1), date.month.?);
    testing.expectEqual(@as(u32, 30), date.day.?);

    const date2 = dayOfYearToDate(29 + 31, true);
    testing.expectEqual(@as(u32, 2), date2.month.?);
    testing.expectEqual(@as(u32, 29), date2.day.?);

    const date3 = dayOfYearToDate(29 + 31, false);
    testing.expectEqual(@as(u32, 3), date3.month.?);
    testing.expectEqual(@as(u32, 1), date3.day.?);
}

test "Epoch To Date" {
    const epoch: i32 = 1617849131;
    const date = epochToDate(epoch);

    const expectedDate = Self {
        .year = 2021,
        .month = 4,
        .day = 7,
        .hour = 2,
        .minute = 32,
        .second = 11,
    };

    testing.expectEqual(expectedDate, date);
}
