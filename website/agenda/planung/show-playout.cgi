#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use ModPerl::Util ();
use Scalar::Util qw( blessed );
use Try::Tiny;
use Exception::Class (
    'ParamError'
};

use config;
use log;
use localization;
use auth;
use uac;
use studios;
use series;
use template;
use playout;
use audio;
use entry;

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    unless ( params::is_json() ) {
        my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
        $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );
        print template::process( $config, template::check( $config, 'show-playout-header.html' ),
            $headerParams );
    }
    uac::check($config, $params, $user_presets);

    my $permissions = $request->{permissions};
    $params->{action} = '' unless defined $params->{action};

    showPlayout( $config, $request );

    print STDERR "$0 ERROR: " . $params->{error} . "\n" if $params->{error} ne '';
    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'event,comment' } );
    print template::process( $config, $params->{template}, $params );
}

sub showPlayout {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ( 'project_id', 'studio_id' ) {
        unless ( defined $params->{$attr} ) {
            ParamError->throw(error=> "missing $attr to show playout" );
        }
    }

    my $today     = time::time_to_date( time() );
    my $startDate = time::add_days_to_date( $today, -14 );
    my $events    = playout::get_scheduled(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            order      => 'p.modified_at asc, p.start asc',
            from       => $startDate
        }
    );

    unless ( defined $events ) {
        uac::print_error("not found");
        return;
    }

    for my $event (@$events) {
        $event->{stream_size} ||= '';
        $event->{stream_size} =~ s/(\d)(\d\d\d)$/$1\.$2/g;
        $event->{stream_size} =~ s/(\d)(\d\d\d\.\d\d\d)$/$1\.$2/g;
        $event->{duration} =~ s/(\d\.\d)(\d+)$/$1/g;
        $event->{duration} =~ s/(\d)\.0/$1/g;
        $event->{rms_left}      = audio::formatLoudness( $event->{rms_left}, 'L:' );
        $event->{rms_right}     = audio::formatLoudness( $event->{rms_right}, 'R:' );
        $event->{bitrate}       = audio::formatBitrate( $event->{bitrate} );
        $event->{bitrate_mode}  = audio::formatBitrateMode( $event->{bitrate_mode} );
        $event->{sampling_rate} = audio::formatSamplingRate( $event->{sampling_rate} );
        $event->{duration}      = audio::formatDuration(
            $event->{duration},
            $event->{event_duration},
            sprintf( "%.1g h", $event->{duration} / 3600)
        );
        $event->{channels} = audio::formatChannels( $event->{channels} );
        $event->{class} = "past" if  $event->{start} lt $today;
    }

    $params->{events} = $events;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};
    $checked->{error} = '';
    $checked->{template} = template::check( $config, $params->{template}, 'show-playout' );

    entry::set_numbers( $checked, $params, [
         'project_id', 'studio_id', 'default_studio_id', 'series_id', 'event_id', 'id'
    ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

