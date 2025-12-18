#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use utf8;

use JSON;
use Data::Dumper;
use URI::Escape();
use DateTime();
use Scalar::Util qw(blessed);
use Try::Tiny;
use Exception::Class qw(
  ActionError AppError AssignError AuthError ConfigError DatabaseError
  DateTimeError  DbError EventError EventExistError ExistError InsertError
  InvalidIdError LocalizationError  LoginError ParamError PermissionError
  ProjectError SeriesError SessionError StudioError  TimeCalcError UacError
  UpdateError UserError
);

use params();
use config();
use entry();
use template();
use auth();
use uac();
use calendar_table();
use localization();
use user_settings();
use user_day_start();

binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    $params->{expires} = $session->{expires};

    #add "all" studio to select box
    unshift @{$user_presets->{studios}},
      {
        id   => -1,
        name => '-all-'
      };

    # select studios, TODO: do in JS
    if ($params->{studio_id} eq '-1') {
        for my $studio (@{$user_presets->{studios}}) {
            delete $studio->{selected};
            $studio->{selected} = 1 if $params->{studio_id} eq $studio->{id};
        }
    }
    $params = $request->{params}->{checked};
    my $headerParams =
      uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} =
      localization::get($config, {user => $session->{user}, file => 'menu.po'});

    my $start_of_day = $params->{day_start};
    my $end_of_day   = $start_of_day;
    $end_of_day += 24 if ($end_of_day <= $start_of_day);
    our $hour_height = 60;
    our $yzoom       = 1.5;

    my $out = $session->{header} if $session->{header};
    $out .=
      template::process($config,
        template::check($config, 'calendar-header.html'),
        $headerParams);
    return $out
      . showCalendar(
        $config, $request,
        {
            hour_height  => $hour_height,
            yzoom        => $yzoom,
            start_of_day => $start_of_day,
            end_of_day   => $end_of_day,
        }
      );
}

sub showCalendar {
    my ($config, $request, $cal_options) = @_;

    my $hour_height  = $cal_options->{hour_height};
    my $yzoom        = $cal_options->{yzoom};
    my $start_of_day = $cal_options->{start_of_day};
    my $end_of_day   = $cal_options->{end_of_day};

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions} || {};
    PermissionError->throw(error => 'Missing permission to read_series')
        unless $permissions->{read_series};

    #get range from user settings
    my $user_settings =
      user_settings::get($config, {user => $params->{presets}->{user}});
    $params->{range} = $user_settings->{range} unless defined $params->{range};
    $params->{range} = 28                      unless defined $params->{range};

    my $out = '';
    #get colors from user settings
    $out .=
      user_settings::getColorCss($config, {user => $params->{presets}->{user}});

    $params->{loc} =
      localization::get($config,
        {user => $params->{presets}->{user}, file => 'all,calendar.po'});
    my $language = $user_settings->{language} || 'en';
    $params->{language} = $language;
    $out .= localization::getJavascript($params->{loc});

    my $calendar = calendar_table::getCalendar($config, $params, $language);
    my $options  = {};
    my $events   = [];

    $out .= getToolbar($config, $params, $calendar);
    $out .= qq{<div id="calendarTable"> </div>};
    $out .= qq{
            </main>
    };
    # time has to be set when events come in
    $out .= calendar_table::getJavascript($config, $permissions, $params,
        $cal_options);
    $out .= qq{</body></html>};
    return $out;
}

sub getToolbar {
    my ($config, $params, $calendar) = @_;
    my $today   = time::time_to_date();
    my $class   = $params->{list} ? 'toolbar' : 'toolbar';
    my $toolbar = qq{<div id="$class">};

    $toolbar .= qq!
        <div class="row">
            <div id="previous_month"><button id="previous">&laquo;</button></div>
            <div id="selectDate" data-toggle>
                <input id="start_date" data-input/>
                <div id="current_date">$calendar->{month} $calendar->{year}</div>
            </div>
            <div id="next_month"><button id="next">&raquo;</button></div>
            <button id="setToday">!
      . $params->{loc}->{button_today}
      . q!</button>
        </div>
    !;

    unless ($params->{list}) {
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
            $toolbar .=
              qq{<option name="$range" value="$value">} . $range . '</option>';
        }
        $toolbar .= q{
            </select>
        };

        # start of day
        my $day_start = $params->{day_start} || '';
        $toolbar .= qq{
            <select id="day_start" name="day_start" onchange="updateDayStart();reloadCalendar()" value="$day_start">
        };
        for my $hour (0 .. 24) {
            my $selected = '';
            $selected = 'selected="selected"' if $hour eq $day_start;
            $toolbar .=
                qq{<option value="$hour">}
              . sprintf("%02d:00", $hour)
              . '</option>';
        }
        $toolbar .= q{
            </select>
        };
    }

    #search
    $toolbar .= qq{
        <form class="search">
            <input type="hidden" name="project_id" value="$params->{project_id}">
            <input type="hidden" name="studio_id" value="$params->{studio_id}">
            <input type="hidden" name="date"      value="$params->{date}">
            <input type="hidden" name="list"      value="1">
            <input class="search" name="search" value="$params->{search}" placeholder="}
      .$params->{loc}->{button_search} . qq{">
            <button type="submit" name="action" value="search">
                <sprite-icon name="search"></sprite-icon>
                $params->{loc}->{button_search} 
              </button>
        </form>
    };

    #
    $toolbar .= qq{<button id="editSeries">}
      . '<sprite-icon name="edit"></sprite-icon>'
      . $params->{loc}->{button_edit_series}
      . qq{</button>
    } if $params->{list} == 1;

    $toolbar .= qq{
        </div>
    };

    return $toolbar;
}

sub check_params {
    my ($config, $params) = @_;

    my $checked  = {user => $config->{user}};
    my $template = '';
    $checked->{template} =
      template::check($config, $params->{template}, 'calendar');

    #numeric values
    $checked->{list}     = 0;
    $checked->{open_end} = 1;
    entry::set_numbers(
        $checked, $params,
        [
            'id',        'project_id',
            'studio_id', 'default_studio_id',
            'user_id',   'series_id',
            'event_id',  'list',
            'day_start', 'open_end'
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
