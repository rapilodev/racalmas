#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Encode();
use Scalar::Util qw(blessed);
use Try::Tiny;

use time();
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
use series_schedule();
use series_events();
use series_dates();
use markup();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get($config, { user => $session->{user}, file => 'menu.po' });
    uac::check($config, $params, $user_presets);

    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'scan_series_events') unless $permissions->{scan_series_events} == 1;

    if (defined $params->{action}) {
        return assign_events($config, $request) if ($params->{action} eq 'assign_events');
        return  template::process($config, template::check($config, 'assignments-header.html'), $headerParams)
            . show_events($config, $request) if $params->{action} eq 'get';
    }
    ActionError->throw(error => "invalid action");

}

sub show_events {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{assign_series_events} == 1) {
        PermissionError->throw(error => 'assign_series_events');
    }

    my $projects = project::get($config, { project_id => $params->{project_id} });
    my $project = $projects->[0];

    ExistError->throw(error=>"expect one project") unless scalar @$projects == 1;

    my $studios = studios::get($config, { project_id => $params->{project_id}, studio_id => $params->{studio_id} });
    my $studio = $studios->[0];
    ExistError->throw(error=>"expect one studio") unless scalar @$studios == 1;

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
    my $results = db::get($dbh, $query);

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
    if ($project_name ne '') {
        push @$conditions,  'e.project=?';
        push @$bind_values, $project_name;
    }
    if ($studio_name ne '') {
        push @$conditions,  'e.location=?';
        push @$bind_values, $studio_name;
    }
    $conditions = ' and ' . join(' and ', @$conditions) if scalar(@$conditions) > 0;
    $query = qq{
        select   e.id, program, project, location, start, series_name, title, episode, rerun
        from     calcms_events e left join calcms_series_events se on se.event_id =e.id
        where    se.event_id is null
        $conditions
        order by series_name,title,start
        limit 1000
    };
    $results = db::get($dbh, $query, $bind_values);

    # detect title and episode
    my $weekdayNamesShort = time::getWeekdayNamesShort('de');
    for my $result (@$results) {
        $result->{rerun} .= '';
        if ($result->{title} =~ /\#(\d+)([a-z])?\s*$/) {
            $result->{episode} = $1 unless defined $result->{episode};
            $result->{rerun} = $2 || '' unless ($result->{rerun} =~ /\d/);
            $result->{title} =~ s/\#\d+[a-z]?\s*$//;
            $result->{title} =~ s/\s+$//;
        }
        my $a = time::datetime_to_array($result->{start});

        #print STDERR "($a->[0],$a->[1],$a->[2])\n";
        $result->{weekday} = time::weekday($a->[0], $a->[1], $a->[2]);
        $result->{weekday} = $weekdayNamesShort->[ $result->{weekday} - 1 ];
    }

    #fill template
    $params->{unassigned_events} = $results;
    $params->{sum_events}        = @$results;
    $params->{project_name}      = $project_name;
    $params->{studio_name}       = $studio_name;

    return template::process($config, $params->{template}, $params);
}

sub assign_events {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{assign_series_events} == 1) {
        PermissionError->throw(error => 'assign_series_events');
    }

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'series_id', 'event_ids') {
        if (defined $params->{$attr}) {
            $entry->{$attr} = $params->{$attr};
        } else {
            ParamError->throw(error => $attr . ' not given!');
        }
    }

    local $config->{access}->{write} = 1;
    for my $event_id (split(/[\,\s]+/, $params->{event_ids})) {
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
                        phase    => 'all',
                    }
                )
            },
            config      => $request->{config},
            permissions => $request->{permissions}
        };
        $request2->{params}->{checked}->{published} = 'all';
        my $events = events::get($config, $request2);
        my $event = $events->[0];
        unless (defined $event) {
            print STDERR
"event not found for project $entry->{project_id}, studio $entry->{studio_id}, series $entry->{series_id}, event $entry->{event_id}\n";
            next;
        }

        #check if series is assigned to project/studio
        my $series = series::get(
            $config,
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
            }
        );
        if (scalar(@$series) == 0) {

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
        if (scalar(@$series) == 1) {
            my $serie = $series->[0];

            #set event's series name to value from series
            my $series_name = $serie->{series_name} || '';
            if ($series_name ne '') {

                # prepend series_name from event to title on adding to single_events series
                my $title = $event->{title};
                if ($serie->{has_single_events} eq '1') {
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
                event_history::insert($config, $event);

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
    }

    uac::print_info("event successfully assigned to series");
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};

    $checked->{action} = entry::element_of($params->{action}, ['assign_events']);

    $checked->{exclude} = 0;
    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'series_id', 'event_id'
        ]);

    for my $param ('event_ids') {
        if ((defined $params->{$param}) && ($params->{$param} =~ /^[\d,]+$/)) {
            $checked->{$param} = $params->{$param};
        }
    }

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check($config, $params->{template}, 'assignments');

    if ((defined $checked->{action}) && ($checked->{action} eq 'save_schedule')) {

        #set defaults
        $checked->{create_events}  = 0;
        $checked->{publish_events} = 0;
    }
    entry::set_numbers($checked, $params, [
        'frequency', 'duration', 'default_duration', 'create_events', 'publish_events', 'live']);

    entry::set_strings($checked, $params,
        [ 'search', 'from', 'till' ]);

    return $checked;
}

__DATA__

SELECT ps.project_id, ps.studio_id, ps.series_id,p.name,s.name,se.series_name,se.title
FROM calcms_project_series ps ,calcms_projects p,calcms_studios s,calcms_series se
where ps.project_id=p.project_id and ps.studio_id=s.id and ps.series_id=se.id
order by se.series_name,p.name,s.name

