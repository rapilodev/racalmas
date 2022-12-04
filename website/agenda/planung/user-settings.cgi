#! /usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Scalar::Util qw( blessed );
use Try::Tiny;

use config();
use entry();
use log();
use template();
use auth();
use entry();
use uac();
use project();
use studios();
use params();
use user_settings();
use user_default_studios();
use localization();

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );
    my $out = template::process( $config, template::check( $config, 'default.html' ), $headerParams );
    uac::check($config, $params, $user_presets);

    our $errors = [];

    if ( defined $params->{action} ) {
        return $out . update_settings( $config, $request ) if ( $params->{action} eq 'save' );
        return $out . updateDefaultProjectStudio( $config, $request )
          if ( $params->{action} eq 'updateDefaultProjectStudio' );
    }
    $config->{access}->{write} = 0;
    return $out . show_settings( $config, $request );
}

sub show_settings {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $user = $params->{presets}->{user};
    my $colors = user_settings::getColors( $config, { user => $user } );

    #map colors to params
    my @colors = ();
    my $c      = 0;
    for my $color (@$colors) {
        push @colors,
          {
            title => $color->{name},
            class => $color->{css},
            name  => 'color_' . $c,
            value => $color->{color}
          };
        $c++;
    }

    $params->{colors}      = \@colors;
    $params->{css}         = user_settings::getColorCss( $config, { user => $user } );
    $params->{permissions} = $permissions;

    my $user_settings = user_settings::get( $config, { user => $user } );
    my $language = $user_settings->{language} || 'en';
    $params->{language} = $language;
    $params->{ 'language_' . $language } = 1;

    my $period = $user_settings->{period} || 'month';
    $params->{ 'period_' . $period } = 1;

    $params->{loc} =
      localization::get( $config, { language => $language, file => 'user-settings' } );

    for my $color ( @{ $params->{colors} } ) {
        $color->{title} = $params->{loc}->{ $color->{title} };
    }

    uac::set_template_permissions( $permissions, $params );

    return template::process( $config, $params->{template}, $params );
}

sub updateDefaultProjectStudio {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    my $user        = $params->{presets}->{user};

    my $entry = {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
    };

    $config->{access}->{write} = 1;
    if (
        defined user_settings::get(
            $config,
            { user => $user }
        )
      )
    {
        uac::print_info("update project and studio settings");
        user_settings::update( $config, $entry );
    } else {
        uac::print_info("insert user settings, as missing on updating default project and studio");
        update_settings( $config, $request );
    }

    if (
        defined user_default_studios::get(
            $config,
            {
                user       => $user,
                project_id => $params->{project_id}
            }
        )
      )
    {
        uac::print_info("update user default studio");
        user_default_studios::update( $config, $entry );
    } else {
        uac::print_info("insert user default studio");
        user_default_studios::insert( $config, $entry );
    }

    $config->{access}->{write} = 0;
}

sub update_settings {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    my $user        = $params->{presets}->{user};

    # map params to colors
    my @colors = ();
    my $c      = 0;
    for my $color ( @{$user_settings::defaultColors} ) {
        if ( defined $params->{ 'color_' . $c } ) {
            push @colors, $color->{css} . '=' . $params->{ 'color_' . $c };
        } else {
            push @colors, $color->{css} . '=' . $color->{color};
        }
        $c++;
    }

    my $settings = {
        user     => $user,
        colors   => join( "\n", @colors ),
        language => $params->{language},
        period   => $params->{period},
    };

    my $results = user_settings::get( $config, { user => $user } );
    if ( defined $results ) {
        uac::print_info("update user settings");
        $config->{access}->{write} = 1;
        user_settings::update( $config, $settings );
    } else {
        $config->{access}->{write} = 1;
        uac::print_info("insert user settings");
        $settings->{project_id} = $params->{project_id};
        $settings->{studio_id}  = $params->{studio_id};
        user_settings::insert( $config, $settings );
    }
    $config->{access}->{write} = 0;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    #template
    my $template = '';
    $template = template::check( $config, $params->{template}, 'user-settings' );
    $checked->{template} = $template;

    #numeric values
    entry::set_numbers( $checked, $params, [
        'project_id', 'default_studio_id', 'studio_id', 'default_studio',
        'default_project' ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    for my $param ( keys %$params ) {
        if ( ( defined $params->{$param} ) && ( $param =~ /^(color\_\d+)$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }

    $checked->{language} = 'en';
    if ( ( defined $params->{language} ) && ( $params->{language} =~ /^de$/ ) ) {
        $checked->{language} = 'de';
    }

    if ( defined $params->{period} ) {
        if ( $params->{period} =~ /(\S+)/ ) {
            $checked->{period} = $1;
        }
    }

    $checked->{action} = entry::element_of( $params->{action}, ['save', 'updateDefaultProjectStudio']);
    return $checked;
}

