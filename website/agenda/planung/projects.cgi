#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

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
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');

my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( $user eq '' );

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
template::process( $config, 'print', template::check( $config, 'projects-header.html' ), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

if ( defined $params->{action} ) {
    save_project( $config, $request ) if ( $params->{action} eq 'save' );
    delete_project( $config, $request ) if ( $params->{action} eq 'delete' );
    assign_studio( $config, $request ) if ( $params->{action} eq 'assign_studio' );
    unassign_studio( $config, $request ) if ( $params->{action} eq 'unassign_studio' );
}
show_projects( $config, $request );

sub delete_project {
    my ($config, $request) = @_;

    my $permissions = $request->{permissions};
    unless ( $permissions->{delete_project} == 1 ) {
        uac::permissions_denied('delete_project');
        return;
    }

    my $params  = $request->{params}->{checked};
    my $columns = project::get_columns($config);

    my $entry = {};
    for my $param ( keys %$params ) {
        if ( exists $columns->{$param} ) {
            $entry->{$param} = $params->{$param} || '';
        }
    }

    my $project_id = $params->{pid} || '';

    if ( $project_id ne '' ) {
        local $config->{access}->{write} = 1;
        $entry->{project_id} = $project_id;
        delete $entry->{studio_id};
        project::delete( $config, $entry );
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
    for my $param ( keys %$params ) {
        if ( exists $columns->{$param} ) {
            $entry->{$param} = $params->{$param} || '';
        }
    }

    my $project_id = $params->{pid} || '';
    if ( $project_id ne '' ) {
        unless ( $permissions->{update_project} == 1 ) {
            uac::permissions_denied('update_project');
            return;
        }
        $entry->{project_id} = $project_id;
        delete $entry->{studio_id};

        local $config->{access}->{write} = 1;
        project::update( $config, $entry );
        uac::print_info("project saved");
    } else {
        unless ( $permissions->{create_project} == 1 ) {
            uac::permissions_denied('create_project');
            return;
        }
        my $projects = project::get( $config, { name => $entry->{name} } );
        if ( scalar @$projects > 0 ) {
            uac::print_error("project with name '$entry->{name}' already exists");
            return;
        }
        delete $entry->{project_id};
        delete $entry->{studio_id};

        local $config->{access}->{write} = 1;
        project::insert( $config, $entry );
        uac::print_info("project created");
    }
}

sub assign_studio {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_project_studio} == 1 ) {
        uac::permissions_denied('assign_project_studio');
        return;
    }

    for my $param ( 'pid', 'sid' ) {
        unless ( defined $params->{$param} ) {
            uac::print_error( 'missing ' . $param );
            return;
        }
    }
    local $config->{access}->{write} = 1;
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
    unless ( $permissions->{assign_project_studio} == 1 ) {
        uac::permissions_denied('assign_project_studio');
        return;
    }

    for my $param ( 'pid', 'sid' ) {
        unless ( defined $params->{$param} ) {
            uac::print_error( 'missing ' . $param );
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

    unless ( $permissions->{read_project} == 1 ) {
        uac::permissions_denied('read_project');
        return;
    }

    my $projects = project::get($config);
    my $studios  = studios::get($config);
    my @projects = reverse sort { $a->{end_date} cmp $b->{end_date} } (@$projects);
    $projects = \@projects;

    for my $project (@$projects) {

        # get assigned studios
        my $project_studio_assignements =
          project::get_studio_assignments( $config, { project_id => $project->{project_id} } );
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
            if ( defined $assigned_studio_by_id->{ $studio->{id} } ) {
                push @$assigned_studios, $studio;
            } else {
                push @$unassigned_studios, $studio;
            }
        }
        $project->{assigned_studios}   = $assigned_studios;
        $project->{unassigned_studios} = $unassigned_studios;

        if ( ( defined $params->{setImage} ) && ( $project->{pid} eq $params->{pid} ) ) {
            $project->{image} = $params->{setImage};
        }
    }

    $params->{projects} = $projects;
    $params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'projects' } );
    uac::set_template_permissions( $permissions, $params );

    template::process( $config, 'print', $params->{template}, $params );
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    #template
    my $template = '';
    $template = template::check( $config, $params->{template}, 'projects' );
    $checked->{template} = $template;

    $checked->{action} = entry::element_of($params->{action}, 
        ['save', 'delete', 'assign_studio', 'unassign_studio'] );

    entry::set_strings( $checked, $params, [
        'name', 'title', 'subtitle', 'start_date', 'end_date', 'image', 'email', 'setImage' ]);

    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id', 'default_studio_id', 'pid', 'sid']);
        
    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

