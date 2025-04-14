#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use utf8;

use JSON();
use Data::Dumper;
use URI::Escape();
use DateTime();
use Try::Tiny qw(try catch);
use Exception::Class qw(
    ActionError AppError AssignError AuthError ConfigError DatabaseError
    DateTimeError  DbError EventError EventExistError ExistError InsertError
    InvalidIdError LocalizationError  LoginError ParamError PermissionError
    ProjectError SeriesError SessionError StudioError  TimeCalcError UacError
    UpdateError UserError
);

use utf8();
use params();
use config();
use log();
use entry();
use template();
use calendar();
use calendar_table();
use auth();
use uac();
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
use user_day_start();

binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #add "all" studio to select box
    unshift @{ $user_presets->{studios} },
        {
        id   => -1,
        name => '-all-'
        };

    # select studios, TODO: do in JS
    if ($params->{studio_id} eq '-1') {
        for my $studio (@{ $user_presets->{studios} }) {
            delete $studio->{selected};
            $studio->{selected} = 1 if $params->{studio_id} eq $studio->{id};
        }
    }

    my $p = $request->{params}->{checked};
    $config->{access}->{write} = 0;
    AppError->throw(error => "Please select a project") unless defined $p->{project_id};

    project::check($config, { project_id => $p->{project_id} }) if $p->{project_id} ne '-1';
    AppError->throw(error => "Please select a studio") unless defined $p->{studio_id};
    studios::check($config, {studio_id => $p->{studio_id}}) if $p->{studio_id} ne '-1';

    my $start_of_day = $params->{day_start};
    my $end_of_day   = $start_of_day;
    $end_of_day += 24 if ($end_of_day <= $start_of_day);
    our $hour_height = 60;
    our $yzoom       = 1.5;

    return showCalendar(
        $config, $request,
        {
            hour_height  => $hour_height,
            yzoom        => $yzoom,
            start_of_day => $start_of_day,
            end_of_day   => $end_of_day,
        }
    );
};

sub showCalendar {
    my $config      = shift;
    my $request     = shift;
    my $cal_options = shift;

    my $hour_height  = $cal_options->{hour_height};
    my $yzoom        = $cal_options->{yzoom};
    my $start_of_day = $cal_options->{start_of_day};
    my $end_of_day   = $cal_options->{end_of_day};

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions} || {};
    PermissionError->throw(error=>'Missing permission to read_series') unless $permissions->{read_series} == 1;

    #get range from user settings
    my $user_settings =
        user_settings::get($config, { user => $params->{presets}->{user} });
    $params->{range} = $user_settings->{range} unless defined $params->{range};
    $params->{range} = 28                      unless defined $params->{range};

    $params->{loc} =
        localization::get($config,
        { user => $params->{presets}->{user}, file => 'all,calendar.po' });
    my $language = $user_settings->{language} || 'en';
    $params->{language} = $language;

    my $calendar = calendar_table::getCalendar($config, $params, $language);
    my $options  = {};
    my $events   = [];

    #set date range
    my $from = $calendar->{from_date};
    my $till = $calendar->{till_date};

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #build event filter
    $options = {
        project_id => $project_id,
        template   => 'html',
        limit      => 600,
        from_date          => $from,
        till_date          => $till,
        date_range_include => 1,
        archive            => 'all',
    };

    # set options depending on switches
    if ($params->{studio_id} ne '-1') {
        $options->{studio_id} = $studio_id;
        my $location = $params->{presets}->{studio}->{location};
        $options->{location} = $location if $location =~ /\S/;
    }

    if ($params->{project_id} ne '-1') {
        $options->{project_id} = $project_id;
        my $project = $params->{presets}->{project}->{name};
        $options->{project} = $project if $project =~ /\S/;
    }

    if (defined $params->{series_id}) {
        $options->{series_id} = $params->{series_id};
        delete $options->{from_date};
        delete $options->{till_date};
        delete $options->{date_range_include};
    }

    if ($params->{search} =~ /\S/) {
        if ($params->{list} == 1) {
            $options->{search} = $params->{search};
            delete $options->{from_date};
            delete $options->{till_date};
            delete $options->{date_range_include};
        }
    }
    $options->{from_time} = '00:00' if defined $options->{from_date};

    $options->{draft} = 0 unless $params->{list} == 1;

    #get events sorted by date
    $events = calendar_table::getSeriesEvents($config, $request, $options, $params);
    unless ($params->{list} == 1) {
        for my $event (@$events) {
            $event->{origStart}   = $event->{start};
            $event->{origContent} = $event->{origContent};
        }
        $events = calendar_table::break_dates($events, $start_of_day);
    }

    # recalc after break (for list only?)
    for my $event (@$events) {
        delete $event->{day};
        delete $event->{start_date};
        delete $event->{end_date};
        $event = events::calc_dates($config, $event);
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

    if (defined $params->{series_id}) {
        $options->{series_id} = $params->{series_id};
        delete $options->{from};
        delete $options->{till};
        delete $options->{date_range_include};
    }

    if ($params->{search} =~ /\S/) {
        $options->{search} = $params->{search};
        if ($params->{list} == 1) {
            delete $options->{from};
            delete $options->{till};
            delete $options->{date_range_include};
        }
    }

    #get all series dates
    my $series_dates = series_dates::get_series($config, $options);
    my $id           = 0;
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
    unless ($params->{list} == 1) {
        $series_dates = calendar_table::break_dates($series_dates, $start_of_day);
    }

    #merge series and events
    for my $date (@$series_dates) {
        $date = events::calc_dates($config, $date);
        push @$events, $date;
    }

    #get timeslot_dates
    my $studio_dates = studio_timeslot_dates::get($config, $options);

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
    unless ($params->{list} == 1) {
        $studio_dates = calendar_table::break_dates($studio_dates, $start_of_day);
    }

    for my $date (@$studio_dates) {
        $date = events::calc_dates($config, $date);
        push @$events, $date;
    }

    #get work_dates
    my $work_dates = work_dates::get($config, $options);
    for my $date (@$work_dates) {
        $date->{work}      = 1;
        $date->{series_id} = -1;
        $date->{event_id}  = -1;
        $date->{origStart} = $date->{start};
        delete $date->{day};
        delete $date->{start_date};
        delete $date->{end_date};
    }
    unless ($params->{list} == 1) {
        $work_dates = calendar_table::break_dates($work_dates, $start_of_day);
    }

    for my $date (@$work_dates) {
        $date = events::calc_dates($config, $date);
        push @$events, $date;
    }

    #get playout
    delete $options->{exclude};
    my $playout_dates = playout::get_scheduled($config, $options);
    $id = 0;
    for my $date (@$playout_dates) {
        my $format = undef;
        if (defined $date->{'format'}) {
            $format =
                  ($date->{'format'}         || '') . " "
                . ($date->{'format_version'} || '') . " "
                . ($date->{'format_profile'} || '');
            $format =~ s/MPEG Audio Version 1 Layer 3/MP3/g;
            $format .= ' ' . ($date->{'format_settings'} || '')
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
            sprintf("duration: %.1g h", $date->{duration} / 3600) . "<br>",
            sprintf("%d s",             $date->{duration})
        ) if defined $date->{duration};
        $date->{title} .=
            audio::formatLoudness($date->{rms_left}, 'L: ') . ', '
            if defined $date->{rms_left};
        $date->{title} .=
            audio::formatLoudness($date->{rms_right}, 'R: ') . '<br>'
            if defined $date->{rms_right};
        $date->{title} .= audio::formatBitrate($date->{bitrate})
            if defined $date->{bitrate};
        $date->{title} .=
            ' ' . audio::formatBitrateMode($date->{bitrate_mode}) . '<br>'
            if defined $date->{bitrate_mode};
        $date->{title} .=
            '<b>replay gain</b> '
            . sprintf("%.1f", $date->{replay_gain}) . '<br>'
            if defined $date->{replay_gain};
        $date->{title} .= audio::formatSamplingRate($date->{sampling_rate})
            if defined $date->{sampling_rate};
        $date->{title} .= audio::formatChannels($date->{channels}) . '<br>'
            if defined $date->{channels};
        $date->{title} .=
            int(($date->{'stream_size'} || '0') / (1024 * 1024)) . 'MB<br>'
            if defined $date->{'stream_size'};
        $date->{title} .= $format if defined $format;
        $date->{title} .=
            '<b>library</b>: ' . ($date->{writing_library} || '') . '<br>'
            if defined $date->{'writing_library'};
        $date->{title} .= '<b>path</b>: ' . ($date->{file} || '') . '<br>'
            if defined $date->{file};
        $date->{title} .=
            '<b>updated_at</b>: ' . ($date->{updated_at} || '') . '<br>'
            if defined $date->{updated_at};
        $date->{title} .=
            '<b>modified_at</b>: ' . ($date->{modified_at} || '') . '<br>'
            if defined $date->{modified_at};

        $date->{rms_image} = URI::Escape::uri_unescape($date->{rms_image})
            if defined $date->{rms_image};

        $date->{origStart} = $date->{start};

      # set end date seconds to 00 to handle error at break_dates/join_dates
        $date->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1\:00/;
        delete $date->{day};
        delete $date->{start_date};
        delete $date->{end_date};
        $id++;
    }

    unless ($params->{list} == 1) {
        $playout_dates = calendar_table::break_dates($playout_dates, $start_of_day);
    }

    for my $date (@$playout_dates) {
        $date = events::calc_dates($config, $date);
        if (defined $events_by_start->{ $date->{start} }) {
            $events_by_start->{ $date->{start} }->{duration} =
                $date->{duration} || 0;
            $events_by_start->{ $date->{start} }->{event_duration} =
                $date->{event_duration} || 0;
            $events_by_start->{ $date->{start} }->{rms_left} =
                $date->{rms_left} || 0;
            $events_by_start->{ $date->{start} }->{rms_right} =
                $date->{rms_right} || 0;
            $events_by_start->{ $date->{start} }->{playout_modified_at} =
                $date->{modified_at};
            $events_by_start->{ $date->{start} }->{playout_updated_at} =
                $date->{updated_at};
            $events_by_start->{ $date->{start} }->{file} = $date->{file};
        }
        push @$events, $date;
    }

    # series dates
    if ($params->{list} == 1 and defined $options->{series_id}) {
        my $series = series::get(
            $config,
            {
                #project_id => $project_id,
                #studio_id  => $studio_id,
                series_id => $options->{series_id}
            }
        );
        if (    defined $series->[0]
            and $series->[0]->{predecessor_id}
            and $series->[0]->{predecessor_id} ne $series->[0]->{id})
        {
            my $events2 = getSeriesEvents(
                $config, $request,
                {
                    series_id => $series->[0]->{predecessor_id}
                },
                $params
            );

            for my $event (@$events2) {
                delete $event->{day};
                delete $event->{start_date};
                delete $event->{end_date};
                push @$events, events::calc_dates($config, $event);
            }
        }
    }

    my $out = "Content-type:text/html; charset=utf-8;\n\n";
    $out .= qq{
        <script>
            var current_date="$calendar->{month} $calendar->{year}";
            var previous_date="$calendar->{previous_date}";
            var next_date="$calendar->{next_date}";
        </script>
        };

    #filter events by time
    unless ($params->{list} == 1) {
        $events = calendar_table::filterEvents($events, $options, $start_of_day);
    }

    #sort events by start
    @$events = sort {$a->{start} cmp $b->{start}} @$events;

    #separate by day (e.g. to 6 pm)
    my $events_by_day = {};
    for my $event (@$events) {
        my $day =
            time::datetime_to_date(
            time::add_hours_to_datetime($event->{start}, -$start_of_day));
        push @{ $events_by_day->{$day} }, $event;
    }

    #get min and max hour from all events
    unless ($params->{list} == 1) {
        my $min_hour = 48;
        my $max_hour = 0;

        for my $event (@$events) {
            if ($event->{start} =~ /(\d\d)\:\d\d\:\d\d$/) {
                my $hour = $1;
                $hour += 24 if $hour < $start_of_day;
                $min_hour = $hour
                    if ($hour < $min_hour) && ($hour >= $start_of_day);
            }
            if ($event->{end} =~ /(\d\d)\:\d\d\:\d\d$/) {
                my $hour = $1;
                $hour += 24 if $hour <= $start_of_day;
                $max_hour = $hour
                    if ($hour > $max_hour) && ($hour <= $end_of_day);
            }
        }
        $cal_options->{min_hour} = $min_hour;
        $cal_options->{max_hour} = $max_hour;
    }

    # calculate positions and find schedule errors (depending on position)
    for my $date (sort (keys %$events_by_day)) {
        my $events = $events_by_day->{$date};
        calendar_table::calc_positions($events, $cal_options);
        calendar_table::find_errors($events);
    }

    for my $event (@$events) {
        next unless defined $event->{uploaded_at};
        next
            if (defined $event->{playout_updated_at})
            && ($event->{uploaded_at} lt $event->{playout_updated_at});

    }

    if ($params->{list} == 1) {
        return $out . calendar_table::showEventList($config, $permissions, $params, $events_by_day);
    } else {
        calendar_table::calcCalendarTable($config, $permissions, $params, $calendar,
            $events_by_day, $cal_options);
        $out .= calendar_table::getTableHeader($config, $permissions, $params, $cal_options);
        $out .= calendar_table::getTableBody($config, $permissions, $params, $cal_options);
        if ($params->{part} == 0) {
            #TODO: load dynamically
            $out .= calendar_table::getSeries($config, $permissions, $params, $cal_options);
            $out.= qq{
                    </main>
            };
        }

        # time has to be set when events come in
        $out .= calendar_table::getJavascript($config, $permissions, $params, $cal_options);
        return $out;
    }
}


sub check_params {
    my ($config, $params) = @_;

    my $checked  = { user => $config->{user} };
    my $template = '';
    $checked->{template} =
        template::check($config, $params->{template}, 'calendar');

    #numeric values
    $checked->{part}     = 0;
    $checked->{list}     = 0;
    $checked->{open_end} = 1;
    entry::set_numbers(
        $checked, $params,
        [
            'id',        'project_id',
            'studio_id', 'default_studio_id',
            'user_id',   'series_id',
            'event_id',  'part',
            'list',      'day_start',
            'open_end'
        ]
    );

    if ($checked->{user} and $checked->{project_id} and $checked->{studio_id}) {
        my $start = user_day_start::get(
            $config,
            {
                user       => $checked->{user},
                project_id => $checked->{project_id},
                studio_id  => $checked->{studio_id}
            }
        );
        $checked->{day_start} = $start->{day_start} if $start;
    }
    $checked->{day_start} = $config->{date}->{day_starting_hour}
        unless defined $checked->{day_start};
    $checked->{day_start} %= 24;

    if (defined $checked->{studio_id}) {

        # a studio is selected, use the studio from parameter
        $checked->{default_studio_id} = $checked->{studio_id};
    } elsif ((defined $params->{studio_id}) && ($params->{studio_id} eq '-1')) {

        # all studios selected, use -1
        $checked->{studio_id} = -1;
    } else {

        # no studio given, use default studio
        $checked->{studio_id} = $checked->{default_studio_id};
    }

    for my $param ('expires') {
        $checked->{$param} = time::check_datetime($params->{$param});
    }

    #scalars
    $checked->{search} = '';
    $checked->{filter} = '';

    for my $param ('date', 'from_date', 'till_date') {
        $checked->{$param} = time::check_date($params->{$param});
    }

    entry::set_strings(
        $checked, $params,
        [
            'search', 'filter',  'range',   'series_name',
            'title',  'excerpt', 'content', 'program',
            'image',  'user_content'
        ]
    );

    $checked->{action} = entry::element_of(
        $params->{action},
        [
            'add_user', 'remove_user', 'delete',     'save',
            'details',  'show',        'edit_event', 'save_event'
        ]
    );

    return $checked;
}
