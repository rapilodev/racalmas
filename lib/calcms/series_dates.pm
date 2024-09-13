package series_dates;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc();

use time();
use db();
use log();
use studio_timeslot_dates();
use series_schedule();

# schedule dates for series_schedule
# table:   calcms_series_dates
# columns: id, studio_id, series_id, start(datetime), end(datetime)
# TODO: delete column schedule_id
our @EXPORT_OK = qw(get_columns get insert update delete get_dates get_series);

sub get_columns ($) {
    my ($config) = @_;

    my $dbh = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_series_dates');
}

# get all series_dates for studio_id and series_id within given time range
# calculate start_date, end_date, weeday, day from start and end(datetime)
sub get ($;$) {
    my ($config, $condition) = @_;

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

    if ((defined $condition->{series_id}) && ($condition->{series_id} ne '')) {
        push @conditions,  'series_id=?';
        push @bind_values, $condition->{series_id};
    }

    if ((defined $condition->{start_at}) && ($condition->{start_at} ne '')) {
        push @conditions,  'start=?';
        push @bind_values, $condition->{start_at};
    }

    if ((defined $condition->{from}) && ($condition->{from} ne '')) {
        push @conditions,  'start_date>=?';
        push @bind_values, $condition->{from};
    }

    if ((defined $condition->{till}) && ($condition->{till} ne '')) {
        push @conditions,  'end_date<?';
        push @bind_values, $condition->{till};
    }

    if ((defined $condition->{schedule_id}) && ($condition->{schedule_id} ne '')) {
        push @conditions,  'id=?';
        push @bind_values, $condition->{schedule_id};
    }

    if ((defined $condition->{exclude}) && ($condition->{exclude} ne '')) {
        push @conditions,  'exclude=?';
        push @bind_values, $condition->{exclude};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select     date(start) start_date
                ,date(end)   end_date
                ,dayname(start)     weekday
                ,start_date         day
                ,start
                ,end
                ,id                 schedule_id
                ,series_id
                ,studio_id
                ,project_id
                ,exclude

        from     calcms_series_dates
        $conditions
        order by start
    };

    my $entries = db::get($dbh, $query, \@bind_values);
    for my $entry (@$entries) {
        $entry->{weekday} = substr($entry->{weekday}, 0, 2);
    }

    return $entries;
}

#check if event is scheduled (on permission check)
sub is_event_scheduled($$) {
    my ($request, $options) = @_;

    for ('project_id', 'studio_id', 'series_id', 'start_at') {
        ParamError->throw(error => "missing $_") unless defined $options->{$_}
    };

    my $config    = $request->{config};
    my $schedules = series_dates::get(
        $config,
        {
            project_id => $options->{project_id},
            studio_id  => $options->{studio_id},
            series_id  => $options->{series_id},
            start_at   => $options->{start_at}
        }
    );
    return 0 if scalar @$schedules != 1;
    return 1;
}

#get all series for given studio_id, time range and search
sub get_series($;$) {
    my ($config, $condition) = @_;

    my $date_range_include = 0;
    $date_range_include = 1
      if (defined $condition->{date_range_include}) && ($condition->{date_range_include} == 1);

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    push @conditions, 'd.series_id=s.id';

    #    push @conditions, 'd.studio_id=s.studio_id';

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @conditions,  'd.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')) {
        push @conditions,  'd.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ((defined $condition->{series_id}) && ($condition->{series_id} ne '')) {
        push @conditions,  'd.series_id=?';
        push @bind_values, $condition->{series_id};
    }

    if ((defined $condition->{start_at}) && ($condition->{start_at} ne '')) {
        push @conditions,  'd.start=?';
        push @bind_values, $condition->{start_at};
    }

    if ((defined $condition->{from}) && ($condition->{from} ne '')) {
        if ($date_range_include == 1) {
            push @conditions,  'd.end_date>=?';
            push @bind_values, $condition->{from};
        } else {
            push @conditions,  'd.start_date>=?';
            push @bind_values, $condition->{from};
        }
    }

    if ((defined $condition->{till}) && ($condition->{till} ne '')) {
        if ($date_range_include == 1) {
            push @conditions,  'd.start_date<=?';
            push @bind_values, $condition->{till};
        } else {
            push @conditions,  'd.end_date<?';
            push @bind_values, $condition->{till};
        }
    }

    if ((defined $condition->{schedule_id}) && ($condition->{schedule_id} ne '')) {
        push @conditions,  'd.id=?';
        push @bind_values, $condition->{schedule_id};
    }

    if ((defined $condition->{exclude}) && ($condition->{exclude} ne '')) {
        push @conditions,  'd.exclude=?';
        push @bind_values, $condition->{exclude};
    }

    my $search_cond = '';
    if ((defined $condition->{search}) && ($condition->{search} ne '')) {
        my $search = lc $condition->{search};
        $search =~ s/[^a-z0-9\_\.\-\:\!öäüßÖÄÜ \&]/%/;
        $search =~ s/\%+/\%/;
        $search =~ s/^[\%\s]+//;
        $search =~ s/[\%\s]+$//;
        if ($search ne '') {
            $search = '%' . $search . '%';
            my @attr = ('s.title', 's.series_name', 's.excerpt', 's.content');
            push @conditions, "(" . join(" or ", map { 'lower(' . $_ . ') like ?' } @attr) . ")";
            for my $attr (@attr) {
                push @bind_values, $search;
            }
        }
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select     date(d.start)         start_date
                ,date(d.end)         end_date
                ,dayname(d.start)     weekday
                ,d.start_date       day
                ,d.start
                ,d.end
                ,d.id                 schedule_id
                ,d.series_id
                ,d.series_schedule_id
                ,d.exclude
                ,d.studio_id
                ,d.project_id
                ,s.series_name
                ,s.title
                ,s.has_single_events
        from     calcms_series_dates d, calcms_series s
        $conditions
        order by start
    };

    my $entries = db::get($dbh, $query, \@bind_values);

    for my $entry (@$entries) {
        $entry->{weekday} = substr($entry->{weekday}, 0, 2);
    }

    # add series schedule
    $entries = series_dates::addSeriesScheduleAttributes($config, $entries);

    return $entries;
}

sub addSeriesScheduleAttributes ($$) {
    my ($config, $entries) = @_;

    # get series schedule ids used at entries
    my $scheduleIds = { map { $_->{series_schedule_id} => 1 } @$entries };
    my @scheduleIds = keys %$scheduleIds;
    return $entries if scalar(@scheduleIds) == 0;

    # get schedules with schedule ids
    my $schedules = series_schedule::get(
        $config,
        {
            schedule_ids => \@scheduleIds
        }
    );

    # get schedules by id
    my $scheduleById = {};
    for my $schedule (@$schedules) {
        $scheduleById->{ $schedule->{schedule_id} } = $schedule;
    }

    for my $entry (@$entries) {
        $entry->{frequency}   = $scheduleById->{ $entry->{series_schedule_id} }->{frequency};
        $entry->{period_type} = $scheduleById->{ $entry->{series_schedule_id} }->{period_type};
    }

    return $entries;
}

#update series dates for all schedules of a series and studio_id
sub update($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);

    #delete all dates for series (by studio and series id)
    series_dates::delete($config, $entry);

    my $day_start = $config->{date}->{day_starting_hour};

    #get all schedules for series ordered by exclude, date
    my $schedules = series_schedule::get(
        $config,
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
        }
    );

    #add scheduled series dates and remove exluded dates
    my $series_dates = {};

    #TODO:set schedules exclude to 0 if not 1
    #insert all normal dates (not excludes)
    for my $schedule (@$schedules) {
        my $dates = get_schedule_dates($schedule, { exclude => 0 });
        for my $date (@$dates) {
            $date->{exclude} = 0;
            $series_dates->{ $date->{start} } = $date;
        }
    }

    #insert / overwrite all exlude dates
    for my $schedule (@$schedules) {
        my $dates = get_schedule_dates($schedule, { exclude => 1 });
        for my $date (@$dates) {
            $date->{exclude} = 1;
            $series_dates->{ $date->{start} } = $date;
        }
    }

    my $request = { config => $config };

    my $i = 0;
    my $j = 0;
    for my $date (keys %$series_dates) {
        my $series_date = $series_dates->{$date};

        #insert date
        my $entry = {
            project_id         => $entry->{project_id},
            studio_id          => $entry->{studio_id},
            series_id          => $entry->{series_id},
            series_schedule_id => $series_date->{series_schedule_id},
            start              => $series_date->{start},
            end                => $series_date->{end},
            exclude            => $series_date->{exclude},
        };
        if (studio_timeslot_dates::can_studio_edit_events($config, $entry) == 1) {    # by studio_id, start, end
            $entry->{start_date} = time::add_hours_to_datetime($entry->{start}, -$day_start);
            $entry->{end_date}   = time::add_hours_to_datetime($entry->{end},   -$day_start);
            db::insert($dbh, 'calcms_series_dates', $entry);
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
            $schedule->{start},   $schedule->{end},   $schedule->{duration}, $schedule->{week_of_month},
            $schedule->{weekday}, $schedule->{month}, $schedule->{nextDay}
        );
    } else {
        print STDERR "unknown schedule period_type\n";
    }

    # set series schedule id
    for my $date (@$dates) {
        $date->{series_schedule_id} = $schedule->{schedule_id};
    }
    return $dates;
}

sub get_week_of_month_dates ($$$$$$$) {
    my ($start, $end, $duration, $week, $weekday, $frequency, $nextDay) = @_;
    #datetime, datetime, minutes, every nth week of month, weekday [1..7], every 1st,2nd,3th time, add 24 hours to start, (for night hours at last weekday of month)

    return undef if $start eq '';
    return undef if $end eq '';
    return undef if $duration eq '';
    return undef if $week eq '';
    return undef if $weekday eq '';
    return undef if $frequency eq '';
    return undef if $frequency == 0;

    my $start_dates = time::get_nth_weekday_in_month($start, $end, $week, $weekday);

    if ((defined $nextDay) && ($nextDay > 0)) {
        for (my $i = 0 ; $i < @$start_dates ; $i++) {
            $start_dates->[$i] = time::add_hours_to_datetime($start_dates->[$i], 24);
        }
    }

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
sub get_single_date ($$) {
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
    # in minutes, in days

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
    return unless scalar @end >= 3;
    my @end_date = ($end[0], $end[1], $end[2]);

    my $today = time::time_to_date();
    my ($year, $month, $day) = split(/\-/, $today);

    my $dates = [];
    return $dates if $end_date lt $today;
    return $dates if $frequency < 1;

    my $j = Date::Calc::Delta_Days(@start_date, @end_date);
    my $c = 0;
    for (my $i = 0 ; $i <= $j ; $i += $frequency) {
        my @date = Date::Calc::Add_Delta_Days($start[0], $start[1], $start[2], $i);
        my $date = {};
        $date->{start} = sprintf("%04d-%02d-%02d", @date) . ' ' . $start_time;

        #if($date->{start} gt $today){
        my @end_datetime = Date::Calc::Add_Delta_DHMS(
            $date[0],  $date[1],  $date[2],     # start date
            $start[3], $start[4], $start[5],    # start time
            0, 0, $duration, 0                  # delta days, hours, minutes, seconds
        );
        $date->{end} = time::array_to_datetime(\@end_datetime);
        push @$dates, $date;

        #}
        last if ($c > 200);
        $c++;
    }
    return $dates;
}

#remove all series_dates for studio_id and series_id
sub delete ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);

    my $query = qq{
        delete
        from calcms_series_dates
        where project_id=? and studio_id=? and series_id=?
    };
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{series_id} ];

    db::put($dbh, $query, $bind_values);
}

# get all series dates where no event has been created for
sub getDatesWithoutEvent ($$) {
    my ($config, $options) = @_;

    for ('project_id', 'studio_id', 'from', 'till') {
        ParamError->throw(error => "missing $_") unless defined $options->{$_}
    };

    my $dbh = db::connect($config);
    my $cond = $options->{series_id} ? 'and sd.series_id = ?' : '';

    my $query = qq{
        SELECT sd.*
        FROM calcms_series_dates sd LEFT JOIN calcms_events e
        on (sd.start = e.start)
        where e.start is null
        and sd.exclude != 1
        and sd.project_id = ?
        and sd.studio_id  = ?
        $cond
        and sd.start      > ?
        and sd.end        < ?
        order by sd.start
    };

    my $bind_values = [
        $options->{project_id}, $options->{studio_id},
        $options->{series_id} ? $options->{series_id} : (),
        $options->{from}, $options->{till}
    ];
    my $entries = db::get($dbh, $query, $bind_values);
    return $entries;

}

#do not delete last line!
1;
