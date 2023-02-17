#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Scalar::Util qw( blessed );
use Try::Tiny;
use Exception::Class (
    'ParamError',
    'PermissionError'
);

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
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );
    print template::process( $config, template::check( $config, 'studios-header.html' ), $headerParams );
    uac::check($config, $params, $user_presets);

    if ( defined $params->{action} ) {
        save_studio( $config, $request ) if ( $params->{action} eq 'save' );
        delete_studio( $config, $request ) if ( $params->{action} eq 'delete' );
    }
    $config->{access}->{write} = 0;
    show_studios( $config, $request );
}

sub delete_studio {
    my ($config, $request) = @_;

    my $permissions = $request->{permissions};
    unless ( $permissions->{update_studio} == 1 ) {
        PermissionError->throw(error=>'Missing permission to update_studio');
        return;
    }

    my $params  = $request->{params}->{checked};
    my $columns = studios::get_columns($config);

    my $entry = {};
    for my $param ( keys %$params ) {
        if ( exists $columns->{$param} ) {
            $entry->{$param} = $params->{$param} || '';
        }
    }

    my $studio_id = $entry->{id} || '';
    if ( $studio_id ne '' ) {
        $config->{access}->{write} = 1;

        project::unassign_studio(
            $config,
            {
                project_id => $params->{project_id},
                studio_id  => $studio_id
            }
        );

        my $studio_assignments = project::get_studio_assignments(
            $config,
            {
                studio_id => $studio_id
            }
        );

        unless ( scalar @$studio_assignments == 0 ) {
            uac::print_info("Studio unassigned from project");
            uac::print_warn("Studio is assigned to other projects, so it will not be deleted");
            return undef;
        }
        studios::delete( $config, $entry );
        uac::print_info("Studio deleted");
    }
}

sub save_studio {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{update_studio} == 1 ) {
        PermissionError->throw(error=>'Missing permission to update_studio');
        return;
    }

    #filter entry for studio columns
    my $columns = studios::get_columns($config);
    my $entry   = {};
    for my $param ( keys %$params ) {
        if ( exists $columns->{$param} ) {
            $entry->{$param} = $params->{$param} || '';
        }
    }

    $config->{access}->{write} = 1;
    if ( ( defined $entry->{id} ) && ( $entry ne '' ) ) {
        studios::update( $config, $entry );
    } else {
        my $studios = studios::get( $config, { name => $entry->{name} } );
        if ( scalar @$studios > 0 ) {
            ExistError->throw(error=> "studio with name '$entry->{name}' already exists");
        }
        $entry->{id} = studios::insert( $config, $entry );

        project::assign_studio(
            $config,
            {
                project_id => $params->{project_id},
                studio_id  => $entry->{id}
            }
        );
    }

    #insert series for single events (if not already existing)
    my $studio_id     = $entry->{id};
    my $single_series = series::get(
        $config,
        {
            project_id        => $params->{project_id},
            studio_id         => $studio_id,
            has_single_events => 1
        }
    );
    if ( scalar @$single_series == 0 ) {
        series::insert(
            $config,
            {
                project_id        => $params->{project_id},
                studio_id         => $studio_id,
                has_single_events => 1,
                count_episodes    => 0,
                series_name       => '_single_',
                modified_by       => $params->{presets}->{user}
            }
        );
    }

    print qq{<div class="ok head">changes saved</div>};
}

sub show_studios {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $studios = studios::get(
        $config,
        {
            project_id => $params->{project_id}
        }
    );

    if ( $params->{setImage} ) {
        for my $studio (@$studios) {
            next unless $studio->{id} eq $params->{studio_id};
            $studio->{image} = $params->{setImage};
        }
    }

    $params->{studios} = $studios;
    $params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'studios' } );
    uac::set_template_permissions( $permissions, $params );

    print template::process( $config, $params->{template}, $params );
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    #template
    my $template = '';
    $template = template::check( $config, $params->{template}, 'studios' );
    $checked->{template} = $template;

    $checked->{action} = entry::element_of( $params->{action}, ['save', 'delete']);

    entry::set_strings( $checked, $params, [
        'name', 'description', 'location', 'stream', 'image', 'setImage' ]);

    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id', 'default_studio_id', 'id'
    ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

