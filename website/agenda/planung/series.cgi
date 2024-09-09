#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Encode();
use Scalar::Util qw( blessed );
use Try::Tiny qw(try catch finally);

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

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    my $out = $session->{header} // '';
    $config->{access}->{write} = 0;

    #process header
    if ($params->{action} =~ m/^(show_series|list_series)$/ && !params::is_json()) {
        my $headerParams
            = uac::set_template_permissions($request->{permissions}, $params);
        $headerParams->{loc} = localization::get($config,
            {user => $session->{user}, file => 'menu'}
        );
        $out .= template::process($config,
            template::check($config, 'series-header.html'), $headerParams
        );

        my $header_template = {
            'show_series' => 'show-series-header.html',
            'list_series' => 'list-series-header.html',
        }->{$params->{action}};
        $out .= template::process($config, template::check($config, $header_template), {})
            if defined $header_template;
    }
    uac::check($config, $params, $user_presets);

    my %actions = (
        show_series => \&show_series,
        list_series => \&list_series,
        save_schedule => \&save_schedule,
        delete_schedule => \&delete_schedule,
        add_user => \&add_user,
        remove_user => \&remove_user,
        save_series => \&save_series,
        create_series => \&save_series,
        delete_series => \&delete_series,
        assign_event => \&assign_event,
        unassign_event => \&unassign_event,
        reassign_event => \&reassign_event,
        rebuild_episodes => \&rebuild_episodes,
        set_rebuilt_episodes => \&set_rebuilt_episodes,
    );

    my $action = $actions{$params->{action}};
    return $out . $action->($config, $request) if defined $action;
    ActionError->throw(error => "invalid action <$params->{action}>");
}

#insert or update a schedule and update all schedule dates
sub save_schedule {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'Missing permission to update_schedule')
        unless $permissions->{update_schedule} == 1;

    ParamError->throw(error => "missing $_") for
        uac::missing($params, 'project_id', 'studio_id', 'series_id', 'start');

    my $entry = {map {$_ => $params->{$_}} grep {defined $params->{$_}} (
        'project_id', 'studio_id', 'series_id',     'start',
        'duration',   'exclude',   'period_type',   'end',
        'frequency',  'weekday',   'week_of_month', 'month',
        'nextDay'
    )};

    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $entry) == 1;

    ParamError->throw(error => 'no period type selected!')
        unless $entry->{period_type} =~ m/^(single|days|week_of_month)$/;

    $entry->{nextDay} = 0 unless defined $entry->{nextDay};
    $entry->{exclude} = 0 if $entry->{exclude} ne '1';
    $entry->{nextDay} = 0 if $entry->{nextDay} ne '1';

    DateTimeError->throw(error => 'start date should be before end date!')
        if ($entry->{end} ne '') && ($entry->{end} le $entry->{start});

    #TODO: check if schedule is in studio_timeslots

    #on adding a single exclude schedule, remove any existing single schedules with same date
    if (($entry->{period_type} eq 'single') && ($entry->{exclude} eq '1')) {
        PermissionError->throw(error => 'Missing permission to delete_schedule')
            unless $permissions->{delete_schedule} == 1;

        #get single schedules
        my $schedules = series_schedule::get($config, {
            uac::set($entry, 'project_id', 'studio_id', 'series_id', 'start'),
                period_type => 'single',
                exclude     => 0
        });
        if (scalar(@$schedules) > 0) {
            $config->{access}->{write} = 1;
            for my $schedule (@$schedules) {
                series_schedule::delete($config, $schedule);
            }
            my $updates = series_dates::update($config, $entry);
            return uac::json({ "entry" => {
                uac::set($params, 'project_id', 'studio_id', 'series_id'),
                    },
                    "status" => "schedule deleted"
                }
            );
        }
    }

    $config->{access}->{write} = 1;
    if (defined $params->{schedule_id}) {
        $entry->{schedule_id} = $params->{schedule_id};
        series_schedule::update($config, $entry);

        #timeslots are checked inside
        my $updates = series_dates::update($config, $entry);

        return uac::json(
            {   "entry" => {
                    uac::set(
                        $params, 'project_id', 'studio_id', 'series_id'
                    ),
                },
                "status" => "schedule saved"
            }
        );
    } else {
        series_schedule::insert($config, $entry);

        #timeslots are checked inside
        my $updates = series_dates::update($config, $entry);

        return uac::json(
            {   "entry" => {
                    uac::set(
                        $params, 'project_id', 'studio_id', 'series_id'
                    ),
                },
                "status" => "schedule added"
            }
        );
    }
}

sub delete_schedule {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'Missing permission to delete_schedule')
        unless $permissions->{delete_schedule} == 1;

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'series_id', 'schedule_id') {
        ParamError->throw(error => "missing $attr")
            unless defined $params->{$attr};
        $entry->{$attr} = $params->{$attr};
    }

    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $entry) == 1;

    $config->{access}->{write} = 1;
    $entry->{schedule_id} = $params->{schedule_id};
    series_schedule::delete($config, $entry);
    series_dates::update($config, $entry);

    return uac::json(
        {   "entry" =>
                { uac::set($params, 'project_id', 'studio_id', 'series_id'), },
            "status" => "schedule deleted"
        }
    );
}

#todo: check if assigned to studio
sub delete_series {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'missing permission to delete_series')
        unless $permissions->{delete_series} == 1;

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $attr to delete series")
            unless defined $params->{$attr};
        $entry->{$attr} = $params->{$attr};
    }

    ParamError->throw(error => "series is not assigned to project")
        unless project::is_series_assigned($config, $entry) == 1;

    $config->{access}->{write} = 1;
    if ($entry->{series_id} ne '') {
        series::delete($config, $entry);
        user_stats::increase(
            $config,
            'delete_series',
            {   uac::set($entry, 'project_id', 'studio_id', 'series_id'),
                user => $params->{presets}->{user}
            }
        );
    }

    return uac::json(
        {   "entry" =>
                { uac::set($params, 'project_id', 'studio_id', 'series_id') },
            "status" => "series deleted"
        }
    );
}

sub save_series {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    my $columns     = series::get_columns($config);

    ParamError->throw(error => "save_series: missing $_")
        for uac::missing($params, 'project_id', 'studio_id');

    # fill series entry
    my $entry = {map {$_ => $params->{$_}||''} grep {exists $columns->{$_}} keys %$params };
    $entry->{$_} = $params->{$_} || '' for qw(project_id studio_id series_id);
    $entry->{$_} = $params->{$_} // 0 for qw(live count_episodes predecessor_id);

    Error->throw(error => sprintf(
        "save:Predecessor %s must be different from series id %s.",
        $entry->{predecessor_id}, $entry->{series_id}
    )) if $entry->{predecessor_id} eq $entry->{series_id};

    if ($entry->{content_format} // '' eq "markdown") {
        $entry->{html_content} = markup::markdown_to_html($entry->{content});
    } else {
        $entry->{html_content} = markup::creole_to_html($entry->{content});
        $entry->{html_content} =~ s/([^\>])\n+([^\<])/$1<br\/><br\/>$2/g;
    }

    $entry->{modified_at} = time::time_to_datetime(time());
    $entry->{modified_by} = $request->{user};

    ParamError->throw(error => "please set at least series name!")
        if ($params->{title} eq '') && ($params->{series_name} eq '');

    # make sure name is not used anywhere else
    my $series_ids = series::get($config, {
        uac::set($entry, 'project_id', 'studio_id', 'series_name', 'title'),
    });
    #print STDERR Dumper($series_ids);

    if ($params->{action} eq 'create_series') {
        PermissionError->throw(error => 'missing permission to create_series')
            unless $permissions->{create_series} == 1;
        AssignError->throw(error => 'series is already assigned to project!')
            if project::is_series_assigned($config, $entry) == 1;
        InsertError->throw(error => 'insert, entry already exists')
            if scalar(@$series_ids) > 0;

        $config->{access}->{write} = 1;
        my $series_id = series::insert($config, $entry);
        InsertError->throw(error => 'could not insert series') unless defined $series_id;

        user_stats::increase($config, 'create_series', {
            uac::set($entry, 'project_id', 'studio_id', 'series_id'),
            user => $params->{presets}->{user}
        });
        return uac::json({
            "entry" => {uac::set($entry, 'project_id', 'studio_id', 'series_id')},
            "status" => "series created"
        });
    } elsif ($params->{action} eq 'save_series') {

        PermissionError->throw(error => 'missing permission to update_series')
            unless $permissions->{update_series} == 1;
        ParamError->throw(error => 'update. missing parameter series_id')
            unless (defined $params->{series_id})
            && ($params->{series_id} ne '');
        AssignError->throw(error => 'series is not assigned to project!')
            unless project::is_series_assigned($config, $entry) == 1;

        UpdateError->throw(error =>
            q{update due to series already exists multiple times with name "$entry->{series_name}" and title "$entry->{title}"}
        ) if scalar(@$series_ids) > 1;
        PermissionError->throw(error =>
            'update due to series id does not match to existing entry'
        ) if (scalar(@$series_ids) == 1)
            && ($series_ids->[0]->{series_id} ne $params->{series_id});

        $config->{access}->{write} = 1;
        series::update($config, $entry);

        series_events::update_series_images($config,{
            uac::set($entry, 'project_id', 'studio_id', 'series_id'),
            series_image => $params->{image}
        });

        user_stats::increase($config, 'update_series', {
            uac::set($entry, 'project_id', 'studio_id', 'series_id'),
            user => $params->{presets}->{user}
        });

        return uac::json({
            "entry" => { uac::set($entry, 'project_id', 'studio_id', 'series_id'), },
            "status" => "series saved"
        });
    }
    ActionError->throw(error => "Invalid save action");
}

sub assign_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => "missing permission to assign_series_events")
        unless $permissions->{assign_series_events} == 1;

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "missing $attr at assign_event")
            unless defined $params->{$attr};
        $entry->{$attr} = $params->{$attr};
    }

    # check if event exists,
    # this has to use events::get, since it cannot check for series_id
    # TODO: check location of studio_id
    my $request2 = {
        params => {
            checked => events::check_params(
                $config,
                {   event_id => $entry->{event_id},
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

    my $events = events::get($config, $request2);
    EventExistError->throw(error =>
            "no event found for event_id=$entry->{event_id}, archive=all")
        if scalar(@$events) != 1;

    my $event = $events->[0];

    #is series assigned to studio
    series_events::check_permission(
        $request,
        {   permission => 'assign_series_events',
            check_for  => [ 'studio', 'user', 'series', 'studio_timeslots' ],
            uac::set(
                $entry, 'project_id', 'studio_id', 'series_id',
                'event_id'
            ),
            start => $event->{start_datetime},
            end   => $event->{end_datetime}
        }
    );

    $config->{access}->{write} = 1;
    series::assign_event(
        $config,
        {   uac::set(
                $entry, 'project_id', 'studio_id', 'series_id',
                'event_id'
            ),
            manual => 1
        }
    );

    my $series = series::get($config,
        { uac::set($entry, 'project_id', 'studio_id', 'series_id'), });

    SeriesError->throw(
        error => sprintf(
            "no series title found for studio %s, series %s, event %s",
            $entry->{studio_id}, $entry->{series_id}, $entry->{event_id}
        )
    ) if @$series != 1;

    my $serie = $series->[0];

    #set event's series name to value from series
    my $series_name = $serie->{series_name} || '';
    if ($series_name ne '') {

     # prepend series_name from event to title on adding to single_events series
        my $title = $event->{title};
        if ($serie->{has_single_events} eq '1') {
            $title = $event->{series_name} . ' - ' . $title
                if $event->{series_name} ne '';
        }

        # save event content
        series_events::save_content(
            $config,
            {   studio_id   => $entry->{studio_id},
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
        event_history::insert($config, $event);
    }
    return uac::json(
        {   "entry" =>
                { uac::set($entry, 'project_id', 'studio_id', 'series_id'), },
            "status" => "event assigned"
        }
    );
}

sub unassign_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    AssignError->throw(error => "missing permission to unassign event")
        unless $permissions->{assign_series_events} == 1;

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "unassign_event: $attr not given at")
            unless defined $params->{$attr};
        $entry->{$attr} = $params->{$attr};
    }

    #check if event exists
    my $event = series::get_event(
        $config,
        {   uac::set(
                $entry, 'project_id', 'studio_id', 'series_id',
                'event_id'
            ),
        }
    );
    ExistError->throw(
        error => sprintf(
            "event %s not found for project_id=%s, studio_id=%s, series_id=%s",
            $entry->{event_id},  $entry->{project_id},
            $entry->{studio_id}, $entry->{series_id}
        )
    ) unless defined $event;

    #is series assigned to studio
    series_events::check_permission(
        $request,
        {   permission => 'assign_series_events',
            check_for  => [ 'studio', 'user', 'series', 'studio_timeslots' ],
            uac::set(
                $entry, 'project_id', 'studio_id', 'series_id',
                'event_id'
            ),
            start => $event->{start_datetime},
            end   => $event->{end_datetime}
        }
    );

    $config->{access}->{write} = 1;
    series::unassign_event(
        $config,
        {   uac::set(
                $entry, 'project_id', 'studio_id', 'series_id',
                'event_id'
            ),
        }
    );

    return uac::json(
        {   "entry" => {
                uac::set(
                    $entry, 'project_id', 'studio_id', 'series_id',
                    'event_id'
                ),
            },
            "status" => "event unassigned"
        }
    );

}

# assign event to new series id and remove from old series id
sub reassign_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(
        error => "missing permission to assign series events"
    ) unless $permissions->{assign_series_events} == 1;

    for my $attr ('project_id', 'studio_id', 'series_id', 'new_series_id', 'event_id') {
        ParamError->throw(error => "missing $attr at reassign_event") unless defined $params->{$attr};
    }

    $request->{params}->{checked}->{series_id} = $params->{new_series_id};
    assign_event($config, $request);

    $request->{params}->{checked}->{series_id} = $params->{series_id};
    unassign_event($config, $request);

    return uac::json({
        "entry" => {uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id')},
        "status" => "event reassigned"
    });
}

sub add_user {
    my ($config, $request) = @_;
    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    print STDERR Dumper($params);
    PermissionError->throw(
        error => "missing permission to assign_series_member")
        unless $permissions->{assign_series_member} == 1;

    for my $param ('project_id', 'studio_id', 'series_id', 'user_id') {
        ParamError->throw(error => "maissing $param") if $params->{$param} eq '';
    }

    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $params) == 1;

    $config->{access}->{write} = 1;
    series::add_user(
        $config,
        {   uac::set(
                $params, 'project_id', 'studio_id', 'series_id',
                'user_id'
            ),
            user => $request->{user}
        }
    );
    return uac::json(
        {   "entry" => {
                uac::set(
                    $params, 'project_id', 'studio_id', 'series_id',
                    'user_id'
                ),
                user => $request->{user}
            },
            "status" => "added"
        }
    );
}

sub remove_user {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(
        error => 'Missing permission to remove_series_member')
        unless $permissions->{remove_series_member} == 1;

    for my $param ('project_id', 'studio_id', 'series_id', 'user_id') {
        ParamError->throw(error => "missing $param") if $params->{$param} eq '';
    }

    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $params) == 1;

    $config->{access}->{write} = 1;
    series::remove_user(
        $config,
        {   uac::set(
                $params, 'project_id', 'studio_id', 'series_id',
                'user_id'
            ),
        }
    );
    return uac::json(
        {   "entry" => {
                uac::set(
                    $params, 'project_id', 'studio_id', 'series_id',
                    'user_id'
                ),
            },
            "status" => "user removed"
        }
    );
}

sub list_series {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'Missing permission to read_series')
        unless $permissions->{read_series} == 1;
    my $studios = studios::get($config,
        { uac::set($params, 'project_id', 'studio_id'), });

    my $studio_by_id = {};
    for my $studio (@$studios) {
        $studio_by_id->{ $studio->{id} } = $studio;
    }
    my $studio = $studio_by_id->{ $params->{studio_id} };

    my $series_conditions = { uac::set($params, 'project_id', 'studio_id'), };
    my $series            = series::get_event_age($config, $series_conditions);
    for my $serie (sort {lc $a->{series_name} cmp lc $b->{series_name}}
        (@$series))
    {
        if ($serie->{days_over} > 30) {
            $serie->{is_old} = 1;
        } else {
            $serie->{is_new} = 1;
        }
    }
    my @series = sort {lc $a->{series_name} cmp lc $b->{series_name}} @$series;
    $params->{series} = \@series;

    $params->{image} = studios::getImageById(
        $config,
        {   project_id => $params->{project_id},
            studio_id  => $params->{studio_id}
        }
    ) if (!defined $params->{image}) || ($params->{image} eq '');
    $params->{image}
        = project::getImageById($config,
            { project_id => $params->{project_id} })
        if (!defined $params->{image}) || ($params->{image} eq '');

    $params->{loc} = localization::get($config,
        { user => $params->{presets}->{user}, file => 'all,series' });
    return template::process($config, $params->{template}, $params);
}

sub show_series {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'Missing permission to read_series')
        unless $permissions->{read_series} == 1;

    for my $param ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $param")
            unless defined $params->{$param};
    }
    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $params) == 1;

    #this will be updated later (especially allow_update_events)
    for my $permission (keys %{ $request->{permissions} }) {
        $params->{'allow'}->{$permission}
            = $request->{permissions}->{$permission};
    }

    #list of all studios by id
    my $studios = studios::get($config,
        { uac::set($params, 'project_id', 'studio_id'), });
    my $studio_by_id = {};
    for my $studio (@$studios) {
        $studio_by_id->{ $studio->{id} } = $studio;
    }

    #get series
    my $series_conditions = {
        uac::set($params, 'project_id', 'studio_id', 'series_id'),

    };

    my $series = series::get($config, $series_conditions);

    ExistError->throw(error => "too much series found for studio '"
            . $studio_by_id->{ $params->{studio_id} }->{name} . "'")
        if @$series > 1;

    AssignError->throw(error => "selected series not assigned to studio '"
            . $studio_by_id->{ $params->{studio_id} }->{name} . "'")
        if @$series == 0;
    my $serie = $series->[0];

    AssignError->throw(
        error => sprintf(
            qq{show: Predecessor %s must be different from series id %s.},
            $serie->{predecessor_id},
            $serie->{series_id}
        )
    ) if ($serie->{predecessor_id} // '') eq $serie->{series_id};

    #get all users currently assigned to the user
    my $user_studios = uac::get_studios_by_user($config,
        { project_id => $params->{project_id}, user => $request->{user} });

    my $studio_users = uac::get_users_by_studio(
        $config,
        {   project_id => $params->{project_id},
            studio_id  => $params->{studio_id}
        }
    );
    for my $studio_user (@$studio_users) {
        $studio_user->{user_id} = $studio_user->{id};
    }
    my @users = @$studio_users;
    @users        = sort {lc $a->{full_name} cmp lc $b->{full_name}} @users;
    $studio_users = \@users;

    #show events from last month until next 3 months
    my $from = DateTime->now(time_zone => $config->{date}->{time_zone})
        ->subtract(months => 1)->datetime();
    my $till = DateTime->now(time_zone => $config->{date}->{time_zone})
        ->add(months => 3)->datetime();

    #add name of current studio
    my $studio = $studio_by_id->{ $serie->{studio_id} };
    $serie->{studio} = $studio->{name};
    my $location = $studio->{location};

    # set default image from studio
    $serie->{image} = studios::getImageById(
        $config,
        {   project_id => $params->{project_id},
            studio_id  => $params->{studio_id}
        }
    ) if (!defined $serie->{image}) || ($serie->{image} eq '');
    $serie->{image}
        = project::getImageById($config,
            { project_id => $params->{project_id} })
        if (!defined $serie->{image}) || ($serie->{image} eq '');

    #add users
    $serie->{series_users} = series::get_users($config,
        { uac::set($serie, 'project_id', 'studio_id', 'series_id'), });
    $serie->{show_hint_to_add_users} = 1 if @{ $serie->{series_users} } == 0;

    #add events
    $serie->{events} = series::get_events(
        $config,
        {   uac::set($serie, 'project_id', 'studio_id', 'series_id'),
            from_date => $from,
            till_date => $till,
            location  => $location,
            limit     => 30,
            archive   => 'all',
            published => 'all'
        }
    );
    @{ $serie->{events} } = reverse @{ $serie->{events} };

    $params->{allow}->{update_event} = 1;
    try {
        series_events::check_permission(
            $request,
            {   permission =>
                    'update_event_of_series,update_event_of_others',
                check_for => [ 'studio', 'user', 'series' ],
                uac::set($serie, 'project_id', 'studio_id', 'series_id'),
            },
        );
    } catch {
        $params->{allow}->{update_event} = 0;
    };

    $serie->{studio_users} = $studio_users;

    if (($serie->{markup_format} // '') eq 'markdown') {
        $serie->{html_content} = markup::markdown_to_html($serie->{content});
    } else {
        $serie->{html_content} = markup::creole_to_html($serie->{content});
        $serie->{html_content} =~ s/([^\>])\n+([^\<])/$1<br\/><br\/>$2/g;
    }

    for my $user (@{ $serie->{series_users} }) {
        $user->{user_id} = $user->{id};
    }

    #add schedules
    my $schedules = series_schedule::get($config,
        { uac::set($serie, 'project_id', 'studio_id', 'series_id'), });

    #remove seconds from dates
    for my $schedule (@$schedules) {
        $schedule->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/
            if defined $schedule->{start};
        $schedule->{end} =~ s/(\d\d\:\d\d)\:\d\d/$1/
            if defined $schedule->{end};

        #detect schedule type
        if ($schedule->{period_type} eq '') {
            $schedule->{period_type} = 'week_of_month';
            $schedule->{period_type} = 'days'
                unless ($schedule->{week_of_month} =~ /\d/);
            $schedule->{period_type} = 'single'
                unless ($schedule->{end} =~ /\d/);
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
    $serie->{end}   =~ s/(\d\d\:\d\d)\:\d\d/$1/ if defined $serie->{end};

    #add series dates
    my $series_dates = series_dates::get($config,
        { uac::set($serie, 'project_id', 'studio_id', 'series_id'), });

    #remove seconds from dates
    for my $date (@$series_dates) {
        $date->{start} =~ s/(\d\d\:\d\d)\:\d\d/$1/;
        $date->{end}   =~ s/(\d\d\:\d\d)\:\d\d/$1/;
    }
    $serie->{series_dates} = $series_dates;

    $serie->{show_hint_to_add_schedule} = $params->{show_hint_to_add_schedule};

    if (    (defined $params->{setImage})
        and ($params->{setImage} ne $serie->{image}))
    {
        $serie->{image}          = $params->{setImage};
        $params->{forced_change} = 1;
    }

    #copy series to params
    for my $key (keys %$serie) {
        $params->{$key} = $serie->{$key};
    }

    for my $value ('markdown', 'creole') {
        $params->{"content_format_$value"} = 1
            if ($params->{content_format} // '') eq $value;
    }

    $params->{loc} = localization::get($config,
        { user => $params->{presets}->{user}, file => 'all,series' });
    return template::process($config, $params->{template}, $params);
}

sub set_rebuilt_episodes {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'Missing permission to read_series')
        unless $permissions->{read_series} == 1;

    for my $param ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $param")
            unless defined $params->{$param};
    }

    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $params) == 1;

    #this will be updated later (especially allow_update_events)
    for my $permission (keys %{ $request->{permissions} }) {
        $params->{'allow'}->{$permission}
            = $request->{permissions}->{$permission};
    }
    my $events = series::get_rebuilt_episodes($config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id'), });

    my $updates = 0;
    for my $event (@$events) {
        next if $event->{project_id} ne $params->{project_id};
        next if $event->{studio_id} ne $params->{studio_id};
        next if $event->{old_episode} eq $event->{episode};
        series_events::set_episode(
            $config,
            {   id      => $event->{id},
                episode => $event->{episode}
            }
        );
        $updates++;
    }
    return uac::json(
        {   "entry" =>
                { uac::set($params, 'project_id', 'studio_id', 'series_id'), },
            "status" => "episodes rebuilt"
        }
    );
}

#TODO…
sub rebuild_episodes {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error => 'Missing permission to read_series')
        unless $permissions->{read_series} == 1;

    for my $param ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $param")
            unless defined $params->{$param};
    }

    AssignError->throw(error => 'series is not assigned to project!')
        unless project::is_series_assigned($config, $params) == 1;

    #this will be updated later (especially allow_update_events)
    for my $permission (keys %{ $request->{permissions} }) {
        $params->{'allow'}->{$permission}
            = $request->{permissions}->{$permission};
    }
    my $events = series::get_rebuilt_episodes($config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id'), });

    my $events_by_id = {};
    for my $event (@$events) {
        $events_by_id->{ $event->{id} } = $event;
    }

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
        if ($e1 eq $e2) {
            $event->{class} = 'ok';
        } else {
            $changes++;
            $event->{class} = 'warn';
        }
        if ($e1 and $e2 and $o1 and $o2 and (($e2 - $o2) != ($e1 - $o1))) {
            $event->{class} = "error" if $e1 ne $e2;
            $prev->{class}  = "error" if defined $prev and $o1 ne $o2;
            $errors++;
        }
        if ($event->{episode} < $max_episode and !$event->{recurrence}) {
            $event->{class} = "error";
            $errors++;
        }
        $event->{recurrence_start}
            = $events_by_id->{ $event->{recurrence} }->{start};
        $event->{recurrence} = '-' unless $event->{recurrence};
        $prev = $event;
    }
    my @cols = qw(id start series_name title episode old_episode
        recurrence recurrence_start project_name studio_name class);
    my $out = {
        uac::set($params, 'project_id', 'studio_id', 'series_id'),
        result => { changes => $changes, conflicts => $errors },
        cols   => \@cols,
        rows   => []
    };
    for my $event (@$events) {
       push @{ $out->{rows} }, { map {$_ => $event->{$_} // '-'} @cols };
    }
    return uac::json $out;
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};

    $checked->{action} = entry::element_of(
        $params->{action},
        [ qw( show_series list_series
            create_series delete_series save_series
            save_schedule delete_schedule
            add_user remove_user
            assign_event unassign_event reassign_event
            rebuild_episodes set_rebuilt_episodes
        ) ]
    );

    $checked->{exclude} = 0;
    entry::set_numbers(
        $checked, $params,
        [   'id',            'project_id',
            'studio_id',     'default_studio_id',
            'user_id',       'new_series_id',
            'series_id',     'schedule_id',
            'exclude',       'show_hint_to_add_schedule',
            'event_id',      'weekday',
            'week_of_month', 'month',
            'nextDay',       'predecessor_id'
        ]
    );

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    if (defined $checked->{series_id}) {
        $checked->{template}
            = template::check($config, $params->{template}, 'edit-series');
    } else {
        $checked->{template}
            = template::check($config, $params->{template}, 'series');
    }

    #set defaults
    if ((defined $checked->{action}) && ($checked->{action} eq 'save_schedule'))
    {
        $checked->{create_events}  = 0;
        $checked->{publish_events} = 0;
    }

    entry::set_numbers(
        $checked, $params,
        [   'frequency',        'duration',
            'default_duration', 'create_events',
            'publish_events',   'live',
            'count_episodes'
        ]
    );

    #scalars
    entry::set_strings($checked, $params,
        [ 'search', 'from', 'till', 'period_type' ]);

    entry::set_strings(
        $checked, $params,
        [   'series_name',        'title',
            'excerpt',            'content',
            'topic',              'image',
            'image_label',        'assign_event_series_name',
            'assign_event_title', 'comment',
            'podcast_url',        'archive_url',
            'setImage',           'content_format'
        ]
    );

    for my $attr ('start') {
        if (   (defined $params->{$attr})
            && ($params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)/))
        {
            $checked->{$attr} = $1 . ':00';
        }
    }

    for my $attr ('end') {
        if (   (defined $params->{$attr})
            && ($params->{$attr} =~ /(\d\d\d\d\-\d\d\-\d\d)/))
        {
            $checked->{$attr} = $1;
        }
    }
    use Data::Dumper;print STDERR Dumper($checked);
    return $checked;
}
