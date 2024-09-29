package studio_timeslot_dates;

use strict;
use warnings;
no warnings 'redefine';

use Date::Calc();
use time();

# schedule dates for calcms_studio_schedule
# table:   calcms_studio_timeslot_dates
# columns: id, studio_id, start(datetime), end(datetime)
# TODO: delete column schedule_id

sub get_columns ($){
    my ($config) = @_;

    my $dbh = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_studio_timeslot_dates');
}

# get all studio_timeslot_dates for studio_id within given time range
# calculate start_date, end_date, weeday, day from start and end(datetime)
sub get ($$){
    my ($config, $condition) = @_;

    my $date_range_include = 0;
    $date_range_include = 1 if (defined $condition->{date_range_include}) && ($condition->{date_range_include} == 1);

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ((defined $condition->{schedule_id}) && ($condition->{schedule_id} ne '')) {
        push @conditions,  'schedule_id=?';
        push @bind_values, $condition->{schedule_id};
    }

    # from and till range from an event should beween start and end of the studio's permission
    if ((defined $condition->{start}) && ($condition->{start} ne '')) {
        push @conditions,  'start<=?';
        push @bind_values, $condition->{start};
    }

    if ((defined $condition->{end}) && ($condition->{end} ne '')) {
        push @conditions,  'end>=?';
        push @bind_values, $condition->{end};
    }

    # check only a given date date range (without time)
    if ((defined $condition->{from}) && ($condition->{from} ne '')) {
        if ($date_range_include == 1) {
            push @conditions,  'end_date>=?';
            push @bind_values, $condition->{from};
        } else {
            push @conditions,  'start_date>=?';
            push @bind_values, $condition->{from};
        }
    }

    if ((defined $condition->{till}) && ($condition->{till} ne '')) {
        if ($date_range_include == 1) {
            push @conditions,  'start_date<=?';
            push @bind_values, $condition->{till};
        } else {
            push @conditions,  'end_date<=?';
            push @bind_values, $condition->{till};
        }
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select     date(start)        start_date
                ,date(end)          end_date
                ,dayname(start)     start_weekday
                ,dayname(end)         end_weekday
                ,start_date         day
                ,start
                ,end
                ,schedule_id
                ,studio_id

        from     calcms_studio_timeslot_dates
        $conditions
        order by start
    };

    my $entries = db::get($dbh, $query, \@bind_values);
    for my $entry (@$entries) {
        $entry->{start_weekday} = substr($entry->{start_weekday}, 0, 2);
        $entry->{end_weekday}   = substr($entry->{end_weekday},   0, 2);
    }

    return $entries;
}

#get all studio_timeslot_schedules for studio_id and update studio_timeslot_dates
sub update {
    my ($config, $entry) = @_;
    for ('project_id', 'studio_id', 'schedule_id') {
        return undef unless defined $entry->{$_};
    }

    my $dbh = db::connect($config);

    #delete all dates for schedule id
    studio_timeslot_dates::delete($config, $entry);

    my $day_start = $config->{date}->{day_starting_hour};

    #get the schedule with schedule id ordered by date
    my $schedules = studio_timeslot_schedule::get($config,
        {schedule_id => $entry->{schedule_id}}
    );

    #add scheduled dates
    my $i     = 0;
    my $dates = {};
    for my $schedule (@$schedules) {
        my $dateList;
        if ($schedule->{period_type} eq 'days') {
            #calculate dates from start to end_date
            $dateList = get_dates($schedule->{start}, $schedule->{end}, $schedule->{end_date}, $schedule->{frequency});
        } elsif ($schedule->{period_type} eq 'week_of_month') {
            my $timezone = $config->{date}->{time_zone};
            $dateList = get_week_of_month_dates($timezone,
                $schedule->{start},   $schedule->{end},   $schedule->{end_date},
                $schedule->{week_of_month}, $schedule->{weekday}, $schedule->{month},
                $schedule->{nextDay}
            );
        }

        for my $date (@$dateList) {
            $date->{project_id}  = $schedule->{project_id};
            $date->{studio_id}   = $schedule->{studio_id};
            $date->{schedule_id} = $schedule->{schedule_id};
            $dates->{$date->{start} . $date->{studio_id}} = $date;
        }
    }

    for my $date (sort keys %$dates) {
        my $timeslot_date = $dates->{$date};
        my $entry = {
            project_id  => $timeslot_date->{project_id},
            studio_id   => $timeslot_date->{studio_id},
            schedule_id => $timeslot_date->{schedule_id},
            start       => $timeslot_date->{start},
            end         => $timeslot_date->{end},
        };
        $entry->{start_date} = time::add_hours_to_datetime($entry->{start}, -$day_start);
        $entry->{end_date}   = time::add_hours_to_datetime($entry->{end},   -$day_start);
        db::insert($dbh, 'calcms_studio_timeslot_dates', $entry);
        $i++;
    }
    return $i;
}

# calculate all start/end datetimes between start_date and stop_date with a frequency(days)
# returns list of hashs with start and end
sub get_dates {
    my ($start_datetime, $end_datetime, $stop_date, $frequency) = @_;
                                                    #days

    my @start = @{ time::datetime_to_array($start_datetime) };
    return unless @start >= 6;
    my @start_date = ($start[0], $start[1], $start[2]);
    my $start_date = sprintf("%04d-%02d-%02d", @start_date);
    my $start_time = sprintf('%02d:%02d:%02d', $start[3], $start[4], $start[5]);

    my @end = @{ time::datetime_to_array($end_datetime) };
    return unless @end >= 6;
    my @end_date = ($end[0], $end[1], $end[2]);
    my $end_date = sprintf("%04d-%02d-%02d", @end_date);
    my $end_time = sprintf('%02d:%02d:%02d', $end[3], $end[4], $end[5]);

    my @stop = @{ time::date_to_array($stop_date) };
    return unless @end >= 3;
    my @stop_date = ($stop[0], $stop[1], $stop[2]);
    $stop_date = sprintf("%04d-%02d-%02d", @stop_date);

    my $date = {};
    $date->{start} = $start_date . ' ' . $start_time;
    $date->{end}   = $end_date . ' ' . $end_time;

    my $dates = [];
    return $dates if ($date->{end} le $date->{start});
    return $dates if ($stop_date lt $end_date);

    my $j = Date::Calc::Delta_Days(@start_date, @stop_date);
    return $dates if $j < 0;

    # split full time events into single days
    if ($frequency < 1) {

        #start day
        my @next_date = Date::Calc::Add_Delta_Days($start[0], $start[1], $start[2], 1);
        my $next_date = sprintf("%04d-%02d-%02d", @next_date);
        push @$dates,
          {
            start => $start_date . ' ' . $start_time,
            end   => $next_date . ' 00:00:00',
          };
        my $c = 0;
        for (my $i = 1 ; $i < $j ; $i++) {
            my @start_date = Date::Calc::Add_Delta_Days($start[0], $start[1], $start[2], $i);
            my $start_date = sprintf("%04d-%02d-%02d", @start_date);
            my @next_date = Date::Calc::Add_Delta_Days($start[0], $start[1], $start[2], $i + 1);
            my $next_date = sprintf("%04d-%02d-%02d", @next_date);
            push @$dates, {
                start => $start_date . ' 00:00:00',
                end   => $next_date . ' 00:00:00',
            };
            last if $c > 1000;
            $c++;
        }

        #end day
        push @$dates, {
            start => $end_date . ' 00:00:00',
            end   => $end_date . ' ' . $end_time,
        } if $end_time ne '00:00:00';
        return $dates;
    }

    # multiple time events
    my $c = 0;
    for (my $i = 0 ; $i <= $j ; $i += $frequency) {

        #add frequency to start and end date
        my @start_date = Date::Calc::Add_Delta_Days($start[0], $start[1], $start[2], $i);
        my @end_date   = Date::Calc::Add_Delta_Days($end[0],   $end[1],   $end[2],   $i);

        my $start_date = sprintf("%04d-%02d-%02d", @start_date);
        my $end_date   = sprintf("%04d-%02d-%02d", @end_date);
        push @$dates, {
            start => $start_date . ' ' . $start_time,
            end   => $end_date . ' ' . $end_time,
        };
        last if $c > 1000;
        $c++;
    }
    return $dates;
}

# based on series_dates but with (timezone, start, end) instead of (start, duration)
sub get_week_of_month_dates ($$$$$$$$) {
    my ($timezone, $start, $end, $end_date, $week, $weekday, $frequency, $nextDay) = @_;
    #datetime, datetime, date, every nth week of month, weekday [1..7], every 1st,2nd,3th time, add 24 hours to start, (for night hours at last weekday of month)

    return undef if $timezone eq '';
    return undef if $start eq '';
    return undef if $end eq '';
    return undef if $end_date eq '';
    return undef if $week eq '';
    return undef if $weekday eq '';
    return undef if $frequency eq '';
    return undef if $frequency == 0;

    my $start_dates = time::get_nth_weekday_in_month($start, $end_date, $week, $weekday);

    if (defined $nextDay && $nextDay > 0) {
        for (my $i = 0; $i < @$start_dates; $i++) {
            $start_dates->[$i] = time::add_hours_to_datetime($start_dates->[$i], 24);
        }
    }

    my $results = [];
    my $duration = time::get_duration($start, $end, $timezone);
    my $c = -1;
    for my $start_datetime (@$start_dates) {
        $c++;
        my @start = @{ time::datetime_to_array($start_datetime) };
        next unless @start >= 6;
        next if ($c % $frequency) != 0;
        my @end_datetime = Date::Calc::Add_Delta_DHMS(
            $start[0], $start[1], $start[2],    # start date
            $start[3], $start[4], $start[5],    # start time
            0, 0, $duration, 0                  # delta days, hours, minutes, seconds
        );
        my $end_datetime = time::array_to_datetime(\@end_datetime);
        push @$results, {
            start => $start_datetime,
            end   => $end_datetime
        };
    }
    return $results;
}

#remove all studio_timeslot_dates for studio_id and schedule_id
sub delete {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'schedule_id') {
        return unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);

    my $query = qq{
        delete
        from calcms_studio_timeslot_dates
        where schedule_id=?
    };
    my $bind_values = [ $entry->{schedule_id} ];

    db::put($dbh, $query, $bind_values);
}

# time based filter to check if studio is assigned to an studio at a given time range
# return 1 if there is a schedule date starting before start and ending after end
sub can_studio_edit_events {
    my ($config, $condition) = @_;

    my @conditions  = ();
    my @bind_values = ();

    for ('studio_id', 'start', 'end') {
       return 0 unless defined $condition->{$_}
    };

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ((defined $condition->{start}) && ($condition->{start} ne '')) {
        push @conditions,  'start<=?';
        push @bind_values, $condition->{start};
    }

    if ((defined $condition->{end}) && ($condition->{end} ne '')) {
        push @conditions,  'end>=?';
        push @bind_values, $condition->{end};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $dbh   = db::connect($config);
    my $query = qq{
        select    count(*) permission
        from     calcms_studio_timeslot_dates
        $conditions
    };

    my $entries = db::get($dbh, $query, \@bind_values);

    return 0 if scalar(@$entries) == 0;
    return 1 if $entries->[0]->{permission} > 0;

    if ($entries->[0]->{permission} == 0) {
        my $timeslot = getMergedDays($config, $condition);
        return 0 unless defined $timeslot;
        if (($condition->{start} ge $timeslot->{start})
            && ($condition->{end} le $timeslot->{end}))
        {
            return 1;
        }
    }
    return 0;
}

# merge two subsequent days if first day ends at same time as next day starts
# returns hashref with start and end of merged slot
# returns undef if not slot could be found
sub getMergedDays {
    my ($config, $condition) = @_;

    my @conditions  = ();
    my @bind_values = ();

    for ('studio_id', 'start', 'end') {
        return 0 unless defined $condition->{$_}
    };

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    # set start to next day at 00:00
    my $start = undef;
    if ($condition->{start} =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
        $start = $1 . ' 00:00';
        $start = time::add_days_to_datetime($start, 1);
        push @bind_values, $start;
    }

    # set end to end days at 00:00
    my $end = undef;
    if ($condition->{end} =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
        $end = $1 . ' 00:00';
        push @bind_values, $end;
    }
    return undef unless defined $start;
    return undef unless defined $end;

    push @conditions, '(start=? or end=?)';

    my $conditions = '';
    $conditions = 'where ' . join(" and ", @conditions) if (@conditions > 0);

    # get all days starting on first day or ending at next day
    my $dbh   = db::connect($config);
    my $query = qq{
        select    start, end
        from     calcms_studio_timeslot_dates
        $conditions
        order by start
    };

    my $entries = db::get($dbh, $query, \@bind_values);
    if (scalar(@$entries) == 2) {
        if ($entries->[0]->{end} eq $entries->[1]->{start}) {
            $entries = {
                start => $entries->[0]->{start},
                end   => $entries->[1]->{end}
            };
            return $entries;
        }
    }

    return undef;
}

sub error {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
