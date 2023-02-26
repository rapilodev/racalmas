#!/usr/bin/perl 

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();

use series();
use localization();
use user_selected_events();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( ( !defined $user ) || ( $user eq '' ) );

print "Content-type:text/plain; charset=UTF-8;\n\n";

my $user_presets = uac::get_user_presets(
    $config,
    {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        user       => $user
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params                      = uac::setDefaultStudio( $params, $user_presets );
$params                      = uac::setDefaultProject( $params, $user_presets );

my $request = {
    url    => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    },
};
$request = uac::prepare_request( $request, $user_presets );
return unless uac::check( $config, $params, {} ) == 1;
log_event_selection( $config, $request, $user );

sub get_select_fields {
    return [
        'project_id', 'studio_id',
        'series_id', 'filter_project_studio', 'filter_series'
    ];
}

sub get_value_fields {
    return [
        'selected_project', 'selected_studio', 
        'selected_series', 'selected_event' 
    ];
}

sub log_event_selection {
    my $config  = shift;
    my $request = shift;
    my $user    = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_event} == 1 ) {
        uac::permissions_denied('read_event');
        return;
    }
    
    my $select_fields = get_select_fields();
    my $value_fields  = get_value_fields();

    my $entry = { user => $user };
    $entry->{$_} = $params->{$_} for @$select_fields;
    my $preset = user_selected_events::get( $config, $entry );
    $entry->{$_} = $params->{$_} for ( @$select_fields, @$value_fields);
    for ( @$select_fields, @$value_fields ) {
        uac::print_error("missing $_") unless defined $entry->{$_};
    }

    if ($preset) {
        print "update\n";
        user_selected_events::update( $config, $entry );
    } else {
        print "insert\n";
        user_selected_events::insert( $config, $entry );
    }
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my @fields = ( @{get_select_fields()}, @{get_value_fields()} );
    my $checked = {};
    entry::set_numbers( $checked, $params, \@fields );
    return $checked;
}
