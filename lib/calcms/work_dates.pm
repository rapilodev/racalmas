package work_dates;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc();

use time();
use db();
use log();
use studio_timeslot_dates();
use work_schedule();

# schedule dates for work_schedule
# table:   calcms_work_dates
# columns: id, studio_id, schedule_id, start(datetime), end(datetime)
# TODO: delete column schedule_id
our @EXPORT_OK = qw(get_columns get insert update delete get_dates);

sub get_columns($) {
    my ($config) = @_;
    my $dbh = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_work_dates');
}

# get all work_dates for studio_id and schedule_id within given time range
# calculate start_date, end_date, weeday, day from start and end(datetime)
sub get ($$) {
    my ($config, $condition) = @_;

    my $date_range_include = 0;
    $date_range_include = 1
      if (defined $condition->{date_range_include}) && ($condition->{date_range_include} == 1);

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

    if ((defined $condition->{start_at}) && ($condition->{start_at} ne '')) {
        push @conditions,  'start=?';
        push @bind_values, $condition->{start_at};
    }

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

    if ((defined $condition->{exclude}) && ($condition->{exclude} ne '')) {
        push @conditions,  'exclude=?';
        push @bind_values, $condition->{exclude};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select     date(start)         start_date
                ,date(end)             end_date
                ,dayname(start)     weekday
                ,start_date         day
                ,start
                ,end
                ,schedule_id
                ,studio_id
                ,project_id
                ,exclude
                ,type
                ,title

        from     calcms_work_dates
        $conditions
        order by start
    };

    my $entries = db::get($dbh, $query, \@bind_values);
    for my $entry (@$entries) {
        $entry->{weekday} = substr($entry->{weekday}, 0, 2);
    }

    return $entries;
}

#update work dates for all schedules of a work and studio_id
sub update($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'schedule_id') {
        return undef unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);

    #delete all existing work dates (by project, studio and schedule id)
    work_dates::delete($config, $entry);

    my $day_start = $config->{date}->{day_starting_hour};

    #get all schedules for schedule id ordered by exclude, date
    my $schedules = work_schedule::get(
        $config,
        {
            project_id  => $entry->{project_id},
            studio_id   => $entry->{studio_id},
            schedule_id => $entry->{schedule_id},
        }
    );

    #add scheduled work dates and remove exluded dates
    my $work_dates = {};

    #TODO:set schedules exclude to 0 if not 1
    #insert all normal dates (not excludes)
    for my $schedule (@$schedules) {
        my $dates = get_schedule_dates($schedule, { exclude => 0 });
        for my $date (@$dates) {
            $date->{exclude} = 0;
            $work_dates->{ $date->{start} } = $date;
        }
    }

    #insert / overwrite all exlude dates
    for my $schedule (@$schedules) {
        my $dates = get_schedule_dates($schedule, { exclude => 1 });
        for my $date (@$dates) {
            $date->{exclude} = 1;
            $work_dates->{ $date->{start} } = $date;
        }
    }

    my $request = { config => $config };
    my $i = 0;
    my $j = 0;
    for my $date (keys %$work_dates) {
        my $work_date = $work_dates->{$date};

        #insert date
        my $entry = {
            project_id  => $entry->{project_id},
            studio_id   => $entry->{studio_id},
            schedule_id => $entry->{schedule_id},
            title       => $entry->{title},
            type        => $entry->{type},
            schedule_id => $entry->{schedule_id},
            start       => $work_date->{start},
            end         => $work_date->{end},
            exclude     => $work_date->{exclude}
        };
        if (studio_timeslot_dates::can_studio_edit_events($config, $entry) == 1) {    # by studio_id, start, end
            $entry->{start_date} = time::add_hours_to_datetime($entry->{start}, -$day_start);
            $entry->{end_date}   = time::add_hours_to_datetime($entry->{end},   -$day_start);
            db::insert($dbh, 'calcms_work_dates', $entry);
            $i++;
        } else {
            $j++;
        }
    }

    return $j . " dates out of studio times, " . $i;
}

sub get_schedule_dates($$) {
    my ($schedule, $options) = @_;

    my $is_exclude = $options->{exclude} || 0;
    my $dates = [];
    return $dates if ($is_exclude eq '1') && ($schedule->{exclude} ne '1');
    return $dates if ($is_exclude eq '0') && ($schedule->{exclude} eq '1');

    if ($schedule->{period_type} eq 'single') {
        $dates = get_single_date($schedule->{start}, $schedule->{duration});
    } elsif ($schedule->{period_type} eq 'days') {
        $dates = get_dates($schedule->{start}, $schedule->{end}, $schedule->{duration}, $schedule->{frequency});
    } elsif ($schedule->{period_type} eq 'week_of_month') {
        $dates = get_week_of_month_dates(
            $schedule->{start},         $schedule->{end},     $schedule->{duration},
            $schedule->{week_of_month}, $schedule->{weekday}, $schedule->{month}
        );
    } else {
        print STDERR "unknown schedule period_type\n";
    }
    return $dates;
}

sub get_week_of_month_dates($$$$$$) {
    my ($start, $end, $duration, $week, $weekday, $frequency) = @_;
    # datetime, datetime, minutes, every nth week of month, weekday [1..7], every 1st,2nd,3th time

    return undef if $start eq '';
    return undef if $end eq '';
    return undef if $duration eq '';
    return undef if $week eq '';
    return undef if $weekday eq '';
    return undef if $frequency eq '';
    return undef if $frequency == 0;

    my $start_dates = time::get_nth_weekday_in_month($start, $end, $week, $weekday);

    my $results = [];

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

        push @$results,
          {
            start => $start_datetime,
            end   => $end_datetime
          };
    }
    return $results;
}

#add duration to a single date
sub get_single_date($$) {
    my ($start_datetime, $duration) = @_;

    my @start = @{ time::datetime_to_array($start_datetime) };
    return unless @start >= 6;

    my @end_datetime = Date::Calc::Add_Delta_DHMS(
        $start[0], $start[1], $start[2],    # start date
        $start[3], $start[4], $start[5],    # start time
        0, 0, $duration, 0                  # delta days, hours, minutes, seconds
    );
    my $date = {
        start => $start_datetime,
        end   => time::array_to_datetime(\@end_datetime)
    };
    return [$date];
}

#calculate all dates between start_datetime and end_date with duration(minutes) and frequency(days)
sub get_dates($$$$) {
    my ($start_datetime, $end_date, $duration, $frequency) = @_;
    #duration in seconds, frequency in minutes

    my @start = @{ time::datetime_to_array($start_datetime) };
    return unless @start >= 6;
    my @start_date = ($start[0], $start[1], $start[2]);
    my $start_time = sprintf('%02d:%02d:%02d', $start[3], $start[4], $start[5]);

    #return on single date
    my $date = {};
    $date->{start} = sprintf("%04d-%02d-%02d", @start_date) . ' ' . $start_time;
    return undef if $duration eq '';

    return undef if ($frequency eq '') || ($end_date eq '');

    #continue on recurring date
    my @end = @{ time::datetime_to_array($end_date) };
    return unless @end >= 3;
    my @end_date = ($end[0], $end[1], $end[2]);

    my $today = time::time_to_date();
    my ($year, $month, $day) = split(/\-/, $today);

    #do not show dates one month back
    my $not_before = sprintf("%04d-%02d-%02d", Date::Calc::Add_Delta_Days($year, $month, $day, -30));

    my $dates = [];
    return $dates if ($end_date lt $today);
    return $dates if ($frequency < 1);

    my $j = Date::Calc::Delta_Days(@start_date, @end_date);
    my $c = 0;
    for (my $i = 0 ; $i <= $j ; $i += $frequency) {
        my @date = Date::Calc::Add_Delta_Days($start[0], $start[1], $start[2], $i);
        my $date = {};
        $date->{start} = sprintf("%04d-%02d-%02d", @date) . ' ' . $start_time;

        my @end_datetime = Date::Calc::Add_Delta_DHMS(
            $date[0],  $date[1],  $date[2],     # start date
            $start[3], $start[4], $start[5],    # start time
            0, 0, $duration, 0                  # delta days, hours, minutes, seconds
        );
        $date->{end} = time::array_to_datetime(\@end_datetime);

        last if ($c > 200);
        $c++;

        next if $date->{end} lt $not_before;
        push @$dates, $date;

    }
    return $dates;
}

#remove all work_dates for studio_id and schedule_id
sub delete($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'schedule_id') {
        return undef unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);

    my $query = qq{
        delete
        from calcms_work_dates
        where project_id=? and studio_id=? and schedule_id=?
    };
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{schedule_id} ];
    return db::put($dbh, $query, $bind_values);
}

sub error($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
