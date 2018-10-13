#!/usr/bin/perl

local $| = 0;

use warnings;
use strict;

use Data::Dumper;
use ModPerl::Util ();

use config;
use log;
use localization;
use auth;
use uac;
use studios;
use series;
use template;
use playout;
binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( !defined $user ) || ( $user eq '' );

my $user_presets = uac::get_user_presets(
    $config,
    {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        user       => $user
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio( $params, $user_presets );
$params = uac::setDefaultProject( $params, $user_presets );

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    },
};
$request = uac::prepare_request( $request, $user_presets );
$params = $request->{params}->{checked};

#process header
unless ( params::isJson() ) {
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
    template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
}
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
    <script src="js/show-playout.js" type="text/javascript"></script>
    <link rel="stylesheet" href="css/show-playout.css" type="text/css" /> 
} unless (params::isJson);

my $permissions = $request->{permissions};
$params->{action} = '' unless defined $params->{action};
$params->{error} = $error || '';

showPlayout( $config, $request );

print STDERR "$0 ERROR: " . $params->{error} . "\n" if $params->{error} ne '';
$params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'event,comment' } );
template::process( $config, 'print', $params->{template}, $params );

exit;

sub showPlayout {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ( 'project_id', 'studio_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show playout" );
            return;
        }
    }

    my $today=time::time_to_date(time());
    my $startDate=time::add_days_to_date( $today, -14 );
    my $events = playout::get(
        $config,
           {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            order      => 'modified_at asc, start asc',
            from => $startDate
        }
    );

    unless ( defined $events ) {
        uac::print_error("not found");
        return;
    }

    
    for my $event (@$events) {
        $event->{stream_size} =~ s/(\d)(\d\d\d)$/$1\.$2/g;
        $event->{stream_size} =~ s/(\d)(\d\d\d\.\d\d\d)$/$1\.$2/g;
        $event->{duration}  =~ s/(\d\.\d)(\d+)$/$1/g;
        $event->{duration}  =~ s/(\d)\.0/$1/g;
        $event->{rms_left}  = formatLoudness( $event->{rms_left} );
        $event->{rms_right} = formatLoudness( $event->{rms_right} );
        $event->{bitrate}   = formatBitrate($event);
        $event->{duration}  = formatDuration($event);
        if ($event->{start} lt $today){
            $event->{class} = "past";
        }
    }

    $params->{events} = $events;
}

sub formatDuration {
    my $event    = $_[0];
    my $duration = $event->{duration};
    return '' unless defined $duration;
    return '' if $duration eq '';
    my $result =  ( ( $duration +30 ) % 60)-30;
    my $class = "ok";
    $class = "warn"  if abs($result) > 1;
    $class = "error" if abs($result) > 2;
    return sprintf( qq{<div class="%s">%.01f</div>}, $class, $duration );
}

sub formatBitrate {
    my $event   = $_[0];
    my $bitrate = $event->{bitrate};
    my $mode    = $event->{bitrate_mode};
    if ( $bitrate ne '' ) {
        if ( $bitrate >= 200 ) {
            $bitrate = '<div class="warn">' . $bitrate . ' ' . $mode . '</div>';
        } elsif ( $bitrate < 190 ) {
            $bitrate = '<div class="error">' . $bitrate . ' ' . $mode . '</div>';
        } else {
            $bitrate .= ' ' . $mode;
        }
    }
    return $bitrate;
}

sub formatLoudness {
    my $value = shift;
    return '' unless defined $value;
    return '' if $value == 0;
    return '' if $value eq '';

    $value = sprintf( "%.1f", $value );
    my $class = 'ok';
    $class = 'warn'  if $value > -18.5;
    $class = 'error' if $value > -16.0;
    $class = 'warn'  if $value < -24.0;
    $class = 'error' if $value < -27.0;

    return qq{<div class="$class">$value dB</div>};
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};
    $checked->{error} = '';
    $checked->{template} = template::check( $config, $params->{template}, 'show_playout' );

    #numeric values
    for my $param ( 'project_id', 'studio_id', 'default_studio_id', 'series_id', 'event_id', 'id' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    #word
    for my $param ('debug') {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\s*(.+?)\s*$/ ) ) {
            $checked->{$param} = $1;
        }
    }

    return $checked;
}

