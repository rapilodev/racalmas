#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use lib '../lib/calcms';
use Const::Fast;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use config();
use db;
use utf8;

my $config = config::get('../website/agenda/config/config.cgi');

sub creole_to_markdown {
    my ($input) = @_;

    return $input
      unless ($input =~ /\[\[.*?\]\]/
        || $input =~ /^=/m
        || $input =~ /^#[^#].*\n#/m
        || $input =~ /^\*/m
        || $input =~ /\/\/.*?\/\//);

    my $output = $input;
    $output =~ s/\xA0/ /g;

    $output =~ s/^===[ \t]*(.*?)[ \t]*=*$/### $1/mg;
    $output =~ s/^==[ \t]*(.*?)[ \t]*=*$/## $1/mg;
    $output =~ s/^[ \t]*=[ \t]*(.*?)[ \t]*=*$/# $1/mg;
    $output =~ s/^((?:#[ \t]+.*\n){1,}#[ \t]+.*)/
        my $block = $1;
        $block =~ s|^#[ \t]+|1. |mg;
        $block;
    /mge;
    $output =~ s/^\*[ \t]+/* /mg;
    $output =~ s/\{\{([^|\}]+)\|([^\}]+)\}\]/![$2]($1)/g;
    $output =~ s/\{\{([^\}]+)\}\]/![]($1)/g;    
    $output =~ s/\[\[([^|\]]+)\|([^\]]+)\]\]/[$2]($1)/g;
    $output =~ s/\[\[([^\]]+)\]\]/[$1]($1)/g;
    $output =~ s/(?<!:)\/\/(.*?)\/\//_$1_/g;

    return $output;
}

my $i=0;
sub update_events {
    my ($dbh) = @_;
    my @entries=();
    my @bind_values = ();
    my $query       = qq{
        SELECT * from calcms_events 
        where content_format is null or content_format != 'markdown' 
        order by id
    };
    my $sth = $dbh->prepare($query);
    $sth->execute();
    while (my $entry = $sth->fetchrow_hashref) {
        push @entries, $entry
    };
    $sth->finish();

    for my $entry (@entries){ 
        if (($entry->{content_format}//'') ne 'markdown') {
            $entry->{content_format} = 'markdown';
            $entry->{content}        = creole_to_markdown($entry->{content});
            $entry->{topic}          = creole_to_markdown($entry->{topic});
        }
        my $query = q{
            update calcms_events 
            set content_format=?, content=?, topic=?
            where id = ?
        };
        my $bind_values = [
            $entry->{content_format}, $entry->{content},
            $entry->{topic},          $entry->{id}
        ];
        warn Dumper $bind_values;
        db::put($dbh, $query, $bind_values);
#        die;
    }
}

$config->{access}->{write} = 1;
my $dbh = db::connect($config);
update_events($dbh);
