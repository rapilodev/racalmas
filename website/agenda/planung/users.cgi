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
use studios();
use params();
use localization();
use password_requests();

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

if ( defined $params->{action} ) {
    update_user_roles( $config, $request ) if ( $params->{action} eq 'assign' );
    update_user( $config, $request ) if ( $params->{action} eq 'save' );
    delete_user( $config, $request ) if ( $params->{action} eq 'delete' );
    if ( $params->{action} eq 'change_password' ) {
        change_password( $config, $request, $user );
        $config->{access}->{write} = 0;
        return;
    }
}
$config->{access}->{write} = 0;
show_users( $config, $request );

sub show_users {
    my $config  = shift;
    my $request = shift;

    my $params = $request->{params}->{checked};

    my $permissions = $request->{permissions};

    unless ( ( defined $permissions->{read_user} ) && ( $permissions->{read_user} == 1 ) ) {
        uac::permissions_denied('read_user');
        return;
    }

    my $max_level  = $permissions->{level};
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #TODO: get from presets
    my $studios = studios::get( $config, { project_id => $project_id } );
    my $users   = uac::get_users($config);
    my $roles   = uac::get_roles(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id
        }
    );

    #	print "max level:$max_level<br>";

    #user roles
    for my $user (@$users) {
        $user->{disabled_checked} = 'selected="selected"' if ( $user->{disabled} eq '1' );

        my $user_roles = uac::get_user_roles(
            $config,
            {
                user       => $user->{name},
                project_id => $project_id,
                studio_id  => $studio_id
            }
        );
        my @user_roles = ( map { { role => $_->{role} } } @$user_roles );

        $user->{user_roles} = \@user_roles;

        #mark all roles assigned to user
        my $has_roles        = 0;
        my @assignable_roles = ();
        for my $role ( reverse sort { $a->{level} <=> $b->{level} } @$roles ) {

            #next if ($role->{level}>$max_level);
            $role->{assigned} = 0;
            my %role = %$role;
            for my $user_role (@user_roles) {
                if ( $role->{role} eq $user_role->{role} ) {
                    $role{assigned} = 1;

                    #					print "if ($role->{role} eq $user_role->{role}<br>";
                    $has_roles = 1;
                    last;
                }
            }
            push @assignable_roles, \%role;
        }
        $user->{has_roles}  = $has_roles;
        $user->{roles}      = \@assignable_roles;
        $user->{studio_id}  = $studio_id;
        $user->{project_id} = $project_id;
        uac::set_template_permissions( $permissions, $user );
    }

    my $sort_by = 'name';
    my @users = sort { lc( $a->{$sort_by} ) cmp lc( $b->{$sort_by} ) } @$users;

    my @users_with_roles    = ();
    my @users_without_roles = ();
    for my $user (@users) {
        if ( $user->{has_roles} == 1 ) {
            push @users_with_roles, $user;
        } else {
            push @users_without_roles, $user;
        }
    }

    if ( $permissions->{update_user_role} == 1 ) {
        @users = ( @users_with_roles, @users_without_roles );
    } else {
        @users = (@users_with_roles);
    }

    $params->{users}       = \@users;
    $params->{studios}     = $studios;
    $params->{permissions} = $permissions;
    $params->{errors}      = $errors;
    $params->{loc}         = localization::get( $config, { user => $params->{presets}->{user}, file => 'users' } );
    uac::set_template_permissions( $permissions, $params );

    template::process( $config, 'print', $params->{template}, $params );

}

sub update_user {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $user = {
        full_name => $params->{user_full_name},
        email     => $params->{user_email},
        id        => $params->{user_id}
    };
    $user->{name} = $params->{user_name} if ( ( defined $params->{user_name} ) && ( $params->{user_name} ne '' ) );

    if ( $permissions->{disable_user} == 1 ) {
        $user->{disabled} = $params->{disabled} || 0;
    }

    if ( ( !defined $user->{id} ) || ( $user->{id} eq '' ) ) {
        unless ( $permissions->{create_user} == 1 ) {
            uac::permissions_denied('create_user');
            return;
        }

        my $users = uac::get_users( $config, { email => $params->{user_email} } );
        if ( scalar(@$users) > 0 ) {

            error('There is already a user registered for the given email address');
            return;
        }

        return unless password_requests::checkPassword( $params->{user_password} );

        if ( $params->{user_password} ne $params->{user_password2} ) {
            error('password mismatch');
            return;
        }
        my $crypt = auth::crypt_password( $params->{user_password} );
        $user->{salt} = $crypt->{salt};
        $user->{pass} = $crypt->{crypt};

        $user->{created_at}  = time::time_to_datetime( time() );
        $user->{modified_at} = time::time_to_datetime( time() );
        $user->{created_by}  = $params->{presets}->{user};

        $config->{access}->{write} = 1;
        uac::insert_user( $config, $user );
    } else {
        unless ( $permissions->{update_user} == 1 ) {
            uac::permissions_denied('update_user');
            return;
        }
        $user->{modified_at} = time::time_to_datetime( time() );
        $config->{access}->{write} = 1;
        uac::update_user( $config, $user );
    }
}

sub change_password {
    my $config   = shift;
    my $request  = shift;
    my $userName = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $result = password_requests::changePassword( $config, $request, $userName );

    $params->{errors} = $result->{error}   if defined $result->{error};
    $params->{info}   = $result->{success} if defined $result->{success};
    $params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'users' } );
    uac::set_template_permissions( $permissions, $params );

    template::process( $config, 'print', template::check( $config, 'change-password' ), $params );
}

sub delete_user {
    my $config  = shift;
    my $request = shift;

    my $permissions = $request->{permissions};
    unless ( $permissions->{delete_user} == 1 ) {
        uac::permissions_denied('delete_user');
        return;
    }

    $config->{access}->{write} = 1;
    my $params = $request->{params}->{checked};
    uac::delete_user( $config, $params->{user_id} );
}

# add or remove user from role for given studio_id
# todo: assign/unassign role oly if max(change user rank) is < max(users rank)
sub update_user_roles {
    my $config  = shift;
    my $request = shift;

    my $permissions = $request->{permissions};
    unless ( $permissions->{update_user_role} == 1 ) {
        uac::permissions_denied('update_user_role');
        return;
    }
    my $params     = $request->{params}->{checked};
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};
    my $user_id    = $params->{user_id} || '';

    #	return undef if ($user_id eq '');

    #get all roles
    my $roles = uac::get_roles(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id
        }
    );

    #get roles for the selected user
    my $user_roles = uac::get_user_roles(
        $config,
        {
            project_id => $project_id,
            studio_id  => $studio_id,
            user_id    => $user_id
        }
    );

    #maximum level of the user who wants to perform the update (given by $permissions)
    my $max_level = $permissions->{level};

    #maximum level of the user to be changed (given by $user_id)
    my $max_user_level = 0;

    #get all roles by id
    my $role_by_id = {};
    for my $role (@$roles) {
        $role_by_id->{ $role->{id} } = $role;
    }

    #get user role by id
    my $user_role_by_id = {};
    for my $role (@$user_roles) {
        $user_role_by_id->{ $role->{id} } = $role;
        $max_user_level = $role->{level} if $max_user_level < $role->{level};
    }

    $config->{access}->{write} = 1;

    #remove unchecked user roles
    for my $user_role_id ( keys %$user_role_by_id ) {
        my $user_role = $user_role_by_id->{$user_role_id};
        my $role      = $role_by_id->{$user_role_id};

        #		print "$user_role_id - $params->{role_ids}->{$user_role_id} ($studio_id)<br>";
        unless ( defined $params->{role_ids}->{$user_role_id} ) {
            my $message =
"remove role '$role->{role}' (level $role->{level}) from user $user_id (level $max_user_level) for studio_id=$studio_id, project_id=$project_id. Your level is $max_level";
            my $update = 0;
            $update = 1 if defined $permissions->{is_admin};
            $update = 1
              if ( ( $role_by_id->{ $user_role->{role_id} }->{level} < $max_level )
                && ( $max_user_level < $max_level ) );
            if ( $update == 0 ) {
                uac::permissions_denied($message);
                next;
            }
            my $result = uac::remove_user_role(
                $config,
                {
                    project_id => $project_id,
                    studio_id  => $studio_id,
                    user_id    => $user_id,
                    role_id    => $user_role_id
                }
            );
            unless ( defined $result ) {
                uac::print_error("missing parameter on remove user role");
                return;
            }
            if ( $result == 0 ) {
                uac::print_error("no changes");
                return;
            }
            uac::print_info($message);
        }
    }

    #insert/update user roles
    for my $role_id ( keys %{ $params->{role_ids} } ) {
        my $role = $role_by_id->{$role_id};
        unless ( defined $user_role_by_id->{$role_id} ) {
            my $message =
"assign role $role->{role} (level $role->{level}) to user (level $max_user_level). Your level is $max_level";

            #			print "user role id: $role->{id}<br>\n";
            my $update = 0;
            $update = 1 if defined $permissions->{is_admin};
            $update = 1
              if ( ( $role_by_id->{ $role->{id} }->{level} < $max_level )
                && ( $max_user_level < $max_level ) );
            if ( $update == 0 ) {
                uac::permissions_denied($message);
                next;
            }
            uac::assign_user_role(
                $config,
                {
                    project_id => $project_id,
                    studio_id  => $studio_id,
                    user_id    => $user_id,
                    role_id    => $role_id
                }
            );
            uac::print_info($message);
        }
    }
    $config->{access}->{write} = 0;
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    #template
    my $template = '';
    $template = template::check( $config, $params->{template}, 'users' );
    $checked->{template} = $template;

    #numeric values
    for my $param ( 'project_id', 'user_id', 'default_studio_id', 'studio_id', 'disabled' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }
    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    for my $param ( 'user_name', 'user_full_name', 'user_email' ) {
        if ( defined $params->{$param} ) {
            my $value = $params->{$param};
            $value =~ s/^\s+//g;
            $value =~ s/\s+$//g;
            $checked->{$param} = $value;
        }
    }

    for my $param ( 'user_password', 'user_password2' ) {
        if ( defined $params->{$param} ) {
            $checked->{$param} = $params->{$param};
        }
    }

    #actions and roles
    if ( defined $params->{action} ) {
        if ( $params->{action} =~ /^(save|assign|delete|change_password)$/ ) {
            $checked->{action} = $params->{action};
        }

        if ( $params->{action} eq 'assign' ) {
            $checked->{action} = $params->{action};
            for my $param ( keys %$params ) {
                $checked->{role_ids}->{$1} = 1 if ( $param =~ /^role_(\d+)$/ );
            }
        }
    }

    return $checked;
}

sub error {
    push @$errors, { error => $_[0] };
}

