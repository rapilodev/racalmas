package CalcmsEvents;

use strict;
use warnings;

use Common ('info','error');
use DateTime;
use Data::Dumper;

use creole_wiki;
use events;
use time;
#use config;

my $settings = {};

sub init($) {
    $settings = shift || {};
}

sub set($$) {
    my $key   = shift;
    my $value = shift;
    $settings->{$key} = $value;
}

sub get($) {
    my $key = shift;
    return $settings->{$key};
}

# return a list of start_min, start_max request parameters.
sub splitRequest($$$) {
    my $from     = shift;
    my $till     = shift;
    my $timeZone = shift;

    return undef unless defined $from;
    return undef unless defined $till;
    return undef if $from eq '';
    return undef if $till eq '';

    my $dates = [];

    my $start = time::get_datetime( $from, $timeZone );
    my $end   = time::get_datetime( $till, $timeZone );

    #build a list of dates
    my $date  = $start;
    my @dates = ();
    while ( $date < $end ) {
        push @dates, $date;
        $date = $date->clone->add( days => 7 );
    }
    my $duration = $end - $date;

    push @dates, $end->clone if $duration->delta_seconds <= 0;

    #build a list of parameters from dates
    $start = shift @dates;
    for my $end (@dates) {
        push @$dates,
          {
            from => $start,
            till => $end
          };
        $start = $end;
    }

    return $dates;

}

#get a hash with per-day-lists days of a google calendar, given by its url defined at $calendar_name
sub getEvents($$) {
    my $from = shift;
    my $till = shift;

    my $last_update = get('last_update');
    info "getEvents from $from till $till";

    my $request_parameters = {
        from_date => $from,
        till_date => $till,
        project   => get('project'),
        archive   => 'all',
        template  => 'no'
    };
    my $location = get('location') || '';
    $request_parameters->{location} = $location if $location ne '';

    my $config  = $settings;
    my %params  = ();
    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => \%params,
            checked  => events::check_params( $config, $request_parameters, $settings ),
        },
    };

    my $sourceEvents = events::get( $config, $request, $settings );

    #return events by date
    my $eventsByDate = {};
    for my $source (@$sourceEvents) {
        $source->{calcms_start} = $source->{start};
        my $key = substr( $source->{start}, 0, 10 );
        push @{ $eventsByDate->{$key} }, $source;
    }
    return $eventsByDate;
}

sub mapToSchema {
    my $event = shift;

    #override settings by source map filter
    for my $key ( keys %{ get('mapping') } ) {
        $event->{$key} = get('mapping')->{$key};
    }

    #resolve variables set in mapped values
    for my $mkey ( keys %{ get('mapping') } ) {
        for my $key ( keys %{$event} ) {
            my $val = $event->{$key};
            $val = $event->{$key} if ( $mkey eq $key );
            $event->{$mkey} =~ s/<TMPL_VAR $key>/$val/g;
        }
    }

    return $event;
}

#do not delete last line
1;
