#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Time::Local;
use lib '../lib/calcms/';
use utf8;

# Mock config module if it doesn't exist
BEGIN {
    unless (eval { require config; 1 }) {
        package config;
        our %config = (
            date => {
                language => 'en',
                day_starting_hour => 4,
            }
        );
        $INC{'config.pm'} = 1;
    }
}

# Mock TimeCalcError exception class
BEGIN {
    package TimeCalcError;
    use base 'Error::Simple';
    sub throw {
        my ($class, %args) = @_;
        die bless { error => $args{error} }, $class;
    }
    $INC{'TimeCalcError.pm'} = 1;
    package main;
}

# Load the time module
BEGIN {
    use_ok('time') || BAIL_OUT("Cannot load time module");
}

# Test datetime_to_array
subtest 'datetime_to_array' => sub {
    my $result = time::datetime_to_array('2024-12-18 14:30:45');
    is_deeply($result, [2024, 12, 18, 14, 30, 45], 'Parse full datetime');
    
    $result = time::datetime_to_array('2024-01-05 09:05:03');
    is_deeply($result, [2024, '01', '05', '09', '05', '03'], 'Parse datetime with single digit month/day');
    
    $result = time::datetime_to_array('2024-12-18T14:30:45');
    is_deeply($result, [2024, 12, 18, 14, 30, 45], 'Parse ISO8601 format with T separator');
    
    $result = time::datetime_to_array('2024-12-18');
    is_deeply($result, [2024, 12, 18, '00', '00', '00'], 'Parse date only (time defaults to 00:00:00)');
    
    $result = time::datetime_to_array('');
    is($result, undef, 'Empty string returns undef');
    
    done_testing();
};

# Test date_to_array
subtest 'date_to_array' => sub {
    my $result = time::date_to_array('2024-12-18');
    is_deeply($result, [2024, 12, 18], 'Parse date');
    
    $result = time::date_to_array('2024-01-05');
    is_deeply($result, [2024, '01', '05'], 'Parse date with single digit month/day');
    
    $result = time::date_to_array('invalid');
    is($result, undef, 'Invalid date returns undef');
    
    done_testing();
};

# Test array_to_datetime
subtest 'array_to_datetime' => sub {
    my $result = time::array_to_datetime([2024, 12, 18, 14, 30, 45]);
    is($result, '2024-12-18 14:30:45', 'Convert array to datetime');
    
    $result = time::array_to_datetime(2024, 12, 18, 14, 30, 45);
    is($result, '2024-12-18 14:30:45', 'Convert individual values to datetime');
    
    $result = time::array_to_datetime(2024, 1, 5, 9, 5, 3);
    is($result, '2024-01-05 09:05:03', 'Properly pad single digits');
    
    done_testing();
};

# Test array_to_date
subtest 'array_to_date' => sub {
    my $result = time::array_to_date([2024, 12, 18]);
    is($result, '2024-12-18', 'Convert array to date');
    
    $result = time::array_to_date(2024, 12, 18);
    is($result, '2024-12-18', 'Convert individual values to date');
    
    $result = time::array_to_date(2024, 1, 5);
    is($result, '2024-01-05', 'Properly pad single digits');
    
    done_testing();
};

# Test array_to_time
subtest 'array_to_time' => sub {
    my $result = time::array_to_time([2024, 12, 18, 14, 30, 45]);
    is($result, '14:30:45', 'Extract time from datetime array');
    
    $result = time::array_to_time(9, 5, 3);
    is($result, '09:05:03', 'Convert individual values with padding');
    
    done_testing();
};

# Test array_to_time_hm
subtest 'array_to_time_hm' => sub {
    my $result = time::array_to_time_hm([2024, 12, 18, 14, 30, 45]);
    is($result, '14:30', 'Extract time HH:MM from datetime array');
    
    $result = time::array_to_time_hm(9, 5);
    is($result, '09:05', 'Convert individual values with padding');
    
    done_testing();
};

# Test datetime_to_date
subtest 'datetime_to_date' => sub {
    my $result = time::datetime_to_date('2024-12-18 14:30:45');
    is($result, '2024-12-18', 'Extract date from datetime');
    
    $result = time::datetime_to_date('2024-1-5 9:5:3');
    is($result, '2024-01-05', 'Extract and format date with single digits');
    
    $result = time::datetime_to_date('');
    is($result, undef, 'Empty string returns undef');
    
    done_testing();
};

# Test datetime_to_time
subtest 'datetime_to_time' => sub {
    my $dt = '2024-12-18 14:30:45';
    my $time = time::datetime_to_time($dt);
    ok($time > 0, 'Convert datetime to unix timestamp');
    
    # Verify round-trip conversion
    my $dt_back = time::time_to_datetime($time);
    is($dt_back, $dt, 'Round-trip datetime -> time -> datetime');
    
    eval { time::datetime_to_time('invalid') };
    ok($@, 'Invalid datetime throws error');
    like($@->{error}, qr/no valid date time/, 'Error message contains expected text');
    
    done_testing();
};

# Test time_to_datetime
subtest 'time_to_datetime' => sub {
    my $time = Time::Local::timelocal(45, 30, 14, 18, 11, 2024-1900);
    my $result = time::time_to_datetime($time);
    is($result, '2024-12-18 14:30:45', 'Convert unix time to datetime');
    
    # Test with current time (no argument)
    $result = time::time_to_datetime();
    like($result, qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, 'Current time format');
    
    done_testing();
};

# Test time_to_date
subtest 'time_to_date' => sub {
    my $time = Time::Local::timelocal(45, 30, 14, 18, 11, 2024-1900);
    my $result = time::time_to_date($time);
    is($result, '2024-12-18', 'Convert unix time to date');
    
    done_testing();
};

# Test add_days_to_datetime
subtest 'add_days_to_datetime' => sub {
    my $result = time::add_days_to_datetime('2024-12-18 14:30:45', 5);
    is($result, '2024-12-23 14:30:45', 'Add 5 days');
    
    $result = time::add_days_to_datetime('2024-12-18 14:30:45', -5);
    is($result, '2024-12-13 14:30:45', 'Subtract 5 days');
    
    $result = time::add_days_to_datetime('2024-12-18 14:30:45', 0);
    is($result, '2024-12-18 14:30:45', 'Add 0 days (no change)');
    
    # Test month rollover
    $result = time::add_days_to_datetime('2024-12-30 14:30:45', 5);
    is($result, '2025-01-04 14:30:45', 'Add days across year boundary');
    
    done_testing();
};

# Test add_hours_to_datetime
subtest 'add_hours_to_datetime' => sub {
    my $result = time::add_hours_to_datetime('2024-12-18 14:30:45', 3);
    is($result, '2024-12-18 17:30:45', 'Add 3 hours');
    
    $result = time::add_hours_to_datetime('2024-12-18 22:30:45', 5);
    is($result, '2024-12-19 03:30:45', 'Add hours across day boundary');
    
    $result = time::add_hours_to_datetime('2024-12-18 14:30:45', -2);
    is($result, '2024-12-18 12:30:45', 'Subtract hours');
    
    done_testing();
};

# Test add_minutes_to_datetime
subtest 'add_minutes_to_datetime' => sub {
    my $result = time::add_minutes_to_datetime('2024-12-18 14:30:45', 45);
    is($result, '2024-12-18 15:15:45', 'Add 45 minutes');
    
    $result = time::add_minutes_to_datetime('2024-12-18 23:50:00', 20);
    is($result, '2024-12-19 00:10:00', 'Add minutes across day boundary');
    
    $result = time::add_minutes_to_datetime('2024-12-18 14:30:45', -15);
    is($result, '2024-12-18 14:15:45', 'Subtract minutes');
    
    done_testing();
};

# Test add_days_to_date
subtest 'add_days_to_date' => sub {
    my $result = time::add_days_to_date('2024-12-18', 7);
    is($result, '2024-12-25', 'Add 7 days to date');
    
    $result = time::add_days_to_date('2024-12-25', 10);
    is($result, '2025-01-04', 'Add days across year boundary');
    
    done_testing();
};

# Test date_cond
subtest 'date_cond' => sub {
    my $result = time::date_cond('2024-12-18');
    is($result, '2024-12-18', 'Valid date unchanged');
    
    $result = time::date_cond('2024-1-5');
    is($result, '2024-01-05', 'Single digit month/day formatted');
    
    $result = time::date_cond('today');
    is($result, 'today', 'Special keyword "today" preserved');
    
    $result = time::date_cond('');
    is($result, '', 'Empty string returns empty');
    
    $result = time::date_cond('invalid');
    is($result, '', 'Invalid date returns empty');
    
    done_testing();
};

# Test time_cond
subtest 'time_cond' => sub {
    my $result = time::time_cond('14:30:45');
    is($result, '14:30:45', 'Valid time with seconds');
    
    $result = time::time_cond('9:5');
    is($result, '09:05:00', 'Single digit hour/minute formatted, seconds added');
    
    $result = time::time_cond('');
    is($result, '', 'Empty string returns empty');
    
    $result = time::time_cond('now');
    like($result, qr/^\d{2}:00$/, 'Special keyword "now" returns current hour');
    
    done_testing();
};

# Test check_date
subtest 'check_date' => sub {
    my $result = time::check_date('2024-12-18');
    is($result, '2024-12-18', 'ISO format date');
    
    $result = time::check_date('18.12.2024');
    is($result, '2024-12-18', 'German format converted to ISO');
    
    $result = time::check_date('today');
    is($result, 'today', 'Special keyword preserved');
    
    $result = time::check_date('tomorrow');
    is($result, 'tomorrow', 'Special keyword preserved');
    
    $result = time::check_date('');
    is($result, '', 'Empty string returns empty');
    
    $result = time::check_date('invalid');
    is($result, -1, 'Invalid date returns -1');
    
    done_testing();
};

# Test check_time
subtest 'check_time' => sub {
    my $result = time::check_time('14:30');
    is($result, '14:30', 'Valid time');
    
    $result = time::check_time('now');
    is($result, 'now', 'Special keyword preserved');
    
    $result = time::check_time('');
    is($result, '', 'Empty string returns empty');
    
    eval { time::check_time('invalid') };
    ok($@, 'Invalid time throws error');
    
    done_testing();
};

# Test check_datetime
subtest 'check_datetime' => sub {
    my $result = time::check_datetime('2024-12-18 14:30');
    is($result, '2024-12-18T14:30', 'Space separator converted to T');
    
    $result = time::check_datetime('2024-12-18T14:30');
    is($result, '2024-12-18T14:30', 'T separator preserved');
    
    $result = time::check_datetime('2024-1-5 9:5');
    is($result, '2024-01-05T09:05', 'Single digits formatted');
    
    eval { time::check_datetime('invalid') };
    ok($@, 'Invalid datetime throws error');
    
    done_testing();
};

# Test epoch_to_utc_datetime
subtest 'epoch_to_utc_datetime' => sub {
    my $result = time::epoch_to_utc_datetime(1703000000);
    like($result, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/, 'UTC datetime format');
    warn $result;
    is($result, '2023-12-19T15:33:20Z', 'Specific epoch converts correctly');
    
    $result = time::epoch_to_utc_datetime(undef);
    is($result, undef, 'undef input returns undef');
    
    done_testing();
};

# Test getDurations
subtest 'getDurations' => sub {
    my $durations = time::getDurations();
    is(ref($durations), 'ARRAY', 'Returns array reference');
    ok(scalar(@$durations) > 0, 'Array is not empty');
    is($durations->[0], 0, 'First duration is 0');
    is($durations->[-1], 1440, 'Last duration is 1440 (24 hours)');
    
    done_testing();
};

# Test getWeekdayNames
subtest 'getWeekdayNames' => sub {
    my $names_en = time::getWeekdayNames('en');
    is(scalar(@$names_en), 7, 'Returns 7 weekday names');
    is($names_en->[0], 'Monday', 'First day is Monday (en)');
    
    my $names_de = time::getWeekdayNames('de');
    is($names_de->[0], 'Montag', 'First day is Montag (de)');
    
    my $names_default = time::getWeekdayNames();
    is_deeply($names_default, $names_en, 'Default is English');
    
    done_testing();
};

# Test getWeekdayNamesShort
subtest 'getWeekdayNamesShort' => sub {
    my $names_en = time::getWeekdayNamesShort('en');
    is(scalar(@$names_en), 7, 'Returns 7 abbreviated weekday names');
    is($names_en->[0], 'Mo', 'First day abbreviation is Mo (en)');
    
    my $names_de = time::getWeekdayNamesShort('de');
    is($names_de->[0], 'Mo', 'First day abbreviation is Mo (de)');
    
    done_testing();
};

# Test getMonthNames
subtest 'getMonthNames' => sub {
    my $names_en = time::getMonthNames('en');
    is(scalar(@$names_en), 12, 'Returns 12 month names');
    is($names_en->[0], 'January', 'First month is January (en)');
    
    my $names_de = time::getMonthNames('de');
    is($names_de->[0], 'Januar', 'First month is Januar (de)');
    
    done_testing();
};

# Test getMonthNamesShort
subtest 'getMonthNamesShort' => sub {
    my $names_en = time::getMonthNamesShort('en');
    is(scalar(@$names_en), 12, 'Returns 12 abbreviated month names');
    is($names_en->[0], 'Jan', 'First month abbreviation is Jan (en)');
    
    my $names_de = time::getMonthNamesShort('de');
    is($names_de->[2], 'Mär', 'March abbreviation is Mär (de)');
    
    done_testing();
};

# Test getWeekdayIndex
subtest 'getWeekdayIndex' => sub {
    is(time::getWeekdayIndex('0'), 0, 'Numeric index 0');
    is(time::getWeekdayIndex('Mo'), 0, 'Monday index is 0');
    is(time::getWeekdayIndex('Tu'), 1, 'Tuesday index is 1');
    is(time::getWeekdayIndex('Fr'), 4, 'Friday index is 4');
    is(time::getWeekdayIndex('Su'), 6, 'Sunday index is 6');
    is(time::getWeekdayIndex('So'), 6, 'Sonntag index is 6');
    
    done_testing();
};

# Test time_format
subtest 'time_format' => sub {
    my $result = time::time_format('2024-12-18 14:30:45');
    is($result, '14:30', 'Extract HH:MM from datetime');
    
    $result = time::time_format('14:30');
    is($result, '14:30', 'Time only input unchanged');
    
    $result = time::time_format('invalid');
    is($result, 'invalid', 'Invalid input returned as-is');
    
    done_testing();
};

# Test get_duration_seconds
subtest 'get_duration_seconds' => sub {
    my $duration = time::get_duration_seconds(
        '2024-12-18 14:00:00',
        '2024-12-18 15:30:00',
        'UTC'
    );
    is($duration, 5400, 'Duration is 5400 seconds (1.5 hours)');
    
    $duration = time::get_duration_seconds(
        '2024-12-18 15:30:00',
        '2024-12-18 14:00:00',
        'UTC'
    );
    is($duration, -5400, 'Negative duration when end is before start');
    
    eval { time::get_duration_seconds(undef, '2024-12-18 15:00:00') };
    ok($@, 'Missing start throws error');
    
    eval { time::get_duration_seconds('2024-12-18 14:00:00', undef) };
    ok($@, 'Missing end throws error');
    
    done_testing();
};

# Test datetime_to_rfc822
subtest 'datetime_to_rfc822' => sub {
    my $result = time::datetime_to_rfc822('2024-12-18 14:30:00');
    like($result, qr/^\w{2,3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2}/, 'RFC822 format');
    
    done_testing();
};

# Test get_datetime
subtest 'get_datetime' => sub {
    my $dt = time::get_datetime('2024-12-18 14:30:45', 'UTC');
    ok(defined $dt, 'Returns DateTime object');
    isa_ok($dt, 'DateTime');
    is($dt->year, 2024, 'Year is correct');
    is($dt->month, 12, 'Month is correct');
    is($dt->day, 18, 'Day is correct');
    is($dt->hour, 14, 'Hour is correct');
    is($dt->minute, 30, 'Minute is correct');
    
    $dt = time::get_datetime('', 'UTC');
    is($dt, undef, 'Empty string returns undef');
    
    $dt = time::get_datetime(undef, 'UTC');
    is($dt, undef, 'undef returns undef');
    
    done_testing();
};

# Test datetime_to_epoch
subtest 'datetime_to_epoch' => sub {
    my $epoch = time::datetime_to_epoch('2024-01-01 00:00:00', 'UTC');
    ok($epoch > 0, 'Returns positive epoch');
    is($epoch, 1704067200, 'Correct epoch for 2024-01-01 00:00:00 UTC');
    
    done_testing();
};

done_testing();