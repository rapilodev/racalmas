#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use Encode();

use utf8();
use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use project();
use studios();
use events();
use series();
use series_dates();
use markup();
use localization();
use series_schedule();
use series_events();
use user_stats();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
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
$params = uac::setDefaultProject( $params, $user_presets );

#print STDERR $params->{project_id}."\n";
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
unless ( params::isJson() ) {
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
    template::process( $config, 'print', template::check( $config, 'series-header.html' ),
        $headerParams );
}
return unless uac::check( $config, $params, $user_presets ) == 1;

if ( defined $params->{action} ) {
    save_schedule( $config, $request ) if ( $params->{action} eq 'save_schedule' );
    delete_schedule( $config, $request ) if ( $params->{action} eq 'delete_schedule' );
    add_user( $config, $request ) if ( $params->{action} eq 'add_user' );
    remove_user( $config, $request ) if ( $params->{action} eq 'remove_user' );
    save_series( $config, $request ) if ( $params->{action} eq 'save' );
    save_series( $config, $request ) if ( $params->{action} eq 'create' );
    delete_series( $config, $request ) if ( $params->{action} eq 'delete' );

    #    scan_events  ($config, $request)    if ($params->{action} eq 'scan_events');
    assign_event( $config, $request ) if ( $params->{action} eq 'assign_event' );
    unassign_event( $config, $request ) if ( $params->{action} eq 'unassign_event' );
    if ( $params->{action} eq 'reassign_event' ) {
        my $result = reassign_event( $config, $request );
        return if defined $result;
    }
    if ( $params->{action} eq 'rebuild_episodes' ) {
        rebuild_episodes( $config, $request );
        return;
    }
    if ( $params->{action} eq 'set_rebuilt_episodes' ) {
        set_rebuilt_episodes( $config, $request );
        return;
    }
}

if ( defined $params->{series_id} ) {
    template::process( $config, 'print', template::check( $config, 'show-series-header.html' ),{})
        unless params::isJson();
    show_series( $config, $request );
} else {
    template::process( $config, 'print', template::check( $config, 'list-series-header.html' ),{})
        unless params::isJson();
    list_series( $config, $request );
}

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

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'start' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    my $entry = {};
    for my $attr (
        'project_id',  'studio_id', 'series_id', 'start',   'duration',      'exclude',
        'period_type', 'end',       'frequency', 'weekday', 'week_of_month', 'month',
        'nextDay'
      )
    {
        $entry->{$attr} = $params->{$attr} if defined $params->{$attr};
    }

    unless ( project::is_series_assigned( $config, $entry ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    my $found = 0;
    for my $type ( 'single', 'days', 'week_of_month' ) {
        $found = 1 if ( $entry->{period_type} eq $type );
    }
    if ( $found == 0 ) {
        uac::print_error('no period type selected!');
        return;
    }

    $entry->{nextDay} = 0 unless defined $entry->{nextDay};
    $entry->{exclude} = 0 if $entry->{exclude} ne '1';
    $entry->{nextDay} = 0 if $entry->{nextDay} ne '1';

    if ( ( $entry->{end} ne '' ) && ( $entry->{end} le $entry->{start} ) ) {
        uac::print_error('start date should be before end date!');
        return;
    }

    #TODO: check if schedule is in studio_timeslots

    #on adding a single exclude schedule, remove any existing single schedules with same date
    if ( ( $entry->{period_type} eq 'single' ) && ( $entry->{exclude} eq '1' ) ) {
        unless ( $permissions->{delete_schedule} == 1 ) {
            uac::permissions_denied('delete_schedule');
            return;
        }

        #get single schedules
        my $schedules = series_schedule::get(
            $config,
            {
                project_id  => $entry->{project_id},
                studio_id   => $entry->{studio_id},
                series_id   => $entry->{series_id},
                start       => $entry->{start},
                period_type => 'single',
                exclude     => 0
            }
        );
        if ( scalar(@$schedules) > 0 ) {
            local $config->{access}->{write} = 1;
            for my $schedule (@$schedules) {
                series_schedule::delete( $config, $schedule );
            }
            my $updates = series_dates::update( $config, $entry );
            uac::print_info("single schedule deleted. $updates dates scheduled");
            return;
        }
    }

    local $config->{access}->{write} = 1;
    if ( defined $params->{schedule_id} ) {
        $entry->{schedule_id} = $params->{schedule_id};
        series_schedule::update( $config, $entry );

        #timeslots are checked inside
        my $updates = series_dates::update( $config, $entry );
        uac::print_info("schedule saved. $updates dates scheduled");
    } else {
        series_schedule::insert( $config, $entry );

        #timeslots are checked inside
        my $updates = series_dates::update( $config, $entry );
        uac::print_info("schedule added. $updates dates added");
    }
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
    for my $attr ( 'project_id', 'studio_id', 'series_id', 'schedule_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $entry ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    local $config->{access}->{write} = 1;
    $entry->{schedule_id} = $params->{schedule_id};
    series_schedule::delete( $config, $entry );
    series_dates::update( $config, $entry );
    uac::print_info("schedule deleted");
}

#todo: check if assigned to studio
sub delete_series {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{delete_series} == 1 ) {
        uac::permissions_denied('delete_series');
        return;
    }

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'series_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $entry ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $series_id  = $entry->{series_id};

    local $config->{access}->{write} = 1;
    if ( $entry->{series_id} ne '' ) {
        my $result = series::delete( $config, $entry );

        user_stats::increase(
            $config,
            'delete_series',
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
                user       => $params->{presets}->{user}
            }
        );
        unless ( $result == 1 ) {
            uac::print_error('could not delete series');
            return;
        }
    }
    uac::print_info("series deleted");
}

sub save_series {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    my $columns     = series::get_columns($config);

    for my $attr ( 'project_id', 'studio_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    # fill series entry
    my $entry = {};
    for my $param ( keys %$params ) {
        if ( exists $columns->{$param} ) {
            $entry->{$param} = $params->{$param} || '';
        }
    }
    $entry->{project_id}     = $params->{project_id};
    $entry->{studio_id}      = $params->{studio_id};
    $entry->{series_id}      = $params->{series_id} || '';
    $entry->{live}           = $params->{live} // 0;
    $entry->{count_episodes} = $params->{count_episodes} // 0;
    $entry->{predecessor_id} = $params->{predecessor_id} // 0;
    
    if ($entry->{predecessor_id} eq $entry->{series_id}){
        uac::print_error( qq{save:Predecessor $entry->{predecessor_id} must be different from series id $entry->{series_id}.} );
        return;
    }

    #$entry->{html_content} = Encode::decode( 'utf-8', $entry->{content} );
    if ($entry->{content_format} //'' eq "markdown"){
        $entry->{html_content} = markup::markdown_to_html( $entry->{content} );
    }else{
        $entry->{html_content} = markup::creole_to_html( $entry->{content} );
        $entry->{html_content} =~ s/([^\>])\n+([^\<])/$1<br\/><br\/>$2/g;
    }

    $entry->{modified_at} = time::time_to_datetime( time() );
    $entry->{modified_by} = $request->{user};

    if ( ( $params->{title} eq '' ) && ( $params->{series_name} eq '' ) ) {
        uac::print_error("please set at least series name!");
        return;
    }

    # make sure name is not used anywhere else
    my $series_ids = series::get(
        $config,
        {
            project_id  => $entry->{project_id},
            studio_id   => $entry->{studio_id},
            series_name => $entry->{series_name},
            title       => $entry->{title}
        }
    );

    if ( $params->{action} eq 'create' ) {

        unless ( $permissions->{create_series} == 1 ) {
            uac::permissions_denied('create_series');
            return;
        }
        if ( project::is_series_assigned( $config, $entry ) == 1 ) {
            uac::print_error('series is already assigned to project!');
            return undef;
        }
        if ( scalar(@$series_ids) > 0 ) {
            uac::permissions_denied('insert, entry already exists');
            return;
        }

        local $config->{access}->{write} = 1;
        my $series_id = series::insert( $config, $entry );

        user_stats::increase(
            $config,
            'create_series',
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
                user       => $params->{presets}->{user}
            }
        );

        unless ( defined $series_id ) {
            uac::print_error('could not insert series');
            return;
        }
    }
    if ( $params->{action} eq 'save' ) {

        unless ( $permissions->{update_series} == 1 ) {
            uac::permissions_denied('update_series');
            return;
        }
        unless ( ( defined $params->{series_id} ) && ( $params->{series_id} ne '' ) ) {
            uac::permissions_denied('update. missing parameter series_id');
            return;
        }
        unless ( project::is_series_assigned( $config, $entry ) == 1 ) {
            uac::print_error('series is not assigned to project!');
            return undef;
        }
        
        if ( scalar(@$series_ids) > 1 ) {
            uac::permissions_denied(q{update due to series already exists multiple times with name "$entry->{series_name}" and title "$entry->{title}"});
            return;
        }
        if (   ( scalar(@$series_ids) == 1 )
            && ( $series_ids->[0]->{series_id} ne $params->{series_id} ) )
        {
            uac::permissions_denied('update due to series id does not match to existing entry');
            return;
        }

        local $config->{access}->{write} = 1;
        my $result = series::update( $config, $entry );

        series_events::update_series_images(
            $config,
            {
                project_id   => $entry->{project_id},
                studio_id    => $entry->{studio_id},
                series_id    => $entry->{series_id},
                series_image => $params->{image}
            }
        );

        user_stats::increase(
            $config,
            'update_series',
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
                user       => $params->{presets}->{user}
            }
        );

        unless ( defined $result ) {
            uac::print_error('could not update series');
            return;
        }

    }
    uac::print_info("series saved");
}

#save series name and title of events to be assigned to this series
#deprecated
sub save_scan {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{scan_series_events} == 1 ) {
        uac::permissions_denied('scan_series_events');
        return;
    }

    unless ( $permissions->{update_series} == 1 ) {
        uac::permissions_denied('update_series');
        return;
    }
    for my $param ( 'project_id', 'studio_id', 'series_id' ) {
        unless ( ( defined $params->{$param} ) && ( $params->{$param} ne '' ) ) {
            uac::permissions_denied("save. missing parameter $param");
            return;
        }
    }
    unless ( ( $params->{assign_event_series_name} =~ /\S/ )
        || ( $params->{assign_event_title} =~ /\S/ ) )
    {
        uac::permissions_denied("save. one of series name or title must be set");
        return;
    }
    my $entry = {
        studio_id                => $params->{studio_id},
        series_id                => $params->{series_id},
        assign_event_series_name => $params->{assign_event_series_name},
        assign_event_title       => $params->{assign_event_title},
    };

    local $config->{access}->{write} = 1;
    series::update( $config, $entry );
    uac::print_info("changes saved");
}

#deprecated
sub scan_events {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{scan_series_events} == 1 ) {
        uac::permissions_denied('scan_series_events');
        return;
    }

    local $config->{access}->{write} = 1;
    my $series = series::get(
        $config,
        {
            'project_id' => $params->{project_id},
            'studio_id'  => $params->{studio_id}
        }
    );

    $params->{scan_results} = q{
        <table>
            <tr>
                <th>event</th>
                <th>scan for</th>
                <th>events found</th>
            </tr>
    };

    #list of all studios by id
    my $studios = studios::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id}
        }
    );
    my $studio_by_id = {};
    for my $studio (@$studios) {
        $studio_by_id->{ $studio->{id} } = $studio;
    }
    my $studio   = $studio_by_id->{ $params->{studio_id} };
    my $location = $studio->{location};

    for my $serie (@$series) {

        #get matching events by series_name and title
        my $series_name = $serie->{assign_event_series_name};
        my $title       = $serie->{assign_event_title};
        my $events      = series::search_events(
            $config, $request,
            {
                series_name => $series_name,
                location    => $location,
                title       => $title,
                get         => 'no_content',
                archive     => 'all',
                limit       => 1000,
            }
        );
        my $event_ids = [];
        @$event_ids = map { $_->{event_id} } @$events;

        $params->{scan_results} .=
            '<tr>' . '<td>'
          . $serie->{series_name} . ' - '
          . $serie->{title} . '</td>' . '<td>'
          . $series_name . ' - '
          . $title . '</td>' . '<td>'
          . scalar(@$event_ids) . '</td>' . '</tr>' . "\n";

        series::set_event_ids( $config, $params->{project_id}, $params->{studio_id}, $serie,
            $event_ids );
    }
    $params->{scan_results} .= "</table><hr>\n";
    uac::print_info("events successfully assigned to all series");
}

sub assign_event {
    my $config  = shift;
    my $request = shift;

    print STDERR "assign event\n";

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return undef;
    }

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return undef;
        }
    }

    # check if event exists,
    # this has to use events::get, since it cannot check for series_id
    # TODO: check location of studio_id
    my $request2 = {
        params => {
            checked => events::check_params(
                $config,
                {
                    event_id => $entry->{event_id},
                    template => 'no',
                    limit    => 1,
                    archive  => 'all',

                    #                    no_exclude => 1
                }
            )
        },
        config      => $request->{config},
        permissions => $request->{permissions}
    };
    $request2->{params}->{checked}->{published} = 'all';

    my $events = events::get( $config, $request2 );

    if ( scalar(@$events) != 1 ) {
        uac::print_error("no event found for event_id=$entry->{event_id}, archive=all");
        return undef;
    }

    my $event = $events->[0];

    #is series assigned to studio
    my $result = series_events::check_permission(
        $request,
        {
            permission => 'assign_series_events',
            check_for  => [ 'studio', 'user', 'series', 'studio_timeslots' ],
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
            event_id   => $entry->{event_id},
            start      => $event->{start_datetime},
            end        => $event->{end_datetime}
        }
    );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return undef;
    }

    local $config->{access}->{write} = 1;
    $result = series::assign_event(
        $config,
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
            event_id   => $entry->{event_id},
            manual     => 1
        }
    );
    unless ( defined $result ) {
        uac::print_error("error on assigning event to series");
        return undef;
    }

    my $series = series::get(
        $config,
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
        }
    );
    if ( @$series == 1 ) {
        my $serie = $series->[0];

        #set event's series name to value from series
        my $series_name = $serie->{series_name} || '';
        if ( $series_name ne '' ) {

            # prepend series_name from event to title on adding to single_events series
            my $title = $event->{title};
            if ( $serie->{has_single_events} eq '1' ) {
                $title = $event->{series_name} . ' - ' . $title if $event->{series_name} ne '';
            }

            # save event content
            series_events::save_content(
                $config,
                {
                    studio_id   => $entry->{studio_id},
                    id          => $entry->{event_id},    #TODO: id=> event_id
                    series_name => $series_name,
                    title       => $title,
                    episode     => $event->{episode},
                    rerun       => $event->{rerun},
                }
            );

            # add to history
            $event->{project_id}  = $entry->{project_id};
            $event->{studio_id}   = $entry->{studio_id};
            $event->{series_id}   = $entry->{series_id};
            $event->{event_id}    = $entry->{event_id};
            $event->{series_name} = $series_name;
            $event->{title}       = $title;
            $event->{user}        = $params->{presets}->{user};
            event_history::insert( $config, $event );
        }
    } else {
        print STDERR
"no series title found for studio $entry->{studio_id} series $entry->{series_id}, event $entry->{event_id}\n";
    }

    uac::print_info("event successfully assigned to series");
    $params->{getBack} = 1;
    return 1;
}

sub unassign_event {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return undef;
    }

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return undef;
        }
    }

    #check if event exists
    my $event = series::get_event(
        $config,
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
            event_id   => $entry->{event_id},
        }
    );
    unless ( defined $event ) {
        uac::print_error(
"event $entry->{event_id} not found for project_id=$entry->{project_id}, studio_id=$entry->{studio_id}, series_id=$entry->{series_id}"
        );
        return undef;
    }

    #is series assigned to studio
    my $result = series_events::check_permission(
        $request,
        {
            permission => 'assign_series_events',
            check_for  => [ 'studio', 'user', 'series', 'studio_timeslots' ],
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
            event_id   => $entry->{event_id},
            start      => $event->{start_datetime},
            end        => $event->{end_datetime}
        }
    );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return undef;
    }

    local $config->{access}->{write} = 1;
    $result = series::unassign_event(
        $config,
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
            event_id   => $entry->{event_id},
        }
    );
    unless ( defined $result ) {
        uac::print_error("error on unassigning event from series");
        return undef;
    }
    uac::print_info("event successfully unassigned from series");
    $params->{getBack} = 1;
    return 1;
}

# assign event to new series id and remove from old series id
sub reassign_event {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return undef;
    }

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'new_series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( $attr . ' not given!' );
            return undef;
        }
    }

    my $project_id    = $params->{project_id};
    my $studio_id     = $params->{studio_id};
    my $event_id      = $params->{event_id};
    my $series_id     = $params->{series_id};
    my $new_series_id = $params->{new_series_id};

    $request->{params}->{checked}->{series_id} = $new_series_id;
    my $result = assign_event( $config, $request );
    unless ( defined $result ) {
        uac::print_error("could not assign event");
        return undef;
    }

    $request->{params}->{checked}->{series_id} = $series_id;
    $result = unassign_event( $config, $request );
    unless ( defined $result ) {
        uac::print_error("could not unassign event");
        return undef;
    }

    my $url =
        'broadcast.cgi?project_id='
      . $project_id
      . '&studio_id='
      . $studio_id
      . '&series_id='
      . $new_series_id
      . '&event_id='
      . $event_id;
    print qq{<meta http-equiv="refresh" content="0; url=$url" />} . "\n";
    delete $params->{getBack};
    return 1;
}

sub add_user {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_member} == 1 ) {
        uac::permissions_denied('assign_series_member');
        return;
    }

    for my $param ( 'project_id', 'studio_id', 'series_id', 'user_id' ) {
        if ( $params->{$param} eq '' ) {
            uac::print_error("missing $param");
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $params ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    local $config->{access}->{write} = 1;
    series::add_user(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            user_id    => $params->{user_id},
            user       => $request->{user}
        }
    );

    uac::print_info("user assigned to series");
}

sub remove_user {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{remove_series_member} == 1 ) {
        uac::permissions_denied('remove_series_member');
        return;
    }

    for my $param ( 'project_id', 'studio_id', 'series_id', 'user_id' ) {
        if ( $params->{$param} eq '' ) {
            uac::print_error("missing $param");
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $params ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    local $config->{access}->{write} = 1;
    series::remove_user(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            user_id    => $params->{user_id}
        }
    );
    uac::print_info("user removed from series");
}

sub list_series {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_series} == 1 ) {
        uac::permissions_denied('read_series');
        return;
    }

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    my $studios = studios::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id
        }
    );

    my $studio_by_id = {};
    for my $studio (@$studios) {
        $studio_by_id->{ $studio->{id} } = $studio;
    }
    my $studio = $studio_by_id->{$studio_id};

    my $series_conditions = {
        project_id => $project_id,
        studio_id  => $studio_id
    };
    my $series = series::get_event_age( $config, $series_conditions );

    my $newSeries = [];
    my $oldSeries = [];
    for my $serie ( sort { lc $a->{series_name} cmp lc $b->{series_name} } (@$series) ) {
        if ( $serie->{days_over} > 30 ) {
            push @$oldSeries, $serie;
        } else {
            push @$newSeries, $serie;
        }
    }

    $params->{newSeries} = $newSeries;
    $params->{oldSeries} = $oldSeries;

    $params->{image} =
      studios::getImageById( $config, { project_id => $project_id, studio_id => $studio_id } )
      if ( ( !defined $params->{image} ) || ( $params->{image} eq '' ) );
    $params->{image} = project::getImageById( $config, { project_id => $project_id } )
      if ( ( !defined $params->{image} ) || ( $params->{image} eq '' ) );

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'all,series' } );
    template::process( $config, 'print', $params->{template}, $params );
}

sub show_series {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_series} == 1 ) {
        uac::permissions_denied('read_series');
        return;
    }

    for my $param ( 'project_id', 'studio_id', 'series_id' ) {
        unless ( defined $params->{$param} ) {
            uac::print_error("missing $param");
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $params ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    #this will be updated later (especially allow_update_events)
    for my $permission ( keys %{ $request->{permissions} } ) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #list of all studios by id
    my $studios = studios::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id
        }
    );
    my $studio_by_id = {};
    for my $studio (@$studios) {
        $studio_by_id->{ $studio->{id} } = $studio;
    }

    #get series
    my $series_conditions = {
        project_id => $project_id,
        studio_id  => $studio_id,
        series_id  => $params->{series_id}
    };

    my $series = series::get( $config, $series_conditions );
    if ( @$series > 1 ) {
        uac::print_error(
            "too much series found for studio '" . $studio_by_id->{$studio_id}->{name} . "'" );
        return;
    }

    if ( @$series == 0 ) {
        uac::print_error( "selected series not assigned to studio '"
              . $studio_by_id->{$studio_id}->{name}
              . "'" );
        return;
    }
    my $serie = $series->[0];

    uac::print_error( qq{show: Predecessor $serie->{predecessor_id} must be different from series id $serie->{series_id}.} ) 
        if ($serie->{predecessor_id}//'') eq $serie->{series_id};

    #get all users currently assigned to the user
    my $user_studios =
      uac::get_studios_by_user( $config, { project_id => $project_id, user => $request->{user} } );

    my $studio_users =
      uac::get_users_by_studio( $config, { project_id => $project_id, studio_id => $studio_id } );
    for my $studio_user (@$studio_users) {
        $studio_user->{user_id} = $studio_user->{id};
    }
    my @users = @$studio_users;
    @users = sort { lc $a->{full_name} cmp lc $b->{full_name} } @users;
    $studio_users = \@users;

    #show events from last month until next 3 months
    my $from = DateTime->now( time_zone => $config->{date}->{time_zone} )->subtract( months => 1 )
      ->datetime();
    my $till =
      DateTime->now( time_zone => $config->{date}->{time_zone} )->add( months => 3 )->datetime();

    #add name of current studio
    my $studio = $studio_by_id->{ $serie->{studio_id} };
    $serie->{studio} = $studio->{name};

    my $location = $studio->{location};

    # set default image from studio
    $serie->{image} =
      studios::getImageById( $config, { project_id => $project_id, studio_id => $studio_id } )
      if ( ( !defined $serie->{image} ) || ( $serie->{image} eq '' ) );
    $serie->{image} = project::getImageById( $config, { project_id => $project_id } )
      if ( ( !defined $serie->{image} ) || ( $serie->{image} eq '' ) );

    #add users
    $serie->{series_users} = series::get_users(
        $config,
        {
            project_id => $project_id,
            studio_id  => $serie->{studio_id},
            series_id  => $serie->{series_id}
        }
    );
    uac::print_warn("There is no user assigned, yet. Please assign a user!")
      if scalar @{ $serie->{series_users} } == 0;

    #add events
    $serie->{events} = series::get_events(
        $config,
        {
            project_id => $project_id,
            studio_id  => $serie->{studio_id},
            series_id  => $serie->{series_id},
            from_date  => $from,
            till_date  => $till,
            location   => $location,
            limit      => 30,
            archive    => 'all',
            published  => 'all'
        }
    );
    @{ $serie->{events} } = reverse @{ $serie->{events} };

    my $allow_update_event = series_events::check_permission(
        $request,
        {
            permission => 'update_event_of_series,update_event_of_others',
            check_for  => [ 'studio', 'user', 'series' ],
            project_id => $project_id,
            studio_id  => $serie->{studio_id},
            series_id  => $params->{series_id}
        },

    );

    $params->{allow}->{update_event} = 0;
    $params->{allow}->{update_event} = 1 if ( $allow_update_event eq '1' );

    $serie->{studio_users} = $studio_users;

    if (($serie->{markup_format}//'') eq 'markdown'){
        $serie->{html_content} = markup::markdown_to_html( $serie->{content} );
    }else{
        $serie->{html_content} = markup::creole_to_html( $serie->{content} );
        $serie->{html_content} =~ s/([^\>])\n+([^\<])/$1<br\/><br\/>$2/g;
    }

    for my $user ( @{ $serie->{series_users} } ) {
        $user->{user_id} = $user->{id};
    }

    #add schedules
    my $schedules = series_schedule::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
            series_id  => $serie->{series_id}
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
    }

    $serie->{schedule}  = $schedules;
    $serie->{start}     = $params->{start};
    $serie->{end}       = $params->{end};
    $serie->{frequency} = $params->{frequency};
    $serie->{duration}  = $serie->{default_duration};
    my $duration = $params->{duration} || '';
    $serie->{duration} = $params->{duration} if $duration ne '';

    $serie->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/ if defined $serie->{start};
    $serie->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/   if defined $serie->{end};

    #add series dates
    my $series_dates = series_dates::get(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
            series_id  => $serie->{series_id}
        }
    );

    #remove seconds from dates
    for my $date (@$series_dates) {
        $date->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $date->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
    }
    $serie->{series_dates} = $series_dates;

    $serie->{show_hint_to_add_schedule} = $params->{show_hint_to_add_schedule};

    if ( ( defined $params->{setImage} ) and ( $params->{setImage} ne $serie->{image} ) ) {
        $serie->{image}          = $params->{setImage};
        $params->{forced_change} = 1;
    }

    #copy series to params
    for my $key ( keys %$serie ) {
        $params->{$key} = $serie->{$key};
    }

    for my $value ('markdown', 'creole'){
        $params->{"content_format_$value"}=1 if ($params->{content_format}//'') eq $value;
    }

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'all,series' } );
    template::process( $config, 'print', $params->{template}, $params );
}

sub set_rebuilt_episodes {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_series} == 1 ) {
        uac::permissions_denied('read_series');
        return;
    }

    for my $param ( 'project_id', 'studio_id', 'series_id' ) {
        unless ( defined $params->{$param} ) {
            uac::print_error("missing $param");
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $params ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    #this will be updated later (especially allow_update_events)
    for my $permission ( keys %{ $request->{permissions} } ) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $series_id  = $params->{series_id};
    my $events     = series::get_rebuilt_episodes(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
            series_id  => $series_id
        }
    );

    my $updates = 0;
    for my $event (@$events) {
        next if $event->{project_id} ne $project_id;
        next if $event->{studio_id} ne $studio_id;
        next if $event->{old_episode} eq $event->{episode};
        series_events::set_episode(
            $config,
            {
                id      => $event->{id},
                episode => $event->{episode}
            }
        );
        $updates++;
    }
}

sub rebuild_episodes {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_series} == 1 ) {
        uac::permissions_denied('read_series');
        return;
    }

    for my $param ( 'project_id', 'studio_id', 'series_id' ) {
        unless ( defined $params->{$param} ) {
            uac::print_error("missing $param");
            return;
        }
    }

    unless ( project::is_series_assigned( $config, $params ) == 1 ) {
        uac::print_error('series is not assigned to project!');
        return undef;
    }

    #this will be updated later (especially allow_update_events)
    for my $permission ( keys %{ $request->{permissions} } ) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $series_id  = $params->{series_id};
    my $events     = series::get_rebuilt_episodes(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
            series_id  => $series_id
        }
    );

    my $events_by_id = {};
    for my $event (@$events) {
        $events_by_id->{ $event->{id} } = $event;
    }

    print "<style>
        tr        {cursor:pointer}
        td        {border:1px solid gray}
        tr.error  {background:#f99}
        tr.warn   {background:#ff9}
        tr.ok     {background:#9f9}
        </style>
    ";

    my $prev        = undef;
    my $max_episode = 0;
    my $changes     = 0;
    my $errors      = 0;
    for my $event (@$events) {
        $max_episode = $event->{episode} if $event->{episode} > $max_episode;
        my $e1 = $event->{old_episode} // '';
        my $e2 = $event->{episode}     // '';
        my $o1 = $prev->{old_episode}  // '';
        my $o2 = $prev->{episode}      // '';
        if ( $e1 eq $e2 ) {
            $event->{class} = 'ok';
        } else {
            $changes++;
            $event->{class} = 'warn';
        }
        if ( $e1 and $e2 and $o1 and $o2 and ( ( $e2 - $o2 ) != ( $e1 - $o1 ) ) ) {
            $event->{class} = "error" if $e1 ne $e2;
            $prev->{class} = "error" if defined $prev and $o1 ne $o2;
            $errors++;
        }
        if ( $event->{episode} < $max_episode and !$event->{recurrence} ) {
            $event->{class} = "error";
            $errors++;
        }
        $event->{recurrence_start} = $events_by_id->{ $event->{recurrence} }->{start};
        $event->{recurrence}       = '-' unless $event->{recurrence};
        $prev                      = $event;
    }
    print "$errors errors, $changes changes\n";
    if ( ( $changes > 0 ) and ( $errors == 0 ) ) {
        my $url =
"series.cgi?action=set_rebuilt_episodes&project_id=$project_id&studio_id=$studio_id&series_id=$series_id";
        print qq{<a class="button" href="$url"><button>apply changes</button></a>};
    }
    my @cols =
      qw(id start series_name title episode old_episode recurrence recurrence_start project_name studio_name);
    print "<table>\n";
    print "<tr>" . join( "", map { "<th>" . ( $_ // '-' ) . "</th>" } @cols ) . "</tr>\n";

    for my $event (@$events) {
        print qq{<tr class="$event->{class}" onclick="window.location.href=\$(this).attr('href');"}
          . qq{ href="broadcast.cgi?action=edit&project_id=$event->{project_id}&studio_id=$event->{studio_id}&series_id=$series_id&event_id=$event->{id}"\n}
          . qq{>}
          . join( "", map { "<td>" . ( $event->{$_} // '-' ) . "</td>" } @cols )
          . "</tr>\n";
    }
    print "</table>\n";
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    $checked->{action} = entry::element_of( $params->{action}, 
    [ qw( add_user remove_user
          create delete save details show
          save_schedule delete_schedule
          save_scan scan_events
          assign_event unassign_event reassign_event
          rebuild_episodes set_rebuilt_episodes
    )]);
    
    $checked->{exclude} = 0;
    entry::set_numbers( $checked, $params, [
        'id',            'project_id',
        'studio_id',     'default_studio_id',
        'user_id',       'new_series_id',
        'series_id',     'schedule_id',
        'exclude',       'show_hint_to_add_schedule',
        'event_id',      'weekday',
        'week_of_month', 'month',
        'nextDay',       'predecessor_id'
    ]);
    
    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    if ( defined $checked->{series_id} ) {
        $checked->{template} = template::check( $config, $params->{template}, 'edit-series' );
    } else {
        $checked->{template} = template::check( $config, $params->{template}, 'series' );
    }

    if ( ( defined $checked->{action} ) && ( $checked->{action} eq 'save_schedule' ) ) {

        #set defaults
        $checked->{create_events}  = 0;
        $checked->{publish_events} = 0;
    }
    
    entry::set_numbers( $checked, $params, [
        'frequency',      'duration', 'default_duration', 'create_events',
        'publish_events', 'live',     'count_episodes'
    ]);

    #scalars
    entry::set_strings( $checked, $params, 
        [ 'search', 'from', 'till', 'period_type' ]
    );

    entry::set_strings( $checked, $params, [
        'series_name',        'title',
        'excerpt',            'content',
        'topic',              'image',
        'image_label',        'assign_event_series_name',
        'assign_event_title', 'comment',
        'podcast_url',        'archive_url',
        'setImage',           'content_format'
    ]);

    for my $attr ('start') {
        if (   ( defined $params->{$attr} )
            && ( $params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)/ ) )
        {
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

