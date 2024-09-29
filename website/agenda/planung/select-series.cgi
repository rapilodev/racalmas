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
$params->{loc} = localization::get($config, { user => $user, file => 'select-series' });

#process header
print "Content-type:text/html; charset=UTF-8;\n\n";

return unless uac::check($config, $params, $user_presets) == 1;

my $permissions = $request->{permissions};
unless ($permissions->{read_series} == 1) {
    uac::permissions_denied('read_series');
    return;
}

show_series($config, $request);

sub show_series {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{read_series} == 1) {
        uac::permissions_denied('read_series');
        return;
    }

    # get user projects
    my $user_projects = uac::get_projects_by_user($config, { user => $request->{user} });
    my $projects = {};
    for my $project (@$user_projects) {
        $projects->{ $project->{project_id} } = $project;
    }

    # get user studios
    my $user_studios = uac::get_studios_by_user($config, { user => $request->{user} });
    for my $studio (@$user_studios) {
        my $project_id = $studio->{project_id};
        my $studio_id  = $studio->{id};
        $studio->{project_name} = $projects->{$project_id}->{name};
        $studio->{selected} = 1 if ($project_id eq $params->{p_id}) && ($studio_id eq $params->{s_id});
    }

    # get series
    my $options = {};
    $options->{project_id} = $params->{p_id} if defined $params->{p_id};
    $options->{studio_id}  = $params->{s_id} if defined $params->{s_id};
    my $series = series::get($config, $options);

    for my $serie (@$series) {
        $serie->{selected} = 1 if (defined $params->{series_id}) && ($serie->{series_id} eq $params->{series_id});
        $serie->{series_name} = 'Einzelsendung' if $serie->{series_name} eq '_single_';
    }

    $params->{studios} = $user_studios;
    $params->{series}  = $series;

    template::process($config, 'print', $params->{template}, $params);
    return;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'series_id', 'p_id', 's_id'
    ]);

    entry::set_bools($checked, $params, [
         'selectProjectStudio', 'selectSeries', 'selectRange' ]);

    for my $param ('resultElemId') {
        if ((defined $params->{$param}) && ($params->{$param} =~ /^[a-zA-ZöäüÖÄÜß_\d]+$/)) {
            $checked->{$param} = $params->{$param};
        }
    }

    # set defaults for project and studio id if not given
    $checked->{s_id} = $params->{studio_id}  || '-1' unless defined $params->{s_id};
    $checked->{p_id} = $params->{project_id} || '-1' unless defined $params->{p_id};

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check($config, $params->{template}, 'select-series');

    return $checked;
}

