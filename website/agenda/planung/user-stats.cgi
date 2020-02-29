#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use config();
use log();
use template();
use auth();
use uac();
use roles();
use project();
use studios();
use params();
use user_settings();
use user_stats();
use localization();

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( ( !defined $user ) || ( $user eq '' ) );

my $user_presets = uac::get_user_presets(
    $config,
    {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
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
template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

our $errors = [];

show_stats( $config, $request );

sub show_stats {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_user_stats} ) {
        uac::permissions_denied('read_user_stats');
        return;
    }
    print STDERR "continue\n";
    $params->{user_stats}  = user_stats::get_stats( $config, $params );
    $params->{permissions} = $permissions;
    $params->{errors}      = $errors;

    $params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'user-stats' } );
    uac::set_template_permissions( $permissions, $params );
    template::process( $config, 'print', $params->{template}, $params );
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    #template
    my $template = '';
    $template = template::check( $config, $params->{template}, 'user-stats' );
    $checked->{template} = $template;

    #numeric values
    for my $param ( 'project_id', 'default_studio_id', 'studio_id', 'series_id' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }
    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

sub error {
    push @$errors, { error => $_[0] };
}
