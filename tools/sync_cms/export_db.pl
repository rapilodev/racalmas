#!/usr/bin/perl

use strict;
use warnings;
use lib "../calcms";
use utf8;

use Data::Dumper;
use Config::General;
use Storable qw(nstore);

use db;
use config;

our $default={
    configFile      => '/home/radio/piradio.de/agenda/config/config.cgi',
    timezone        => 'Europe/Berlin',
    local_media_url => 'http://piradio.de/agenda_files/media/',
    project         => '88vier',
    location        => 'piradio',
};

my $config = config::get($default->{configFile});
print Dumper($config);

my $dbh=db::connect($config);
my $query=q{
    select * from calcms_events 
    order by start
};

my $events=db::get($dbh, $query);
nstore($events, 'event_export.dat');
