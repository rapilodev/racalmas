package uac;

use strict;
use warnings;
no warnings 'redefine';

use Scalar::Util qw( blessed );
use JSON;
use Try::Tiny qw(try catch finally);
use CGI::Session qw(-ip-match);
use CGI::Cookie();
use Data::Dumper;
use List::Util qw(none all);

use auth();
use params();
use db();
use template();
use project();
use studios();
use user_settings();
use user_default_studios();

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

# get user by name
sub get_user($$) {
    my ($config, $user) = @_;

    my $query = qq{
		select	id, name, full_name, email, disabled, modified_at, created_at
		from 	calcms_users
		where 	name=?
	};
    my $bind_values = [$user];

    my $dbh = db::connect($config);
    my $users = db::get( $dbh, $query, $bind_values );
    UserError->throw(error => "cannot find user '$user'\n") if scalar @$users != 1;
    return $users->[0];
}

# get all users
sub get_users($;$) {
    my ($config, $condition) = @_;

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
    my ($config, $condition) = @_;
    return unless defined $condition->{studio_id};

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
    my ($config, $condition) = @_;

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
    my ($config, $condition) = @_;

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
    my ($config, $entry) = @_;

    $entry->{created_at}  = time::time_to_datetime( time() );
    $entry->{modified_at} = time::time_to_datetime( time() );

    my $dbh = db::connect($config);
    db::insert( $dbh, 'calcms_users', $entry );
}

sub update_user($$) {
    my ($config, $entry) = @_;

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
    my ($config, $id) = @_;
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
    my ($config, $condition) = @_;

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
    my ($config) = @_;
    my $dbh     = db::connect($config);
    my $columns = db::get_columns_hash( $dbh, 'calcms_roles' );
    return $columns;
}

# get roles
# filter: studio_id project_id
sub get_roles($$) {
    my ($config, $condition) = @_;

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
    my ($config, $entry) = @_;

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
    my ($config, $entry) = @_;

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
    my ($config, $id) = @_;

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
    my ($config, $condition) = @_;

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
    return [@$admin_roles, @$user_roles];
}

#return admin user roles for given conditions: project_id, studio_id, user, user_id
sub get_admin_user_roles ($$) {
    my ($config, $condition) = @_;

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
		where 	ur.user_id=u.id and ur.role_id=r.id and r.admin=1
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
    my ($config, $conditions, $user_permissions) = @_;

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
    my ($config, $user) = @_;
    return undef unless defined $user;

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
    my ($config, $role) = @_;
    return undef unless defined $role;

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
    my ($config, $options) = @_;

    for ('project_id', 'studio_id', 'user_id', 'role_id') {
        ParamError->throw(error=>"assign_user_role: missing $_") unless defined $options->{$_}
    }

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
    my ($config, $options) = @_;

    for ('project_id', 'studio_id', 'user_id', 'role_id') {
        ParamError->throw(error=>"remove_user_role: missing $_") unless defined $options->{$_}
    }

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
    my ($request, $options) = @_;

    my $config = $request->{config};
    for ('project_id', 'studio_id') {
        ParamError->throw(error=>"is_user_assigned_to_studio: missing $_") unless defined $options->{$_}
    }
    ParamError->throw(error=>"is_user_assigned_to_studio: missing user") unless defined $request->{user};

    my $user_studios = uac::get_studios_by_user( $config, {
        user       => $request->{user},
        studio_id  => $options->{studio_id},
        project_id => $options->{project_id}
    });
    return (@$user_studios == 1);
}

# print errors at get_user_presets and check for project id and studio id
# call after header is printed
sub check($$$) {
    my ($config, $params, $user_presets) = @_;
    project::check( $config, { project_id => $params->{project_id} } );
    studios::check( $config, { studio_id => $params->{studio_id} } );
}

# get user, projects and studios user is assigned to for selected values from params
# set permissions for selected project and studio
# return request
sub get_user_presets($$) {
    my ($config, $options) = @_;

    my $user = $options->{user} || '';
    UacError->throw(error => "no user selected") if $user eq '';

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
    UacError->throw(error => "no project is assigned to user") if scalar @$projects == 0;

    $projects = project::get($config) if ( @$admin_roles > 0 );
    my @projects = reverse sort { $a->{end_date} cmp $b->{end_date} } (@$projects);
    $projects = \@projects;

    if ( $project_id ne '' && $project_id ne '-1' ) {
        UacError->throw( error => "project $project_id is not assigned to user $user")
        if none { $_->{project_id} eq $project_id } @projects;
    } else {
        $project_id = $projects->[0]->{project_id};
    }

    #check if studios are assigned to project
    my $studios = project::get_studios( $config, { project_id => $project_id } );
    UacError->throw(error => "no studio is assigned to project") if scalar @$studios == 0;

    if ( scalar @$admin_roles == 0 ) {

        #get all studios by user
        $studios = uac::get_studios_by_user( $config, { user => $user, project_id => $project_id } );
        UacError->throw(error =>"no studio is assigned to user") if scalar @$studios == 0;
        if ( ( $studio_id ne '' ) && ( $studio_id ne '-1' ) ) {
            UacError->throw(error=>"studio is not assigned to user")
            if none { $_->{id} eq $studio_id } @$studios;
        } else {
            $studio_id = $studios->[0]->{id} unless defined $studio_id;
        }
    } else {

        #for admin get studios by project
        $studios = studios::get( $config, { project_id => $project_id } );
        if ( ( $studio_id ne '' ) && ( $studio_id ne '-1' ) ) {
            UacError->throw(error=>"studio $studio_id is not assigned to project $project_id")
            if none { $_->{id} eq $studio_id } @$studios;
        } else {
            $studio_id = $studios->[0]->{id} unless defined $studio_id;
        }
    }

    my $permissions =
      uac::get_user_permissions( $config, { user => $user, project_id => $project_id, studio_id => $studio_id } );
    if ($permissions->{admin} == 1) {
        for my $key (keys %$permissions) {
            $permissions->{$key} = 1;
        }
    }

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
    return $result;
}

sub setDefaultProject ($$) {
    my ($params, $user_presets) = @_;

    $params->{project_id} = $user_presets->{project_id}
      if ( !defined $params->{authAction} ) || ( $params->{authAction} eq '' ) || ( $params->{authAction} eq 'login' );
    return $params;
}

sub setDefaultStudio($$) {
    my ($params, $user_presets) = @_;

    $params->{studio_id} = $user_presets->{studio_id}
      if ( !defined $params->{authAction} ) || ( $params->{authAction} eq '' ) || ( $params->{authAction} eq 'login' );
    return $params;
}

#set user preset properties to request
sub prepare_request ($$) {
    my ($request, $user_presets) = @_;

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
    my ($permissions, $params) = @_;

    for my $usecase ( keys %$permissions ) {
        $params->{'allow'}->{$usecase} = 1 if ( $permissions->{$usecase} eq '1' );
    }
    return $params;
}

#print error message
sub permissions_denied($) {
    my ($message) = @_;
    $message =~ s/_/ /g;
    PermissionError->throw(error=>'Missing permissions to ' . $message);
}

sub print_info($) {
    return '<div class="ok head">'
      . '<span class="ui-icon ui-icon-check" style="float:left"></span>&nbsp;'
      . $_[0]
      . '</div>' . "\n";
}

sub print_warn($) {
    return '<div class="warn head">'
      . '<span class="ui-icon ui-icon-info" style="float:left"></span>&nbsp;'
      . $_[0]
      . '</div>' . "\n";
}

sub print_error ($) {
    my ($message) = @_;
    print STDERR "ERROR:" . $message . "\n";
    print '<div class="error" head>'
      . '<span class="ui-icon ui-icon-alert" style="float:left"></span>&nbsp;'
      . $message
      . '</div>' . "\n";
}

sub json {
    my ($obj) = @_;
    return qq{Cache-Control: no-store, no-cache, must-revalidate, max-age=0
Pragma: no-cache
Expires: 0
Content-Type:application/json; charset=utf-8

} . JSON->new->canonical->utf8(0)->encode($obj) . "\n";
}

sub error_handler {
    print STDERR Dumper(\@_);
    my $last = $_[-1];
    if (blessed($last) and $last->isa("APR::Request::Error")){
        print json({error => $last->{func}});    
    }
    return json({
            error => ref $_[0] eq 'SCALAR' ? $_[0]: $_[0]->{message} // $_[0]->{error} //'',
            "status" => 200
        }, 200) if blessed $_[0];
    die @_;
};

sub init{
    my ($r, $check_params, $main, $options) = @_;
    binmode STDOUT, ":encoding(utf8)";
    try {
        my ($params, $fh) = params::get($r, $options);
        my $config = config::get('../config/config.cgi');
        my $session = try {
            return auth::get_session($config, $params);
        } catch {
            if (blessed $_ and $_->isa('AuthError') and !params::is_json) {
                print auth::show_login_form($config, '', $_->message // $_->error);
                exit;
            }
            AuthError->throw(error=>"session not found");
        };
        $params = $session->{params};

        my $user_presets = uac::get_user_presets(
            $config,
            {
                user       => $session->{user},
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
                checked  => $check_params->( $config, $params ),
            },
        };

        #set user at params->presets->user
        $request = uac::prepare_request( $request, $user_presets );
        print $main->($config, $session, $params, $user_presets, $request, $fh);
    } catch {
        print STDERR uac::error_handler(@_);
        exit if $_->isa ("APR::Error");
        # ^ silent quit on exit
        print uac::error_handler(@_);
    };
}

sub set {
    my ($entry, @fields) = @_;
    return wantarray ? %$entry{@fields} : { map { $_ => $entry->{$_} } @fields };
}

sub missing {
    my ($entry, @fields) = @_;
    return grep {!defined $entry->{$_}} @fields;
}

#do not delete last line!
1;
