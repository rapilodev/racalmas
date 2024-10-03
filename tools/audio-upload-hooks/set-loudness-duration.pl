#!/usr/bin/env perl
use strict;
use warnings;
use IPC::Open3;
use Symbol 'gensym';

die "Usage: $0 <input.m4a>\n" unless $ARGV[0];

my $filename = $ARGV[0];

if (-T $filename) {
    my $duration;
    open(my $file, '<', $filename) or die qq{could not read "$filename"};
    while (<$file>) {
        $duration ||= $1 if /#EXTINF:(\d+)/;
        $duration ||= $1 if /^\s*(\d+)\s*$/;
    }
    close $file;
    print "calcms_audio_recordings.audioDuration = $duration\n";
    exit;
}

$filename =~ s/'/'\\''/g;  # Escape any single quotes in the filename
$filename = "'$filename'"; # Wrap the filename in single quotes to handle spaces and special chars

my $cmd = "ffmpeg -i $filename -f wav - | sox -t wav - -n stats";
my $err = gensym();  # To capture STDERR from sox
my $pid = open3(undef, undef, $err, "sh", "-c", $cmd);

while (defined(my $line = <$err>)) {
    my @fields = split /\s+/, $line;
    if ($line =~ /^RMS lev dB/) {
        print "calcms_audio_recordings.rmsLeft = "
            . int($fields[3] + 0.5) . "\n";
        print "calcms_audio_recordings.rmsRight = "
            . int($fields[4] + 0.5) . "\n";
    } elsif ($line =~ /^Length\ss/) {
        print "calcms_audio_recordings.audioDuration = "
            . int($fields[2] + 0.5) . "\n";
    }
}

waitpid($pid, 0);
die "Command failed with exit code: $?\n" if $? != 0;
