package calendar;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc();

use template();
use events();

use base 'Exporter';
our @EXPORT_OK = qw(init get_cached_or_render get render get_calendar_weeks configure_cache);

sub init() {
}

sub get_cached_or_render($$$) {

    #   my $output  = $_[0]
    my $config  = $_[1];
    my $request = $_[2];

    my $parms = $request->{params}->{checked};
    my $debug = $config->{system}->{debug};

    my $calendar = calendar::get( $config, $request );

    calendar::render( $_[0], $config, $request, $calendar );
}

sub get($$) {
    my $config  = shift;
    my $request = shift;

    my $params = $request->{params}->{checked};
    my $debug  = $config->{system}->{debug};

    my $language = $config->{date}->{language} || 'en';

    my $date      = $params->{date}      || '';
    my $template  = $params->{template}  || '';
    my $from_time = $params->{from_time} || '';
    my $till_time = $params->{till_time} || '';

    my @today = localtime( time() );
    my $today = sprintf( '%04d-%02d-%02d', 1900 + $today[5], $today[4] + 1, $today[3] );

    my $weekday_names       = time::getWeekdayNames($language);
    my $weekday_short_names = time::getWeekdayNamesShort($language);
    my $week_label          = {};
    my $c                   = 0;
    for my $weekday (@$weekday_short_names) {
        $week_label->{$weekday} = $weekday_names->[$c] || '';
        $c++;
    }

    $template =~ s/\'//gi;
    $from_time =~ s/\'//gi;
    $till_time =~ s/\'//gi;

    #put "clear all" filter into final results
    my $day_result   = {};
    my $clear_filter = $day_result;

    #put "week day" filter into final results
    my $days = [];
    $c = 0;
    for my $weekday (@$weekday_short_names) {
        my $day_result = {
            label              => $week_label->{$weekday},
            weekday            => $c + 1,
            weekday_parameter  => 'weekday=' . $c,
            weekday_short_name => $weekday_short_names->[$c] || '',
            weekday_name       => $weekday_names->[$c] || '',
            description        => qq{alle $week_label->{$weekday}-Termine anzeigen},
        };
        push @$days, $day_result;
        $c++;
    }

    #weeks and days array
    my $weekAndDayResults = [];

    #weekday array
    my $weekdayResults = $days;

    #week array
    my $weekResults = [];

    #info hash by timedate
    my $dateInfo = {};

    #generate content for each day in a week in a month in a year
    #get today
    my $start_date = '';
    my $end_date   = '';
    if ( $date =~ /(\d{4})\-(\d{2})/ ) {
        my $year  = $1;
        my $month = $2;
        $start_date = "$year-$month-01";
        $end_date = "$year-$month-" . Date::Calc::Days_in_Month( $year, $month );
    } else {
        $start_date = $params->{start_date};
        $end_date   = $params->{end_date};
    }

    my $previous_month = $start_date;
    if ( $previous_month =~ /(\d{4})\-(\d{2})/ ) {
        my $year  = $1;
        my $month = $2 - 1;
        $month = '0' . $month if ( length($month) < 2 );
        if ( $month lt '01' ) {
            $year -= 1;
            $month = '12';
        }
        $previous_month = "$year-$month-01";
        $previous_month = $params->{start_date} if ( $previous_month lt $params->{start_date} );
    }

    my $next_month = $end_date;
    if ( $next_month =~ /(\d{4})\-(\d{2})/ ) {
        my $year  = $1;
        my $month = $2 + 1;
        $month = '0' . $month if ( length($month) < 2 );
        if ( $month gt '12' ) {
            $year += 1;
            $month = '01';
        }
        $next_month = "$year-$month-01";
        $next_month = $params->{end_date} if ( $next_month gt $params->{end_date} );
    }

    my $start_year  = undef;
    my $start_month = undef;
    if ( $start_date =~ /(\d{4})\-(\d{2})/ ) {
        $start_year  = $1;
        $start_month = $2;
    }
    my $monthNames       = time::getMonthNamesShort($language);
    my $start_month_name = $monthNames->[ $start_month - 1 ];

    if ( $params->{month_only} eq '1' ) {
        return {
            next_month       => $next_month,
            previous_month   => $previous_month,
            start_year       => $start_year,
            start_month      => $start_month,
            start_month_name => $start_month_name
        };
    }

    my $years = calendar::get_calendar_weeks( $config, $start_date, $end_date );

    my $dbh = db::connect( $config, $request );

    my $used_days = events::get_by_date_range(
        $dbh, $config,
        $start_date,
        $end_date,
        {
            exclude_projects  => 1,
            exclude_locations => 1,
        }
    );
    my $used_day = { map { $_->{start_date} => 1 } @$used_days };

    for my $year ( sort { $a <=> $b } keys %$years ) {
        my $months = $years->{$year};

        for my $month ( sort { $a <=> $b } keys %$months ) {
            my $weeks = $months->{$month};

            my $weekCounter = 1;
            for my $week (@$weeks) {
                my $dayResults = [];

                my $week_end   = undef;
                my $week_start = undef;

                my $week_of_year = undef;
                my $woy_year     = undef;

                for my $date (@$week) {
                    my ( $year, $month, $day ) = split( /\-/, $date, 3 );
                    my $weekday    = 0;
                    my $day_result = undef;

                    ( $week_of_year, $woy_year ) = Date::Calc::Week_of_Year( $year, $month, $day )
                      unless defined $week_of_year;

                    $day_result = {
                        date           => $date,
                        date_parameter => 'date=' . $date,
                        day            => $day,
                        year           => $year,
                        month          => $month,
                    };
                    $day_result->{time} = $from_time if defined $from_time;

                    $day_result->{class} .= ' calcms_today' if $date eq $today;
                    $day_result->{class} .= ' selected'     if defined $used_day->{$date};
                    $day_result->{class} .= " week_$weekCounter";
                    $day_result->{class} .= " other_month" if ( $weekCounter < 2 ) && ( $day gt "15" );
                    $day_result->{class} .= " other_month" if ( $weekCounter > 3 ) && ( $day lt "15" );
                    $day_result->{class} =~ s/^\s+//g;

                    $week_start = $day unless defined $week_start;
                    $week_end = $day;

                    $day_result->{weekday_name}       = $weekday_names->[$weekday];
                    $day_result->{weekday_short_name} = $weekday_short_names->[$weekday];
                    $day_result->{weekday}            = $weekday + 1;

                    $dateInfo->{ $day_result->{date} } = $day_result->{weekday} if defined $day_result->{date};

                    push @$dayResults, $day_result;
                    $weekday++;

                }    #end for days

                #week filter
                my $start_date = $week->[0];
                my $end_date   = $week->[-1];

                my $week_result = {
                    from_date    => $start_date,
                    till_date    => $end_date,
                    week_start   => $week_start,
                    week_end     => $week_end,
                    week_month   => sprintf( "%2d", $month ),
                    week_year    => $year,
                    week_of_year => $week_of_year,
                };

                $week_result->{class} .= ' selected'
                  if ( ( defined $params->{from_date} ) && ( $start_date eq $params->{from_date} ) )
                  || ( ( defined $params->{till_date} ) && ( $end_date eq $params->{till_date} ) );
                $week_result->{class} .= " week_$weekCounter";
                $week_result->{class} =~ s/^\s+//g;

                push @$weekResults, $week_result;

                push @$weekAndDayResults,
                  {
                    days => $dayResults,
                    week => [$week_result]
                  };
                $weekCounter++;

            }    #end week

        }    #end month

    }    #end year

    for my $weekday (@$weekdayResults) {
        $weekday->{start_date} = $start_date;
        $weekday->{end_date}   = $end_date;
    }

    return {
        week_and_days    => $weekAndDayResults,
        weekdays         => $weekdayResults,
        weeks            => $weekResults,
        days             => $dateInfo,
        next_month       => $next_month,
        previous_month   => $previous_month,
        start_date       => $start_date,
        end_date         => $end_date,
        start_month_name => $start_month_name,
        start_month      => $start_month,
        start_year       => $start_year,
        base_url         => $config->{locations}->{base_url},
        cache_base_url   => $config->{cache}->{base_url},
        controllers      => $config->{controllers},
    };

}

sub render($$$$) {

    #    my $out     = $_[0];
    my $config   = $_[1];
    my $request  = $_[2];
    my $calendar = $_[3];

    my $parms = $request->{params}->{checked};
    my $debug = $config->{system}->{debug};

    my $template_parameters = $calendar;
    $template_parameters->{debug}            = $config->{system}->{debug};
    $template_parameters->{base_url}         = $config->{locations}->{base_url};
    $template_parameters->{cache_base_url}   = $config->{cache}->{base_url};
    $template_parameters->{server_cache}     = $config->{cache}->{server_cache} if ( $config->{cache}->{server_cache} );
    $template_parameters->{use_client_cache} = $config->{cache}->{use_client_cache}
      if ( $config->{cache}->{use_client_cache} );

    template::process( $config, $_[0], $parms->{template}, $template_parameters );
}

sub get_calendar_weeks($$$) {
    my $config = shift;
    my $start  = shift;
    my $end    = shift;

    my $debug = $config->{system}->{debug};

    $start = time::date_to_array($start);
    $end   = time::date_to_array($end);

    my $start_year = int( $start->[0] );
    my $end_year   = int( $end->[0] );

    my $start_month = int( $start->[1] );
    my $end_month   = int( $end->[1] );

    my $years = {};
    for my $year ( $start_year .. $end_year ) {
        my $months = {};
        for my $month ( $start_month .. $end_month ) {

            #get week arrays of days of the month
            my $weeks = getWeeksOfMonth( $year, $month );
            $months->{$month} = $weeks;
        }
        $years->{$year} = $months;
    }
    return $years;
}

sub getWeeksOfMonth($$) {
    my $thisYear  = shift;
    my $thisMonth = shift;
    my $thisDay   = 1;

    # get weekday of 1st of month
    my $thisMonthWeekday = Date::Calc::Day_of_Week( $thisYear, $thisMonth, 1 );

    # get next month date
    my ( $nextYear, $nextMonth, $nextDay ) = Date::Calc::Add_Delta_YM( $thisYear, $thisMonth, $thisDay, 0, 1 );

    # get weekday of 1st of next month
    my $nextMonthWeekday = Date::Calc::Day_of_Week( $nextYear, $nextMonth, $nextDay );
    my ( $lastYear, $lastMonth, $lastDayOfMonth ) = Date::Calc::Add_Delta_Days( $nextYear, $nextMonth, $nextDay, -1 );

    # get date of 1st of row
    my ( $week, $year ) = Date::Calc::Week_of_Year( $thisYear, $thisMonth, $thisDay );
    ( $year, my $month, my $day ) = Date::Calc::Monday_of_Week( $week, $year );

    my @weeks   = ();
    my $weekday = 1;

    {
        # first week
        my @days = ();
        for $weekday ( 0 .. $thisMonthWeekday - 2 ) {
            push @days, sprintf( "%04d-%02d-%02d", $year, $month, $day );
            $day++;
        }

        # set current month
        $month = $thisMonth;
        $year  = $thisYear;
        $day   = 1;
        for $weekday ( $thisMonthWeekday .. 7 ) {
            push @days, sprintf( "%04d-%02d-%02d", $year, $month, $day );
            $day++;
        }

        # next week
        push @weeks, \@days;
    }

    # weeks until end of month
    while ( scalar(@weeks) < 6 ) {
        my @days = ();
        $weekday = 1;
        while ( $weekday <= 7 ) {
            push @days, sprintf( "%04d-%02d-%02d", $year, $month, $day );
            $day++;
            $weekday++;
            last if $day > $lastDayOfMonth;
        }

        if ( $day > $lastDayOfMonth ) {

            # set next month
            $month = $nextMonth;
            $year  = $nextYear;
            $day   = 1;

            if ( $nextMonthWeekday != 1 ) {

                # finish end week
                if ( $weekday <= 7 ) {
                    while ( $weekday <= 7 ) {
                        push @days, sprintf( "%04d-%02d-%02d", $year, $month, $day );
                        $day++;
                        $weekday++;
                    }
                }
            }
            push @weeks, \@days;
            last;
        }
        push @weeks, \@days if $weeks[-1]->[-1] ne $days[-1];
    }

    #coming weeks
    while ( scalar(@weeks) < 6 ) {
        my @days = ();
        for $weekday ( 1 .. 7 ) {
            push @days, sprintf( "%04d-%02d-%02d", $year, $month, $day );
            $day++;
        }
        push @weeks, \@days;
    }
    return \@weeks;
}

sub check_params($$) {
    my $config = shift;
    my $params = shift;

    #get start and stop from projects
    my $range      = project::get_date_range($config);
    my $start_date = $range->{start_date};
    my $end_date   = $range->{end_date};

    #switch off limiting end date by project
    my $open_end = 0;
    if ( ( defined $params->{'open_end'} ) && ( $params->{'open_end'} =~ /(\d+)/ ) ) {
        $open_end = $1;
        $end_date = time::add_days_to_datetime( time::time_to_datetime(), 365 );
    }

    my $month_only = $params->{month_only} || '';

    #filter for date
    my $date = time::check_date( $params->{date} );

    $date = $start_date if ( $date lt $start_date );
    $date = $end_date   if ( $date gt $end_date );
    log::error( $config, "no valid year-month format given!" ) if ( $date eq "-1" );

    my $time = time::check_time( $params->{time} );
    log::error( $config, "no valid time format given!" ) if ( $time eq "-1" );

    my $from_date = time::check_date( $params->{from_date} ) || '';
    log::error( $config, "no valid date format given!" ) if ( defined $from_date && $from_date eq "-1" );
    $from_date = $start_date if ( $from_date lt $start_date );
    $from_date = $end_date   if ( $from_date gt $end_date );

    my $till_date = time::check_date( $params->{till_date} || '' );
    log::error( $config, "no valid date format given!" ) if ( defined $till_date && $till_date eq "-1" );
    $till_date = $start_date if ( $till_date lt $start_date );
    $till_date = $end_date   if ( $till_date gt $end_date );

    my $template = template::check( $config, $params->{template}, 'calendar.html' );

    my $debug = $params->{debug};
    if ( ( defined $debug ) && ( $debug =~ /([a-z\_\,]+)/ ) ) {
        $debug = $1;
    }

    return {
        template   => $template,
        date       => $date,
        from_date  => $from_date,
        till_date  => $till_date,
        debug      => $debug,
        month_only => $month_only,
        open_end   => $open_end,
        start_date => $start_date,
        end_date   => $end_date
    };
}

#do not delete last line!
1;

