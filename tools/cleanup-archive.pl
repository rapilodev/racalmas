#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;

my $base_dir=shift;
-d $base_dir or die "Usage: $0 <path-to-cleanup>\n";

my $now = time;
my $day = 24 *60 * 60;

sub remove{
    my ($file) = @_;
    print "remove $file\n";
    unlink $file;
}

sub cleanup_files{
    my ($dir) = @_;
    opendir my $dh, $base_dir or die "Could not open '$base_dir' for reading: $!\n";
    while (my $file = readdir $dh) {
        next if $file eq '.' or $file eq '..';
        my $path="$base_dir/$file";
        if (-l $path){
            my $age = ($now-(lstat $path)[9])/$day;
            remove $path if $age > 7;
        }elsif(-f $path){
            my $age = ($now-(stat $path)[9])/$day;
            remove $path if $age > 360;
        }
    }
}

sub cleanup_tmp_files{
    my ($dir) = @_;
    opendir my $dh, $dir or die "Could not open '$dir' for reading: $!\n";
    while (my $file = readdir $dh) {
        next if $file eq '.' or $file eq '..';
        my $path="$base_dir/$file";
        my $age = ($now-(stat $path)[9])/$day;
        remove $path if $age > 7;
    }
}

cleanup_files($base_dir);
cleanup_tmp_files("$base_dir/tmp");

