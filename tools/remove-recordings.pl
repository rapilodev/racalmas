#! /usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use List::Util qw();

use FindBin qw($Bin);
use lib "$Bin/../lib/calcms";
use config;
use time;
use db;
use File::Basename qw(basename);
my $config = config::get(pop @ARGV);
my $delete = grep {$_ eq "--delete"} @ARGV;

my $dbh   = db::connect($config);
my $query = qq{
    select start, path
    from calcms_events e, calcms_audio_recordings r
    where e.id = r.event_id
    and e.start > date_add(now(), INTERVAL -14 DAY)
};
my $entries = db::get($dbh, $query);
my %paths   = map {normalize($_->{path}) => $_->{start}} @$entries;

my $dir = $config->{locations}->{local_audio_recordings_dir};
for my $file(sort glob("$dir/*")) {
    next if $file !~ /\.(mp3|wav|flac|aac|ogg|m4a|aiff|aif|opus|aac)$/i;
    next if -M $file < 14;
    my $filename = normalize($file);
    unless (exists $paths{$filename}) {
        print "$filename\n";
        unlink $file or die $! if $delete;
    }
}

sub normalize {
    my $s = shift;
    $s = basename $s;
    $s =~ s/\.master(\.\w+)$/$1/;
    return $s;
}
