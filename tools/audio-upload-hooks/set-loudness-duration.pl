#!/usr/bin/perl
use warnings;
use strict;
use Symbol 'gensym';
use IPC::Open3 qw(open3);
$| = 1;

# measure duration and rms
# requires sox and libsox-fmt-all

die unless $ARGV[0];
my $pid
    = open3(undef, undef, my $err = gensym(), "sox", $ARGV[0], "-n", "stats");

while (defined(my $line = <$err>)) {
    my @fields = split /\s+/, $line;
    if ($line =~ /^RMS lev dB/) {
        print "calcms_audio_recordings.rmsLeft = "
            . int($fields[3] + 0.5) . "\n";
        print "calcms_audio_recordings.rmsRight = "
            . int($fields[4] + 0.5) . "\n";
    } elsif($line =~ /^Length\ss/) {
        print "calcms_audio_recordings.audioDuration = "
            . int($fields[2] + 0.5)
            . "\n";
    }
}
waitpid($pid, 0);
die if $?;
