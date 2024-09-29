package series_events;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc;

use markup();
use db();
use log();
use time();
use uac();
use events();
use series();
use series_dates();
use studios();
use studio_timeslot_dates();
use event_history();
use images();

# check permissions, insert and update events related to series

sub get_content_columns($) {
    my ($config) = @_;
    return (
    'series_name',  'title',              'excerpt',            'content',
    'html_content', 'user_title',         'user_excerpt',       'topic',
    'html_topic',   'episode',            'image',              'image_label',
    'series_image', 'series_image_label', 'podcast_url',        'archive_url',
    'live',         'published',          'playout',            'archived',
    'rerun',        'draft',              'disable_event_sync', 'modified_by',
    'content_format'
    );
}

# update main fields of the event by id
# do not check for project,studio,series
# all changed columns are returned for history handling
sub save_content($$) {
    my ($config, $entry) = @_;
    for ('id') {
        return undef unless defined $entry->{$_}
    };

    for my $attr (keys %$entry) {
        next unless defined $entry->{$attr};
        $entry->{$attr} =~ s/^\s+//g;
        $entry->{$attr} =~ s/\s+$//g;
    }

    for my $attr ('image', 'series_image') {
        $entry->{$attr} = images::normalizeName($entry->{$attr}) if defined $entry->{$attr};
    }

    for my $attr ('content', 'topic') {
        next unless defined $entry->{$attr};
        if (($entry->{content_format}//'') eq 'markdown'){
            $entry->{ 'html_' . $attr } = markup::markdown_to_html($entry->{$attr});
        }else{
            $entry->{ 'html_' . $attr } = markup::creole_to_html($entry->{$attr});
        }
    }

    $entry->{modified_at} = time::time_to_datetime(time());
    #update only existing atributes

    #TODO: double check series_name (needed for reassignment but not for editing...)
    my @keys = ();
    for my $key (get_content_columns($config)) {
        push @keys, $key if defined $entry->{$key};
    }
    $entry->{rerun}     = 0 unless $entry->{rerun};
    $entry->{episode}   = undef if (defined $entry->{episode}) && ($entry->{episode} eq '0');
    $entry->{published} = 0     if (defined $entry->{draft})   && ($entry->{draft} eq '1');

    my $values = join(",", map { $_ . '=?' } (@keys));
    my @bind_values = map { $entry->{$_} } (@keys);

    push @bind_values, $entry->{id};
    my $query = qq{
        update calcms_events
        set    $values
        where  id=?
    };

    my $dbh = db::connect($config);
    my $result = db::put($dbh, $query, \@bind_values);
    unless (defined $result) {
        print STDERR "error on updating event\n";
        return undef;
    }

    return $entry;
}

sub set_episode{
    my ($config, $entry) = @_;

    for ('id', 'episode') {
        return undef unless defined $entry->{$_}
    };

    my $query = qq{
        update calcms_events
        set    episode=?
        where  id=?
    };
    my $bind_values= [ $entry->{episode}, $entry->{id} ];
    my $dbh = db::connect($config);
    my $result = db::put($dbh, $query, $bind_values);
    unless (defined $result) {
        print STDERR "error on setting episode in event\n";
        return undef;
    }
    return $entry;
}

# save event time by id
# do not check project, studio, series
# for history handling all changed columns are returned
sub save_event_time($$) {
    my ($config, $entry) = @_;

    for ('id', 'duration', 'start_date') {
        return undef unless defined $entry->{$_}
    };

    my $dbh   = db::connect($config);
    my $event = {
        id    => $entry->{id},
        start => $entry->{start_date},
        end   => time::add_minutes_to_datetime($entry->{start_date}, $entry->{duration})
    };

    my $day_start = $config->{date}->{day_starting_hour};
    my $event_hour = int((split(/[\-\:\sT]/, $event->{start}))[3]);

    my @update_columns = ();
    my $bind_values    = [];
    push @update_columns, 'start=?';
    push @$bind_values,   $event->{start};

    push @update_columns, 'end=?';
    push @$bind_values,   $event->{end};

    # add start date
    my $start_date = time::add_hours_to_datetime($event->{start}, -$day_start);
    push @update_columns, 'start_date=?';
    push @$bind_values,   $start_date;
    $event->{start_date} = $start_date;

    # add end date
    my $end_date = time::add_hours_to_datetime($event->{end}, -$day_start);
    push @update_columns, 'end_date=?';
    push @$bind_values,   $end_date;
    $event->{end_date} = $end_date;

    my $update_columns = join(",\n", @update_columns);
    my $update_sql = qq{
        update calcms_events
        set     $update_columns
        where    id=?
    };
    push @$bind_values, $event->{id};
    db::put($dbh, $update_sql, $bind_values);
    return $event;
}

sub set_playout_status ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'start', 'playout') {
        return undef unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);
    # check if event is assigned to project and studio
    my $sql = qq{
        select  se.event_id event_id
        from calcms_series_events se, calcms_events e
        where
            se.event_id=e.id
        and e.start=?
        and se.project_id=?
        and se.studio_id=?
    };
    my $bind_values = [ $entry->{start}, $entry->{project_id}, $entry->{studio_id} ];

    my $events = db::get($dbh, $sql, $bind_values);
    return undef if scalar(@$events) != 1;
    my $event_id = $events->[0]->{event_id};
    $sql = qq{
        update  calcms_events
        set     playout=?
        where    id=?
        and     start=?
    };
    $bind_values = [ $entry->{playout}, $event_id, $entry->{start} ];
    my $result = db::put($dbh, $sql, $bind_values);
    return $result;
}

# is event assigned to project, studio and series?
sub is_event_assigned($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id', 'event_id') {
        return 0 unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);
    my $sql = q{
        select * from calcms_series_events
        where project_id=? and studio_id=? and series_id=? and event_id=?
    };
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{event_id} ];
    my $results = db::get($dbh, $sql, $bind_values);

    return 1 if scalar @$results >= 1;
    return 0;
}

sub delete_event ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id', 'event_id', 'user') {
        return undef unless defined $entry->{$_}
    };

    #is event assigned to project, studio and series?
    unless (is_event_assigned($config, $entry) == 1) {
        print STDERR
"cannot delete event with project_id=$entry->{project_id}, studio_id=$entry->{studio_id}, series_id=$entry->{series_id}, event_id=$entry->{event_id}";
        return 0;
    }

    event_history::insert_by_event_id($config, $entry);

    #delete the association
    series::unassign_event($config, $entry);

    # delete the event
    my $dbh = db::connect($config);
    my $sql = q{
        delete from calcms_events
        where id=?
    };
    my $bind_values = [ $entry->{event_id} ];
    db::put($dbh, $sql, $bind_values);

    return 1;
}

#check permissions
# options:           conditions (studio_id, series_id,...)
# key permission:    permissions to be checked (one of)
# key check_for:     user, studio, series, events, schedule
# return error text or 1 if okay
sub check_permission($$) {
    my ($request, $options) = @_;

    return "missing permission at check" unless defined $options->{permission};
    return "missing check_for at check"  unless defined $options->{check_for};
    return "missing user at check"       unless defined $request->{user};
    return "missing project_id at check" unless defined $options->{project_id};
    return "missing studio_id at check"  unless defined $options->{studio_id};
    return "missing series_id at check"  unless defined $options->{series_id};

    my $permissions = $request->{permissions};
    my $config      = $request->{config};

    my $studio_check = studios::check($config, $options);
    return $studio_check if ($studio_check ne '1');
    print STDERR "check studio ok\n";

    my $project_check = project::check($config, $options);
    return $project_check if ($project_check ne '1');
    print STDERR "check project ok\n";

    #check if permissions are set (like create_event)
    my $found = 0;
    for my $permission (split /\,/, $options->{permission}) {
        $found = 1 if (defined $permissions->{$permission}) && ($permissions->{$permission}) eq '1';
    }
    return 'missing permission to ' . $options->{permission} if $found == 0;
    delete $options->{permission};

    #convert check list to hash
    my $check = { map { $_ => 1 } @{ $options->{check_for} } };
    delete $options->{check_for};

    # is project assigned to studio
    return "studio is not assigned to project" unless project::is_studio_assigned($config, $options) == 1;

    #get studio names
    my $studios = studios::get(
        $config,
        {
            project_id => $options->{project_id},
            studio_id  => $options->{studio_id}
        }
    );
    return "unknown studio" unless defined $studios;
    return "unknown studio" unless scalar @$studios == 1;
    my $studio = $studios->[0];
    my $studio_name = $studio->{name} || '';

    #get series names
    my $series = series::get(
        $config,
        {
            project_id => $options->{project_id},
            studio_id  => $options->{studio_id},
            series_id  => $options->{series_id}
        }
    );
    my $series_name = $series->[0]->{series_name} || '';
    $series_name .= ' - ' . $series->[0]->{title} if $series->[0]->{series_name} ne '';

    my $draft = 0;
    $draft = 1 if (defined $options->{draft}) && ($options->{draft} == 1);

    #check all items from checklist
    if ((defined $check->{user}) && (uac::is_user_assigned_to_studio($request, $options) == 0)) {
        return "User '$request->{user}' is not assigned to studio $studio_name ($options->{studio_id})";
    }

    if ((defined $check->{studio}) && (project::is_series_assigned($config, $options) == 0)) {
        return
"Series '$series_name' ($options->{series_id}) is not assigned to studio '$studio_name' ($options->{studio_id})";
    }

    # check series and can user update events
    if ((defined $check->{series}) && (series::can_user_update_events($request, $options) == 0)) {
        return "unknown series" unless defined $series;
        return "User $request->{user} cannot update events for series '$series_name' ($options->{series_id})";
    }

    # check series and can user create events
    if ((defined $check->{create_events}) && (series::can_user_create_events($request, $options) == 0)) {
        return "unknown series" unless defined $series;
        return "User $request->{user} cannot create events for series '$series_name' ($options->{series_id})";
    }

    if (($draft == 0)
        && (defined $check->{studio_timeslots})
        && (studio_timeslot_dates::can_studio_edit_events($config, $options) == 0)
    ) {
        return "requested time is not assigned to studio '$studio_name' ($options->{studio_id})";
    }

    #check if event is assigned to user,project,studio,series,location
    if (defined $check->{events}) {
        return "missing event_id" unless defined $options->{event_id};
        my $result = series::is_event_assigned_to_user($request, $options);
        return $result if $result ne '1';
    }

    # prevent editing events that are over for more than 14 days
    if (($draft == 0) && (defined $check->{event_age})) {
        if (
            series::is_event_older_than_days(
                $config,
                {
                    project_id => $options->{project_id},
                    studio_id  => $options->{studio_id},
                    series_id  => $options->{series_id},
                    event_id   => $options->{event_id},
                    max_age    => 14
                }
            ) == 1
        ) {
            return "show is over for more than 2 weeks"
              unless ((defined $permissions->{update_event_after_week})
                && ($permissions->{update_event_after_week} eq '1'));
        }
    }

    #check if schedule event exists for given date
    if (($draft == 0) && (defined $check->{schedule})) {
        return "unknown series" unless defined $series;
        return "missing start_at at check_permission" unless defined $options->{start_date};

        #TODO: check "is_event_scheduled" if start_at could be moved to start_date
        $options->{start_at} = $options->{start_date};
        return "No event scheduled for series '$series_name' ($options->{series_id})"
          if (series_dates::is_event_scheduled($request, $options) == 0);
    }

    return '1';
}

#not handled, yet:
# responsible, status, rating, podcast_url, media_url, visible, recurrence, reference, created_at

#insert event
sub insert_event ($$) {
    my ($config, $options) = @_;

    for ('project_id', 'studio', 'serie', 'event', 'user') {
        return 0 unless defined $options->{$_}
    };

    my $project_id = $options->{project_id};
    my $studio     = $options->{studio};
    my $serie      = $options->{serie};
    my $params     = $options->{event};
    my $user       = $options->{user};

    return 0 unless defined $studio->{location};

    my $projects = project::get($config, { project_id => $project_id });
    if (scalar @$projects == 0) {
        print STDERR "project not found at insert event\n";
        return 0;
    }
    my $projectName = $projects->[0]->{name};
    my $event       = {
        project  => $projectName,
        location => $studio->{location},    # location from studio
    };

    $event = series_events::add_event_dates($config, $event, $params);

    #get event content from series
    for my $attr (
        'program', 'series_name', 'title',       'excerpt', 'content', 'topic',
        'image',   'episode',     'podcast_url', 'archive_url', 'content_format'
    ) {
        $event->{$attr} = $serie->{$attr} if defined $serie->{$attr};
    }
    $event->{series_image}       = $serie->{image}   if defined $serie->{image};
    $event->{series_image_label} = $serie->{licence} if defined $serie->{licence};

    #overwrite series values from parameters
    for my $attr (
        'program', 'series_name', 'title', 'user_title', 'excerpt',     'user_except',
        'content', 'topic',       'image', 'episode',    'podcast_url', 'archive_url',
        'content_format'
    ) {
        $event->{$attr} = $params->{$attr} if defined $params->{$attr};
    }
    if (($event->{'content_format'}//'') eq 'markdown'){
        $event->{'html_content'} = markup::markdown_to_html($event->{'content'}) if defined $event->{'content'};
        $event->{'html_topic'}   = markup::markdown_to_html($event->{'topic'})   if defined $event->{'topic'};
    }else{
        $event->{'html_content'} = markup::creole_to_html($event->{'content'}) if defined $event->{'content'};
        $event->{'html_topic'}   = markup::creole_to_html($event->{'topic'})   if defined $event->{'topic'};
    }

    #add event status
    for my $attr ('live', 'published', 'playout', 'archived', 'rerun', 'draft', 'disable_event_sync') {
        $event->{$attr} = $params->{$attr} || 0;
    }

    if ($serie->{has_single_events} eq '1') {
        delete $event->{series_name};
        delete $event->{episode};
    }

    $event->{modified_at} = time::time_to_datetime(time());
    $event->{created_at}  = time::time_to_datetime(time());
    $event->{modified_by} = $user;

    my $dbh = db::connect($config);
    my $event_id = db::insert($dbh, 'calcms_events', $event);

    #add to history
    $event->{project_id} = $project_id;
    $event->{studio_id}  = $studio->{id};
    $event->{series_id}  = $serie->{series_id};
    $event->{event_id}   = $event_id;
    event_history::insert($config, $event);
    return $event_id;
}

#set start, end, start-date, end_date to an event
sub add_event_dates($$$) {
    my ($config, $event, $params) = @_;

    #start and end datetime
    $event->{start} = $params->{start_date};
    $event->{end} = time::add_minutes_to_datetime($params->{start_date}, $params->{duration});

    #set program days
    my $day_start = $config->{date}->{day_starting_hour};
    $event->{start_date} = time::date_cond(time::add_hours_to_datetime($event->{start}, -$day_start));
    $event->{end_date}   = time::date_cond(time::add_hours_to_datetime($event->{end},   -$day_start));
    return $event;
}

sub update_series_images ($$) {
    my ($config, $options) = @_;

    return "missing project_id"   unless defined $options->{project_id};
    return "missing studio_id"    unless defined $options->{studio_id};
    return "missing series_id"    unless defined $options->{series_id};
    return "missing series_image" unless defined $options->{series_image};

    #print "save $options->{series_image}\n";

    my $events = series::get_events(
        $config, uac::set($options, qw(project_id studio_id series_id))
   );

    for my $event (@$events) {
        $event->{series_image} = $options->{series_image};
        series_events::save_content($config, $event);
    }
}

sub error ($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
