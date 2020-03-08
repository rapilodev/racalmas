#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use params();
use config();
use log();
use template();
use auth();
use uac();
use roles();
use project();
use studios();
use work_schedule();
use work_dates();
use localization();
binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( ( !defined $user ) || ( $user eq '' ) );

#print STDERR $params->{project_id}."\n";
my $user_presets = uac::get_user_presets(
    $config,
    {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        user       => $user
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio( $params, $user_presets );
$params = uac::setDefaultProject( $params, $user_presets );

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    },
};
$request = uac::prepare_request( $request, $user_presets );
$params = $request->{params}->{checked};

#process header
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

if ( defined $params->{action} ) {
    save_schedule( $config, $request ) if ( $params->{action} eq 'save_schedule' );
    delete_schedule( $config, $request ) if ( $params->{action} eq 'delete_schedule' );
}

$config->{access}->{write} = 0;
print q{<script src="js/edit_work_time.js" type="text/javascript"></script>};
show_work_schedule( $config, $request );
return;

#insert or update a schedule and update all schedule dates
sub save_schedule {
    my $config  = shift;
    my $request = shift;

    my $params = $request->{params}->{checked};

    my $permissions = $request->{permissions};
    unless ( $permissions->{update_schedule} == 1 ) {
        uac::permissions_denied('update_schedule');
        return;
    }

    for my $attr ( 'project_id', 'studio_id', 'start' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    my $entry = {};
    for my $attr (
        'project_id', 'studio_id', 'start',   'duration',      'exclude', 'period_type',
        'end',        'frequency', 'weekday', 'week_of_month', 'month',   'title',
        'type'
      )
    {
        $entry->{$attr} = $params->{$attr} if defined $params->{$attr};
    }

    my $found = 0;
    for my $type ( 'single', 'days', 'week_of_month' ) {
        $found = 1 if ( $entry->{period_type} eq $type );
    }
    if ( $found == 0 ) {
        uac::print_error('no period type selected!');
        return;
    }

    $entry->{exclude} = 0 if ( $entry->{exclude} ne '1' );

    if ( ( $entry->{end} ne '' ) && ( $entry->{end} le $entry->{start} ) ) {
        uac::print_error('start date should be before end date!');
        return;
    }

    #TODO: check if schedule is in studio_timeslots

    $config->{access}->{write} = 1;
    if ( defined $params->{schedule_id} ) {
        $entry->{schedule_id} = $params->{schedule_id};
        work_schedule::update( $config, $entry );

        #timeslots are checked inside
        my $updates = work_dates::update( $config, $entry );
        uac::print_info("schedule saved. $updates dates scheduled");
    } else {
        my $schedule_id = work_schedule::insert( $config, $entry );
        $entry->{schedule_id} = $schedule_id;

        #timeslots are checked inside
        my $updates = work_dates::update( $config, $entry );
        uac::print_info("schedule added. $updates dates added");
    }
    $config->{access}->{write} = 0;
}

sub delete_schedule {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{delete_schedule} == 1 ) {
        uac::permissions_denied('delete_schedule');
        return;
    }

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'schedule_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    $config->{access}->{write} = 1;
    $entry->{schedule_id} = $params->{schedule_id};
    work_schedule::delete( $config, $entry );
    work_dates::update( $config, $entry );
    uac::print_info("schedule deleted");
}

sub show_work_schedule {
    my $config  = shift;
    my $request = shift;

    $config->{access}->{write} = 0;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_series} == 1 ) {
        uac::permissions_denied('read_series');
        return;
    }

    for my $param ( 'project_id', 'studio_id' ) {
        unless ( defined $params->{$param} ) {
            uac::print_error("missing $param");
            return;
        }
    }

    #this will be updated later (especially allow_update_events)
    for my $permission ( keys %{ $request->{permissions} } ) {
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
        if ( $schedule->{period_type} eq '' ) {
            $schedule->{period_type} = 'week_of_month';
            $schedule->{period_type} = 'days' unless ( $schedule->{week_of_month} =~ /\d/ );
            $schedule->{period_type} = 'single' unless ( $schedule->{end} =~ /\d/ );
        }
        $schedule->{ 'period_type_' . $schedule->{period_type} } = 1;
        if ( $params->{schedule_id} eq $schedule->{schedule_id} ) {
            $schedule->{selected} = 1;
        }

        #print STDERR $schedule->{period_type}."\n";
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
    #$params->{series}=[$serie];
    for my $key ( keys %$serie ) {
        $params->{$key} = $serie->{$key};
    }

    $params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'work-time' } );
    template::process( $config, 'print', $params->{template}, $params );
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    my $debug = $params->{debug} || '';
    if ( $debug =~ /([a-z\_\,]+)/ ) {
        $debug = $1;
    }
    $checked->{debug} = $debug;

    #actions and roles
    $checked->{action} = '';
    if ( defined $params->{action} ) {
        if ( $params->{action} =~ /^(show|save_schedule|delete_schedule)$/ ) {
            $checked->{action} = $params->{action};
        }
    }

    #numeric values
    $checked->{exclude} = 0;
    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id',                 'default_studio_id',     'schedule_id',
        'exclude',    'show_hint_to_add_schedule', 'weekday week_of_month', 'month'
    ]);
    
    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check( $config, $params->{template}, 'edit-work-time' );

    if ( ( defined $checked->{action} ) && ( $checked->{action} eq 'save_schedule' ) ) {

        #set defaults
        $checked->{create_events}  = 0;
        $checked->{publish_events} = 0;
    }
    for my $param ( 'frequency', 'duration', 'default_duration' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /(\d+)/ ) ) {
            $checked->{$param} = $1;
        }
    }

    #scalars
    for my $param ( 'from', 'till', 'period_type', 'type', 'title' ) {
        if ( defined $params->{$param} ) {
            $checked->{$param} = $params->{$param};
            $checked->{$param} =~ s/^\s+//g;
            $checked->{$param} =~ s/\s+$//g;
        }
    }

    for my $attr ('start') {
        if ( ( defined $params->{$attr} ) && ( $params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)/ ) ) {
            $checked->{$attr} = $1 . ':00';
        }
    }

    for my $attr ('end') {
        if ( ( defined $params->{$attr} ) && ( $params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d)/ ) ) {
            $checked->{$attr} = $1;
        }
    }

    return $checked;
}

