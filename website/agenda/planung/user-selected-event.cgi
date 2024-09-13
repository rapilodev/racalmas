#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Scalar::Util qw( blessed );
use Try::Tiny;

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
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    return unless uac::check( $config, $params, {} ) == 1;
    return log_event_selection( $config, $request, $session->{user} );
}

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
    my ($config, $request, $user) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_event} == 1 ) {
        PermissionError->throw(error=>'Missing permission to read_event');
    }

    my $select_fields = get_select_fields();
    my $value_fields  = get_value_fields();

    my $entry = { user => $user };
    $entry->{$_} = $params->{$_} for @$select_fields;
    my $preset = user_selected_events::get( $config, $entry );
    $entry->{$_} = $params->{$_} for ( @$select_fields, @$value_fields);
    for ( @$select_fields, @$value_fields ) {
        ParamError->throw(error=> "missing $_") unless defined $entry->{$_};
}

    if ($preset) {
        user_selected_events::update( $config, $entry );
        return uac::json({status => "updated"});
    } else {
        user_selected_events::insert( $config, $entry );
        return uac::json({status => "inserted"});
    }
}

sub check_params {
    my ($config, $params) = @_;
    my @fields = (@{get_select_fields()}, @{get_value_fields()});
    my $checked = {};
    entry::set_numbers($checked, $params, \@fields);
    return $checked;
}
