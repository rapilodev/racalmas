#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Encode();

use params();
use config();
use log();
use template();
use auth();
use uac();
use roles();
use project();
use studios();
use events();
use series();
use series_schedule();
use series_events();
use series_dates();
use markup();
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

#print STDERR $params->{project_id}."\n";
my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params($params),
    },
};
$request = uac::prepare_request( $request, $user_presets );

$params = $request->{params}->{checked};

#process header
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
	<script src="js/datetime.js" type="text/javascript"></script>
	<script src="js/event.js" type="text/javascript"></script>
	<script src="js/localization.js" type="text/javascript"></script>
	<link rel="stylesheet" href="css/series.css" type="text/css" /> 
};

my $permissions = $request->{permissions};
unless ( $permissions->{scan_series_events} == 1 ) {
    uac::permissions_denied('scan_series_events');
    return;
}

if ( defined $params->{action} ) {
    assign_events( $config, $request ) if ( $params->{action} eq 'assign_events' );
}
show_events( $config, $request );

sub show_events {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return;
    }

    my $projects = project::get( $config, { project_id => $params->{project_id} } );
    my $project = $projects->[0];

    #print STDERR Dumper($project);
    return unless ( @$projects == 1 );

    my $studios = studios::get( $config, { project_id => $params->{project_id}, studio_id => $params->{studio_id} } );
    my $studio = $studios->[0];

    #print STDERR Dumper($studio);
    return unless ( @$studios == 1 );

    my $project_name = $project->{name};
    my $studio_name  = $studio->{location};

    #get series_names
    my $dbh   = db::connect($config);
    my $query = q{
        select project_id, studio_id, series_id, series_name, title 
        from   calcms_series s, calcms_project_series ps 
        where  s.id=ps.series_id
        order  by series_name, title
    };
    my $results = db::get( $dbh, $query );

    # get projects by id
    my $projects_by_id = {};
    $projects = project::get($config);
    for my $project (@$projects) {
        $projects_by_id->{ $project->{project_id} } = $project;
    }

    # get studios by id
    my $studios_by_id = {};
    $studios = studios::get($config);
    for my $studio (@$studios) {
        $studios_by_id->{ $studio->{id} } = $studio;
    }

    #add project and studio name to series
    for my $result (@$results) {
        $result->{project_name} = $projects_by_id->{ $result->{project_id} }->{name};
        $result->{studio_name}  = $studios_by_id->{ $result->{studio_id} }->{location};
        $result->{series_name}  = 'Einzelsendung' if $result->{series_name} eq '_single_';
    }
    $params->{series} = $results;

    # get events not assigned to series
    my $conditions  = [];
    my $bind_values = [];
    if ( $project_name ne '' ) {
        push @$conditions,  'e.project=?';
        push @$bind_values, $project_name;
    }
    if ( $studio_name ne '' ) {
        push @$conditions,  'e.location=?';
        push @$bind_values, $studio_name;
    }
    $conditions = ' and ' . join( ' and ', @$conditions ) if scalar(@$conditions) > 0;
    $query = qq{
        select   e.id, program, project, location, start, series_name, title, episode, rerun 
        from     calcms_events e left join calcms_series_events se on se.event_id =e.id
        where    se.event_id is null
        $conditions
        order by series_name,title,start
        limit 1000
    };
    print '<pre>' . Dumper($query) . Dumper($bind_values) . '</pre>';
    $results = db::get( $dbh, $query, $bind_values );

    # detect title and episode
    my $weekdayNamesShort = time::getWeekdayNamesShort('de');
    for my $result (@$results) {
        $result->{rerun} .= '';
        if ( $result->{title} =~ /\#(\d+)([a-z])?\s*$/ ) {
            $result->{episode} = $1 unless defined $result->{episode};
            $result->{rerun} = $2 || '' unless ( $result->{rerun} =~ /\d/ );
            $result->{title} =~ s/\#\d+[a-z]?\s*$//;
            $result->{title} =~ s/\s+$//;
        }
        my $a = time::datetime_to_array( $result->{start} );

        #print STDERR "($a->[0],$a->[1],$a->[2])\n";
        $result->{weekday} = time::weekday( $a->[0], $a->[1], $a->[2] );
        $result->{weekday} = $weekdayNamesShort->[ $result->{weekday} - 1 ];
    }

    #fill template
    $params->{unassigned_events} = $results;
    $params->{sum_events}        = @$results;
    $params->{project_name}      = $project_name;
    $params->{studio_name}       = $studio_name;

    template::process( $config, 'print', $params->{template}, $params );
}

sub assign_events {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return;
    }

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_ids' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    $config->{access}->{write} = 1;
    for my $event_id ( split( /[\,\s]+/, $params->{event_ids} ) ) {
        next unless $event_id =~ /^\d+/;
        $entry->{event_id} = $event_id;

        #get and parse event
        my $request2 = {
            params => {
                checked => events::check_params(
                    $config,
                    {
                        event_id => $entry->{event_id},
                        template => 'no',
                        limit    => 1,
                        archive  => 'all',
                    }
                )
            },
            config      => $request->{config},
            permissions => $request->{permissions}
        };
        $request2->{params}->{checked}->{published} = 'all';
        my $events = events::get( $config, $request2 );
        my $event = $events->[0];
        unless ( defined $event ) {
            print STDERR
"event not found for project $entry->{project_id}, studio $entry->{studio_id}, series $entry->{series_id}, event $entry->{event_id}\n";
            next;
        }
        print STDERR "'"
          . $event->{event_id} . "' '"
          . $event->{series_name} . "' '"
          . $event->{title} . "' '"
          . $event->{episode} . "'\n";

        #next;

        #check if series is assigned to project/studio
        my $series = series::get(
            $config,
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
            }
        );
        if ( scalar(@$series) == 0 ) {

            # assign series to project/studio
            project::assign_series(
                $config,
                {
                    project_id => $entry->{project_id},
                    studio_id  => $entry->{studio_id},
                    series_id  => $entry->{series_id},
                }
            );
        } else {
            print STDERR
"event $entry->{event_id} already asigned to project $entry->{project_id}, studio $entry->{studio_id}, series $entry->{series_id}\n";
        }

        #get series
        $series = series::get(
            $config,
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
            }
        );
        if ( scalar(@$series) == 1 ) {
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
                        id          => $entry->{event_id},           #TODO: id=> event_id
                        series_name => $series_name,
                        title       => $title,
                        episode     => $event->{episode},
                        rerun       => $event->{rerun},
                        modified_by => $params->{presets}->{user},
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

                #            print STDERR "ok\n";
            }
        } else {
            print STDERR
"no series title found for studio $entry->{studio_id} series $entry->{series_id}, event $entry->{event_id}\n";
            next;
        }

        #assign event
        my $result = series::assign_event(
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
    }

    $config->{access}->{write} = 0;
    uac::print_info("event successfully assigned to series");

    #$params->{getBack}=1;
}

sub check_params {
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
        if ( $params->{action} =~ /^(assign_events)$/ ) {
            $checked->{action} = $params->{action};
        }
    }

    #numeric values
    $checked->{exclude} = 0;
    for my $param ( 'id', 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }

    for my $param ('event_ids') {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^[\d,]+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check( $config, $params->{template}, 'assignments' );

    if ( ( defined $checked->{action} ) && ( $checked->{action} eq 'save_schedule' ) ) {

        #set defaults
        $checked->{create_events}  = 0;
        $checked->{publish_events} = 0;
    }
    for my $param ( 'frequency', 'duration', 'default_duration', 'create_events', 'publish_events', 'live',
        'count_episodes' )
    {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /(\d+)/ ) ) {
            $checked->{$param} = $1;
        }
    }

    #scalars
    for my $param ( 'search', 'from', 'till' ) {
        if ( defined $params->{$param} ) {
            $checked->{$param} = $params->{$param};
            $checked->{$param} =~ s/^\s+//g;
            $checked->{$param} =~ s/\s+$//g;
        }
    }

    return $checked;
}

__DATA__

SELECT ps.project_id, ps.studio_id, ps.series_id,p.name,s.name,se.series_name,se.title
FROM calcms_project_series ps ,calcms_projects p,calcms_studios s,calcms_series se
where ps.project_id=p.project_id and ps.studio_id=s.id and ps.series_id=se.id
order by se.series_name,p.name,s.name

