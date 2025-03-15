#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Scalar::Util qw(blessed);
use Try::Tiny;

use config();
use entry();
use params();
use log();
use template();
use auth();
use uac();
use studios();
use series();
use localization();

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get($config, { user => $session->{user}, file => 'menu.po' });
    my $out = template::process($config, template::check($config, 'projects-header.html'), $headerParams);
    uac::check($config, $params, $user_presets);

    if (defined $params->{action}) {
        return $out . save_project($config, $request) if ($params->{action} eq 'save');
        return $out . delete_project($config, $request) if ($params->{action} eq 'delete');
        return $out . assign_studio($config, $request) if ($params->{action} eq 'assign_studio');
        return $out . unassign_studio($config, $request) if ($params->{action} eq 'unassign_studio');
    }
    $config->{access}->{write} = 0;
    return $out . show_projects($config, $request);
}

sub delete_project {
    my ($config, $request) = @_;

    my $permissions = $request->{permissions};
    unless ($permissions->{delete_project} == 1) {
        PermissionError->throw(error=>'Missing permission to delete_project');
    }

    my $params  = $request->{params}->{checked};
    my $columns = project::get_columns($config);

    my $entry = {};
    for my $param (keys %$params) {
        if (exists $columns->{$param}) {
            $entry->{$param} = $params->{$param} || '';
        }
    }

    my $project_id = $params->{pid} || '';

    if ($project_id ne '') {
        local $config->{access}->{write} = 1;
        $entry->{project_id} = $project_id;
        delete $entry->{studio_id};
        project::delete($config, $entry);
        uac::print_info("Project deleted");
    }
}

sub save_project {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    #filter entry for studio columns
    my $columns = project::get_columns($config);
    my $entry   = {};
    for my $param (keys %$params) {
        if (exists $columns->{$param}) {
            $entry->{$param} = $params->{$param} || '';
        }
    }

    my $project_id = $params->{pid} || '';
    if ($project_id ne '') {
        unless ($permissions->{update_project} == 1) {
            PermissionError->throw(error=>'Missing permission to update_project');
}
        $entry->{project_id} = $project_id;
        delete $entry->{studio_id};

        local $config->{access}->{write} = 1;
        project::update($config, $entry);
        uac::print_info("project saved");
    } else {
        unless ($permissions->{create_project} == 1) {
            PermissionError->throw(error=>'Missing permission to create_project');
        }
        my $projects = project::get($config, { name => $entry->{name} });
        if (scalar @$projects > 0) {
            ExistError->throw(error=> "project with name '$entry->{name}' already exists");
    }
        delete $entry->{project_id};
        delete $entry->{studio_id};

        local $config->{access}->{write} = 1;
        project::insert($config, $entry);
        uac::print_info("project created");
    }
}

sub assign_studio {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{assign_project_studio} == 1) {
        PermissionError->throw(error=>'Missing permission to assign_project_studio');
        }

    for my $param ('pid', 'sid') {
        unless (defined $params->{$param}) {
            ParamError->throw(error=> 'missing ' . $param);
            return;
        }
    }
    $config->{access}->{write} = 1;
    project::assign_studio(
        $config,
        {
            project_id => $params->{pid},
            studio_id  => $params->{sid}
        }
    );
    uac::print_info("project assigned");

}

# TODO: unassign series from studio
sub unassign_studio {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{assign_project_studio} == 1) {
        PermissionError->throw(error=>'Missing permission to assign_project_studio');
    }

    for my $param ('pid', 'sid') {
        unless (defined $params->{$param}) {
            ParamError->throw(error=> 'missing ' . $param);
            return;
        }
    }
    local $config->{access}->{write} = 1;
    project::unassign_studio(
        $config,
        {
            project_id => $params->{pid},
            studio_id  => $params->{sid}
        }
    );
    uac::print_info("project unassigned");

}

sub show_projects {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ($permissions->{read_project} == 1) {
        PermissionError->throw(error=>'Missing permission to read_project');
    }

    my $projects = project::get($config);
    my $studios  = studios::get($config);
    my @projects = reverse sort { $a->{end_date} cmp $b->{end_date} } (@$projects);
    $projects = \@projects;

    for my $project (@$projects) {

        # get assigned studios
        my $project_studio_assignements =
          project::get_studio_assignments($config, { project_id => $project->{project_id} });
        $project->{pid} = $project->{project_id};

        # get assigned studios by id
        my $assigned_studio_by_id = { map { $_->{studio_id} => 1 } @$project_studio_assignements };
        my $assigned_studios   = [];
        my $unassigned_studios = [];
        for my $studio (@$studios) {
            my %studio = %$studio;
            $studio        = \%studio;
            $studio->{pid} = $project->{pid};
            $studio->{sid} = $studio->{id};
            if (defined $assigned_studio_by_id->{ $studio->{id} }) {
                push @$assigned_studios, $studio;
            } else {
                push @$unassigned_studios, $studio;
            }
        }
        $project->{assigned_studios}   = $assigned_studios;
        $project->{unassigned_studios} = $unassigned_studios;

        if ((defined $params->{setImage}) && ($project->{pid} eq $params->{pid})) {
            $project->{image} = $params->{setImage};
        }
    }

    $params->{projects} = $projects;
    $params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'projects.po' });
    uac::set_template_permissions($permissions, $params);

    return template::process($config, $params->{template}, $params);
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    #template
    my $template = '';
    $template = template::check($config, $params->{template}, 'projects');
    $checked->{template} = $template;

    $checked->{action} = entry::element_of($params->{action},
        ['save', 'delete', 'assign_studio', 'unassign_studio']);

    entry::set_strings($checked, $params, [
        'name', 'title', 'subtitle', 'start_date', 'end_date', 'image', 'email', 'setImage' ]);

    entry::set_numbers($checked, $params, [
        'project_id', 'studio_id', 'default_studio_id', 'pid', 'sid']);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

