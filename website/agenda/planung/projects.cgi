#! /usr/bin/perl -w 

use warnings "all";
use strict;
use Data::Dumper;

use config();
use params();
use log();
use template();
use auth();
use roles();
use uac();
use studios();
use series();
use localization();

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};

my ( $user, $expires ) = auth::get_user( $cgi, $config );
return if ( $user eq '' );

my $permissions  = roles::get_user_permissions();
my $user_presets = uac::get_user_presets(
	$config,
	{
		user       => $user,
		project_id => $params->{project_id},
		studio_id  => $params->{studio_id}
	}
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params->{studio_id}         = $params->{default_studio_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );
$params->{project_id} = $user_presets->{project_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );

my $request = {
	url => $ENV{QUERY_STRING} || '',
	params => {
		original => $params,
		checked  => check_params($params),
	},
};
$request = uac::prepare_request( $request, $user_presets );
log::init($request);

$params = $request->{params}->{checked};

#process header
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( 'print', template::check('default.html'), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
	<link rel="stylesheet" href="css/projects.css" type="text/css" /> 
	<script src="js/datetime.js"  type="text/javascript"></script>
	<script src="js/projects.js"  type="text/javascript"></script>
};

if ( defined $params->{action} ) {
	save_project( $config, $request ) if ( $params->{action} eq 'save' );
	delete_project( $config, $request ) if ( $params->{action} eq 'delete' );
	assign_studio( $config, $request ) if ( $params->{action} eq 'assign_studio' );
	unassign_studio( $config, $request ) if ( $params->{action} eq 'unassign_studio' );
}
$config->{access}->{write} = 0;
show_projects( $config, $request );

sub delete_project {
	my $config  = shift;
	my $request = shift;

	my $permissions = $request->{permissions};
	unless ( $permissions->{delete_project} == 1 ) {
		uac::permissions_denied('delete_project');
		return;
	}

	my $params  = $request->{params}->{checked};
	my $columns = project::get_columns($config);

	my $entry = {};
	for my $param ( keys %$params ) {
		if ( defined $columns->{$param} ) {
			$entry->{$param} = $params->{$param} || '';
		}
	}

	my $project_id = $params->{pid} || '';

	if ( $project_id ne '' ) {
		$config->{access}->{write} = 1;
		$entry->{project_id} = $project_id;
		delete $entry->{studio_id};
		project::delete( $config, $entry );
		uac::print_info("Project deleted");
	}
}

sub save_project {
	my $config  = shift;
	my $request = shift;

	my $params      = $request->{params}->{checked};
	my $permissions = $request->{permissions};

	#filter entry for studio columns
	my $columns = project::get_columns($config);
	my $entry   = {};
	for my $param ( keys %$params ) {
		if ( defined $columns->{$param} ) {
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

		$config->{access}->{write} = 1;
		project::update( $config, $entry );
		$config->{access}->{write} = 0;
		uac::print_info("project saved");
	} else {
		unless ( $permissions->{create_project} == 1 ) {
			uac::permissions_denied('create_project');
			return;
		}
		my $projects = project::get( $config, { name => $entry->{name} } );
		if ( @$projects > 0 ) {
			uac::print_error("project with name '$entry->{name}' already exists");
			return;
		}
		delete $entry->{project_id};
		delete $entry->{studio_id};

		$config->{access}->{write} = 1;
		project::insert( $config, $entry );
		$config->{access}->{write} = 0;
		uac::print_info("project created");
	}
}

sub assign_studio {
	my $config  = shift;
	my $request = shift;

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
	$config->{access}->{write} = 1;
	project::assign_studio(
		$config,
		{
			project_id => $params->{pid},
			studio_id  => $params->{sid}
		}
	);
	$config->{access}->{write} = 0;
	uac::print_info("project assigned");

}

# TODO: unassign series from studio
sub unassign_studio {
	my $config  = shift;
	my $request = shift;

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
	$config->{access}->{write} = 1;
	project::unassign_studio(
		$config,
		{
			project_id => $params->{pid},
			studio_id  => $params->{sid}
		}
	);
	$config->{access}->{write} = 0;
	uac::print_info("project unassigned");

}

sub show_projects {
	my $config  = shift;
	my $request = shift;

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
		my $project_studio_assignements = project::get_studio_assignments( $config, { project_id => $project->{project_id} } );
		$project->{pid} = $project->{project_id};

		# get assigned studios by id
		my $assigned_studio_by_id = {};
		for my $studio (@$project_studio_assignements) {
			$assigned_studio_by_id->{ $studio->{studio_id} } = 1;
		}

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
	}

	$params->{projects} = $projects;
	$params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'projects' } );
	uac::set_template_permissions( $permissions, $params );

	template::process( 'print', $params->{template}, $params );
}

sub check_params {
	my $params = shift;

	my $checked = {};

	#template
	my $template = '';
	$template = template::check( $params->{template}, 'projects' );
	$checked->{template} = $template;

	#actions
	my $action = '';
	if ( defined $params->{action} ) {
		if ( $params->{action} =~ /^(save|delete|assign_studio|unassign_studio)$/ ) {
			$checked->{action} = $params->{action};
		}
	}

	for my $param ( 'name', 'title', 'subtitle', 'start_date', 'end_date', 'image', 'email' ) {
		if ( defined $params->{$param} ) {
			$checked->{$param} = $params->{$param};
		}
	}

	#numeric values
	for my $param ( 'project_id', 'studio_id', 'default_studio_id', 'pid', 'sid' ) {
		if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
			$checked->{$param} = $params->{$param};
		}
	}
	if ( defined $checked->{studio_id} ) {
		$checked->{default_studio_id} = $checked->{studio_id};
	} else {
		$checked->{studio_id} = -1;
	}

	return $checked;
}

