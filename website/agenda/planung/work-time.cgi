#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use Scalar::Util qw(blessed);

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use project();
use studios();
use work_schedule();
use work_dates();
use localization();
binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get($config, { user => $session->{user}, file => 'menu.po' });
    my $out =  template::process($config, template::check($config, 'default.html'), $headerParams);
    uac::check($config, $params, $user_presets);

    if (defined $params->{action}) {
        return $out . save_schedule($config, $request) if ($params->{action} eq 'save_schedule');
        return $out . delete_schedule($config, $request) if ($params->{action} eq 'delete_schedule');
    }

    $out.= template::process($config, template::check($config, 'worktime-header.html'), $headerParams);
    return $out . show_work_schedule($config, $request);
}

#insert or update a schedule and update all schedule dates
sub save_schedule {
    my ($config, $request) = @_;

    my $params = $request->{params}->{checked};

    my $permissions = $request->{permissions};
    unless ($permissions->{update_schedule} == 1) {
        PermissionError->throw(error=>'Missing permission to update_schedule');
        return;
    }

    for my $attr ('project_id', 'studio_id', 'start') {
        ParamError->throw(error=> "missing $attr") unless defined $params->{$attr};
    }

    my $entry = {};
    for my $attr (
        'project_id', 'studio_id', 'start',   'duration',      'exclude', 'period_type',
        'end',        'frequency', 'weekday', 'week_of_month', 'month',   'title',
        'type'
    ) {
        $entry->{$attr} = $params->{$attr} if defined $params->{$attr};
    }

    my $found = 0;
    for my $type ('single', 'days', 'week_of_month') {
        $found = 1 if ($entry->{period_type} eq $type);
    }
    ParamError->throw(error=> 'no period type selected!' if $found == 0;

    $entry->{exclude} = 0 if ($entry->{exclude} ne '1');

    ParamError->throw(error=> 'start date should be before end date!' if 
        ($entry->{end} ne '') && ($entry->{end} le $entry->{start});

    #TODO: check if schedule is in studio_timeslots

    local $config->{access}->{write} = 1;
    if (defined $params->{schedule_id}) {
        $entry->{schedule_id} = $params->{schedule_id};
        work_schedule::update($config, $entry);

        #timeslots are checked inside
        my $updates = work_dates::update($config, $entry);
        uac::print_info("schedule saved. $updates dates scheduled");
    } else {
        my $schedule_id = work_schedule::insert($config, $entry);
        $entry->{schedule_id} = $schedule_id;

        #timeslots are checked inside
        my $updates = work_dates::update($config, $entry);
        uac::print_info("schedule added. $updates dates added");
    }
}

sub delete_schedule {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{delete_schedule} == 1) {
        PermissionError->throw(error=>'Missing permission to delete_schedule');
        return;
    }

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'schedule_id') {
        if (defined $params->{$attr}) {
            $entry->{$attr} = $params->{$attr};
        } else {
            ParamError->throw(error=> "missing $attr");
        }
    }

    local $config->{access}->{write} = 1;
    $entry->{schedule_id} = $params->{schedule_id};
    work_schedule::delete($config, $entry);
    work_dates::update($config, $entry);
    uac::print_info("schedule deleted");
}

sub show_work_schedule {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_series')
        unless $permissions->{read_series} == 1;

    for my $param ('project_id', 'studio_id') {
        ParamError->throw(error=>"missing $param") unless defined $params->{$param};
    }

    #this will be updated later (especially allow_update_events)
    for my $permission (keys %{ $request->{permissions} }) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #add schedules
    my $schedules = work_schedule::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
        }
    );

    #remove seconds from dates
    for my $schedule (@$schedules) {
        $schedule->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/ if defined $schedule->{start};
        $schedule->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/   if defined $schedule->{end};

        #detect schedule type
        if ($schedule->{period_type} eq '') {
            $schedule->{period_type} = 'week_of_month';
            $schedule->{period_type} = 'days' unless ($schedule->{week_of_month} =~ /\d/);
            $schedule->{period_type} = 'single' unless ($schedule->{end} =~ /\d/);
        }
        $schedule->{ 'period_type_' . $schedule->{period_type} } = 1;
        if ($params->{schedule_id} eq $schedule->{schedule_id}) {
            $schedule->{selected} = 1;
        }
    }
    my $serie = {};
    $serie->{schedule} = $schedules;

    $serie->{start}     = $params->{start};
    $serie->{end}       = $params->{end};
    $serie->{frequency} = $params->{frequency};
    $serie->{duration}  = $serie->{default_duration};
    my $duration = $params->{duration} || '';
    $serie->{duration} = $params->{duration} if $duration ne '';

    $serie->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/ if defined $serie->{start};
    $serie->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/   if defined $serie->{end};

    #add series dates
    my $work_dates = work_dates::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
        }
    );

    #remove seconds from dates
    for my $date (@$work_dates) {
        $date->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $date->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
    }
    $serie->{work_dates} = $work_dates;

    $serie->{show_hint_to_add_schedule} = $params->{show_hint_to_add_schedule};

    #copy series to params
    for my $key (keys %$serie) {
        $params->{$key} = $serie->{$key};
    }

    $params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'work-time.po' });
    return template::process($config, $params->{template}, $params);
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    $checked->{action} = entry::element_of($params->{action},
        ['show', 'save_schedule', 'delete_schedule']
    );

    $checked->{exclude} = 0;
    entry::set_numbers($checked, $params, [
        'project_id', 'studio_id',                 'default_studio_id',     'schedule_id',
        'exclude',    'show_hint_to_add_schedule', 'weekday week_of_month', 'month'
    ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check($config, $params->{template}, 'edit-work-time');

    if ((defined $checked->{action}) && ($checked->{action} eq 'save_schedule')) {

        #set defaults
        $checked->{create_events}  = 0;
        $checked->{publish_events} = 0;
    }
    entry::set_numbers($checked, $params, [ 'frequency', 'duration', 'default_duration' ]);

    entry::set_strings($checked, $params,
        [ 'from', 'till', 'period_type', 'type', 'title' ]
    );

    for my $attr ('start') {
        if ((defined $params->{$attr}) && ($params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)/)) {
            $checked->{$attr} = $1 . ':00';
        }
    }

    for my $attr ('end') {
        if ((defined $params->{$attr}) && ($params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d)/)) {
            $checked->{$attr} = $1;
        }
    }

    return $checked;
}

