#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Scalar::Util qw(blessed);
use Try::Tiny;

use params();
use config();
use entry();
use template();
use auth();
use uac();
use time();

use series();
use eventOps();

use series_dates();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    uac::check($config, $params, $user_presets);
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to create_event_from_schedule')
        unless $permissions->{create_event_from_schedule} == 1;

    my %actions = (
        create_events => \&create_events,
        get_events => \&get_events,
        show_events => \&show_events
    );
    my $action = $actions{$params->{action}};
    return $action->($config, $request, $session) if defined $action;
    ActionError->throw(error => "invalid action <$params->{action}>");
}

sub show_events {
    my ($config, $request, $session) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_events')
        unless $permissions->{assign_series_events} == 1;

my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get(
        $config, { user => $session->{user}, file => 'menu' }
    );
    my $header = template::process($config,
        template::check($config, 'create-events-header.html'), $headerParams
    );

    my $events = getDates($config, $request);
    $params->{events} = $events;
    $params->{total}  = scalar(@$events);
    $params->{action} = 'show';
    $params->{loc} = localization::get($config, {
        user => $params->{presets}->{user},
        file => 'create-events'
    });

    return $header . template::process($config, $params->{template}, $params);
}

sub get_events {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_events')
        unless $permissions->{assign_series_events} == 1;
    my ($from_date, $till_date) = getTimeRange($params->{duration});
    return uac::json({
        from => $from_date,
        till => $till_date,
        events => getDates($config, $request)
    });
}

sub getTimeRange{
    my ($duration) = @_;

    my $from_date = time::time_to_datetime();
    if ($from_date =~ /(\d\d\d\d\-\d\d\-\d\d \d\d)/) {
        $from_date = $1 . ':00';
    }
    my $till_date = time::add_days_to_datetime($from_date, $duration);
    if ($from_date =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
        $from_date = $1;
    }
    if ($till_date =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
        $till_date = $1;
    }
    return $from_date, $till_date;

}

sub create_events {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to assign_series_events')
        unless $permissions->{assign_series_events} == 1;

    my $dates = getDates($config, $request);
    my @events = map {createEvent($config, $request, $_);} @$dates;
    return uac::json({created => scalar(@events)});
}

sub getDates {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_event')
        unless $permissions->{read_event} == 1;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $series_id  = $params->{series_id};
    my $from_date  = $params->{from_date};
    my $till_date  = $params->{till_date};
    my $duration   = $params->{duration};

    $from_date = time::time_to_datetime();
    if ($from_date =~ /(\d\d\d\d\-\d\d\-\d\d \d\d)/) {
        $from_date = $1 . ':00';
    }
    $till_date = time::add_days_to_datetime($from_date, $duration);
    if ($from_date =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
        $from_date = $1;
    }
    if ($till_date =~ /(\d\d\d\d\-\d\d\-\d\d)/) {
        $till_date = $1;
    }
    $params->{from_date} = $from_date;
    $params->{till_date} = $till_date;
    print STDERR "$0: get events from $from_date to $till_date\n";

    my $dates = series_dates::getDatesWithoutEvent(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
            $series_id ? (series_id  => $series_id) : (),
            from       => $from_date,
            till       => $till_date,
        }
    );
    my $series = series::get($config, {
            project_id => $project_id,
            studio_id  => $studio_id,
            $series_id ? (series_id => $series_id) : ()
    });
    my %series_by_id = map { $_->{series_id} => $_ } @$series;
    for  my $date (@$dates) {
        my $serie = $series_by_id{$date->{series_id}};
        $date->{series_name} = $serie->{series_name};
        $date->{series_title} = $serie->{series_title};
    }

    return $dates;
}

sub createEvent {
    my ($config, $request, $date) = @_;

    my $permissions = $request->{permissions};
    my $user        = $request->{user};

    $date->{show_new_event_from_schedule} = 1;
    unless ($permissions->{create_event_from_schedule} == 1) {
        PermissionError->throw(error=>'Missing permission to create_event_from_schedule');
        return;
    }

    $date->{start_date} = $date->{start};
    my $event = eventOps::getNewEvent($config, $date, 'show_new_event_from_schedule');

    return undef unless defined $event;

    $event->{start_date} = $event->{start};
    eventOps::createEvent($request, $event, 'create_event_from_schedule');
    return $event;
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};
    $checked->{action} = entry::element_of($params->{action},
        ['get_events', 'create_events', 'show_events'])//'';

    $checked->{exclude}  = 0;
    $checked->{duration} = 28;
    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'series_id', 'duration']);
    $checked->{"duration".$checked->{duration}}='selected="selected"';

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check($config, $params->{template}, 'create-events');

    return $checked;
}
