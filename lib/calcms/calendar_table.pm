package calendar_table;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc();
use events();

sub break_dates {
    my ($dates, $start_of_day) = @_;

    for my $date(@$dates) {
        next unless defined $date;

        $date->{splitCount} = 0 unless defined $date->{splitCount};

        #debugDate($date);

        next if $date->{splitCount} > 6;
        my $nextDayStart =
            breaks_day($date->{start}, $date->{end}, $start_of_day);
        next if $nextDayStart eq '0';

        # add new entry
        my $entry = {};
        for my $key(keys %$date) {
            $entry->{$key} = $date->{$key};
        }
        $entry->{start} = $nextDayStart;
        $entry->{splitCount}++;
        push @$dates, $entry;

        #modify existing entry
        my $start_date = time::datetime_to_date($date->{start});
        $date->{end} = $nextDayStart;
        $date->{splitCount}++;
    }

    return join_dates($dates, $start_of_day);
}

# check if event breaks the start of day(e.g. 06:00)
sub breaks_day {
    my ($start, $end, $start_of_day) = @_;

    my $starts    = time::datetime_to_array($start);
    my $startDate = time::array_to_date($starts);
    my $startTime = time::array_to_time($starts);
    $start = $startDate . ' ' . $startTime;

    my $ends    = time::datetime_to_array($end);
    my $endDate = time::array_to_date($ends);
    my $endTime = time::array_to_time($ends);
    $end = $endDate . ' ' . $endTime;

    my $dayStartTime = time::array_to_time($start_of_day);
    my $dayStart     = $startDate . ' ' . $dayStartTime;

    # start before 6:00 of same day
    return $dayStart if ($start lt $dayStart) && ($end gt $dayStart);

    # start before 6:00 of next day
    my $nextDayStart = time::add_days_to_datetime($dayStart, 1);

    #$nextDayStart=~s/:00$//;
    return $nextDayStart
        if ($start lt $nextDayStart) && ($end gt $nextDayStart);

    return 0;
}

# merge events with same seriesId and eventId at 00:00
sub join_dates {
    my ($dates, $start_of_day) = @_;

    return $dates if $start_of_day == 0;
    @$dates = sort {$a->{start} cmp $b->{start}} @$dates;

    my $prev_date = undef;
    for my $date(@$dates) {
        next unless defined $date;
        unless (defined $prev_date) {
            $prev_date = $date;
            next;
        }
        if (($date->{event_id} == $prev_date->{event_id})
            && ($date->{series_id} == $prev_date->{series_id})
            && ($date->{start} eq $prev_date->{end})
            && ($date->{start} =~ /00\:00\:\d\d/))
        {
            $prev_date->{end} = $date->{end};
            $date = undef;
            next;
        }
        $prev_date = $date;
    }

    my $results = [];
    for my $date(@$dates) {
        next unless defined $date;
        push @$results, $date;
    }

    return $results;
}

sub filterEvents {
    my ($events, $options, $start_of_day) = @_;

    return [] unless defined $options->{from};
    return [] unless defined $options->{till};

    my $dayStartTime  = time::array_to_time($start_of_day);
    my $startDatetime = $options->{from} . ' ' . $dayStartTime;
    my $endDatetime   = $options->{till} . ' ' . $dayStartTime;

    my $results = [];
    for my $date(@$events) {
        next
            if (($date->{start} ge $endDatetime)
            ||($date->{end} le $startDatetime));
        push @$results, $date;
    }
    return $results;
}

sub getCalendar {
    my ($config, $params, $language) = @_;

    my $from_date = getFromDate($config, $params);
    my $till_date = getTillDate($config, $params);
    my $range     = $params->{range};

    my $previous = '';
    my $next     = '';
    if ($range eq 'month') {
        $previous =
            time::get_datetime($from_date, $config->{date}->{time_zone})
            ->subtract(months => 1)->set_day(1)->date();
        $next = time::get_datetime($from_date, $config->{date}->{time_zone})
            ->add(months => 1)->set_day(1)->date();
    } else {
        $previous = time::get_datetime($from_date, $config->{date}->{time_zone})
            ->subtract(days => $range)->date();
        $next =
            time::get_datetime($from_date, $config->{date}->{time_zone})
            ->add(days => $range)->date();
    }
    my ($year, $month, $day) = split(/\-/, $from_date);
    my $monthName = time::getMonthNamesShort($language)->[ $month - 1 ] || '';

    return {
        from_date     => $from_date,
        till_date     => $till_date,
        next_date     => $next,
        previous_date => $previous,
        month         => $monthName,
        year          => $year
    };

}

sub getFromDate {
    my ($config, $params) = @_;

    if ($params->{from_date} ne '') {
        return $params->{from_date};
    }
    my $date = $params->{date};
    if ($date eq '') {
        $date =
            DateTime->now(time_zone => $config->{date}->{time_zone})->date();
    }

    if ($params->{range} eq '28') {

        #get start of 4 week period
        $date = time::get_datetime($date, $config->{date}->{time_zone})
            ->truncate(to => 'week')->ymd();
    }
    if ($params->{range} eq 'month') {

        #get first day of month
        return time::get_datetime($date, $config->{date}->{time_zone})
            ->set_day(1)->date();
    }

    #get date
    return time::get_datetime($date, $config->{date}->{time_zone})->date();
}

sub getTillDate {
    my ($config, $params) = @_;

    if ($params->{till_date} ne '') {
        return $params->{till_date};
    }
    my $date = $params->{date} || '';
    if ($date eq '') {
        $date =
            DateTime->now(time_zone => $config->{date}->{time_zone})->date();
    }
    if ($params->{range} eq '28') {
        $date = time::get_datetime($date, $config->{date}->{time_zone})
            ->truncate(to => 'week')->ymd();
    }
    if ($params->{range} eq 'month') {

        #get last day of month
        return time::get_datetime($date, $config->{date}->{time_zone})
            ->set_day(1)->add(months => 1)->subtract(days => 1)->date();
    }

    #add range to date
    return time::get_datetime($date, $config->{date}->{time_zone})
        ->add(days => $params->{range})->date();
}

sub getFrequency {
    my ($event) = @_;

    my $period_type = $event->{period_type};
    return undef unless defined $period_type;
    return undef if $period_type ne 'days';

    my $frequency = $event->{frequency};
    return undef unless defined $frequency;
    return undef unless $frequency > 0;

    if (($frequency >= 7) && (($frequency % 7) == 0)) {
        $frequency /= 7;
        return '1 week' if $frequency == 1;
        return $frequency .= ' weeks';
    }

    return '1 day' if $frequency == 1;
    return $frequency .= ' days';
}

sub calc_positions {
    my ($events, $cal_options) = @_;

    my $start_of_day = $cal_options->{start_of_day};

    for my $event(@$events) {
        my ($start_hour, $start_min) = getTime($event->{start_time});
        my ($end_hour,   $end_min)   = getTime($event->{end_time});

        $start_hour += 24 if $start_hour < $start_of_day;
        $end_hour   += 24 if $end_hour < $start_of_day;
        $end_hour   += 24 if $start_hour > $end_hour;
        $end_hour   += 24
            if ($start_hour == $end_hour) && ($start_min == $end_min);

        $event->{ystart} = $start_hour * 60 + $start_min;
        $event->{yend}   = $end_hour * 60 + $end_min;
    }
}

sub find_errors {
    my ($events) = @_;

    for my $event(@$events) {
        next if defined $event->{grid};
        next if defined $event->{work};
        next if defined $event->{play};
        next if (defined $event->{draft}) && ($event->{draft} == 1);
        next unless defined $event->{ystart};
        next unless defined $event->{yend};
        $event->{check_errors} = 1;
    }

    #check next events
    for my $i(0 .. scalar(@$events) - 1) {
        my $event = $events->[$i];
        next unless defined $event->{check_errors};

        #look for conflicts with next 5 events of day
        my $min_index = $i + 1;
        next if $min_index >= scalar @$events;
        my $max_index = $i + 8;
        $max_index = scalar(@$events) - 1 if $max_index >= (@$events);
        for my $j($min_index .. $max_index) {
            my $event2 = $events->[$j];
            next unless defined $event2->{check_errors};

         #mark events if same start,stop,series_id, one is schedule one is event
            if ((defined $event->{series_id})
                && (defined $event2->{series_id})
                && ($event->{series_id} == $event2->{series_id}))
            {
                if (($event->{ystart} eq $event2->{ystart})
                    && ($event->{yend} eq $event2->{yend}))
                {
                    if ((defined $event->{schedule})
                        && (!(defined $event2->{schedule})))
                    {
                        $event->{hide}       = 1;
                        $event2->{scheduled} = 1;
                        next;
                    }
                    if ((!(defined $event->{schedule}))
                        && (defined $event2->{schedule}))
                    {
                        $event->{scheduled} = 1;
                        $event2->{hide}     = 1;
                        next;
                    }
                } elsif(($event->{ystart} >= $event2->{ystart})
                    && ($event->{scheduled} == 1)
                    && ($event2->{scheduled} == 1))
                {
                    #subsequent schedules
                    $event->{error}++;
                    $event2->{error} = 1 unless defined $event2->{error};
                    $event2->{error}++;
                    next;
                }
            } elsif($event->{ystart} >= $event2->{ystart}) {

                #errors on multiple schedules or events
                $event->{error}++;
                $event2->{error} = 1 unless defined $event2->{error};
                $event2->{error}++;
            }
        }
    }

#remove error tags from correctly scheduled entries(subsequent entries with same series id)
    for my $event(@$events) {
        delete $event->{error}
            if (
         (defined $event->{error})
            && (((defined $event->{scheduled}) && ($event->{scheduled} == 1))
                ||((defined $event->{hide}) && ($event->{hide} == 1)))
           );
    }
}


sub getTime {
    my ($time) = @_;
    if ($time =~ /^(\d\d)\:(\d\d)/) {
        return ($1, $2);
    }
    return (-1, -1);
}

sub showEventList {
    my ($config, $permissions, $params, $events_by_day) = @_;
    my $language      = $params->{language};

    my $rerunIcon =
        qq{<sprite-icon name="replay" title="$params->{loc}->{label_rerun}"></sprite-icon>};
    my $liveIcon =
        qq{<sprite-icon name="mic" title="$params->{loc}->{label_live}"></sprite-icon>};
    my $draftIcon =
        qq{<sprite-icon name="draft" title="$params->{loc}->{label_draft}"></sprite-icon>};
    my $archiveIcon =
qq{<sprite-icon name="archive" title="$params->{loc}->{label_archived}"></sprite-icon>};
    my $playoutIcon    = qq{<sprite-icon name="play"></sprite-icon>};
    my $processingIcon = qq{<sprite-icon name="processsing"></sprite-icon>};
    my $preparedIcon   = qq{<sprite-icon name="prepared"></sprite-icon>};
    my $creoleIcon     = qq{<sprite-icon name="creole"></sprite-icon>};

    my $out = '';
    $out = qq{
        <div id="event_list" class="table-scroll scrollable">
        <table>
            <thead>
                <tr>
                    <th class="day_of_year">$params->{loc}->{label_day_of_year}</th>
                    <!--<th class="weekday">$params->{loc}->{label_weekday}</th>-->
                    <th class="start_date">$params->{loc}->{label_start}</th>
                    <th class="start_time">$params->{loc}->{label_end}</th>
                    <th class="series_name">$params->{loc}->{label_series}</th>
                    <th class="title">$params->{loc}->{label_title}</th>
                    <th class="episode">$params->{loc}->{label_episode}</th>
                    <th class="rerun">$rerunIcon</th>
                    <th class="ddraft">$draftIcon</th>
                    <th class="live">$liveIcon</th>
                    <th class="playout" title="$params->{loc}->{label_playout}">$playoutIcon</th>
                    <th class="archive">$archiveIcon</th>
                    <!--
                    <th class="project_id">project</th>
                    <th class="studio">studio</th>
                    <th class="series_id">sid</th>
                    <th class="id">$params->{loc}->{label_id}</th>
                    -->
                 </tr>
            </thead>
            <tbody>
    };# if $params->{part} == 0;
    #my $i = 1;

    my $scheduled_events = {};
    for my $date(reverse sort(keys %$events_by_day)) {
        for my $event(reverse @{ $events_by_day->{$date} }) {
            next unless defined $event;
            next if defined $event->{grid};
            next if defined $event->{work};
            next if defined $event->{play};

            #schedules with matching date are marked to be hidden in find_errors
            next if defined $event->{hide};
            $event->{project_id} //= $params->{project_id};
            $event->{studio_id}  //= $params->{studio_id};
            $event->{series_id} = '-1' unless defined $event->{series_id};
            $event->{event_id}  = '-1' unless defined $event->{event_id};
            my $id =
                  'event_'
                . $event->{project_id} . '_'
                . $event->{studio_id} . '_'
                . $event->{series_id} . '_'
                . $event->{event_id};

            my $class = 'event';
            $class = $event->{class} if defined $event->{class};
            $class = 'schedule'      if defined $event->{schedule};
            if ($class =~ /(event|schedule)/) {
                $class .= ' scheduled' if defined $event->{scheduled};
                $class .= ' error'     if defined $event->{error};
                $class .= ' no_series'
                    if (($class eq 'event') && ($event->{series_id} eq '-1'));

                for my $filter(
                    'rerun',   'archived',
                    'playout', 'published',
                    'live',    'disable_event_sync',
                    'draft'
                   )
                {
                    $class .= ' ' . $filter
                        if ((defined $event->{$filter})
                        && ($event->{$filter} eq '1'));
                }
                $class .= ' preproduced'
                    unless ((defined $event->{'live'})
                    && ($event->{'live'} eq '1'));
                $class .= ' no_playout'
                    unless (
                 (defined $event->{'playout'})
                    && (defined $event->{'playout'}
                        and $event->{'playout'} eq '1')
                   );
                $class .= ' no_rerun'
                    unless ((defined $event->{'rerun'})
                    && ($event->{'rerun'} eq '1'));
            }

            $event->{start}              ||= '';
            $event->{weekday_short_name} ||= '';
            $event->{start_date_name}    ||= '';
            $event->{start_time}         ||= '';
            $event->{end_time}           ||= '';
            $event->{series_name}        ||= '';
            $event->{title}              ||= '';
            $event->{user_title}         ||= '';
            $event->{episode}            ||= '';
            $event->{rerun}              ||= '';
            $event->{draft}              ||= '';
            $event->{playout}            ||= '';
            $id                          ||= '';
            $class                       ||= '';

            my $archived = $event->{archived} || '-';
            $archived = '-'          if $archived eq '0';
            $archived = $archiveIcon if $archived eq '1';

            my $live = $event->{live} || '-';
            $live = '-'       if $live eq '0';
            $live = $liveIcon if $live eq '1';

            my $rerun = $event->{rerun} || '-';

            $rerun =
                " [" . markup::base26($event->{recurrence_count} + 1) . "]"
                if (defined $event->{recurrence_count})
                && ($event->{recurrence_count} ne '')
                && ($event->{recurrence_count} > 0);

            my $draft = $event->{draft} || '0';
            $draft = '-'        if $draft eq '0';
            $draft = $draftIcon if $draft eq '1';

            my $playout = '-';
            if (defined $event->{upload_status}) {
                $playout = $processingIcon if $event->{upload_status} ne '';
                $playout = $preparedIcon   if $event->{upload_status} eq 'done';
            }
            $playout = $playoutIcon if $event->{playout} eq '1';

            my $title = join ': ', ($event->{title}, $event->{user_title});

            my $other_studio  = $params->{studio_id} ne $event->{studio_id};
            my $other_project = $params->{project_id} ne $event->{project_id};
            $class .= ' predecessor' if $other_project or $other_studio;
            $other_studio  = '<sprite-icon name="globe"></sprite-icon>' if $other_studio;
            $other_project = '<sprite-icon name="globe></sprite-icon>' if $other_project;

            my $file =
                $event->{file}
                ? 'playout: ' . $event->{file} =~ s/\'/\&apos;/gr
                : 'playout';
            my $playout_info = $file // $event->{upload_status} // '';

            my $studio_name = $event->{studio_name} // '-';

            my $format = { "markdown" => "-", "creole" => "Creole" }
                ->{ $event->{content_format} // '' } // 'Creole';
                #use Data::Dumper;warn Dumper($event);
            $out .= qq!<tr id="$id" class="$class" start="$event->{start}" >!
                . qq!<td class="day_of_year">!
                .(defined $event->{start} ? time::dayOfYear($event->{start}) : '')
                . q!</td>!
                . qq{<!--<td class="weekday">$event->{weekday_short_name},</td>-->}
                . qq!<td class="start_date" data-text="$event->{start_datetime}">$event->{start_date}</td>!
                . qq!<td class="start_time">$event->{start_time} - $event->{end_time}</td>!
                . qq!<td class="series_name">$event->{series_name}</td>!
                . qq!<td class="title">$title</td>!
                . qq!<td class="episode">$event->{episode}</td>!
                . qq!<td class="rerun">$rerun</td>!
                . qq!<td class="ddraft">$draft</td>!
                . qq!<td class="live">$live</td>!
                . qq!<td class="playout" title="$playout_info">$playout</td>!
                . qq!<td class="archived">$archived</td>!
                . qq{<!--}
                . qq!<td>$event->{project_name} $other_studio</td>!
                . qq!<td>$studio_name $other_studio</td>!
                . qq!<td class="series_id">$event->{series_id}</td>!
                . qq!<td class="id">$event->{id}</td>!
                . qq!<tr id="$id" class="$class" start="$event->{start}" >!
                . qq{-->}
                . qq!</tr>! 
                . "\n";
        }
    }
    $out .= qq{
                </tbody>
            </table>
        </div>
    };# if $params->{part} == 0;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #add handler for events not assigned to series
    if (($params->{studio_id} ne '') && ($params->{studio_id} ne '-1')) {
        my $series = series::get(
            $config,
            {
                project_id => $project_id,
                studio_id  => $studio_id
            }
       );
        $out .= q{<div id="event_no_series" style="display:none">};
        $out .= get_assign_events_to_series_form($series, $params)
            if (defined $permissions->{assign_series_events})
            && ($permissions->{assign_series_events} eq '1');
        $out .= get_create_series_form($params)
            if (defined $permissions->{create_series})
            && ($permissions->{create_series} eq '1');
        $out .= q{</div>};
    }

    $out .= qq{
            </main>
            <script defer>
                var region='} . $params->{loc}->{region} . q{';
                var label_events='} . $params->{loc}->{label_events} . q{';
                var label_schedule='} . $params->{loc}->{label_schedule} . q{';
                var label_worktime='} . $params->{loc}->{label_worktime} . q{';
                var label_playout='} . $params->{loc}->{label_playout} . q{';
                var label_pin='} . $params->{loc}->{label_pin} . q{';
            </script>
        </body>
    </html>
    };# if $params->{part} == 0;

    return $out;

}

sub calcCalendarTable {
    my ($config, $permissions, $params, $calendar, $events_by_day, $cal_options) = @_;

    my $start_of_day = $cal_options->{start_of_day};
    my $end_of_day   = $cal_options->{end_of_day};
    my $min_hour     = $cal_options->{min_hour};
    my $max_hour     = $cal_options->{max_hour};
    my $hour_height  = $cal_options->{hour_height};
    my $project_id   = $params->{project_id};
    my $studio_id    = $params->{studio_id};
    my $language     = $params->{language};

    #insert time column
    for my $hour($min_hour .. $max_hour) {
        push @{ $events_by_day->{0} },
            {
            start      => sprintf('%02d:00', $hour % 24),
            start_time => sprintf('%02d:00', $hour),
            end_time   => sprintf('%02d:00', $hour + 1),
            series_id  => -1,
            event_id   => -1,
            project_id => $project_id,
            studio_id  => $studio_id,
            class      => 'time',
            'time'     => sprintf('%02d', $hour % 24)
            };
    }

    #insert current time
    my $time = '00:00';
    my $date = '';
    if (
        time::get_datetime(time::time_to_datetime(time()),
            $config->{date}->{time_zone}) =~
        /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d\:\d\d)/
       )
    {
        $date = $1;
        $time = $2;
    }

    my $next_time = '00:00';
    if (
        time::get_datetime(time::time_to_datetime(time() + 60),
            $config->{date}->{time_zone}) =~
        /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d\:\d\d)/
       )
    {
        $next_time = $2;
    }

    unshift @{ $events_by_day->{0} }, {

        #start      => $time,
        start_time => $time,
        end_time   => $next_time,
        series_id  => -1,
        event_id   => -1,
        project_id => -1,
        studio_id  => -1,
        class      => 'time now',
        'time'     => $time,
    };
    calc_positions($events_by_day->{0}, $cal_options);

    my $yoffset = $min_hour * $hour_height;
    my @days    = sort keys %$events_by_day;

    $cal_options->{days}          = \@days;
    $cal_options->{yoffset}       = $yoffset;
    $cal_options->{events_by_day} = $events_by_day;
    $cal_options->{date}          = $date;

}

sub getTable {
    my ($config, $permissions, $params, $cal_options) = @_;

    my $days          = $cal_options->{days};
    my $events_by_day = $cal_options->{events_by_day};
    my $yoffset       = $cal_options->{yoffset};
    my $date          = $cal_options->{date};
    my $min_hour      = $cal_options->{min_hour};
    my $yzoom         = $cal_options->{yzoom};

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $language   = $params->{language};

    #print row with weekday and date
    my $out = '';

    my $numberOfDays = scalar(@$days);
    my $width        = int(100 / $numberOfDays);
    $out .= qq!
        <script defer>
            var days=$numberOfDays;
        </script>
    !;

#style="visibility:hidden"
    $out .= q{
        <div id="calendar">
            <table>
                <thead>
                    <tr id="weekdays">
    };

    my $next_day_found = 0;

    #print navigation and weekday
    my $ypos     = 0;
    my $old_week = undef;
    my $dt       = undef;
    my $d = 0;
    for my $day(@$days) {
        my $events = $events_by_day->{$day};
        if ($day ne '0') {
            $dt = time::get_datetime($day . 'T00:00:00',
                $config->{date}->{time_zone});
            my $week = $dt->week_number();
            if ((defined $old_week) && ($week ne $old_week)) {
                $out .= qq{<th class="week"><div class="week"></div></th>};
            }
            $old_week = $week;
        }

        #header
        $out .= qq{<th class="col$d">};
        $d = 1;
        my $event   = $events->[0];
        my $content = '';
        my $class   = 'date';
        if ($day eq '0') {
            $out .= qq{<div id="position"></div></td>};
            next;
        } else {
            #print weekday
            $dt->set_locale($language);
            $content = $dt->day_name() . '<br>';
            $content .= $dt->strftime('%d. %b %Y') . '<br>';
            $content .= time::dayOfYear($event->{start}) . '<br>';

            if (($day ge $date) && ($next_day_found == 0)) {
                $class          = "date today";
                $next_day_found = 1;
            }
        }

        #insert date name
        my $hour = $min_hour;
        my $date = $day;
        $event = {
            start      => sprintf('%02d:00', $hour % 24),
            start_time => sprintf('%02d:00', $hour),
            end_time   => sprintf('%02d:30', $hour + 1),
            project_id => $project_id,
            studio_id  => $studio_id,
            content    => $content,
            class      => $class,
            date       => $date
        };

        calc_positions([$event], $cal_options);
        $out .= get_event($params, $event, $ypos, $yoffset, $yzoom);
        $out .= '</th>';
    }
    $out .= q{
        </tr>
        </thead>
        <tbody class="table-scroll">
        <tr>
    };

    #print events with weekday and date
    $ypos     = 1;
    $dt       = undef;
    $old_week = undef;
    $d=0;
    for my $day(@$days) {
        my $events = $events_by_day->{$day};
        if ($d ne '0') {
            $dt = time::get_datetime($day . 'T00:00:00',
                $config->{date}->{time_zone});
            my $week = $dt->week_number();
            if ((defined $old_week) && ($week ne $old_week)) {
                $out .= qq{<td class="week"><div class="week"></div></td>};
            }
            $old_week = $week;
        }

        $out .= qq{<td class="col$d">};
        $d = 1;

        for my $event(@$events) {
            my $content = '';
            if (length($event->{series_name})) {
                $event->{series_name} = $params->{loc}->{single_event}
                    if !length $event->{series_name} || $event->{series_name} eq '_single_';
            }

            if (length($event->{title})) {
                $content .= (($event->{title} =~ /\#\d+/)
                    ? $event->{title}
                    : (length($event->{episode})
                        ? "$event->{title} #$event->{episode}"
                        : $event->{title}));
            }
            $content = $event->{start} if $day eq '0';
            $event->{content}   = $content unless ($event->{class}//'') eq 'time now';
            $event->{project_id} //= $project_id;
            $event->{studio_id} //= $studio_id;
            $event->{class} = 'event' if $day ne '0';
            $event->{class} = 'grid' if $event->{grid};
            $event->{class} = 'schedule' if $event->{schedule};
            $event->{class} = 'work' if $event->{work};
            $event->{class} = 'play' if $event->{play};

            $event->{content} .= join '', (
                q{<br><span class="weak">},
                (defined $event->{duration}
                    ? audio::formatDuration(
                        $event->{duration},
                        $event->{event_duration},
                        sprintf("%d min",($event->{duration} + 30) / 60),
                        sprintf("%d s", $event->{duration}))
                    : ''
                ),
                ($event->{rms_left}
                    ? audio::formatLoudness($event->{rms_left}, 'L: ', 'round') 
                    : ''
                ),
                ($event->{rms_right} 
                    ? audio::formatLoudness($event->{rms_right}, 'R: ', 'round') 
                    : ''
                ),
                audio::formatFile($event->{file}, $event->{event_id}),
                '</span>'
            ) if $event->{class} eq 'event';
            $out .= get_event($params, $event, $ypos, $yoffset, $yzoom);

            $ypos++;
        }
        $out .= '</td>';
    }
    $out .= q{
                </tr>
            </tbody>
        </table>
       </div><!--table-->
    };

    return $out;
}

sub getSeries {
    my ($config, $permissions, $params, $cal_options) = @_;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    my $series = series::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id
        }
   );

    my $out = '';
    if (($params->{studio_id} ne '') && ($params->{studio_id} ne '-1')) {
        $out .= q{<div id="event_no_series" style="display:none">};
        $out .= get_assign_events_to_series_form($series, $params)
            if ((defined $permissions->{assign_series_events})
            && ($permissions->{assign_series_events} eq '1'));
        $out .= get_create_series_form($params)
            if ((defined $permissions->{create_series})
            && ($permissions->{create_series} eq '1'));
        $out .= q{</div>};
    }

    $out .= q{
        <div id="no_studio_selected" style="display:none">
            } . $params->{loc}->{label_no_studio_selected} . q{
        </div>
    };
    return $out;
}

sub getJavascript {
    my ($config, $permissions, $params, $cal_options) = @_;

    my $startOfDay = ($cal_options->{min_hour} // 0) % 24;

    my $out = q{
        <script>
            var region='} . $params->{loc}->{region} . q{';
            var startOfDay=} . $startOfDay . q{;
            var label_events='} . $params->{loc}->{label_events} . q{';
            var label_schedule='} . $params->{loc}->{label_schedule} . q{';
            var label_worktime='} . $params->{loc}->{label_worktime} . q{';
            var label_playout='} . $params->{loc}->{label_playout} . q{';
            var label_pin='} . $params->{loc}->{label_pin} . q{';
        </script>
    };
    return $out;
}


# create form to add events to series(that are not assigned to series, yet)
sub get_assign_events_to_series_form {
    my ($series, $params) = @_;

    return unless defined $series;
    return unless scalar @$series > 0;
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    my $out = '';
    $out .= qq{
        <div>
            <b>} . $params->{loc}->{label_assign_event_series} . qq{</b>
            <form id="assign_series_events" method="post" action="series.cgi">
                <input type="hidden" name="project_id" value="$project_id">
                <input type="hidden" name="studio_id" value="$studio_id">
                <input type="hidden" name="event_id">
                <table>
                    <tr>
                        <td>} . $params->{loc}->{label_series} . qq{</td>
                        <td><select id="select_series" name="series_id">
    };

    for my $serie(@$series) {
        my $id       = $serie->{series_id}   || -1;
        my $duration = $serie->{duration}    || '';
        my $name     = $serie->{series_name} || '';
        my $title    = $serie->{title}       || '';
        $name = $params->{loc}->{single_events}
            if $serie->{has_single_events} == 1;
        $title = ' - ' . $title if $title ne '';
        $out .=
              '<option value="'
            . $id
            . '" duration="'
            . $duration . '">'
            . $name
            . $title
            . '</option>' . "\n";
    }

    $out .= q{
                        </select>
                        </td>
                    </tr>
                    <tr><td></td>
                        <td>
                            <button type="submit" name="action" value="assign_event">}
        . $params->{loc}->{button_assign_event_series} . q{</button>
                        </td>
                    </tr>
                </table>
            </form>
        </div>
    };
    return $out;
}

# insert form to create series on not assigned events
sub get_create_series_form {
    my $params = shift;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    return qq{
        <div>
            <b>$params->{loc}->{label_create_series}</b>
            <form method="post" action="series.cgi">
                <input type="hidden" name="project_id" value="$project_id">
                <input type="hidden" name="studio_id"  value="$studio_id">
                <table>
                    <tr><td class="label">}
        . $params->{loc}->{label_name}
        . qq{</td>     <td><input name="series_name"></td></tr>
                    <tr><td class="label">}
        . $params->{loc}->{label_title}
        . qq{</td>     <td><input name="title"></td></tr>
                    <tr><td></td>
                        <td>
                            <button type="submit" name="action" value="create">}
        . $params->{loc}->{button_create_series} . qq{</button>
                        </td>
                    </tr>
                </table>
            </form>
        </div>
    };
}

sub get_event {
    my ($params, $event, $ypos, $yoffset, $yzoom) = @_;

    $event->{project_id} = '-1' unless defined $event->{project_id};
    $event->{studio_id}  = '-1' unless defined $event->{studio_id};
    $event->{series_id}  = '-1' unless defined $event->{series_id};
    $event->{event_id}   = '-1' unless defined $event->{event_id};

    my $id =
          'event_'
        . $event->{project_id} . '_'
        . $event->{studio_id} . '_'
        . $event->{series_id} . '_'
        . $event->{event_id};
    $id = 'grid_'
        . $event->{project_id} . '_'
        . $event->{studio_id} . '_'
        . $event->{series_id}
        if defined $event->{grid};
    $id = 'work_'
        . $event->{project_id} . '_'
        . $event->{studio_id} . '_'
        . $event->{schedule_id}
        if defined $event->{work};
    $id = 'play_' . $event->{project_id} . '_' . $event->{studio_id}
        if defined $event->{play};

    my @class     = ($event->{class} || ());
    my $showIcons = 0;
    if (grep m/(event|schedule)/, @class) {
        push @class, ' scheduled' if defined $event->{scheduled};
        push @class,  'no_series' if (grep 'event', @class) && $event->{series_id} eq '-1';
        push @class,  "error x$event->{error}" if defined $event->{error};

        for my $filter(
            'rerun', 'archived',           'playout', 'published',
            'live',  'disable_event_sync', 'draft'
        ) {
            push @class,  $filter if defined $event->{$filter} && $event->{$filter} eq '1';
        }
        push @class, 'preproduced'
            unless defined $event->{'live'} && $event->{'live'} eq '1';
        push @class, 'no_playout'
            unless defined $event->{'playout'} && $event->{'playout'} eq '1';
        push @class, 'no_rerun'
            unless defined $event->{'rerun'} && $event->{'rerun'} eq '1';
        $showIcons = 1;
    }

    my $ystart = $event->{ystart} - $yoffset;
    my $yend   = $event->{yend} - $yoffset;

    $ystart = int($ystart * $yzoom);
    $yend   = int($yend * $yzoom);
    my $height = $yend - $ystart + 1;

    $height = ($ypos > 0) ? qq{height:$height} . 'px;' : '';
    my $content = '<div class="header">' . ($event->{content} // '') .'</div>';

    if (grep /schedule/, @class) {
        my $frequency = getFrequency($event);
        $content .= "<br>($frequency)" if defined $frequency;
    }

    my @attr = '';
    if (grep /play/, @class) {
        push  @attr, ' rms="' . $event->{rms_image} . '"' if defined $event->{rms_image};
        push  @attr, ' start="' . $event->{start} . '"' if defined $event->{start};
    }

    $content .= '<br>uploading <progress max="10" ></progress> ' if defined $event->{upload};
    #$content .= q{<div class="scrollable">};
    #$content .= q{<div class="excerpt">} . $event->{excerpt} . q{</div>}
    #    if defined $event->{excerpt};
    #$content .= q{<div class="excerpt">} . $event->{html_topic} . q{</div>}
    #    if defined $event->{topic};
    #$content .= q{</div>};

    if ($showIcons) {
        my $attr = { map {$_ => undef} @class };
        my $file =
            $event->{file}
            ? 'playout: ' . $event->{file} =~ s/\'/\&apos;/gr
            : 'playout';
        my $playoutClass    = qq{<sprite-icon name="play"></sprite-icon>};
        my $processingClass = qq{<sprite-icon name="processing"></sprite-icon>};
        my $preparedClass   = qq{<sprite-icon name="prepare"></sprite-icon>};
        my @icons           = ();
        if (exists $attr->{event}) {
            my $playout = '';
            if (exists $attr->{upload_status}) {
                $playout = $processingClass if length $attr->{upload_status};
                $playout = $preparedClass   if $attr->{upload_status} eq 'done';
            }
            $playout = $playoutClass if exists $attr->{playout};
            push @icons, qq{<span class="header">$event->{series_name}</span>};
            push  @icons, '<sprite-icon name="mic" title="live"></sprite-icon>'
                if exists($attr->{live}) && exists($attr->{no_rerun});
            push  @icons, '<sprite-icon name="mic-off" title="preproduced"></sprite-icon>'
                if exists($attr->{preproduced}) && exists($attr->{no_rerun});
            push  @icons, '<sprite-icon name="replay" title="rerun"></sprite-icon>'
                if exists $attr->{rerun};
            push  @icons, qq{<sprite-icon name="play" title="$file" onmouseenter="console.log('$file');"></sprite-icon>}
                if $playout;
            push  @icons, '<sprite-icon name="archive" title="archived"></sprite-icon>'
                if exists $attr->{archived};
            push @icons, qq{<img class="icon" src="$event->{series_icon_url}">};
        }
        my $icons = join '', @icons;
        $content = qq{
            <div class="icons">$icons</div>
            <div class="text" style="$height">$content</div>
        };
    }

    my $time = (grep m/time/, @class) ? qq{ time="$event->{time}"} : '';
    my $date = (grep m/date/, @class) ? qq{ date="$event->{date}"} : '';

    return sprintf(
        q{<div class="%s" id="%s" style="%s top:%spx;"%s%s %s>%s</div>},
        join(" ",@class), $id, $height, $ystart, $time, $date, join("", @attr), $content
    );
}

sub getSeriesEvents {
    my ($config, $request, $options, $params) = @_;

    #get events by series id
    if (defined $request->{params}->{checked}->{series_id}) {
        my $events = series::get_events($request->{config}, $options);
        return $events;
    }

    #get events(directly from database to get the ones, not assigned, yet)
    delete $options->{studio_id};
    delete $options->{project_id};
    $options->{recordings} = 1;

    my $request2 = {
        params => {
            checked => events::check_params($config, $options)
        },
        config      => $request->{config},
        permissions => $request->{permissions}
    };
    $request2->{params}->{checked}->{published} = 'all';
    $request2->{params}->{checked}->{phase} = 'all';
    $request2->{params}->{checked}->{draft}     = '1' if $params->{list} == 1;

    my $events = events::get($config, $request2);

    series::add_series_ids_to_events($request->{config}, $events);

    my $studios = studios::get(
        $request->{config},
        {
            project_id => $options->{project_id}
        }
   );
    my $studio_id_by_location = {};
    for my $studio(@$studios) {
        $studio_id_by_location->{ $studio->{location} } = $studio->{id};
    }

    for my $event(@$events) {
        $event->{project_id} = $options->{project_id}
            unless defined $event->{project_id};
        $event->{studio_id} = $studio_id_by_location->{ $event->{location} }
            unless defined $event->{studio_id};
    }

    return $events;
}


return 1;