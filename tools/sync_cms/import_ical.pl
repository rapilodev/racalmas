#!/usr/bin/perl

use strict;
use warnings;
use lib "../calcms";
use utf8;

use DateTime;
use Net::Google::Calendar;
use DateTime::Format::ICal;
use Data::Dumper;
use Config::General;

use db;
use config;
use creole_wiki;
use markup;
use events;

my $filename=$ARGV[0];
die("USAGE: $0 filename") unless defined $filename;
die("cannot read from '$filename'") unless -e $filename;

our $default={
    configFile      => '/home/radio/piradio.de/agenda/config/config.cgi',
    timezone        => 'Europe/Berlin',
    local_media_url => 'http://piradio.de/agenda_files/media/',
    project         => '88vier',
    location        => 'piradio',
};

my $config = config::get($default->{configFile});
print Dumper($config);

parseICalFile($config, $filename);
our $active=0;
sub parseICalFile{
    my $config=shift;
    my $filename=shift;

    print "open $filename\n";
    open my $file, "<:encoding(UTF-8)", $filename;
    my $parse=0;
    my $event=undef;
    my $lastKey=undef;

    while (<$file>){
        my $line=$_;
        #print $parse." ".$line;
        if ($line=~/^BEGIN\:VEVENT/){
            $event={};
            $parse=1;
            #print "start event\n";
            next;
        }
        if ($line=~/^END\:VEVENT/){
            $parse=0;
            processEvent($config, $event) if defined $event;
            #print "end event\n";
            next;
        }
        if ($line=~/^\s/){
            my $key   = $lastKey;
            my $value = substr($line, 1);
            $value=~s/[\r\n]+$//;
            $event->{$key}.=$value;
            $lastKey=$key;
            next;
        }else{
            my ($key,$value)=split(/\:/,$line,2);
            $value=~s/[\r\n]+$//;
            $event->{$key}=$value;
            $lastKey=$key;
        }

    }
    close $file;
}

sub processEvent{
    my $config=shift;
    my $source=shift;

    my $event={};

    $event->{title}   = $source->{SUMMARY};
    $event->{content} = $source->{DESCRIPTION};
    $event->{title}   = markup::ical_to_plain($event->{title});
    $event->{content} = markup::ical_to_plain($event->{content});

    unless (defined $source->{DTSTART}){
        print STDERR "missing DTSTART in ".Dumper($source);
        return;
    }
    unless (defined $source->{DTEND}){
        print STDERR "missing DTEND in ".Dumper($source);
        return;
    }
    my $start = DateTime::Format::ICal->parse_datetime($source->{DTSTART});
    $start=$start->set_time_zone($default->{timezone});
    $event->{start} = $start->datetime();

    my $end = DateTime::Format::ICal->parse_datetime($source->{DTEND});
    $end = $end->set_time_zone($default->{timezone});
    $event->{end} = $end->datetime();

	my $params={
		title		    => $event->{title},
		content		    => $event->{content},
		local_media_url	=> $default->{local_media_url}
	};
    
    #$params->{content}=~s/\x0A\x20/\n/g;
    $event=creole_wiki::extractEventFromWikiText($params, $event);

    $event->{project}  = $default->{project};
    $event->{location} = $default->{location};

    return unless ($event->{start} ge '2015-09-01');

    $active=1 if ($event->{series_name}=~/Brainwashed/);
    print "$active $event->{start} $event->{series_name} - $event->{title}\n";
    #saveEvent($config, $event);
    #exit;
}

sub saveEvent{
    my $config = shift;
    my $event  = shift;

	$config->{access}->{write}=1;
	my $dbh=db::connect($config);

	$event->{'html_content'}=markup::creole_to_html($event->{'content'});

    # set start date
	my $day_start=$config->{date}->{day_starting_hour};
	$event->{start_date} = time::add_hours_to_datetime($event->{start}, -$day_start);
    $event->{start_date} = time::datetime_to_date($event->{start_date});

    # set end date
	$event->{end_date}   = time::add_hours_to_datetime($event->{end},   -$day_start);
    $event->{end_date}   = time::datetime_to_date($event->{end_date});

    delete $event->{categories} if defined $event->{categories};

    # set time of day
	my $day_times=$config->{date}->{time_of_day};
	my $event_hour=int((split(/[\-\:\sT]/,$event->{start}))[3]);
	for my $hour(sort {$a <=> $b} (keys %$day_times)){
		if ($event_hour >= $hour){
			$event->{time_of_day}=$day_times->{$hour};
		}else{
			last;
		};
	}
    $event->{published}=0;
    $event->{modified_by}='sync_cms';
	print Dumper($event);
	#db::insert($dbh,'calcms_events', $event);
}

