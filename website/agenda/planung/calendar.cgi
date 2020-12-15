#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use utf8;

use Data::Dumper;
use URI::Escape();
use DateTime();

use utf8();
use params();
use config();
use entry();
use log();
use entry();
use template();
use calendar();
use auth();
use uac();
use roles();
use project();
use studios();
use events();
use series();
use series_dates();
use markup();
use localization();
use studio_timeslot_dates();
use work_dates();
use playout();
use user_settings();
use audio_recordings();
use audio();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( !defined $user ) || ( $user eq '' );

my $user_presets = uac::get_user_presets(
    $config,
    {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio( $params, $user_presets );
$params->{expires} = $expires;

my $scriptName = 'calendar.cgi';

#add "all" studio to select box
unshift @{ $user_presets->{studios} },
  {
    id   => -1,
    name => '-all-'
  };

# select studios, TODO: do in JS
if ( $params->{studio_id} eq '-1' ) {
    for my $studio ( @{ $user_presets->{studios} } ) {
        delete $studio->{selected};
        $studio->{selected} = 1 if $params->{studio_id} eq $studio->{id};
    }
}

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    },
};
$request = uac::prepare_request( $request, $user_presets );
$params = $request->{params}->{checked};

if (
    (
        ( defined $params->{action} ) && ( ( $params->{action} eq 'show' )
            || ( $params->{action} eq 'edit_event' ) )
    )
    || ( $params->{part} == 1 )
  )
{
    print "Content-type:text/html; charset=UTF-8;\n\n";
} else {

    #process header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
    template::process( $config, 'print', template::check( $config, 'default.html' ),
        $headerParams );
    print q{
        <link href="css/jquery-ui-timepicker.css" type="text/css" rel="stylesheet" /> 
        <link rel="stylesheet" href="css/calendar.css" type="text/css" /> 

        <script src="js/jquery-ui-timepicker.js" type="text/javascript"></script>
        <script src="js/calendar.js" type="text/javascript"></script>
        <script src="js/datetime.js" type="text/javascript"></script>
    };
    if ( $params->{list} eq '1' ) {
        print q{
            <!--<link href="css/theme.default.css" rel="stylesheet">-->
            <script src="js/jquery.tablesorter.min.js"></script>
            <style>#content{ top:5rem; position:relative; }</style>
        };
    }
}

if ( defined $user_presets->{error} ) {
    print "<br><br>";
    uac::print_error( $user_presets->{error} );
    return;
}

$config->{access}->{write} = 0;
unless ( defined $params->{project_id} ) {
    uac::print_error("Please select a project");
    return;
}

if ( $params->{project_id} ne '-1' ) {
    if ( project::check( $config, { project_id => $params->{project_id} } ) ne '1' ) {
        uac::print_error("invalid project");
        return;
    }
}

unless ( defined $params->{studio_id} ) {
    uac::print_error("Please select a studio");
    return;
}
if ( $params->{studio_id} ne '-1' ) {
    if ( studios::check( $config, { studio_id => $params->{studio_id} } ) ne '1' ) {
        uac::print_error("invalid studio");
        return;
    }
}

my $start_of_day = $params->{day_start};
my $end_of_day   = $start_of_day;
$end_of_day += 24 if ( $end_of_day <= $start_of_day );
our $hour_height = 60;
our $yzoom       = 1.5;

showCalendar(
    $config, $request,
    {
        hour_height  => $hour_height,
        yzoom        => $yzoom,
        start_of_day => $start_of_day,
        end_of_day   => $end_of_day,
    }
);

sub showCalendar {
    my $config      = shift;
    my $request     = shift;
    my $cal_options = shift;

    my $hour_height  = $cal_options->{hour_height};
    my $yzoom        = $cal_options->{yzoom};
    my $start_of_day = $cal_options->{start_of_day};
    my $end_of_day   = $cal_options->{end_of_day};

    my $params = $request->{params}->{checked};
    my $permissions = $request->{permissions} || {};
    unless ( $permissions->{read_series} == 1 ) {
        uac::permissions_denied('read_series');
        return;
    }

    #get range from user settings
    my $user_settings = user_settings::get( $config, { user => $params->{presets}->{user} } );
    $params->{range} = $user_settings->{range} unless defined $params->{range};
    $params->{range} = 28 unless defined $params->{range};

    #get colors from user settings
    print user_settings::getColorCss( $config, { user => $params->{presets}->{user} } )
      if $params->{part} == 0;

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'all,calendar' } );
    my $language = $user_settings->{language} || 'en';
    $params->{language} = $language;
    print localization::getJavascript( $params->{loc} ) if $params->{part} == 0;

    my $calendar = getCalendar( $config, $params, $language );
    my $options  = {};
    my $events   = [];

    if ( ( $params->{part} == 1 ) || ( $params->{list} == 1 ) ) {

        #set date range
        my $from = $calendar->{from_date};
        my $till = $calendar->{till_date};

        my $project_id = $params->{project_id};
        my $studio_id  = $params->{studio_id};

        #build event filter
        $options = {
            project_id         => $project_id,
            template           => 'no',
            limit              => 600,
            get                => 'no_content',
            from_date          => $from,
            till_date          => $till,
            date_range_include => 1,
            archive            => 'all',
        };

        # set options depending on switches
        if ( $params->{studio_id} ne '-1' ) {
            $options->{studio_id} = $studio_id;
            my $location = $params->{presets}->{studio}->{location};
            $options->{location} = $location if $location =~ /\S/;
        }

        if ( $params->{project_id} ne '-1' ) {
            $options->{project_id} = $project_id;
            my $project = $params->{presets}->{project}->{name};
            $options->{project} = $project if $project =~ /\S/;
        }

        if ( defined $params->{series_id} ) {
            $options->{series_id} = $params->{series_id};
            delete $options->{from_date};
            delete $options->{till_date};
            delete $options->{date_range_include};
        }

        if ( $params->{search} =~ /\S/ ) {
            if ( $params->{list} == 1 ) {
                $options->{search} = $params->{search};
                delete $options->{from_date};
                delete $options->{till_date};
                delete $options->{date_range_include};
            }
        }
        $options->{from_time} = '00:00' if defined $options->{from_date};

        $options->{draft} = 0 unless $params->{list} == 1;

        #get events sorted by date
        $events = getSeriesEvents( $config, $request, $options, $params );
        unless ( $params->{list} == 1 ) {
            for my $event (@$events) {
                $event->{origStart} = $event->{start};
            }
            $events = break_dates( $events, $start_of_day );
        }

        # recalc after break (for list only?)
        for my $event (@$events) {
            delete $event->{day};
            delete $event->{start_date};
            delete $event->{end_date};
            $event = events::calc_dates( $config, $event );
        }

        my $events_by_start = {};
        for my $event (@$events) {
            $events_by_start->{ $event->{start} } = $event;
        }

        #build series filter
        $options = {
            project_id         => $project_id,
            studio_id          => $studio_id,
            from               => $from,
            till               => $till,
            date_range_include => 1,
            exclude            => 0
        };

        if ( defined $params->{series_id} ) {
            $options->{series_id} = $params->{series_id};
            delete $options->{from};
            delete $options->{till};
            delete $options->{date_range_include};
        }

        if ( $params->{search} =~ /\S/ ) {
            $options->{search} = $params->{search};
            if ( $params->{list} == 1 ) {
                delete $options->{from};
                delete $options->{till};
                delete $options->{date_range_include};
            }
        }

        #get all series dates
        my $series_dates = series_dates::get_series( $config, $options );
        my $id = 0;
        for my $date (@$series_dates) {
            $date->{schedule} = 1;

            #$date->{event_id}=-1;
            $date->{event_id}  = $id;
            $date->{origStart} = $date->{start};
            delete $date->{day};
            delete $date->{start_date};
            delete $date->{end_date};
            $id++;
        }
        unless ( $params->{list} == 1 ) {
            $series_dates = break_dates( $series_dates, $start_of_day );
        }

        #merge series and events
        for my $date (@$series_dates) {
            $date = events::calc_dates( $config, $date );
            push @$events, $date;
        }

        #get timeslot_dates
        my $studio_dates = studio_timeslot_dates::get( $config, $options );

        $id = 0;
        for my $date (@$studio_dates) {
            $date->{grid}      = 1;
            $date->{series_id} = -1;

            #$date->{event_id}=-1;
            $date->{event_id}  = $id;
            $date->{origStart} = $date->{start};
            delete $date->{day};
            delete $date->{start_date};
            delete $date->{end_date};
            $id++;
        }
        unless ( $params->{list} == 1 ) {
            $studio_dates = break_dates( $studio_dates, $start_of_day );
        }

        for my $date (@$studio_dates) {
            $date = events::calc_dates( $config, $date );
            push @$events, $date;
        }

        #get work_dates
        my $work_dates = work_dates::get( $config, $options );
        for my $date (@$work_dates) {
            $date->{work}      = 1;
            $date->{series_id} = -1;
            $date->{event_id}  = -1;
            $date->{origStart} = $date->{start};
            delete $date->{day};
            delete $date->{start_date};
            delete $date->{end_date};
        }
        unless ( $params->{list} == 1 ) {
            $work_dates = break_dates( $work_dates, $start_of_day );
        }

        for my $date (@$work_dates) {
            $date = events::calc_dates( $config, $date );
            push @$events, $date;
        }

        #get playout
        delete $options->{exclude};
        my $playout_dates = playout::get_scheduled( $config, $options );
        $id = 0;
        for my $date (@$playout_dates) {
            my $format = undef;
            if ( defined $date->{'format'} ) {
                $format =
                    ( $date->{'format'}         || '' ) . " "
                  . ( $date->{'format_version'} || '' ) . " "
                  . ( $date->{'format_profile'} || '' );
                $format =~ s/MPEG Audio Version 1 Layer 3/MP3/g;
                $format .= ' ' . ( $date->{'format_settings'} || '' )
                  if defined $date->{'format_settings'};
                $format .= '<br>';
            }

            $date->{play}      = 1;
            $date->{series_id} = -1;
            $date->{event_id}  = $id;
            $date->{title}     = '';
            $date->{title} .= '<b>errors</b>: ' . $date->{errors} . '<br>'
              if defined $date->{errors};
            $date->{title} .= audio::formatDuration(
                $date->{duration},
                $date->{event_duration},
                sprintf( "duration: %.1g h", $date->{duration} / 3600 ) . "<br>",
                sprintf( "%d s",             $date->{duration} )
            ) if defined $date->{duration};
            $date->{title} .= audio::formatLoudness( $date->{rms_left}, 'L: ' ) . ', '
              if defined $date->{rms_left};
            $date->{title} .= audio::formatLoudness( $date->{rms_right}, 'R: ' ) . '<br>'
              if defined $date->{rms_right};
            $date->{title} .= audio::formatBitrate( $date->{bitrate} ) if defined $date->{bitrate};
            $date->{title} .= ' ' . audio::formatBitrateMode( $date->{bitrate_mode} ) . '<br>'
              if defined $date->{bitrate_mode};
            $date->{title} .=
              '<b>replay gain</b> ' . sprintf( "%.1f", $date->{replay_gain} ) . '<br>'
              if defined $date->{replay_gain};
            $date->{title} .= audio::formatSamplingRate( $date->{sampling_rate} )
              if defined $date->{sampling_rate};
            $date->{title} .= audio::formatChannels( $date->{channels} ) . '<br>'
              if defined $date->{channels};
            $date->{title} .= int( ( $date->{'stream_size'} || '0' ) / ( 1024 * 1024 ) ) . 'MB<br>'
              if defined $date->{'stream_size'};
            $date->{title} .= $format if defined $format;
            $date->{title} .= '<b>library</b>: ' . ( $date->{writing_library} || '' ) . '<br>'
              if defined $date->{'writing_library'};
            $date->{title} .= '<b>path</b>: ' . ( $date->{file} || '' ) . '<br>'
              if defined $date->{file};
            $date->{title} .= '<b>updated_at</b>: ' . ( $date->{updated_at} || '' ) . '<br>'
              if defined $date->{updated_at};
            $date->{title} .= '<b>modified_at</b>: ' . ( $date->{modified_at} || '' ) . '<br>'
              if defined $date->{modified_at};

            $date->{rms_image} = URI::Escape::uri_unescape( $date->{rms_image} )
              if defined $date->{rms_image};

            $date->{origStart} = $date->{start};

            # set end date seconds to 00 to handle error at break_dates/join_dates
            $date->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1\:00/;
            delete $date->{day};
            delete $date->{start_date};
            delete $date->{end_date};
            $id++;
        }

        unless ( $params->{list} == 1 ) {
            $playout_dates = break_dates( $playout_dates, $start_of_day );
        }

        for my $date (@$playout_dates) {
            $date = events::calc_dates( $config, $date );
            if ( defined $events_by_start->{ $date->{start} } ) {
                $events_by_start->{ $date->{start} }->{duration} = $date->{duration} || 0;
                $events_by_start->{ $date->{start} }->{event_duration} =
                  $date->{event_duration} || 0;
                $events_by_start->{ $date->{start} }->{rms_left}  = $date->{rms_left}  || 0;
                $events_by_start->{ $date->{start} }->{rms_right} = $date->{rms_right} || 0;
                $events_by_start->{ $date->{start} }->{playout_modified_at} = $date->{modified_at};
                $events_by_start->{ $date->{start} }->{playout_updated_at}  = $date->{updated_at};
                $events_by_start->{ $date->{start} }->{file}  = $date->{file};
            }
            push @$events, $date;
        }
        
        # series dates
        if ($params->{list} == 1){
            my $series = series::get(
                $config,
                {
                    #project_id => $project_id,
                    #studio_id  => $studio_id,
                    series_id  => $options->{series_id}
                }
            );
            if ( defined $series->[0] and $series->[0]->{predecessor_id}
                and $series->[0]->{predecessor_id} ne $series->[0]->{id} ){
                my $events2 = getSeriesEvents( $config, $request, {
                    series_id => $series->[0]->{predecessor_id}
                }, $params );
                
                for my $event (@$events2) {
                    delete $event->{day};
                    delete $event->{start_date};
                    delete $event->{end_date};
                    push @$events, events::calc_dates( $config, $event );
                }
            }
        }
    }

    #output
    printToolbar( $config, $params, $calendar ) if $params->{part} == 0;

    #if($params->{part}==1){
    print qq{
        <script> 
            var current_date="$calendar->{month} $calendar->{year}";
            var previous_date="$calendar->{previous_date}";
            var next_date="$calendar->{next_date}";
        </script>
        };

    #}

    #filter events by time
    unless ( $params->{list} == 1 ) {
        $events = filterEvents( $events, $options, $start_of_day );
    }

    #sort events by start
    @$events = sort { $a->{start} cmp $b->{start} } @$events;

    #separate by day (e.g. to 6 pm)
    my $events_by_day = {};
    for my $event (@$events) {
        my $day =
          time::datetime_to_date( time::add_hours_to_datetime( $event->{start}, -$start_of_day ) );
        push @{ $events_by_day->{$day} }, $event;
    }

    #get min and max hour from all events
    unless ( $params->{list} == 1 ) {
        my $min_hour = 48;
        my $max_hour = 0;

        for my $event (@$events) {
            if ( $event->{start} =~ /(\d\d)\:\d\d\:\d\d$/ ) {
                my $hour = $1;
                $hour += 24 if $hour < $start_of_day;
                $min_hour = $hour if ( $hour < $min_hour ) && ( $hour >= $start_of_day );
            }
            if ( $event->{end} =~ /(\d\d)\:\d\d\:\d\d$/ ) {
                my $hour = $1;
                $hour += 24 if $hour <= $start_of_day;
                $max_hour = $hour if ( $hour > $max_hour ) && ( $hour <= $end_of_day );
            }
        }
        $cal_options->{min_hour} = $min_hour;
        $cal_options->{max_hour} = $max_hour;
    }

    #print STDERR $start_of_day." ".$cal_options->{min_hour}."\n";

    # calculate positions and find schedule errors (depending on position)
    for my $date ( sort ( keys %$events_by_day ) ) {
        my $events = $events_by_day->{$date};
        calc_positions( $events, $cal_options );
        find_errors($events);
    }

    for my $event (@$events) {
        next unless defined $event->{uploaded_at};
        next
          if ( defined $event->{playout_updated_at} )
          && ( $event->{uploaded_at} lt $event->{playout_updated_at} );

    }

    if ( $params->{list} == 1 ) {
        showEventList( $config, $permissions, $params, $events_by_day );
    } else {
        if ( $params->{part} == 0 ) {
            print qq{<div id="calendarTable"> </div>};
        }
        if ( $params->{part} == 1 ) {
            calcCalendarTable( $config, $permissions, $params, $calendar, $events_by_day,
                $cal_options );
            printTableHeader( $config, $permissions, $params, $cal_options );
            printTableBody( $config, $permissions, $params, $cal_options );
        }
        if ( $params->{part} == 0 ) {
            printSeries( $config, $permissions, $params, $cal_options );
            print qq{
                    </main>
            };
        }

        # time has to be set when events come in
        printJavascript( $config, $permissions, $params, $cal_options );
        if ( $params->{part} == 0 ) {
            print qq{
                    </body>
                </html>
            };
        }
    }
}

sub debugDate {
    my $date = shift;
    $date->{program}     = '' unless defined $date->{program};
    $date->{series_name} = '' unless defined $date->{series_name};
    $date->{title}       = '' unless defined $date->{title};
    $date->{splitCount}  = 0  unless defined $date->{splitCount};
    my $dt = ( $date->{start} || '' ) . "   " . ( $date->{end} | '' );
    my $da = ( $date->{start_date} || '' ) . "    " . ( $date->{end_date} || '' );
    my $type = "schedule:" . ( $date->{schedule} || "" ) . " grid:" . ( $date->{grid} || "" );

#print STDERR "$dt  $da count:$date->{splitCount} $type  $date->{program}-$date->{series_name}-$date->{title}\n";
}

# break dates at start_of_day

sub break_dates {
    my $dates        = shift;
    my $start_of_day = shift;

    #return $dates if $start_of_day eq '0';

    for my $date (@$dates) {
        next unless defined $date;

        $date->{splitCount} = 0 unless defined $date->{splitCount};

        #debugDate($date);

        next if $date->{splitCount} > 6;
        my $nextDayStart = breaks_day( $date->{start}, $date->{end}, $start_of_day );
        next if $nextDayStart eq '0';

        # add new entry
        my $entry = {};
        for my $key ( keys %$date ) {
            $entry->{$key} = $date->{$key};
        }
        $entry->{start} = $nextDayStart;
        $entry->{splitCount}++;
        push @$dates, $entry;

#        print STDERR "add $entry->{start}   $entry->{end}   count:$entry->{splitCount}  $entry->{program}-$entry->{series_name}-$entry->{title}\n";

        #modify existing entry
        my $start_date = time::datetime_to_date( $date->{start} );
        $date->{end} = $nextDayStart;
        $date->{splitCount}++;

#        print STDERR "set $date->{start}   $date->{end}   count:$date->{splitCount}  $date->{program}-$date->{series_name}-$date->{title}\n";
    }

    return join_dates( $dates, $start_of_day );
}

# check if event breaks the start of day (e.g. 06:00)
sub breaks_day {
    my $start        = shift;
    my $end          = shift;
    my $start_of_day = shift;

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
    return $dayStart if ( $start lt $dayStart ) && ( $end gt $dayStart );

    # start before 6:00 of next day
    my $nextDayStart = time::add_days_to_datetime( $dayStart, 1 );

    #$nextDayStart=~s/:00$//;
    return $nextDayStart if ( $start lt $nextDayStart ) && ( $end gt $nextDayStart );

    return 0;
}

# merge events with same seriesId and eventId at 00:00
sub join_dates {
    my $dates        = shift;
    my $start_of_day = shift;

    return $dates if $start_of_day == 0;
    @$dates = sort { $a->{start} cmp $b->{start} } @$dates;

    my $prev_date = undef;
    for my $date (@$dates) {
        next unless defined $date;
        unless ( defined $prev_date ) {
            $prev_date = $date;
            next;
        }
        if (   ( $date->{event_id} == $prev_date->{event_id} )
            && ( $date->{series_id} == $prev_date->{series_id} )
            && ( $date->{start} eq $prev_date->{end} )
            && ( $date->{start} =~ /00\:00\:\d\d/ ) )
        {
            $prev_date->{end} = $date->{end};
            $date = undef;
            next;
        }
        $prev_date = $date;
    }

    my $results = [];
    for my $date (@$dates) {
        next unless defined $date;
        push @$results, $date;
    }

    return $results;
}

sub filterEvents {
    my $events       = shift;
    my $options      = shift;
    my $start_of_day = shift;

    return [] unless defined $options->{from};
    return [] unless defined $options->{till};

    my $dayStartTime  = time::array_to_time($start_of_day);
    my $startDatetime = $options->{from} . ' ' . $dayStartTime;
    my $endDatetime   = $options->{till} . ' ' . $dayStartTime;

    my $results = [];
    for my $date (@$events) {
        next if ( ( $date->{start} ge $endDatetime ) || ( $date->{end} le $startDatetime ) );
        push @$results, $date;
    }
    return $results;
}

sub showEventList {
    my $config        = shift;
    my $permissions   = shift;
    my $params        = shift;
    my $events_by_day = shift;
    my $language      = $params->{language};

    my $rerunIcon = '<i class="fas fa-redo" title="$params->{loc}->{label_rerun}"></i>';
    my $liveIcon  = '<i class="fas fa-microphone-alt" title="$params->{loc}->{label_live}"></i>';
    my $draftIcon = '<i class="fas fa-drafting-compass" title="$params->{loc}->{label_draft}"></i>';
    my $archiveIcon = '<i class="fas fa-archive" title="$params->{loc}->{label_archived}"></i>';

    my $out = '';
    $out = qq{
        <div id="event_list">
        <table>
            <thead>
                <tr>
                    <th class="day_of_year">$params->{loc}->{label_day_of_year}</th>
                    <th class="weekday">$params->{loc}->{label_weekday}</th>
                    <th class="start_date">$params->{loc}->{label_start}</th>
                    <th class="start_time">$params->{loc}->{label_end}</th>
                    <th class="series_name">$params->{loc}->{label_series}</th>
                    <th class="title">$params->{loc}->{label_title}</th>
                    <th class="episode">$params->{loc}->{label_episode}</th>
                    <th class="rerun">$rerunIcon</th>
                    <th class="draft">$draftIcon</th>
                    <th class="live">$liveIcon</th>
                    <th class="archive">$archiveIcon</th>
                    <th class="project_id">project</th>
                    <th class="studio">studio</th>
                 </tr>
            </thead>
            <tbody>
    } if $params->{part} == 0;
    my $i = 1;

    my $scheduled_events = {};
    for my $date ( reverse sort ( keys %$events_by_day ) ) {
        for my $event ( reverse @{ $events_by_day->{$date} } ) {
            next unless defined $event;
            next if defined $event->{grid};
            next if defined $event->{work};
            next if defined $event->{play};

            #schedules with matching date are marked to be hidden in find_errors
            next if defined $event->{hide};
            $event->{project_id} //= $params->{project_id};
            $event->{studio_id}  //= $params->{studio_id};
            $event->{series_id}  = '-1' unless defined $event->{series_id};
            $event->{event_id}   = '-1' unless defined $event->{event_id};
            my $id =
                'event_'
              . $event->{project_id} . '_'
              . $event->{studio_id} . '_'
              . $event->{series_id} . '_'
              . $event->{event_id};

            my $class = 'event';
            $class = $event->{class} if defined $event->{class};
            $class = 'schedule'      if defined $event->{schedule};
            if ( $class =~ /(event|schedule)/ ) {
                $class .= ' scheduled' if defined $event->{scheduled};
                $class .= ' error'     if defined $event->{error};
                $class .= ' no_series'
                  if ( ( $class eq 'event' ) && ( $event->{series_id} eq '-1' ) );

                for my $filter (
                    'rerun', 'archived',           'playout', 'published',
                    'live',  'disable_event_sync', 'draft'
                  )
                {
                    $class .= ' ' . $filter
                      if ( ( defined $event->{$filter} ) && ( $event->{$filter} eq '1' ) );
                }
                $class .= ' preproduced'
                  unless ( ( defined $event->{'live'} ) && ( $event->{'live'} eq '1' ) );
                $class .= ' no_playout'
                  unless ( ( defined $event->{'playout'} ) && ( $event->{'playout'} eq '1' ) );
                $class .= ' no_rerun'
                  unless ( ( defined $event->{'rerun'} ) && ( $event->{'rerun'} eq '1' ) );
            }

            $event->{start}              ||= '';
            $event->{weekday_short_name} ||= '';
            $event->{start_date_name}    ||= '';
            $event->{start_time_name}    ||= '';
            $event->{end_time}           ||= '';
            $event->{series_name}        ||= '';
            $event->{title}              ||= '';
            $event->{user_title}         ||= '';
            $event->{episode}            ||= '';
            $event->{rerun}              ||= '';
            $event->{draft}              ||= '';
            $id                          ||= '';
            $class                       ||= '';

            my $archived = $event->{archived} || '-';
            $archived = '-'          if $archived eq '0';
            $archived = $archiveIcon if $archived eq '1';

            my $live = $event->{live} || '-';
            $live = '-'       if $live eq '0';
            $live = $liveIcon if $live eq '1';

            my $rerun = $event->{rerun} || '-';

            $rerun = " [" . markup::base26( $event->{recurrence_count} + 1 ) . "]"
              if ( defined $event->{recurrence_count} )
              && ( $event->{recurrence_count} ne '' )
              && ( $event->{recurrence_count} > 0 );

            my $draft = $event->{draft} || '0';
            $draft = '-'        if $draft eq '0';
            $draft = $draftIcon if $draft eq '1';

            my $title = $event->{title};
            $title .= ': ' . $event->{user_title} if $event->{user_title} ne '';
            
            my $other_studio  = $params->{studio_id}  ne $event->{studio_id};
            my $other_project = $params->{project_id} ne $event->{project_id};
            $class.=' predecessor' if $other_project or $other_studio;
            $other_studio  = '<i class="fas fa-globe-americas"></i>' if $other_studio;
            $other_project = '<i class="fas fa-globe-americas"></i>' if $other_project;

            $out .=
                qq!<tr id="$id" class="$class" start="$event->{start}" >!
              . qq!<td class="day_of_year">!
              . time::dayOfYear( $event->{start} )
              . q!</td>!
              . qq!<td class="weekday">$event->{weekday_short_name},</td>!
              . qq!<td class="start_date">$event->{start_date_name}</td>!
              . qq!<td class="start_time">$event->{start_time_name} - $event->{end_time}</td>!
              . qq!<td class="series_name">$event->{series_name}</td>!
              . qq!<td class="title">$title</td>!
              . qq!<td class="episode">$event->{episode}</td>!
              . qq!<td class="rerun">$rerun</td>!
              . qq!<td class="draft">$draft</td>!
              . qq!<td class="live">$live</td>!
              . qq!<td class="archived">$archived</td>!
              . qq!<td>$event->{project_name} $other_studio</td>!
              . qq!<td>$event->{studio_name} $other_studio</td>!
              . qq!</tr>! . "\n";
        }
        $i++;
        if ( $i % 100 == 0 ) {
            print $out;
            $out = '';
        }
    }
    $out .= qq{
                </tbody>
            </table>
        </div>
    } if $params->{part} == 0;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #add handler for events not assigned to series
    if ( ( $params->{studio_id} ne '' ) && ( $params->{studio_id} ne '-1' ) ) {
        my $series = series::get(
            $config,
            {
                project_id => $project_id,
                studio_id  => $studio_id
            }
        );
        $out .= q{<div id="event_no_series" style="display:none">};
        $out .= addEventsToSeries( $series, $params )
          if ( defined $permissions->{assign_series_events} )
          && ( $permissions->{assign_series_events} eq '1' );
        $out .= createSeries($params)
          if ( defined $permissions->{create_series} ) && ( $permissions->{create_series} eq '1' );
        $out .= q{</div>};
    }

    $out .= qq{
            </main>
            <script>
                var region='} . $params->{loc}->{region} . q{';
                var calendarTable=0;
                var label_events='} . $params->{loc}->{label_events} . q{';
                var label_schedule='} . $params->{loc}->{label_schedule} . q{';
                var label_worktime='} . $params->{loc}->{label_worktime} . q{';
                var label_playout='} . $params->{loc}->{label_playout} . q{';
            </script>
        </body>
    </html>
    } if $params->{part} == 0;

    print $out;

}

sub calcCalendarTable {
    my $config        = shift;
    my $permissions   = shift;
    my $params        = shift;
    my $calendar      = shift;
    my $events_by_day = shift;
    my $cal_options   = shift;

    my $start_of_day = $cal_options->{start_of_day};
    my $end_of_day   = $cal_options->{end_of_day};
    my $min_hour     = $cal_options->{min_hour};
    my $max_hour     = $cal_options->{max_hour};
    my $project_id   = $params->{project_id};
    my $studio_id    = $params->{studio_id};
    my $language     = $params->{language};

    #insert time column
    for my $hour ( $min_hour .. $max_hour ) {
        push @{ $events_by_day->{0} },
          {
            start      => sprintf( '%02d:00', $hour % 24 ),
            start_time => sprintf( '%02d:00', $hour ),
            end_time   => sprintf( '%02d:00', $hour + 1 ),
            series_id  => -1,
            event_id   => -1,
            project_id => $project_id,
            studio_id  => $studio_id,
            class      => 'time',
            'time'     => sprintf( '%02d',    $hour % 24 )
          };
    }

    #insert current time
    my $now  = time::get_datetime( time::time_to_datetime(), $config->{date}->{time_zone} );
    my $time = '00:00';
    my $date = '';
    if ( $now =~ /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d\:\d\d)/ ) {
        $date = $1;
        $time = $2;
    }

    push @{ $events_by_day->{0} },
      {
        start      => $time,
        start_time => $time,
        end_time   => $time,
        series_id  => -1,
        event_id   => -1,
        project_id => -1,
        studio_id  => -1,
        class      => 'time now',
        'time'     => $time,
      };
    calc_positions( $events_by_day->{0}, $cal_options );

    my $yoffset = $min_hour * $hour_height;
    my @days    = sort keys %$events_by_day;

    $cal_options->{days}          = \@days;
    $cal_options->{yoffset}       = $yoffset;
    $cal_options->{events_by_day} = $events_by_day;
    $cal_options->{date}          = $date;

}

sub printTableHeader {
    my $config      = shift;
    my $permissions = shift;
    my $params      = shift;
    my $cal_options = shift;

    my $days          = $cal_options->{days};
    my $events_by_day = $cal_options->{events_by_day};
    my $yoffset       = $cal_options->{yoffset};
    my $date          = $cal_options->{date};
    my $min_hour      = $cal_options->{min_hour};

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $language   = $params->{language};

    #print row with weekday and date
    my $out = '';

    my $numberOfDays = scalar(@$days);
    my $width        = int( 85 / $numberOfDays );
    $out .= qq!
        <script>
            var days=$numberOfDays;
        </script>
        <style>
            #calendar div.time, 
            #calendar_weekdays div.date, 
            #calendar div.event, 
            #calendar div.schedule, 
            #calendar div.work, 
            #calendar div.play,
            #calendar div.grid {
                width: $width%
            }        
        </style>
    !;

    $out .= q{
        <div id="calendar_weekdays" style="visibility:hidden">
            <table>
                <tbody>
                    <tr>
    };

    my $next_day_found = 0;

    #print navigation and weekday
    my $ypos     = 0;
    my $old_week = undef;
    my $dt       = undef;
    for my $day (@$days) {
        my $events = $events_by_day->{$day};

        if ( $day ne '0' ) {
            $dt = time::get_datetime( $day . 'T00:00:00', $config->{date}->{time_zone} );
            my $week = $dt->week_number();
            if ( ( defined $old_week ) && ( $week ne $old_week ) ) {
                $out .= qq{<td class="week"><div class="week"></div></td>};
            }
            $old_week = $week;
        }

        #header
        $out .= qq{<td>};
        my $event   = $events->[0];
        my $content = '';
        my $class   = 'date';
        if ( $day eq '0' ) {
            $out .= qq{<div id="position"></div></td>};
            next;
        } else {

            #print weekday
            $dt->set_locale($language);
            $content = $dt->day_name() . '<br>';
            $content .= $dt->strftime('%d. %b %Y') . '<br>';
            $content .= time::dayOfYear( $event->{start} ) . '<br>';

            #$class="date";
            if ( ( $day ge $date ) && ( $next_day_found == 0 ) ) {
                $class          = "date today";
                $next_day_found = 1;
            }
        }

        #insert date name
        my $hour = $min_hour;
        my $date = $day;
        $event = {
            start      => sprintf( '%02d:00', $hour % 24 ),
            start_time => sprintf( '%02d:00', $hour ),
            end_time   => sprintf( '%02d:30', $hour + 1 ),
            project_id => $project_id,
            studio_id  => $studio_id,
            content    => $content,
            class      => $class,
            date       => $date
        };

        calc_positions( [$event], $cal_options );
        $out .= print_event( $params, $event, $ypos, $yoffset, $yzoom );

        $out .= '</td>';
    }
    $out .= q{
                    </tr>
                </tbody>
            </table>
        </div>
    };
    print $out;
}

sub printTableBody {
    my $config      = shift;
    my $permissions = shift;
    my $params      = shift;
    my $cal_options = shift;

    my $days          = $cal_options->{days};
    my $events_by_day = $cal_options->{events_by_day};
    my $yoffset       = $cal_options->{yoffset};

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    if ( scalar( @{$days} ) == 0 ) {
        uac::print_info("no dates found at the selected time span");
    }

    my $out = q{
        <div id="calendar" style="display:none">
            <table>
                <tbody>
                    <tr>
    };

    #print events with weekday and date
    my $ypos     = 1;
    my $dt       = undef;
    my $old_week = undef;

    for my $day (@$days) {
        my $events = $events_by_day->{$day};

        if ( $day ne '0' ) {
            $dt = time::get_datetime( $day . 'T00:00:00', $config->{date}->{time_zone} );
            my $week = $dt->week_number();
            if ( ( defined $old_week ) && ( $week ne $old_week ) ) {
                $out .= qq{<td class="week"><div class="week"></div></td>};
            }
            $old_week = $week;
        }

        $out .= qq{<td>};    # width="$width">};

        for my $event (@$events) {
            my $content = '';
            if ( ( defined $event->{series_name} ) && ( $event->{series_name} ne '' ) ) {
                $event->{series_name} = $params->{loc}->{single_event}
                  if $event->{series_name} eq '' || $event->{series_name} eq '_single_';
                $content = '<b>' . $event->{series_name} . '</b><br>';
            }

            if ( ( defined $event->{title} ) && ( defined $event->{title} ne '' ) ) {
                $content .= $event->{title};
                unless ( $event->{title} =~ /\#\d+/ ) {
                    $content .= ' #' . $event->{episode}
                      if ( ( defined $event->{episode} ) && ( $event->{episode} ne '' ) );
                }
            }
            $content = $event->{start} if $day eq '0';
            $event->{project_id} = $project_id unless defined $event->{project_id};
            $event->{studio_id}  = $studio_id  unless defined $event->{studio_id};
            $event->{content}    = $content
              unless ( ( defined $event->{class} ) && ( $event->{class} eq 'time now' ) );
            $event->{class} = 'event' if $day ne '0';
            $event->{class} = 'grid' if ( ( defined $event->{grid} ) && ( $event->{grid} == 1 ) );
            $event->{class} = 'schedule'
              if ( ( defined $event->{schedule} ) && ( $event->{schedule} == 1 ) );
            $event->{class} = 'work' if ( ( defined $event->{work} ) && ( $event->{work} == 1 ) );
            $event->{class} = 'play' if ( ( defined $event->{play} ) && ( $event->{play} == 1 ) );

            if ( $event->{class} eq 'event' ) {
                $event->{content} .= '<br><span class="weak">';
                $event->{content} .= audio::formatFile($event->{file}, $event->{event_id});
                $event->{content} .= audio::formatDuration(
                    $event->{duration},
                    $event->{event_duration},
                    sprintf( "%d min", ( $event->{duration} + 30 ) / 60 ),
                    sprintf( "%d s", $event->{duration} )
                  )
                  . ' '
                  if defined $event->{duration};
                $event->{content} .= audio::formatLoudness( $event->{rms_left}, 'L: ' ) . ' '
                  if defined $event->{rms_left};
                $event->{content} .= audio::formatLoudness( $event->{rms_right}, 'R: ' )
                  if defined $event->{rms_right};
                #$event->{content} .= formatBitrate( $event->{bitrate} ) if defined $event->{bitrate};
                $event->{content} .= '</span>';
            }

            $out .= print_event( $params, $event, $ypos, $yoffset, $yzoom );

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

    print $out;
}

sub printSeries {
    my $config      = shift;
    my $permissions = shift;
    my $params      = shift;
    my $cal_options = shift;

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

    #add schedule entry for series
    if (   ( defined $permissions->{update_schedule} )
        && ( $permissions->{update_schedule} eq '1' )
        && ( scalar(@$series) > 0 ) )
    {
        $out .= q{<div id="series" style="display:none">};
        $out .= addSeries( $series, $params );
        $out .= q{</div>};
    }

    if ( ( $params->{studio_id} ne '' ) && ( $params->{studio_id} ne '-1' ) ) {
        $out .= q{<div id="event_no_series" style="display:none">};
        $out .= addEventsToSeries( $series, $params )
          if ( ( defined $permissions->{assign_series_events} )
            && ( $permissions->{assign_series_events} eq '1' ) );
        $out .= createSeries($params)
          if ( ( defined $permissions->{create_series} )
            && ( $permissions->{create_series} eq '1' ) );
        $out .= q{</div>};
    }

    $out .= q{
        <div id="no_studio_selected" style="display:none">
            } . $params->{loc}->{label_no_studio_selected} . q{
        </div>
    };
    print $out;
}

sub printJavascript {
    my $config      = shift;
    my $permissions = shift;
    my $params      = shift;
    my $cal_options = shift;

    my $startOfDay = $cal_options->{min_hour} % 24;

    #print STDERR "js: ".$cal_options->{min_hour}." ".$startOfDay."\n";
    my $out = q{
        <script>
            var region='} . $params->{loc}->{region} . q{';
            var calendarTable=1;
            var startOfDay=} . $startOfDay . q{;
            var label_events='} . $params->{loc}->{label_events} . q{';
            var label_schedule='} . $params->{loc}->{label_schedule} . q{';
            var label_worktime='} . $params->{loc}->{label_worktime} . q{';
            var label_playout='} . $params->{loc}->{label_playout} . q{';
        </script>
    };
    print $out;
}

#TODO: Javascript

sub addCalendarButton {
    my $params   = shift;
    my $calendar = shift;

    #add calendar button
    my $content = qq{
        <div id="previous_month"><a id="previous">&laquo;</a></div>
        <div id="selectDate">
            <input id="start_date"/>
            <div id="current_date">$calendar->{month} $calendar->{year}</div>
        </div>
        <div id="next_month"><a id="next">&raquo;</a></div>
    };
    return $content;
}

sub addSeries {
    my $series = shift;
    my $params = shift;

    return unless defined $series;
    return unless scalar @$series > 0;

    my $out = '';
    $out .= q{
        <table>
          <tr>
                <td>} . $params->{loc}->{label_series} . q{</td>
                <td><select id="series_select" name="series_id">
    };

    for my $serie (@$series) {
        my $id       = $serie->{series_id}   || -1;
        my $duration = $serie->{duration}    || 0;
        my $name     = $serie->{series_name} || '';
        my $title    = $serie->{title}       || '';
        $name = $params->{loc}->{single_events} if $serie->{has_single_events} eq '1';
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
            <tr>
                <td>} . $params->{loc}->{label_date} . q{</td>
                <td><input id="series_date" name="start_date" value=""></td>
            </tr>
            <tr>
                <td>} . $params->{loc}->{label_duration} . q{</td>
                <td><input id="series_duration" value="60"></td>
            </tr>
            </table>
        </div>
    };
    return $out;

}

# create form to add events to series (that are not assigned to series, yet)
sub addEventsToSeries {
    my $series = shift;
    my $params = shift;

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

    for my $serie (@$series) {
        my $id       = $serie->{series_id}   || -1;
        my $duration = $serie->{duration}    || '';
        my $name     = $serie->{series_name} || '';
        my $title    = $serie->{title}       || '';
        $name = $params->{loc}->{single_events} if $serie->{has_single_events} == 1;
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
sub createSeries {
    my $params = shift;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    return qq{
        <div>
            <b>} . $params->{loc}->{label_create_series} . qq{</b>
            <form method="post" action="series.cgi">
                <input type="hidden" name="project_id" value="$project_id">
                <input type="hidden" name="studio_id"  value="$studio_id">
                <table>
                    <tr><td class="label">}
      . $params->{loc}->{label_name} . qq{</td>     <td><input name="series_name"></td></tr>
                    <tr><td class="label">}
      . $params->{loc}->{label_title} . qq{</td>     <td><input name="title"></td></tr>
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

sub print_event {
    my $params  = shift;
    my $event   = shift;
    my $ypos    = shift;
    my $yoffset = shift;
    my $yzoom   = shift;

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
    $id = 'grid_' . $event->{project_id} . '_' . $event->{studio_id} . '_' . $event->{series_id}
      if defined $event->{grid};
    $id = 'work_' . $event->{project_id} . '_' . $event->{studio_id} . '_' . $event->{schedule_id}
      if defined $event->{work};
    $id = 'play_' . $event->{project_id} . '_' . $event->{studio_id} if defined $event->{play};

    my $class = $event->{class} || '';
    my $showIcons = 0;
    if ( $class =~ /(event|schedule)/ ) {
        $class .= ' scheduled' if defined $event->{scheduled};
        $class .= ' no_series' if ( ( $class eq 'event' ) && ( $event->{series_id} eq '-1' ) );
        $class .= " error x$event->{error}" if defined $event->{error};

        for my $filter ( 'rerun', 'archived', 'playout', 'published', 'live', 'disable_event_sync',
            'draft' )
        {
            $class .= ' ' . $filter
              if ( ( defined $event->{$filter} ) && ( $event->{$filter} eq '1' ) );
        }
        $class .= ' preproduced'
          unless ( ( defined $event->{'live'} ) && ( $event->{'live'} eq '1' ) );
        $class .= ' no_playout'
          unless ( ( defined $event->{'playout'} ) && ( $event->{'playout'} eq '1' ) );
        $class .= ' no_rerun'
          unless ( ( defined $event->{'rerun'} ) && ( $event->{'rerun'} eq '1' ) );
        $showIcons = 1;
    }

    my $ystart = $event->{ystart} - $yoffset;
    my $yend   = $event->{yend} - $yoffset - 10;

    $ystart = int( $ystart * $yzoom );
    $yend   = int( $yend * $yzoom );
    my $height = $yend - $ystart + 1;

    if ( $ypos > 0 ) {
        $height = q{height:} . ($height) . 'px;';
    } else {
        $height = '';
    }

    #	my $date = $event->{origStart} || $event->{start} || '';
    my $content = $event->{content} || '';

    if ( $class =~ /schedule/ ) {
        my $frequency = getFrequency($event);
        $content .= "<br>($frequency)" if defined $frequency;
    }

    my $attr = '';
    if ( $class =~ /play/ ) {

        #$event->{rms_image}=~s/\.png/.svg/;
        $attr .= ' rms="' . $event->{rms_image} . '"' if defined $event->{rms_image};
        $attr .= ' start="' . $event->{start} . '"'   if defined $event->{start};
    }

    if ( defined $event->{upload} ) {
        $content .= '<br>uploading <progress max="10" ></progress> ';
    }

    if ($showIcons) {
        my $attr =  { map { $_ => undef } split( /\s+/, $class) };
        
        my $file = $event->{file} 
            ? 'playout: ' . $event->{file} =~ s/\'/\&apos;/gr 
            : 'playout';

        my $icons='';
        if ( exists $attr->{event} ){
            $icons.='<i class="fas fa-microphone-alt" title="live"></i>'
                if exists($attr->{live}) && exists($attr->{no_rerun});
            $icons.='<i class="fas fa-microphone-slash" title="preproduced"></i>'
                if exists($attr->{preproduced}) && exists($attr->{no_rerun});
            $icons.='<i class="fas fa-redo" title="rerun"></i>'
                if exists $attr->{rerun};
            $icons.=qq{<i class="fas fa-play" title="$file" onmouseenter="console.log('$file');"></i>}
                if exists $attr->{playout};
            $icons.='<i class="fas fa-archive" title="archived"></i>'
                if exists $attr->{archived};
        }

        $content = qq{<div class="text">$content</div><div class="icons">$icons</div>};
    }

    my $time = '';
    $time = qq{ time="$event->{time}"} if $class =~ m/time/;

    my $date = '';
    $date = qq{ date="$event->{date}"} if $class =~ m/date/;

    my $line = q{<div } . qq{class="$class" id="$id"};
    $line .= qq{ style="} . $height . q{top:} . $ystart . q{px;"};
    $line .= $time . $date . qq{ $attr};
    $line .= qq{>$content</div>};
    $line .= "\n";
    return $line;
}

sub getFrequency {
    my $event = shift;

    my $period_type = $event->{period_type};
    return undef unless defined $period_type;
    return undef if $period_type ne 'days';

    my $frequency = $event->{frequency};
    return undef unless defined $frequency;
    return undef unless $frequency > 0;

    if ( ( $frequency >= 7 ) && ( ( $frequency % 7 ) == 0 ) ) {
        $frequency /= 7;
        return '1 week' if $frequency == 1;
        return $frequency .= ' weeks';
    }

    return '1 day' if $frequency == 1;
    return $frequency .= ' days';
}

sub calc_positions {
    my $events      = $_[0];
    my $cal_options = $_[1];

    my $start_of_day = $cal_options->{start_of_day};

    for my $event (@$events) {
        my ( $start_hour, $start_min ) = getTime( $event->{start_time} );
        my ( $end_hour,   $end_min )   = getTime( $event->{end_time} );

        $start_hour += 24 if $start_hour < $start_of_day;
        $end_hour   += 24 if $end_hour < $start_of_day;
        $end_hour   += 24 if $start_hour > $end_hour;
        $end_hour   += 24 if ( $start_hour == $end_hour ) && ( $start_min == $end_min );

        $event->{ystart} = $start_hour * 60 + $start_min;
        $event->{yend}   = $end_hour * 60 + $end_min;
    }
}

sub find_errors {
    my $events = $_[0];

    for my $event (@$events) {
        next if defined $event->{grid};
        next if defined $event->{work};
        next if defined $event->{play};
        next if ( defined $event->{draft} ) && ( $event->{draft} == 1 );
        next unless defined $event->{ystart};
        next unless defined $event->{yend};
        $event->{check_errors} = 1;
    }

    #check next events
    for my $i ( 0 .. scalar(@$events) - 1 ) {
        my $event = $events->[$i];
        next unless defined $event->{check_errors};

        #look for conflicts with next 5 events of day
        my $min_index = $i + 1;
        next if $min_index >= scalar @$events;
        my $max_index = $i + 8;
        $max_index = scalar(@$events) - 1 if $max_index >= (@$events);
        for my $j ( $min_index .. $max_index ) {
            my $event2 = $events->[$j];
            next unless defined $event2->{check_errors};

            #mark events if same start,stop,series_id, one is schedule one is event
            if (   ( defined $event->{series_id} )
                && ( defined $event2->{series_id} )
                && ( $event->{series_id} == $event2->{series_id} ) )
            {
                if (   ( $event->{ystart} eq $event2->{ystart} )
                    && ( $event->{yend} eq $event2->{yend} ) )
                {
                    if ( ( defined $event->{schedule} ) && ( !( defined $event2->{schedule} ) ) ) {
                        $event->{hide}       = 1;
                        $event2->{scheduled} = 1;
                        next;
                    }
                    if ( ( !( defined $event->{schedule} ) ) && ( defined $event2->{schedule} ) ) {
                        $event->{scheduled} = 1;
                        $event2->{hide}     = 1;
                        next;
                    }
                } elsif ( ( $event->{ystart} >= $event2->{ystart} )
                    && ( $event->{scheduled} == 1 )
                    && ( $event2->{scheduled} == 1 ) )
                {
                    #subsequent schedules
                    $event->{error}++;
                    $event2->{error} = 1 unless defined $event2->{error};
                    $event2->{error}++;
                    next;
                }
            } elsif ( $event->{ystart} >= $event2->{ystart} ) {

                #errors on multiple schedules or events
                $event->{error}++;
                $event2->{error} = 1 unless defined $event2->{error};
                $event2->{error}++;
            }
        }
    }

    #remove error tags from correctly scheduled entries (subsequent entries with same series id)
    for my $event (@$events) {
        delete $event->{error}
          if (
            ( defined $event->{error} )
            && (   ( ( defined $event->{scheduled} ) && ( $event->{scheduled} == 1 ) )
                || ( ( defined $event->{hide} ) && ( $event->{hide} == 1 ) ) )
          );
    }
}

sub printToolbar {
    my $config   = shift;
    my $params   = shift;
    my $calendar = shift;

    my $today = time::time_to_date();

    my $toolbar = '<div id="toolbar">';

    $toolbar .= addCalendarButton( $params, $calendar );
    $toolbar .= qq{<button id="setToday">} . $params->{loc}->{button_today} . qq{</button>};

    #ranges
    my $ranges = {
        $params->{loc}->{label_month}   => 'month',
        $params->{loc}->{label_4_weeks} => '28',
        $params->{loc}->{label_2_weeks} => '14',
        $params->{loc}->{label_1_week}  => '7',
        $params->{loc}->{label_day}     => '1',
    };
    $toolbar .= qq{
        <select id="range" name="range" onchange="reloadCalendar()" value="$params->{range}">
    };

    #    my $options=[];
    for my $range (
        $params->{loc}->{label_month},   $params->{loc}->{label_4_weeks},
        $params->{loc}->{label_2_weeks}, $params->{loc}->{label_1_week},
        $params->{loc}->{label_day}
      )
    {
        my $value = $ranges->{$range} || '';
        $toolbar .= qq{<option name="$range" value="$value">} . $range . '</option>';
    }
    $toolbar .= q{
        </select>
    };

    # start of day
    my $day_start = $params->{day_start} || '';
    $toolbar .= qq{
        <select id="day_start" name="day_start" onchange="reloadCalendar()" value="$day_start">
    };
    for my $hour ( 0 .. 24 ) {
        my $selected = '';
        $selected = 'selected="selected"' if $hour eq $day_start;
        $toolbar .= qq{<option value="$hour">} . sprintf( "%02d:00", $hour ) . '</option>';
    }
    $toolbar .= q{
        </select>
    };

    #filter
    my $filter = $params->{filter} || '';
    $toolbar .= qq{
        <select id="filter" name="filter" onchange="reloadCalendar()">
    };

    for my $filter (
        'no markup', 'conflicts', 'rerun', 'archived',
        'playout',   'published', 'live',  'disable_event_sync',
        'draft'
      )
    {
        my $key = $filter;
        $key =~ s/ /_/g;

        $toolbar .=
          qq{<option value="$filter">} . $params->{loc}->{ 'label_' . $key } . '</option>';
    }

    $toolbar .= q{
        </select>
    };

    #search
    $toolbar .= qq{
        <form class="search">
            <input type="hidden" name="project_id" value="$params->{project_id}">
            <input type="hidden" name="studio_id" value="$params->{studio_id}">
            <input type="hidden" name="date"      value="$params->{date}">
            <input type="hidden" name="list"      value="1">
            <input class="search" name="search" value="$params->{search}" placeholder="}
      . $params->{loc}->{button_search} . qq{">
            <button type="submit" name="action" value="search">}
      . $params->{loc}->{button_search} . qq{</button>
        </form>
    };

    #
    $toolbar .= qq{
        <button id="editSeries">} . $params->{loc}->{button_edit_series} . qq{</button>
    } if $params->{list} == 1;

    $toolbar .= qq{
        </div>
    };

    print $toolbar;
}

sub getTime {
    my $time = shift;
    if ( $time =~ /^(\d\d)\:(\d\d)/ ) {
        return ( $1, $2 );
    }
    return ( -1, -1 );
}

sub getCalendar {
    my $config   = shift;
    my $params   = shift;
    my $language = shift;

    my $from_date = getFromDate( $config, $params );
    my $till_date = getTillDate( $config, $params );
    my $range = $params->{range};

    my $previous = '';
    my $next     = '';
    if ( $range eq 'month' ) {
        $previous =
          time::get_datetime( $from_date, $config->{date}->{time_zone} )->subtract( months => 1 )
          ->set_day(1)->date();
        $next = time::get_datetime( $from_date, $config->{date}->{time_zone} )->add( months => 1 )
          ->set_day(1)->date();
    } else {
        $previous = time::get_datetime( $from_date, $config->{date}->{time_zone} )
          ->subtract( days => $range )->date();
        $next =
          time::get_datetime( $from_date, $config->{date}->{time_zone} )->add( days => $range )
          ->date();
    }
    my ( $year, $month, $day ) = split( /\-/, $from_date );
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
    my $config = shift;
    my $params = shift;

    if ( $params->{from_date} ne '' ) {
        return $params->{from_date};
    }
    my $date = $params->{date};
    if ( $date eq '' ) {
        $date = DateTime->now( time_zone => $config->{date}->{time_zone} )->date();
    }

    if ( $params->{range} eq '28' ) {

        #get start of 4 week period
        $date = time::get_datetime( $date, $config->{date}->{time_zone} )->truncate( to => 'week' )
          ->ymd();
    }
    if ( $params->{range} eq 'month' ) {

        #get first day of month
        return time::get_datetime( $date, $config->{date}->{time_zone} )->set_day(1)->date();
    }

    #get date
    return time::get_datetime( $date, $config->{date}->{time_zone} )->date();
}

sub getTillDate {
    my $config = shift;
    my $params = shift;
    if ( $params->{till_date} ne '' ) {
        return $params->{till_date};
    }
    my $date = $params->{date} || '';
    if ( $date eq '' ) {
        $date = DateTime->now( time_zone => $config->{date}->{time_zone} )->date();
    }
    if ( $params->{range} eq '28' ) {
        $date = time::get_datetime( $date, $config->{date}->{time_zone} )->truncate( to => 'week' )
          ->ymd();
    }
    if ( $params->{range} eq 'month' ) {

        #get last day of month
        return time::get_datetime( $date, $config->{date}->{time_zone} )->set_day(1)
          ->add( months => 1 )->subtract( days => 1 )->date();
    }

    #add range to date
    return time::get_datetime( $date, $config->{date}->{time_zone} )
      ->add( days => $params->{range} )->date();
}

sub getSeriesEvents {
    my $config  = shift;
    my $request = shift;
    my $options = shift;
    my $params  = shift;

    #get events by series id
    my $series_id = $request->{params}->{checked}->{series_id};
    if ( defined $series_id ) {
        my $events = series::get_events( $request->{config}, $options );
        return $events;
    }

    #get events (directly from database to get the ones, not assigned, yet)
    delete $options->{studio_id};
    delete $options->{project_id};
    $options->{recordings} = 1;

    my $request2 = {
        params => {
            checked => events::check_params( $config, $options )
        },
        config      => $request->{config},
        permissions => $request->{permissions}
    };
    $request2->{params}->{checked}->{published} = 'all';
    $request2->{params}->{checked}->{draft} = '1' if $params->{list} == 1;

    my $events = events::get( $config, $request2 );

    series::add_series_ids_to_events( $request->{config}, $events );

    my $studios = studios::get(
        $request->{config},
        {
            project_id => $options->{project_id}
        }
    );
    my $studio_id_by_location = {};
    for my $studio (@$studios) {
        $studio_id_by_location->{ $studio->{location} } = $studio->{id};
    }

    for my $event (@$events) {
        $event->{project_id} = $options->{project_id} unless defined $event->{project_id};
        $event->{studio_id} = $studio_id_by_location->{ $event->{location} }
          unless defined $event->{studio_id};
    }

    return $events;
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked  = {};
    my $template = '';
    $checked->{template} = template::check( $config, $params->{template}, 'series' );

    #numeric values
    $checked->{part}     = 0;
    $checked->{list}     = 0;
    $checked->{open_end} = 1;
    entry::set_numbers( $checked, $params, [
        'id',      'project_id', 'studio_id', 'default_studio_id',
        'user_id', 'series_id',  'event_id',  'part',
        'list',    'day_start',  'open_end'
      ]);

    $checked->{day_start} = $config->{date}->{day_starting_hour}
      unless defined $checked->{day_start};
    $checked->{day_start} %= 24;

    if ( defined $checked->{studio_id} ) {

        # a studio is selected, use the studio from parameter
        $checked->{default_studio_id} = $checked->{studio_id};
    } elsif ( ( defined $params->{studio_id} ) && ( $params->{studio_id} eq '-1' ) ) {

        # all studios selected, use -1
        $checked->{studio_id} = -1;
    } else {

        # no studio given, use default studio
        $checked->{studio_id} = $checked->{default_studio_id};
    }

    for my $param ('expires') {
        $checked->{$param} = time::check_datetime( $params->{$param} );
    }

    #scalars
    $checked->{search} = '';
    $checked->{filter} = '';

    for my $param ( 'date', 'from_date', 'till_date' ) {
        $checked->{$param} = time::check_date( $params->{$param} );
    }

    entry::set_strings( $checked, $params, [
        'search', 'filter', 'range',
        'series_name', 'title',    'excerpt', 'content',
        'program',     'category', 'image',   'user_content'
      ]);

    $checked->{action} = entry::element_of( $params->{action}, 
        [ 'add_user', 'remove_user', 'delete', 'save', 'details', 'show', 'edit_event', 'save_event' ]
    );

    return $checked;
}

