#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Scalar::Util qw(blessed);
use Try::Tiny;

use config();
use entry();
use log();
use template();
use auth();
use uac();
use project();
use studios();
use params();
use user_settings();
use user_stats();
use localization();

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get($config, { user => $session->{user}, file => 'menu' });
    my $out =  template::process($config, template::check($config, 'default.html'), $headerParams);
    uac::check($config, $params, $user_presets);
    return $out . show_active_users($config, $request) if $params->{action} eq 'show-active-users';
    return $out . show_user_stats($config, $request)  if $params->{action} eq 'show-user-stats';
    ActionError->throw(error=>'Invalid action');

}

sub show_user_stats {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_user_stats') unless $permissions->{read_user_stats};
    $params->{user_stats}  = user_stats::get_stats($config, $params);
    $params->{permissions} = $permissions;

    $params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'user-stats' });
    uac::set_template_permissions($permissions, $params);
    my $template = template::check($config, 'user-stats');
    return template::process($config, $template, $params);
}

sub show_active_users{
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to read_user_stats') unless $permissions->{read_user_stats};

    my $user_stats  = user_stats::get_active_users($config, $params);
    for my $user (@$user_stats){
        $user->{disabled} = $user->{disabled} ? 'x' : '-';
    }
    $params->{user_stats}  = $user_stats;
    $params->{permissions} = $permissions;

    $params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'user-stats' });
    uac::set_template_permissions($permissions, $params);
    my $template = template::check($config, 'user-active');
    return template::process($config, $template, $params);
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    $checked->{action} = entry::element_of($params->{action},
        ['show-user-stats', 'show-active-users']
    );

    entry::set_numbers($checked, $params, [
        'project_id', 'default_studio_id', 'studio_id', 'series_id']);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}
