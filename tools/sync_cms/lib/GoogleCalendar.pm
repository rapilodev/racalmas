package GoogleCalendar;

use strict;
use warnings;

use Data::Dumper;

use lib '../calcms/';
use Common ( 'info', 'error' );
use GoogleCalendarApi();
use time();

my $settings = {};
my $cal      = undef;
my $debug    = 1;

sub set($$) {
    my $key   = shift;
    my $value = shift;
    $settings->{$key} = $value;
}

sub get($) {
    my $key = shift;
    return $settings->{$key};
}

sub init($) {
    $settings = shift || {};

    my $access = get('access');

    # 1. create service account at https://console.developers.google.com/
    # 2. enable Calendar API
    # 3. share calendar with service account for update permissions

    # see http://search.cpan.org/~shigeta/Google-API-Client-0.13/lib/Google/API/Client.pm

    my $serviceAccount        = $access->{serviceAccount};
    my $serviceAccountKeyFile = $access->{serviceAccountKeyFile};
    my $calendarId            = $access->{calendarId};

    my $serviceAccountKey = Common::loadFile($serviceAccountKeyFile);
    my $calendar          = GoogleCalendarApi->new(
        {
            'serviceAccount' => $serviceAccount,
            'privateKey'     => $serviceAccountKey,
            'calendarId'     => $calendarId,
            'debug'          => 0
        }
    );

    $cal = $calendar;
}

#map event schema to target schema
sub mapToSchema {
    my $event = shift;

    #clone event
    my $targetEvent = {};
    for my $key ( keys %{$event} ) {
        $targetEvent->{$key} = $event->{$key};
    }

    if ( defined $event->{recurrence} && ref( $event->{recurrence} ) eq 'HASH' ) {
        $targetEvent->{reference} .= '[' . $event->{recurrence}->{number} . ']' if ( $event->{recurrence}->{number} > 0 );
        $targetEvent->{recurrence} = $event->{recurrence}->{number} + 0;
    }
    $targetEvent->{rating}     = 0;
    $targetEvent->{visibility} = 0;

    #set project by project's date range
    my $projects = get('projects');
    if ( ref($projects) eq 'HASH' ) {
        for my $projectName ( keys %$projects ) {
            my $project = get('projects')->{$projectName};
            my $start = substr( $event->{start}, 0, 10 );
            if ( $start ge $project->{start_date} && $start le $project->{end_date} ) {
                $targetEvent->{project} = $project->{name};
            }
        }
    }

    #override settings by target map filter
    for my $key ( keys %{ get('mapping') } ) {
        $targetEvent->{$key} = get('mapping')->{$key};
    }

    #resolve variables set in mapped values
    for my $mkey ( keys %{ get('mapping') } ) {
        for my $key ( sort keys %{$targetEvent} ) {
            my $val = $targetEvent->{$key};
            $val = $event->{$key} if $mkey eq $key;
            $targetEvent->{$mkey} =~ s/<TMPL_VAR $key>/$val/g;
        }
    }
    $targetEvent->{title} =~ s/\s+$//g;
    $targetEvent->{title} =~ s/\s*\#$//g;
    $targetEvent->{title} =~ s/\s*\-\s*$//g;

    my $schema = { event => $targetEvent };

    return $schema;
}

#this is done before sync and allows to delete old events before adding new
sub getEvents {
    my $event = shift;

    return undef if get('date')->{'time_zone'} eq '';
    return undef if $event->{start} eq '';
    return undef if $event->{end} eq '';

    #delete a span of dates
    my $timeZone = get('date')->{'time_zone'};
    my $start    = time::get_datetime( $event->{start}, $timeZone );
    my $end      = time::get_datetime( $event->{end}, $timeZone );

    info( "search target for events from " . $start . " to " . $end );

    #search datetime with same timezone
    my $events = $cal->getEvents(
        {
            timeMin      => $cal->getDateTime( $start->datetime, $timeZone ),
            timeMax      => $cal->getDateTime( $end->datetime,   $timeZone ),
            maxResults   => 50,
            singleEvents => 'true',
            orderBy      => 'startTime'
        }
    );

    return $events;
}

# insert a new event
sub insertEvent {
    my $event  = shift;
    my $entity = $event->{event};

    $entity->{'html_content'} = markup::creole_to_html( $entity->{'content'} );

    my $timeZone = get('date')->{'time_zone'};

    my $start = $cal->getDateTime( $entity->{start}, $timeZone );
    my $end   = $cal->getDateTime( $entity->{end},   $timeZone );

    #info "insert event\t$start\t$entity->{title}";
    my $entry = {
        start        => $start,
        end          => $end,
        summary      => $entity->{title},
        description  => $entity->{content},
        location     => $entity->{location},
        transparency => 'transparent',
        status       => 'confirmed'
    };

    my $result = $cal->insertEvent($entry);
    my $id     = $result->{id};
}

sub deleteEvent {
    my $event = shift;

    #info "delete event";
    $cal->deleteEvent( $event->{id} );
}

sub fixFields {
    my $event = shift;

    #lower case for upper case titles longer than 4 characters
    for my $attr ( 'series_name', 'title' ) {
        my $val = $event->{$attr};
        my $c   = 0;
        while ( $val =~ /\b([A-Z]{5,99})\b/ && $c < 10 ) {
            my $word  = $1;
            my $lower = lc $word;
            $lower =~ s/^([a-z])/\u$1/gi;
            $val =~ s/$word/$lower/g;
            $c++;
        }
        $event->{$attr} = $val if $event->{$attr} ne $val;
    }

    for my $attr ( 'series_name', 'title', 'excerpt', 'content' ) {
        my $val = $event->{$attr};
        $val =~ s/^\s*(.*?)\s*$/$1/g;
        $val =~ s/^[ \t]/ /g;
        $event->{$attr} = $val if $event->{$attr} ne $val;
    }
    return $event;
}

#do not delete last line
1;
