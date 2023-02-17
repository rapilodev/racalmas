#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use Scalar::Util qw( blessed );
use Try::Tiny;
use Exception::Class (
    'ParamError',
    'PermissionError'
);

use localization();
use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use project();
use studios();
use events();
use series();
use series_schedule();
use series_events();
use series_dates();
use markup();
use playout();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );

    uac::check($config, $params, $user_presets);

    if ( defined $params->{action} ) {
        deleteFromPlayout( $config, $request ) if ( $params->{action} eq 'delete' );
    } else {
        print "missing action\n";
    }
}

sub deleteFromPlayout {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{update_event_status_playout} == 1 ) {
        PermissionError->throw(error=>'Missing permission to update_event_status_playout');
    }

    for my $attr ( 'project_id', 'studio_id', 'start_date' ) {
        unless ( defined $params->{$attr} ) {
            ParamError->throw(error=>"missing $attr");
        }
    }

    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);

    playout::delete(
        $config, $dbh,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            start      => $params->{start_date}
        }
    );
    $config->{access}->{write} = 0;
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};

    $checked->{action} = '';
    if ( defined $params->{action} ) {
        if ( $params->{action} =~ /^(delete)$/ ) {
            $checked->{action} = $params->{action};
        }
    }

    #numeric values
    $checked->{exclude} = 0;
    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id']);

    #dates
    for my $param ('start_date') {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /(\d\d\d\d\-\d\d\-\d\d \d\d\:\d\d)/ ) ) {
            $checked->{$param} = $1 . ':00';
        }
    }

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    #$checked->{template}=template::check($config, $params->{template},'playout');

    return $checked;
}

