#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use Config::General;
use DateTime;
use DateTime::Duration;
use IO::Socket::INET;
use Fcntl ':flock';

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../../calcms";

use Common ( 'info', 'error' );
use GoogleCalendar;
use CalcmsEvents;

Common::checkSingleInstance();

BEGIN {
    $ENV{LANG} = "en_US.UTF-8";
}

$| = 1;

my $sourceConfigFile = '';
my $targetConfigFile = '';
my $debug = 1;

my $from = undef;
my $till = undef;
GetOptions(
    "from=s"   => \$from,
    "till=s"   => \$till,
    "source=s" => \$sourceConfigFile,
    "target=s" => \$targetConfigFile,
);

#source and taget settings are loaded from config files
my $settings = {};

error "set one of folling parameters: --from, --till" unless $from || $till;

init();
sync();
info "$0 done.";
exit 0;

#sync all events, splitting multi-day-requests into multiple 1-day-requests to avoid large result sets
sub sync {
    my $timeZone = CalcmsEvents::get('date')->{time_zone};
    my $from     = CalcmsEvents::get('start_min');
    my $till     = CalcmsEvents::get('start_max');

    info "sync from $from till $till at $timeZone";

    #prepare target
    info "last update: " . ( CalcmsEvents::get('last_update') || '' );

    if ( my $days = CalcmsEvents::splitRequest( $from, $till, $timeZone ) ) {
        for my $date (@$days) {
            syncTimespan( $date->{from}, $date->{till} );
        }
    } else {
        syncTimespan( $from, $till );
    }

    info "\nset last-update time: $settings->{event}->{update_start}";
    setLastUpdateTime( $sourceConfigFile, $targetConfigFile, $settings->{event}->{update_start} );
}

#sync all events of a given source timespan
sub syncTimespan {
    my $from = shift;
    my $till = shift;

    #get a list of all days and their events
    my $sourceEvents = CalcmsEvents::getEvents( $from, $till );

    my @dates = keys %$sourceEvents;
    if ( scalar @dates == 0 ) {
        info "\nno entries found.";
        return;
    }

    #sort lists of date and time (same time events should be preserved)
    for my $date ( sort { $a cmp $b } @dates ) {
        syncEvents( $sourceEvents->{$date} );
    }

}

#syncronize a list of source events to target events
sub syncEvents($) {
    my $sourceEvents = shift;

    my @sourceEvents = sort { $a->{calcms_start} cmp $b->{calcms_start} } @$sourceEvents;
    $sourceEvents = \@sourceEvents;
    my $start = $sourceEvents->[0]->{start};
    my $end   = $sourceEvents->[-1]->{end};

    my $targetEvents = GoogleCalendar::getEvents(
        {
            start => $start,
            end   => $end
        }
    );
    $targetEvents = $targetEvents->{items};
    info "google:" . scalar(@$targetEvents) . " vs " . scalar(@$sourceEvents);

    # mark all known target events
    my $targetEventsByKey = {};
    for my $event (@$targetEvents) {
        #print Dumper($event);
        next if $event->{status} eq 'canceled';
        my $key = getGoogleEventToString($event);
        $targetEventsByKey->{$key} = $event;
    }

    # mark all knwon source events
    my $sourceEventsByKey = {};
    for my $event (@$sourceEvents) {
        $event = CalcmsEvents::mapToSchema($event);
        $event = GoogleCalendar::mapToSchema($event);
        my $key = getCalcmsEventToString($event);
        $sourceEventsByKey->{$key} = $event;
    }

    # delete target entries without matching source entries
    for my $key ( keys %$targetEventsByKey ) {
        next if defined $sourceEventsByKey->{$key};
        my $event = $targetEventsByKey->{$key};
        info "delete $key ";
        print Dumper($event);
        GoogleCalendar::deleteEvent($event);
    }

    # insert source entries without matching target entries
    for my $key ( keys %$sourceEventsByKey ) {
        if ( defined $targetEventsByKey->{$key} ) {
            info "$key is up to date";
            next;
        }
        my $event = $sourceEventsByKey->{$key};
        info "insert $key";
        GoogleCalendar::insertEvent($event);
    }

}

sub getGoogleEventToString {
    my $event  = shift;
    my $result = "\n";
    $result .= "start: " . substr( $event->{start}->{dateTime}, 0, 19 ) . "\n";
    $result .= "end  : " . substr( $event->{end}->{dateTime},   0, 19 ) . "\n";
    $result .= "title: $event->{summary}\n";
    $result .= "desc : $event->{description}\n";
    return $result;
}

sub getCalcmsEventToString {
    my $event  = shift;
    my $result = "\n";
    $result .= "start: " . substr( $event->{event}->{start_datetime}, 0, 19 ) . "\n";
    $result .= "end  : " . substr( $event->{event}->{end_datetime},   0, 19 ) . "\n";
    $result .= "title: $event->{event}->{title}\n";
    $result .= "desc : $event->{event}->{content}\n";
    return $result;
}

#import requested source and target libs
sub init {
    binmode STDOUT, ":utf8";

    {
        #require target config file
        error "missing target parameter!"                       unless $targetConfigFile =~ /\S/;
        error "target file: '$targetConfigFile' does not exist" unless -e $targetConfigFile;
        error "cannot read target file: '$targetConfigFile'"    unless -r $targetConfigFile;
        my $config = new Config::General($targetConfigFile);
        $config = $config->{DefaultConfig}->{target};
        GoogleCalendar::init($config);

    }

    {
        #require source config file
        error "missing source parameter!"                       unless $sourceConfigFile =~ /\S/;
        error "source file: '$sourceConfigFile' does not exist" unless -e $sourceConfigFile;
        error "cannot read source file: '$sourceConfigFile'"    unless -r $sourceConfigFile;
        my $config = new Config::General($sourceConfigFile);
        $config = $config->{DefaultConfig}->{source};
        $config->{last_update} = getLastUpdateTime( $sourceConfigFile, $targetConfigFile );
        CalcmsEvents::init($config);
    }

    $from .= 'T00:00' if $from =~ /^\d\d\d\d\-\d\d\-\d\d$/;
    $till .= 'T23:59' if $till =~ /^\d\d\d\d\-\d\d\-\d\d$/;

    if ( $from =~ /^([-+]?\d+$)/ ) {
        my $days = $1;
        my $duration = new DateTime::Duration( days => $days );
        $from = DateTime->today->add_duration($duration);
    }

    if ( $till =~ /^([-+]?\d+$)/ ) {
        my $days = $1 + 1;
        my $duration = new DateTime::Duration( days => $days );
        $till = DateTime->today->add_duration($duration);
    }

    CalcmsEvents::set( 'start_min', $from ) if defined $from;
    CalcmsEvents::set( 'start_max', $till ) if defined $till;

    my $now = time();
    $now = time::time_to_datetime($now);
    $settings->{event} = {
        update_start => time::time_to_datetime( time() ),
        modified_at  => $now,
    };

}

#output usage on error or --help parameter
sub usage {
    print qq{
update all/modified events from source at target.

USAGE: sync_cms.pl [--read,--update] [--modified,--all] --source s --target t

on using --from and --till requests will be processed as multiple single-day-requests.
	
parameters:
	--read          show all events without updating database
	--update        update target database with source events

	--source        source configuration file
	--target        target configuration file

	--from          start of date range: datetime (YYYY-MM-DDTHH:MM::SS) or days from today (e.g. -1 for yesterday, +1 for tomorrow)
	--till          end of date range: datetime (YYYY-MM-DDTHH:MM::SS) or days from today (e.g. -1 for yesterday, +1 for tomorrow)

examples: 
   update modified
	perl sync_cms.pl --update --source=config/source/program.cfg --target=config/target/calcms.cfg
   update a given time range
	perl sync_cms.pl --update --all --from=2009-09-01T00:00:00 --till=2009-11-22T23:59:59 --source=config/source/program.cfg --target=config/target/calcms.cfg
   update from last 2 days until next 3 days
	perl sync_cms.pl --update --from=-2 --till=+3 --source=config/source/program.cfg --target=config/target/calcms.cfg
};
    exit 1;
}

#load last update time out of sync.data
sub getLastUpdateTime {
    my $source = shift;
    my $target = shift;

    my $date = undef;
    return undef unless -r "sync.data";
    my $content = Common::loadFile("sync.data");
    if ( $content =~ /$source\s+\->\s+$target\s+:\s+(\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2})/ ) {
        $date = $1;
    }
    return $date;
}

#save last update time to sync.data
sub setLastUpdateTime {
    my $source = shift;
    my $target = shift;
    my $date   = shift;

    my $data = '';
    if ( -r "sync.data" ) {
        $data = Common::loadFile("sync.data");
    }

    if ( $data =~ /$source\s+\->\s+$target\s+:\s+(\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2})/ ) {
        $data =~ s/($source\s+\->\s+$target\s+:)\s+\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}/$1\t$date/gi;
    } else {
        $data .= "$source\t\->\t$target\t:\t$date\n";
    }

    $data =~ s/[\r\n]+/\n/g;
    Common::saveFile( "sync.data", $data );
}

