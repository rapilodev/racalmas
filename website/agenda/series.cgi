#!/usr/bin/perl -w

use warnings "all";
use strict;
use Data::Dumper;

use params();
use config();
use template();
use studios();
use series();

binmode STDOUT, ":utf8";
print "Content-Type: text/html; charset=utf-8\n\n";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('config/config.cgi');

$params = check_params( $config, $params );

list_series( $config, $params );

sub list_series {
    my $config = shift;
    my $params = shift;

    $config->{access}->{write} = 0;

    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $location   = $params->{location};

    if ( defined $location ) {
        my $studios = studios::get(
            $config,
            {
                project_id => $project_id,
                location   => $location
            }
        );

        $studio_id = $studios->[0]->{id};
    }

    my $conditions = {};
    $conditions->{project_id} = $project_id if defined $project_id;
    $conditions->{studio_id}  = $studio_id  if defined $studio_id;

    if ( scalar( keys %$conditions ) == 0 ) {
        $params->{info} .= "missing parameters";
        return;
    }
    $params->{info} .= Dumper($conditions);

    my $series = series::get_event_age( $config, $conditions );
    my $series2 = [];
    for my $serie ( sort { lc $a->{series_name} cmp lc $b->{series_name} } (@$series) ) {
        next if $serie->{days_over} > 80;
        next if $serie->{days_over} == 0;
        next unless defined $serie->{series_name};
        next if $serie->{series_name} eq '_single_';
        push @$series2, $serie;
    }
    $params->{series} = $series2;

    $params->{info} .= "no results found" if scalar(@$series) == 0;
    $params->{info} = '';

    template::process( $config, 'print', 'templates/series.html', $params );
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    my $debug = $params->{debug} || '';
    if ( $debug =~ /([a-z\_\,]+)/ ) {
        $debug = $1;
    }
    $checked->{debug} = $debug;

    for my $param ( 'project_id', 'studio_id' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }

    for my $param ('location') {
        if ( defined $params->{$param} ) {
            $checked->{$param} = $params->{$param};
            $checked->{$param} =~ s/^\s+//g;
            $checked->{$param} =~ s/\s+$//g;
        }
    }

    return $checked;
}

