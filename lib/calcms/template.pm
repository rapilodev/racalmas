use warnings "all";
use strict;

package template;
use Data::Dumper;
use HTML::Template::Compiled();
use HTML::Template::Compiled::Plugin::XMLEscape();
use JSON();
use Cwd();

use config();
use params();
use project();
use log();
use roles();

require Exporter;
our @ISA = qw(Exporter);

#our @EXPORT = qw(all);
our @EXPORT_OK = qw(check process exit_on_missing_permission clear_cache);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

sub process {

	#	my $output=$_[0];
	my $filename = $_[1];
	my $params   = $_[2];

	my $config = $config::config;
	for my $key ( keys %{ $config::config->{locations} } ) {
		$params->{$key} = $config::config->{locations}->{$key} if ( $key =~ /\_url$/ );
	}

	# add current project
	unless ( defined $params->{project_title} ) {
		my $projects = project::get_with_dates( $config, { name => $config->{project} } );
		if ( @$projects == 1 ) {
			my $project = $projects->[0];
			foreach my $key ( keys %$project ) {
				$params->{ 'project_' . $key } = $project->{$key};
			}
		}
	}

	$params->{user} = $ENV{REMOTE_USER} unless defined $params->{user};

	my $user_permissions = roles::get_user_permissions();
	for my $permission ( keys %$user_permissions ) {
		$params->{$permission} = $user_permissions->{$permission} if ( $user_permissions->{$permission} eq '1' );
	}

	$params->{jobs} = roles::get_user_jobs();
	if ( ( $filename =~ /json\-p/ ) || (params::isJson) ) {
		my $header = "Content-type:application/json; charset=utf-8\n\n";
		my $json = JSON::to_json( $params, { pretty => 1 } );

		#		$json=$header.$params->{json_callback}.'['.$json.']';
		$json = $header . $params->{json_callback} . $json;
		if ( ( defined $_[0] ) && ( $_[0] eq 'print' ) ) {
			print $json. "\n";
		} else {
			$_[0] = $json . "\n";
		}
		return;
	}

	#print STDERR $filename."\n";
	log::error( $config, "cannot find template $filename " ) unless -e $filename;
	log::error( $config, "cannot read template $filename " ) unless -r $filename;

	my $default_escape = '0';
	$default_escape = 'JS'       if ( $filename =~ /\.js$/ );
	$default_escape = 'JS'       if ( $filename =~ /\.json$/ );
	$default_escape = 'HTML_ALL' if ( $filename =~ /\.html$/ );

	my $html_template = undef;

	unless ( $filename =~ /\.xml$/ ) {
		$html_template = HTML::Template::Compiled->new(
			filename          => $filename,
			die_on_bad_params => 0,
			case_sensitive    => 0,
			loop_context_vars => 0,
			global_vars       => 0,
			tagstyle          => '-asp -comment',
			default_escape    => $default_escape,
			cache             => 0,
			utf8              => 1,
		);
	} else {
		$html_template = HTML::Template::Compiled->new(
			filename          => $filename,
			die_on_bad_params => 0,
			case_sensitive    => 1,
			loop_context_vars => 0,
			global_vars       => 0,
			tagstyle          => '-asp -comment',
			default_escape    => 'XML',
			plugin            => [qw(HTML::Template::Compiled::Plugin::XMLEscape)],
			utf8              => 1
		);
	}

	#$params=
	setRelativeUrls( $params, 0 ) unless ( defined $params->{extern} ) && ( $params->{extern} eq '1' );

	#		 HTML::Template::Compiled->preload($cache_dir);
	$html_template->param($params);
	if ( ( defined $_[0] ) && ( $_[0] eq 'print' ) ) {
		print $html_template->output;
	} else {
		$_[0] = $html_template->output;
	}
}

# set relative urls in nested params structure
sub setRelativeUrls {
	my $params = shift;
	my $depth = shift || 0;

	#print STDERR "setRelativeUrls depth:$depth ".ref($params)."\n";

	return unless defined $params;

	if ( $depth > 10 ) {
		print STDERR "prevent deep recursion in template::setRelativeUrls()\n";
		return;
	}

	# set recursive for hash
	if ( ref($params) eq 'HASH' ) {
		for my $key ( keys %$params ) {

			#next unless ($key eq 'icon') || ($key eq 'thumb');
			my $val = $params->{$key};
			next unless defined $val;
			if ( ref($val) eq '' ) {

				# make link relative
				$params->{$key} =~ s/^https?\:(\/\/[^\/]+)/$1/;
			} elsif ( ( ref($val) eq 'HASH' ) || ( ref($val) eq 'ARRAY' ) ) {
				setRelativeUrls( $params->{$key}, $depth + 1 );
			}
		}
		return $params;
	}

	# set recursive for arrays
	if ( ref($params) eq 'ARRAY' ) {
		for my $i ( 0 .. @$params ) {
			my $val = $params->[$i];
			next unless defined $val;
			if ( ( ref($val) eq 'HASH' ) || ( ref($val) eq 'ARRAY' ) ) {
				setRelativeUrls( $params->[$i], $depth + 1 );
			}
		}
		return $params;
	}

	return $params;
}

#requires read config
sub check {
	my $template = shift || '';
	my $default = shift;

	if ( $template =~ /json\-p/ ) {
		$template =~ s/[^a-zA-Z0-9\-\_\.]//g;
		$template =~ s/\.{2,99}/\./g;
		return $template;
	}

	my $config = $config::config;
	if ( $template eq '' ) {
		$template = $default;
	} else {
		$template =~ s/^\.\///gi;

		#template does use ';' in filename
		log::error( $config, 'invalid template!' ) if ( $template =~ /;/ );

		#template does use '..' in filename
		log::error( $config, 'invalid template!' ) if ( $template =~ /\.\./ );
	}

	#print STDERR $config::config->{cache}->{compress}."<.compres default:$template\n";
	$template = ( split( /\//, $template ) )[-1];
	my $cwd = Cwd::getcwd();

	$template .= '.html' unless ( $template =~ /\./ );
	if ( ( $config::config->{cache}->{compress} eq '1' ) && ( -e $cwd . '/templates/compressed/' . $template ) ) {
		$template = $cwd . '/templates/compressed/' . $template;
	} elsif ( -e $cwd . '/templates/' . $template ) {
		$template = $cwd . '/templates/' . $template;
	} else {
		log::error( $config, "template not found: '$cwd/$template'" );

	}

	log::error( $config, "missing permission to read template '$template'" ) unless ( -r $template );
	return $template;
}

#deprecated (for old admin only)
sub exit_on_missing_permission {
	my $permission       = shift;
	my $user_permissions = roles::get_user_permissions();
	if ( $user_permissions->{$permission} ne '1' ) {
		print STDERR "missing permission to $permission\n";
		template::process( 'print', template::check('default.html'), { error => 'sorry, missing permission!' } );
		die();

		#exit;
	}
}

sub clear_cache {
	HTML::Template::Compiled->clear_cache();

	#	return;
	#	my $html_template = HTML::Template::Compiled->new();
	# 	$html_template->clear_cache();
}

#do not delete last line!
1;
