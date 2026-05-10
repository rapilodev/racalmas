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
use time();
use log();
use template();
use auth();
use uac();
use calendar_table();
use localization();
use user_settings();
use user_day_start();
use events();
use series_dates();

binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    $params->{expires} = $session->{expires};
    return list_events($config, $request, $session);
}

sub get_series_events {
    my ($config, $request, $params) = @_;
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $options    = {
        project_id => $params->{project_id},
        archive    => 'all',
        series_id => $params->{series_id},
        template => 'no'
    };
    if ($studio_id ne '-1') {
        $options->{studio_id} = $studio_id;
        my $location = $params->{presets}->{studio}->{location};
        $options->{location} = $location if $location =~ /\S/;
    }

    if ($project_id ne '-1') {
        $options->{project_id} = $project_id;
        my $project = $params->{presets}->{project}->{name};
        $options->{project} = $project if $project =~ /\S/;
    }
    my $events = calendar_table::getSeriesEvents($config, $request, $options, $params);
    return $events;
}

sub get_series_dates {
    my ($config, $request, $params) = @_;
    my $options = {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        series_id  => $params->{series_id},
        exclude    => 0
    };
    my $series_dates = series_dates::get_series($config, $options);
    $_->{schedule} = 1 for @$series_dates;
    return $series_dates;
}

sub list_events {
    my ($config, $request, $session) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions} || {};
    PermissionError->throw(error => 'Missing permission to read_series')
      unless $permissions->{read_series};

    my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get($config, { user => $session->{user}, file => 'menu.po,calendar.po' });
    my $out = template::process($config,
        template::check($config, 'event-list.html'),
        $headerParams
    );
    $out .= user_settings::getColorCss($config, {user => $params->{presets}->{user}});
    
    $params->{loc} = localization::get($config,
        {user => $params->{presets}->{user}, file => 'menu.po,all.po,calendar.po'});
    my $user_settings =
      user_settings::get($config, {user => $params->{presets}->{user}});
    my $language = $user_settings->{language} || 'en';
    $params->{language} = $language;
    $out .= localization::getJavascript($params->{loc});
    
    my $events = get_series_events($config, $request, $params);
    my %event_dates = map {$_->{start} => 1 } @$events;
    my @series_dates = 
        grep { !exists $event_dates{$_->{start}} }
        @{get_series_dates($config, $request, $params)}
        ;
    my @events= (@$events, @series_dates);
    events::calc_dates($config, $_) for @events; 
    @events = sort { $a->{start} cmp $b->{start} } @events;
    $out .= calendar_table::showEventList($config, $permissions, $params, \@events);
    $out .= qq{</main></body></html>};
    return $out;
}

sub check_params {
    my ($config, $params) = @_;

    my $checked  = {user => $config->{user}};

    #numeric values
    $checked->{list}     = 0;
    $checked->{open_end} = 1;
    entry::set_numbers($checked, $params,
        ['id', 'project_id', 'studio_id', 'default_studio_id', 'series_id',]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } elsif (($params->{studio_id}//'') eq '-1') {
        $checked->{studio_id} = -1;
    } else {
        $checked->{studio_id} = $checked->{default_studio_id};
    }

    return $checked;
}
