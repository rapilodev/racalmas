#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Scalar::Util qw( blessed );
use Try::Tiny;

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use project();
use studios();
use studio_timeslot_schedule();
use studio_timeslot_dates();
use markup();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'all,menu' } );

    my $out;
    my $action = $params->{action} || '';
    if ( $action eq 'show_dates' ) {
        #print "Content-type:text/html\n\n";
    } else {
        $out .= template::process( $config, template::check( $config, 'default.html' ), $headerParams );
    }
    uac::check($config, $params, $user_presets);

    if ( $action eq 'show_dates' ) {
        print "Content-Type:text/html\n\n";
    } else {
        $out .=  template::process( $config, template::check( $config, 'studio-timeslots-header.html' ), $headerParams );
    }

    if ( defined $params->{action} ) {
        return $out . save_schedule( $config, $request ) if ( $params->{action} eq 'save_schedule' );
        return $out . delete_schedule( $config, $request ) if ( $params->{action} eq 'delete_schedule' );
        if ( $params->{action} eq 'show_dates' ) {
            return $out . showDates( $config, $request );
        }
    }

    $config->{access}->{write} = 0;
    return $out . showTimeslotSchedule( $config, $request );
}

#insert or update a schedule and update all schedule dates
sub save_schedule {
    my ($config, $request) = @_;

    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to update_studio_timeslot_schedule')
        unless $permissions->{update_studio_timeslot_schedule} == 1;

    my $params = $request->{params}->{checked};

    for my $attr ( 'project_id', 'studio_id', 'start', 'end', 'end_date', 'schedule_studio_id' ) {
        ParamError->throw(error=> "missing $attr" ) unless defined $params->{$attr};
    }

    my $entry = {map {$_ => $params->{$_}} ('project_id', 'start', 'end', 'end_date')};
    if ($params->{period_type} eq 'days') {
        entry::set_numbers($entry, $params, ['frequency']);
        $entry->{period_type} = $params->{period_type};
    } elsif($params->{period_type} eq 'week_of_month') {
        entry::set_numbers($entry, $params, ['weekday', 'week_of_month', 'month']);
        $entry->{period_type} = $params->{period_type};
    }

    #set schedule's studio to value from schedule_studio_id
    $entry->{studio_id} = $params->{schedule_studio_id} if defined $params->{schedule_studio_id};

    return uac::print_error('start date should be before end date!')
        if $entry->{end} ne '' && $entry->{end} le $entry->{start};

    $config->{access}->{write} = 1;
    if (defined $params->{schedule_id}) {
        $entry->{schedule_id} = $params->{schedule_id};
        studio_timeslot_schedule::update( $config, $entry );

        my $updates = studio_timeslot_dates::update( $config, $entry );
        return uac::print_info("timeslot schedule saved. $updates dates scheduled");
    } else {
        $entry->{schedule_id} = studio_timeslot_schedule::insert( $config, $entry );

        my $updates = studio_timeslot_dates::update( $config, $entry );
        return uac::print_info("timeslot schedule added. $updates dates added");
    }
}

sub delete_schedule {
    my ($config, $request) = @_;

    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to update_studio_timeslot_schedule') 
        unless $permissions->{update_studio_timeslot_schedule} == 1;

    my $params = $request->{params}->{checked};

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'schedule_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            ParamError->throw(error=> "missing $attr" );
        }
    }

    $config->{access}->{write} = 1;
    $entry->{schedule_id} = $params->{schedule_id};
    studio_timeslot_schedule::delete( $config, $entry );
    studio_timeslot_dates::update( $config, $entry );
    return uac::print_info("timeslot schedule deleted");
}

sub showTimeslotSchedule {
    my ($config, $request) = @_;

    $config->{access}->{write} = 0;
    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_studio_timeslot_schedule')
        unless $permissions->{read_studio_timeslot_schedule} == 1;

    for my $param ('project_id', 'studio_id') {
        ParamError->throw(error=>"missing $param") unless defined $params->{$param};
    }

    #this will be updated later (especially allow_update_events)
    $params->{'allow'}->{$_} = $request->{permissions}->{$_} for (keys %{$request->{permissions}});

    $params->{loc} =
      localization::get($config, {user => $params->{presets}->{user}, file => 'all,studio-timeslots'});

    my $studio_id  = $params->{studio_id};
    my $project_id = $params->{project_id};

    #get project schedule
    my $schedules = studio_timeslot_schedule::get(
        $config, {project_id => $project_id}
    );

    #list of all studios by id
    my $studios = studios::get($config, {project_id => $project_id});

    #remove seconds from dates
    for my $schedule (@$schedules) {
        $schedule->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $schedule->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $schedule->{period_type_days} = 1        if $schedule->{period_type} eq 'days';
        $schedule->{period_type_week_of_month} = 1 if $schedule->{period_type} eq 'week_of_month';

        #insert assigned studio
        for my $studio (@$studios) {
            my $entry = {
                id   => $studio->{id},
                name => $studio->{name},
            };
            $entry->{selected} = 1 if $studio->{id} eq $schedule->{studio_id};
            push @{$schedule->{studios}}, $entry;
        }
    }

    my $result = {
        project_id => $project_id,
        studio_id  => $studio_id
    };
    $result->{schedule}  = $schedules;
    $result->{studios}   = $studios;
    for my $attr ('start', 'end', 'end_date', 'frequency', 'period_type', 'weekday', 'week_of_month', 'month') {
        $result->{$attr} = $params->{$attr};
    }
    #remove seconds from datetimes
    $result->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/ if defined $result->{start};
    $result->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/   if defined $result->{end};

    #copy entry values to params
    $params->{$_} = $result->{$_} for keys %$result;

    return template::process( $config, $params->{template}, $params );
}

sub showDates {
    my ($config, $request) = @_;

    $config->{access}->{write} = 0;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_studio_timeslot_schedule')
        unless $permissions->{read_studio_timeslot_schedule} == 1;

    for my $param ('project_id', 'studio_id') {
        ParamError->throw(error=>"missing $param") unless defined $params->{$param};
    }

    #this will be updated later (especially allow_update_events)
    $params->{'allow'}->{$_} = $request->{permissions}->{$_}
        for (keys %{$request->{permissions}});

    my $studio_id  = $params->{studio_id};
    my $project_id = $params->{project_id};

    my $fromDate = $params->{show_date} . '-01-01';
    my $tillDate = $params->{show_date} . '-12-31';

    #add timeslot dates
    my $timeslot_dates = studio_timeslot_dates::get(
        $config,
        {
            project_id => $project_id,
            from => $fromDate,
            till => $tillDate
        }
    );

    $params->{loc} =
      localization::get($config, {user => $params->{presets}->{user}, file => 'all,studio-timeslots'});
    my $language = $params->{loc}->{region};

    # translate weekday names to selected language
    my $weekday = {
        'Mo' => $params->{loc}->{weekday_Mo},
        'Tu' => $params->{loc}->{weekday_Tu},
        'We' => $params->{loc}->{weekday_We},
        'Th' => $params->{loc}->{weekday_Th},
        'Fr' => $params->{loc}->{weekday_Fr},
        'Sa' => $params->{loc}->{weekday_Sa},
        'Su' => $params->{loc}->{weekday_Su},
    };

    my $studios = studios::get($config, {project_id => $project_id});
    my $studio_by_id = {map {$_->{id} => $_} @$studios};

    #remove seconds from dates
    for my $date (@$timeslot_dates) {

        #remove seconds from datetimes
        $date->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $date->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/;

        # translate weekday
        if ($language ne 'en') {
            $date->{start_weekday} = $weekday->{$date->{start_weekday}};
            $date->{end_weekday}   = $weekday->{$date->{end_weekday}};
       }
        $date->{studio_name} = $studio_by_id->{$date->{studio_id}}->{name};
    }
    my $result = {
        project_id => $project_id,
        studio_id  => $studio_id,
        dates      => $timeslot_dates
    };

    #copy entry values to params
    $params->{$_} = $result->{$_} for keys %$result;

    my $template = template::check( $config, 'studio-timeslot-dates' );
    return template::process( $config, $template, $params );
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};
    $checked->{template} = template::check($config, $params->{template}, 'studio-timeslots');

    #actions and roles
    $checked->{action} = $params->{action}
        if ($params->{action}//'') =~ /^(show|save_schedule|delete_schedule|show_dates)$/;

    $checked->{exclude} = 0;
    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'default_studio_id', 'schedule_id', 'schedule_studio_id'
    ]);
    $checked->{default_studio_id} = $checked->{studio_id} // -1;

    if (($params->{show_date}//'') =~ /^(\d\d\d\d)/) {
        $checked->{show_date} = $1;
    } else {
        my $date = time::date_to_array(time::time_to_date());
        $checked->{show_date} = $date->[0];
    }

    entry::set_numbers($checked, $params, ['frequency']);
    if ($params->{period_type}eq 'days') {
        $checked->{period_type} = $params->{period_type};
    }elsif($params->{period_type}eq 'week_of_month') {
        entry::set_numbers($checked, $params, ['weekday', 'week_of_month', 'month']);
        $checked->{period_type} = $params->{period_type};
    }

    for my $attr ('start', 'end') {
        if (($params->{$attr}//'') =~ /(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)/) {
            $checked->{$attr} = "$1:00";
        }
    }
    for my $attr ('end_date') {
        if (($params->{$attr}//'') =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
            $checked->{$attr} = $1;
        }
    }

    return $checked;
}
