package eventOps;

use strict;
use warnings;
no warnings 'redefine';

use uac();
use events();
use series();
use series_dates();
use time();
use studios();
use series_events();
use user_stats();

our @EXPORT_OK = qw(
  setAttributesFromSeriesTemplate
  setAttributesFromSchedule
  setAttributesFromOtherEvent
  setAttributesForCurrentTime
  getRecurrenceBaseId
);

# functions: to be separated
sub setAttributesFromSeriesTemplate($$$) {
    my ($config, $params, $event) = @_;

    #get attributes from series
    my $series = series::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
        }
    );
    if (scalar @$series != 1) {
        ExistError->throw(error=>"series not found");
    }

    #copy fields from series template
    my $serie = $series->[0];
    for my $attr (
        'program',  'series_name', 'title', 'excerpt', 'topic',       'content', 'html_content', 'project',
        'location',    'image', 'live',    'archive_url', 'podcast_url', 'content_format'
    )
    {
        $event->{$attr} = $serie->{$attr};
    }
    $event->{series_image}       = $serie->{image};
    $event->{series_image_label} = $serie->{licence};
    return $serie;
}

sub setAttributesFromSchedule ($$$){
    my ($config, $params, $event) = @_;

    #set attributes from schedule
    my $schedules = series_dates::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            start_at   => $params->{start_date}
        }
    );

    if (@$schedules != 1) {
        ExistError->throw(error=>"schedule not found");
    }

    my $schedule = $schedules->[0];
    for my $attr ('start', 'end', 'day', 'weekday', 'start_date', 'end_date') {
        $event->{$attr} = $schedule->{$attr};
    }

    my $timezone = $config->{date}->{time_zone};
    $event->{duration} = time::get_duration($event->{start}, $event->{end}, $timezone);

    return $event;
}

sub setAttributesFromOtherEvent ($$$){
    my ($config, $params, $event) = @_;

    my $event2 = series::get_event(
        $config,
        {
            allow_any => 1,

            #project_id => $params->{project_id},
            #studio_id  => $params->{studio_id},
            #series_id  => $params->{series_id},
            event_id => $params->{source_event_id}
        }
    );
    if (defined $event2) {
        for my $attr (
            'title',       'user_title',  'excerpt',      'user_excerpt', 'content',       'html_content',
            'topics',      'image',       'series_image', 'live',         'no_event_sync', 'podcast_url',
            'archive_url', 'image_label', 'series_image_label', 'content_format'
        )
        {
            $event->{$attr} = $event2->{$attr};
        }
        $event->{rerun}      = 1;
        $event->{recurrence} = getRecurrenceBaseId($event2);
    }

    return $event;
}

sub setAttributesForCurrentTime ($$){
    my ($serie, $event) = @_;

    #on new event not from schedule use current time
    if ($event->{start} eq '') {
        $event->{start} = time::time_to_datetime();
        if ($event->{start} =~ /(\d\d\d\d\-\d\d\-\d\d \d\d)/) {
            $event->{start} = $1 . ':00';
        }
    }
    $event->{duration} = $serie->{duration} || 60;
    $event->{end} = time::add_minutes_to_datetime($event->{start}, $event->{duration});
    $event->{end} =~ s/(\d\d:\d\d)\:\d\d/$1/;

    return $event;
}

# get recurrence base id
sub getRecurrenceBaseId ($){
    my ($event) = @_;
    return $event->{recurrence} if (defined $event->{recurrence}) && ($event->{recurrence} ne '') && ($event->{recurrence} ne '0');
    return $event->{event_id};
}

# get a new event for given series
sub getNewEvent($$$) {
    my ($config, $params, $action) = @_;

    # check for missing parameters
    my $required_fields = [ 'project_id', 'studio_id', 'series_id' ];
    push @$required_fields, 'start_date' if ($action eq 'show_new_event_from_schedule');

    my $event = {};
    for my $attr (@$required_fields) {
        ParamError->throw(error => "eventOps: missing " . $attr) unless defined $params->{$attr};
        $event->{$attr} = $params->{$attr};
    }

    my $serie = eventOps::setAttributesFromSeriesTemplate($config, $params, $event);

    if ($action eq 'show_new_event_from_schedule') {
        eventOps::setAttributesFromSchedule($config, $params, $event);
    } else {
        eventOps::setAttributesForCurrentTime($serie, $event);
    }

    if (defined $params->{source_event_id}) {

        #overwrite by existing event (rerun)
        eventOps::setAttributesFromOtherEvent($config, $params, $event);
    }

    $event = events::calc_dates($config, $event);

    if ($serie->{has_single_events} eq '1') {
        $event->{has_single_events} = 1;
        $event->{series_name}       = undef;
        $event->{episode}           = undef;
    }

    #get next episode
    $event->{episode} = series::get_next_episode(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
        }
    );
    delete $event->{episode} if $event->{episode} == 0;

    $event->{disable_event_sync} = 1;
    $event->{published}          = 1;
    $event->{new_event}          = 1;

    return $event;
}

# add user, action
sub createEvent($$$) {
    my ($request, $event, $action) = @_;

    my $config      = $request->{config};
    my $permissions = $request->{permissions};
    my $user        = $request->{user};

    my $checklist = [ 'studio', 'user', 'create_events', 'studio_timeslots' ];
    push @$checklist, 'schedule' if $action eq 'create_event_from_schedule';

    my $start = $event->{start_date}, my $end = time::add_minutes_to_datetime($event->{start_date}, $event->{duration});

    series_events::check_permission(
        $request,
        {
            permission => 'create_event,create_event_of_series',
            check_for  => $checklist,
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
            start_date => $event->{start_date},
            draft      => $event->{draft},
            start      => $start,
            end        => $end,
        }
    );

    #get series name from series
    my $series = series::get(
        $config,
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
        }
    );
    if (scalar @$series != 1) {
        ExistError->throw(error=>"series not found");
    }
    my $serie = $series->[0];

    #get studio location from studios
    my $studios = studios::get(
        $config,
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id}
        }
    );
    StudioError->throw(error => "studios not found $_") unless defined $studios;
    unless (scalar @$studios == 1) {
        ExistError->throw(error=>"studio not found");
    }
    my $studio = $studios->[0];

    local $config->{access}->{write} = 1;

    #insert event content and save history
    my $event_id = series_events::insert_event(
        $config,
        {
            project_id => $event->{project_id},
            studio     => $studio,
            serie      => $serie,
            event      => $event,
            user       => $user
        }
    );

    #assign event to series
    series::assign_event(
        $config,
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
            event_id   => $event_id
        }
    );

    #update recurrences
    $event->{event_id} = $event_id;
    series::update_recurring_events($config, $event);

    # update user stats
    user_stats::increase(
        $config,
        'create_events',
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
            user       => $user
        }
    );

    return $event_id;
}

return 1;
