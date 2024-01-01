#!/usr/bin/perl 

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();

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
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( ( !defined $user ) || ( $user eq '' ) );

print "Content-type:text/html; charset=UTF-8;\n\n";

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
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );

#template::process($config, 'print', template::check($config, 'default.html'), $headerParams);
return unless uac::check( $config, $params, $user_presets ) == 1;

if ( defined $params->{action} ) {
    deleteFromPlayout( $config, $request ) if ( $params->{action} eq 'delete' );
} else {
    print "missing action\n";
}
return;

sub deleteFromPlayout {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{update_event_status_playout} == 1 ) {
        uac::permissions_denied('update_event_status_playout');
        return;
    }

    for my $attr ( 'project_id', 'studio_id', 'start_date' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show event" );
            return;
        }
    }

    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);

    my $result = playout::delete(
        $config, $dbh,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            start      => $params->{start_date}
        }
    );
    $config->{access}->{write} = 0;

    print "result:$result\n";
}

sub check_params {
    my $config = shift;
    my $params = shift;

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

