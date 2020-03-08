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
use studio_timeslot_schedule();
use studio_timeslot_dates();
use markup();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( ( !defined $user ) || ( $user eq '' ) );

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
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'all,menu' } );

my $action = $params->{action} || '';
if ( $action eq 'show_dates' ) {

    #print "Content-type:text/html\n\n";
} else {
    template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
}
return unless uac::check( $config, $params, $user_presets ) == 1;

if ( $action eq 'show_dates' ) {
    print "Content-Type:text/html\n\n";
} else {
    print q{
	    <script src="js/jquery-ui-timepicker.js" type="text/javascript"></script>
	    <link href="css/jquery-ui-timepicker.css" type="text/css" rel="stylesheet" /> 
	    <link href="css/theme.default.css" rel="stylesheet">

	<script src="js/jquery.tablesorter.min.js"></script>
	<script src="js/jquery.tablesorter.widgets.min.js"></script>
	<script src="js/jquery.tablesorter.scroller.js"></script>

        <script src="js/studio-timeslots.js" type="text/javascript"></script>
	    <script src="js/datetime.js" type="text/javascript"></script>
	    <link rel="stylesheet" href="css/studio-timeslots.css" type="text/css" /> 
    };
}

if ( defined $params->{action} ) {
    save_schedule( $config, $request ) if ( $params->{action} eq 'save_schedule' );
    delete_schedule( $config, $request ) if ( $params->{action} eq 'delete_schedule' );
    if ( $params->{action} eq 'show_dates' ) {
        showDates( $config, $request );
        return;
    }
}

$config->{access}->{write} = 0;
showTimeslotSchedule( $config, $request );
return;

#insert or update a schedule and update all schedule dates
sub save_schedule {
    my $config  = shift;
    my $request = shift;

    my $permissions = $request->{permissions};
    unless ( $permissions->{update_studio_timeslot_schedule} == 1 ) {
        uac::permissions_denied('update_studio_timeslot_schedule');
        return;
    }

    my $params = $request->{params}->{checked};

    for my $attr ( 'project_id', 'studio_id', 'start', 'end', 'end_date', 'schedule_studio_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    my $entry = {};
    for my $attr ( 'project_id', 'start', 'end', 'end_date', 'frequency' ) {
        $entry->{$attr} = $params->{$attr} if defined $params->{$attr};
    }

    #set schedule's studio to value from schedule_studio_id
    $entry->{studio_id} = $params->{schedule_studio_id} if defined $params->{schedule_studio_id};

    if ( ( $entry->{end} ne '' ) && ( $entry->{end} le $entry->{start} ) ) {
        uac::print_error('start date should be before end date!');
        return;
    }

    $config->{access}->{write} = 1;
    if ( defined $params->{schedule_id} ) {
        $entry->{schedule_id} = $params->{schedule_id};
        studio_timeslot_schedule::update( $config, $entry );

        my $updates = studio_timeslot_dates::update( $config, $entry );
        uac::print_info("timeslot schedule saved. $updates dates scheduled");
    } else {
        $entry->{schedule_id} = studio_timeslot_schedule::insert( $config, $entry );

        my $updates = studio_timeslot_dates::update( $config, $entry );
        uac::print_info("timeslot schedule added. $updates dates added");
    }

}

sub delete_schedule {
    my $config  = shift;
    my $request = shift;

    my $permissions = $request->{permissions};
    unless ( $permissions->{update_studio_timeslot_schedule} == 1 ) {
        uac::permissions_denied('update_studio_timeslot_schedule');
        return;
    }

    my $params = $request->{params}->{checked};

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
    studio_timeslot_schedule::delete( $config, $entry );
    studio_timeslot_dates::update( $config, $entry );
    uac::print_info("timeslot schedule deleted");
}

sub showTimeslotSchedule {
    my $config  = shift;
    my $request = shift;

    $config->{access}->{write} = 0;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_studio_timeslot_schedule} == 1 ) {
        uac::permissions_denied('read_studio_timeslot_schedule');
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

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'all,studio-timeslots' } );

    my $studio_id  = $params->{studio_id};
    my $project_id = $params->{project_id};

    #get project schedule
    my $schedules = studio_timeslot_schedule::get(
        $config,
        {
            project_id => $project_id

              #		    studio_id=>$studio_id
        }
    );

    #list of all studios by id
    my $studios = studios::get( $config, { project_id => $project_id } );

    #remove seconds from dates
    for my $schedule (@$schedules) {
        $schedule->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $schedule->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/;

        #insert assigned studio
        for my $studio (@$studios) {
            my $entry = {
                id   => $studio->{id},
                name => $studio->{name},
            };
            $entry->{selected} = 1 if ( $studio->{id} eq $schedule->{studio_id} );
            push @{ $schedule->{studios} }, $entry;
        }
    }

    my $result = {
        project_id => $project_id,
        studio_id  => $studio_id
    };
    $result->{schedule}  = $schedules;
    $result->{studios}   = $studios;
    $result->{start}     = $params->{start};
    $result->{end}       = $params->{end};
    $result->{end_date}  = $params->{end_date};
    $result->{frequency} = $params->{frequency};

    #remove seconds from datetimes
    $result->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/ if defined $result->{start};
    $result->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/   if defined $result->{end};

    #copy entry values to params
    for my $key ( keys %$result ) {
        $params->{$key} = $result->{$key};
    }

    #print '<pre>'.Dumper($params).'</pre>';
    template::process( $config, 'print', $params->{template}, $params );
}

sub showDates {
    my $config  = shift;
    my $request = shift;

    $config->{access}->{write} = 0;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_studio_timeslot_schedule} == 1 ) {
        uac::permissions_denied('read_studio_timeslot_schedule');
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

    my $studio_id  = $params->{studio_id};
    my $project_id = $params->{project_id};

    my $fromDate = $params->{show_date} . '-01-01';
    my $tillDate = $params->{show_date} . '-12-31';

    #add timeslot dates
    my $timeslot_dates = studio_timeslot_dates::get(
        $config,
        {
            project_id => $project_id,

            #		    studio_id=>$studio_id,
            from => $fromDate,
            till => $tillDate
        }
    );

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'all,studio-timeslots' } );
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

    my $studios = studios::get( $config, { project_id => $project_id } );
    my $studio_by_id = {};
    for my $studio (@$studios) {
        $studio_by_id->{ $studio->{id} } = $studio;
    }

    #remove seconds from dates
    for my $date (@$timeslot_dates) {

        #remove seconds from datetimes
        $date->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $date->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/;

        # translate weekday
        if ( $language ne 'en' ) {
            $date->{start_weekday} = $weekday->{ $date->{start_weekday} };
            $date->{end_weekday}   = $weekday->{ $date->{end_weekday} };
        }
        $date->{studio_name} = $studio_by_id->{ $date->{studio_id} }->{name};
    }
    my $result = {
        project_id => $project_id,
        studio_id  => $studio_id,
        dates      => $timeslot_dates
    };

    #copy entry values to params
    for my $key ( keys %$result ) {
        $params->{$key} = $result->{$key};
    }

    my $template = template::check( $config, 'studio-timeslot-dates' );
    template::process( $config, 'print', $template, $params );
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    #actions and roles
    if ( defined $params->{action} ) {
        if ( $params->{action} =~ /^(show|save_schedule|delete_schedule|show_dates)$/ ) {
            $checked->{action} = $params->{action};
        }
    }

    $checked->{exclude} = 0;
    entry::set_numbers( $checked, $params, [
        'id', 'project_id', 'studio_id', 'default_studio_id', 'schedule_id', 'schedule_studio_id'
    ]);

    if ( ( defined $params->{show_date} ) && ( $params->{show_date} =~ /^(\d\d\d\d)/ ) ) {
        $checked->{show_date} = $1;
    } else {
        my $date = time::date_to_array( time::time_to_date() );
        $checked->{show_date} = $date->[0];
    }

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check( $config, $params->{template}, 'studio-timeslots' );

    entry::set_numbers( $checked, $params,  ['frequency'] );

    for my $attr ( 'start', 'end' ) {
        if ( ( defined $params->{$attr} ) && ( $params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)/ ) ) {
            $checked->{$attr} = $1 . ':00';
        }
    }
    for my $attr ('end_date') {
        if ( ( defined $params->{$attr} ) && ( $params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d)/ ) ) {
            $checked->{$attr} = $1;
        }
    }

    return $checked;
}

