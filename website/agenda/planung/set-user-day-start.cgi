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
use user_day_start();

binmode STDOUT, ":utf8";

my $r = shift;
(my $cgi, my $params, my $error) = params::get($r);

my $config = config::get('../config/config.cgi');
my ($user, $expires) = auth::get_user($config, $params, $cgi);
return if ((!defined $user) || ($user eq ''));

my $user_presets = uac::get_user_presets(
    $config,
    {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        user       => $user
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio($params, $user_presets);
$params = uac::setDefaultProject($params, $user_presets);

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params($config, $params),
    },
};
$request = uac::prepare_request($request, $user_presets);

$params = $request->{params}->{checked};
$params = uac::set_template_permissions($request->{permissions}, $params);
$params->{loc} = localization::get($config, { user => $user, file => 'select-event' });

#process header
print "Content-type:text/text; charset=UTF-8;\n\n";

return unless uac::check($config, $params, $user_presets) == 1;
set_start_date($config, $request);

sub set_start_date {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{read_event} == 1) {
        uac::permissions_denied('read_event');
        return;
    }

    my $preset = user_day_start::insert_or_update($config, {
        user        => $request->{user},
        project_id  => $params->{project_id},
        studio_id   => $params->{studio_id},
        day_start   => $params->{day_start},
    });
    print "done\n";
    return;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'day_start'
    ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }
    return $checked;
}

