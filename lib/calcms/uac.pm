package uac;

use strict;
use warnings;
no warnings 'redefine';

use CGI::Session qw(-ip-match);
use CGI::Cookie();
use Data::Dumper;
use auth();
use db();
use template();
use project();
use studios();
use user_settings();
use user_default_studios();

use base 'Exporter';
our @EXPORT_OK = qw(
  get_user get_users update_user insert_user delete_user
  get_roles insert_role update_role  get_role_columns
  get_studios_by_user get_users_by_studio
  get_projects_by_user
  get_user_role get_studio_roles
  assign_user_role remove_user_role
  get_user_permissions get_user_presets
  prepare_request set_template_permissions
  permission_denied
);

sub debug;

# get user by name
sub get_user($$) {
    my $config = shift;
    my $user   = shift;

    my $query = qq{
		select	id, name, full_name, email, disabled, modified_at, created_at
		from 	calcms_users
		where 	name=?
	};
    my $bind_values = [$user];

    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, $bind_values );
    if ( scalar @$users != 1 ) {
        print STDERR "cannot find user '$user'\n";
        return undef;
    }
    return $users->[0];
}

# get all users
sub get_users($;$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    for my $key ( 'name', 'email' ) {
        my $value = $condition->{$key};
        next unless defined $value;
        next if $value eq '';
        push @conditions,  $key . '=?';
        push @bind_values, $value;
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if ( scalar @conditions > 0 );

    my $query = qq{
		select	id, name, full_name, email, disabled, modified_at, created_at
		from 	calcms_users
        $conditions
	};

    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, \@bind_values );
    return $users;
}

#TODO: get_users_by_project

# get all users of a given studio id
# used at series (previously named get_studio_users)
sub get_users_by_studio ($$) {
    my $config    = shift;
    my $condition = shift;

    return unless ( defined $condition->{studio_id} );

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'ur.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'ur.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if ( scalar @conditions > 0 );

    my $query = qq{
		select	distinct(u.id), u.name, u.full_name
		from 	calcms_user_roles ur, calcms_users u
		where 	ur.user_id=u.id
		$conditions
	};

    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, \@bind_values );
    return $users;
}

# get projects a user is assigned by name
sub get_projects_by_user ($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'ur.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'ur.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'u.name=?';
        push @bind_values, $condition->{user};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	distinct p.*, ur.project_id project_id
		from 	calcms_user_roles ur, calcms_users u, calcms_projects p
		where 	ur.user_id=u.id and p.project_id=ur.project_id
        $conditions
	};

    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, \@bind_values );
    return $users;
}

# get all studios a user is assigned to by role
# used at series (previously named get_user_studios)
sub get_studios_by_user ($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'ur.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'ur.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'u.name=?';
        push @bind_values, $condition->{user};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	distinct s.*, ur.project_id project_id
		from 	calcms_user_roles ur, calcms_users u, calcms_studios s
		where 	ur.user_id=u.id and s.id=ur.studio_id
        $conditions
	};
    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, \@bind_values );
    return $users;
}

sub insert_user($$) {
    my $config = shift;
    my $entry  = shift;

    $entry->{created_at}  = time::time_to_datetime( time() );
    $entry->{modified_at} = time::time_to_datetime( time() );

    my $dbh = db::connect($config);
    db::insert( $dbh, 'calcms_users', $entry );
}

sub update_user($$) {
    my $config = shift;
    my $entry  = shift;

    $entry->{modified_at} = time::time_to_datetime( time() );

    my @keys = sort keys %$entry;
    my $values = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{id};

    my $query = qq{
		update calcms_users
		set $values
		where id=?
	};

    my $dbh = db::connect($config);
    db::put( $dbh, $query, \@bind_values );
}

sub delete_user($$) {
    my $config = shift;
    my $id     = shift;
    return unless ( defined $id && ( $id =~ /^\d+$/ ) );

    my $query = qq{
		delete from calcms_users
		where id=?
	};
    my $dbh = db::connect($config);
    db::put( $dbh, $query, [$id] );
}

# get all roles used by all users of a studio
# available conditions: project_id, studio_id
sub get_studio_roles($$) {
    my $config    = shift;
    my $condition = shift;

    return [] if ( $condition->{studio_id} eq '' );

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'ur.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'ur.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	r.*, ur.studio_id, ur.project_id
		from 	calcms_roles r, calcms_user_roles ur
		where 	r.id=ur.role_id 
		$conditions
	};

    my $dbh = db::connect($config);
    my $roles = db::get( $dbh, $query, \@bind_values );
    return $roles;
}

# get role columns (for external use only)
sub get_role_columns($) {
    my $config  = shift;
    my $dbh     = db::connect($config);
    my $columns = db::get_columns_hash( $dbh, 'calcms_roles' );
    return $columns;
}

# get roles
# filter: studio_id project_id
sub get_roles($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    my $dbh = db::connect($config);
    my $columns = db::get_columns_hash( $dbh, 'calcms_roles' );

    for my $column ( sort keys %$columns ) {
        if ( defined $condition->{$column} ) {
            push @conditions,  $column . '=?';
            push @bind_values, $condition->{$column};
        }
    }
    my $conditions = '';
    $conditions = ' where ' . join( ' and ', @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	r.*
		from 	calcms_roles r
		$conditions
	};

    my $roles = db::get( $dbh, $query, \@bind_values );

    return $roles;
}

#insert role to database, set created_at and modified_at
sub insert_role ($$) {
    my $config = shift;
    my $entry  = shift;

    $entry->{created_at}  = time::time_to_datetime( time() );
    $entry->{modified_at} = time::time_to_datetime( time() );

    my $dbh     = db::connect($config);
    my $columns = db::get_columns_hash( $dbh, 'calcms_roles' );
    my $role    = {};
    for my $column ( keys %$columns ) {
        $role->{$column} = $entry->{$column} if defined $entry->{$column};
    }
    db::insert( $dbh, 'calcms_roles', $role );
}

#update role, set modified_at
sub update_role($$) {
    my $config = shift;
    my $entry  = shift;

    $entry->{modified_at} = time::time_to_datetime( time() );

    my $dbh         = db::connect($config);
    my $columns     = db::get_columns_hash( $dbh, 'calcms_roles' );
    my @keys        = sort keys %$columns;
    my $values      = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{id};

    my $query = qq{
		update calcms_roles 
		set $values
		where id=?
	};

    db::put( $dbh, $query, \@bind_values );
}

# delete role from database
sub delete_role($$) {
    my $config = shift;
    my $id     = shift;

    return unless ( defined $id && ( $id =~ /^\d+$/ ) );

    my $query = qq{
		delete from calcms_roles 
		where id=?
	};
    my $dbh = db::connect($config);
    db::put( $dbh, $query, [$id] );
}

# get all roles for given conditions: project_id, studio_id, user_id, name
# includes global admin user role
sub get_user_roles($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    if ( defined $condition->{user} ) {
        push @conditions,  'u.name=?';
        push @bind_values, $condition->{user};
    }
    if ( defined $condition->{user_id} ) {
        push @conditions,  'ur.user_id=?';
        push @bind_values, $condition->{user_id};
    }
    if ( defined $condition->{studio_id} ) {
        push @conditions,  'ur.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }
    if ( defined $condition->{project_id} ) {
        push @conditions,  'ur.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	distinct r.*
		from 	calcms_users u, calcms_user_roles ur, calcms_roles r
		where 	ur.user_id=u.id and ur.role_id=r.id 
			$conditions
	};

    my $dbh = db::connect($config);
    my $user_roles = db::get( $dbh, $query, \@bind_values );

    #return roles, if the contain an admin role
    for my $role (@$user_roles) {
        return $user_roles if $role->{role} eq 'Admin';
    }

    #get all admin roles
    delete $condition->{studio_id}  if defined $condition->{studio_id};
    delete $condition->{project_id} if defined $condition->{project_id};
    my $admin_roles = get_admin_user_roles( $config, $condition );

    #add admin roles to user roles
    my @user_roles = ( @$admin_roles, @$user_roles );
    $user_roles = \@user_roles;

    return $user_roles;
}

#return admin user roles for given conditions: project_id, studio_id, user, user_id
sub get_admin_user_roles ($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'u.name=?';
        push @bind_values, $condition->{user};
    }
    if ( ( defined $condition->{user_id} ) && ( $condition->{user_id} ne '' ) ) {
        push @conditions,  'ur.user_id=?';
        push @bind_values, $condition->{user_id};
    }
    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'ur.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }
    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'ur.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	distinct r.*, ur.studio_id, ur.project_id
		from 	calcms_users u, calcms_user_roles ur, calcms_roles r
		where 	ur.user_id=u.id and ur.role_id=r.id and r.role='Admin' 
			$conditions
		limit 1
	};

    my $dbh = db::connect($config);
    my $user_roles = db::get( $dbh, $query, \@bind_values );
    return $user_roles;
}

# read permissions for given conditions and add to user_permissions
# return user_permissions
# studio_id, user_id, name
sub get_user_permissions ($$;$) {
    my $config           = shift;
    my $conditions       = shift;
    my $user_permissions = shift;

    my $user_roles = get_user_roles( $config, $conditions );
    my $admin_roles = get_admin_user_roles( $config, $conditions );
    my @user_roles = ( @$admin_roles, @$user_roles );

    #set default permissions
    $user_permissions = {} unless defined $user_permissions;
    $user_permissions->{is_admin} = 1 if scalar @$admin_roles > 0;

    my $max_level = 0;

    # aggregate max permissions
    # should be limited by project and studio
    for my $user_role (@user_roles) {
        if ( $user_role->{level} > $max_level ) {
            $user_permissions->{level}      = $user_role->{level};
            $user_permissions->{id}         = $user_role->{id};
            $user_permissions->{role}       = $user_role->{role};
            $user_permissions->{studio_id}  = $user_role->{studio_id};
            $user_permissions->{project_id} = $user_role->{project_id};
            $max_level                      = $user_role->{level};
        }
        for my $permission ( keys %$user_role ) {
            if (   ( $permission ne 'level' )
                && ( $permission ne 'id' )
                && ( $permission ne 'role' )
                && ( $permission ne 'studio_id' )
                && ( $permission ne 'project_id' ) )
            {
                $user_permissions->{$permission} = 1
                  if ( defined $user_role->{$permission} ) && ( $user_role->{$permission} ne '0' );
            }
        }
    }
    return $user_permissions;
}

#get user id by user name
sub get_user_id ($$) {
    my $config = shift;
    my $user   = shift;

    return undef unless ( defined $user );

    my $query = qq{
		select	id
		from 	calcms_users
		where 	binary name=?
	};
    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, [$user] );
    return undef if scalar @$users == 0;
    return $users->[0]->{id};
}

#get role id by role name
sub get_role_id ($$) {
    my $config = shift;
    my $role   = shift;

    return undef unless ( defined $role );

    my $query = qq{
		select	id
		from 	calcms_roles
		where 	role=?
	};
    my $dbh = db::connect($config);
    my $roles = db::get( $dbh, $query, [$role] );
    return undef if scalar @$roles == 0;
    return $roles->[0]->{id};
}

# assign a role to an user (for a studio)
sub assign_user_role($$) {
    my $config  = shift;
    my $options = shift;

    return undef unless defined $options->{project_id};
    return undef unless defined $options->{studio_id};
    return undef unless defined $options->{user_id};
    return undef unless defined $options->{role_id};

    #return if already exists
    my $query = qq{
		select	*
		from 	calcms_user_roles
		where 	project_id=? and studio_id=? and user_id=? and role_id=?
	};
    my $dbh        = db::connect($config);
    my $user_roles = db::get( $dbh, $query,
        [ $options->{project_id}, $options->{studio_id}, $options->{user_id}, $options->{role_id} ] );
    return undef if scalar @$user_roles > 0;

    #insert entry
    my $entry = {
        project_id => $options->{project_id},
        studio_id  => $options->{studio_id},
        user_id    => $options->{user_id},
        role_id    => $options->{role_id},
        created_at => time::time_to_datetime( time() )
    };

    return db::insert( $dbh, 'calcms_user_roles', $entry );
}

# unassign a user from a role of (for a studio)
sub remove_user_role($$) {
    my $config  = shift;
    my $options = shift;

    return undef unless defined $options->{project_id};
    return undef unless defined $options->{studio_id};
    return undef unless defined $options->{user_id};
    return undef unless defined $options->{role_id};

    my $query = qq{
		delete
		from 	calcms_user_roles
		where 	project_id=? and studio_id=? and user_id=? and role_id=?
	};
    my $bind_values = [ $options->{project_id}, $options->{studio_id}, $options->{user_id}, $options->{role_id} ];

    my $dbh = db::connect($config);
    my $result = db::put( $dbh, $query, $bind_values );
    # successfully return  even if no entry exists
    return 1;
}

#checks
sub is_user_assigned_to_studio ($$) {
    my $request = shift;
    my $options = shift;

    my $config = $request->{config};

    return 0 unless defined $request->{user};
    return 0 unless defined $options->{studio_id};
    return 0 unless defined $options->{project_id};

    my $options2 = {
        user       => $request->{user},
        studio_id  => $options->{studio_id},
        project_id => $options->{project_id}
    };

    my $user_studios = uac::get_studios_by_user( $config, $options2 );
    return 1 if scalar @$user_studios == 1;
    return 0;
}

# print errors at get_user_presets and check for project id and studio id
# call after header is printed
sub check($$$) {
    my $config       = shift;
    my $params       = shift;
    my $user_presets = shift;

    if ( defined $user_presets->{error} ) {
        uac::print_error( $user_presets->{error} );
        return 0;
    }

    my $project_check = project::check( $config, { project_id => $params->{project_id} } );
    if ( $project_check ne '1' ) {
        uac::print_error($project_check);
        return 0;
    }

    my $studio_check = studios::check( $config, { studio_id => $params->{studio_id} } );
    if ( $studio_check ne '1' ) {
        uac::print_error($studio_check);
        return 0;
    }
    return 1;
}

# get user, projects and studios user is assigned to for selected values from params
# set permissions for selected project and studio
# return request
sub get_user_presets($$) {
    my $config  = shift;
    my $options = shift;

    my $user = $options->{user} || '';
    my $error = undef;
    return { error => "no user selected" } if ( $user eq '' );

    my $project_id = $options->{project_id} || '';
    my $studio_id  = $options->{studio_id}  || '';
    $config->{access}->{write} = 0;

    my $user_settings = user_settings::get( $config, { user => $user } );
    $project_id = $user_settings->{project_id} // '' if $project_id eq '';
    my $defaults = user_default_studios::get( $config, { user => $user, project_id => $project_id } );
    $studio_id = $defaults->{studio_id} // $user_settings->{studio_id}  // '' if $studio_id eq '';

    #get
    my $admin_roles = get_admin_user_roles( $config, { user => $user } );

    #get all projects by user
    my $projects = uac::get_projects_by_user( $config, { user => $user } );
    return { error => "no project is assigned to user" } if scalar @$projects == 0;

    $projects = project::get($config) if ( @$admin_roles > 0 );
    my @projects = reverse sort { $a->{end_date} cmp $b->{end_date} } (@$projects);
    $projects = \@projects;

    if ( $project_id ne '' && $project_id ne '-1' ) {
        my $projectFound = 0;
        for my $project (@$projects) {
            if ( $project->{project_id} eq $project_id ) {
                $projectFound = 1;
                last;
            }
        }
        return { error => "project is not assigned to user" } if ( $projectFound == 0 );
    } else {
        $project_id = $projects->[0]->{project_id};
    }

    #check if studios are assigned to project
    my $studios = project::get_studios( $config, { project_id => $project_id } );
    $error = "no studio is assigned to project" if scalar @$studios == 0;

    if ( scalar @$admin_roles == 0 ) {

        #get all studios by user
        $studios = uac::get_studios_by_user( $config, { user => $user, project_id => $project_id } );
        $error = "no studio is assigned to user" if scalar @$studios == 0;
        if ( ( $studio_id ne '' ) && ( $studio_id ne '-1' ) ) {
            my $studioFound = 0;
            for my $studio (@$studios) {
                if ( $studio->{id} eq $studio_id ) {
                    $studioFound = 1;
                    last;
                }
            }
            $error = "studio is not assigned to user" if ( $studioFound == 0 );
        } else {
            $studio_id = $studios->[0]->{id} unless defined $studio_id;
        }
    } else {

        #for admin get studios by project
        $studios = studios::get( $config, { project_id => $project_id } );
        if ( ( $studio_id ne '' ) && ( $studio_id ne '-1' ) ) {
            my $studioFound = 0;
            for my $studio (@$studios) {
                if ( $studio->{id} eq $studio_id ) {
                    $studioFound = 1;
                    last;
                }
            }
            $error = "studio is not assigned to project" if ( $studioFound == 0 );
        } else {
            $studio_id = $studios->[0]->{id} unless defined $studio_id;
        }
    }

    my $permissions =
      uac::get_user_permissions( $config, { user => $user, project_id => $project_id, studio_id => $studio_id } );

    #only admin is allowed to select all projects
    #    if($permissions->{is_admin}==1){
    #        $projects=project::get($config);
    #    }

    #set studios and projects as selected, TODO:do in JS
    my $selectedProject = {};
    for my $project (@$projects) {
        if ( $project_id eq $project->{project_id} ) {
            $project->{selected} = 'selected="selected"';
            $selectedProject = $project;
            last;
        }
    }

    my $selectedStudio = {};
    for my $studio (@$studios) {
        if ( $studio_id eq $studio->{id} ) {
            $studio->{selected} = 'selected="selected"';
            $selectedStudio = $studio;
            last;
        }
    }

    my $logout_url = ( split( /\//, $0 ) )[-1];

    my $result = {
        user       => $user,
        logout_url => $logout_url,

        project_id => $project_id,        # from parameter or default
        projects   => $projects,
        project    => $selectedProject,

        studio_id => $studio_id,          # from parameter or default
        studios   => $studios,
        studio    => $selectedStudio,

        permissions => $permissions,      # from parameter or default
        config      => $config
    };
    $result->{error} = $error if defined $error;
    return $result;
}

sub setDefaultProject ($$) {
    my $params       = shift;
    my $user_presets = shift;

    $params->{project_id} = $user_presets->{project_id}
      if ( !defined $params->{authAction} ) || ( $params->{authAction} eq '' ) || ( $params->{authAction} eq 'login' );
    return $params;
}

sub setDefaultStudio($$) {
    my $params       = shift;
    my $user_presets = shift;

    $params->{studio_id} = $user_presets->{studio_id}
      if ( !defined $params->{authAction} ) || ( $params->{authAction} eq '' ) || ( $params->{authAction} eq 'login' );
    return $params;
}

#set user preset properties to request
sub prepare_request ($$) {
    my $request      = shift;
    my $user_presets = shift;

    for my $key ( keys %$user_presets ) {
        $request->{$key} = $user_presets->{$key};
    }

    #enrich menu parameters
    for my $key ( 'studio_id', 'project_id', 'studio', 'project', 'studios', 'projects', 'user', 'logout_url' ) {
        $request->{params}->{checked}->{presets}->{$key} = $user_presets->{$key};
    }
    return $request;
}

#TODO: shift to permissions sub entry
sub set_template_permissions ($$) {
    my $permissions = shift;
    my $params      = shift;

    for my $usecase ( keys %$permissions ) {
        $params->{'allow'}->{$usecase} = 1 if ( $permissions->{$usecase} eq '1' );
    }
    return $params;
}

#print error message
sub permissions_denied($) {
    my $message = shift;
    $message =~ s/_/ /g;
    print '<div class="error">Sorry! Missing permissions to ' . $message . '</div>' . "\n";
    print STDERR 'Sorry! Missing permissions to ' . $message . "\n";
}

sub print_info($) {
    print '<div class="ok head">'
      . '<span class="ui-icon ui-icon-check" style="float:left"></span>&nbsp;'
      . $_[0]
      . '</div>' . "\n";
}

sub print_warn($) {
    print '<div class="warn head">'
      . '<span class="ui-icon ui-icon-info" style="float:left"></span>&nbsp;'
      . $_[0]
      . '</div>' . "\n";
}

sub print_error ($) {
    my $message = shift;
    print STDERR "ERROR:" . $message . "\n";
    print '<div class="error" head>'
      . '<span class="ui-icon ui-icon-alert" style="float:left"></span>&nbsp;'
      . $message
      . '</div>' . "\n";
}

#do not delete last line!
1;
