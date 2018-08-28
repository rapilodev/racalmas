#! /usr/bin/perl -w

#use utf8;
use warnings "all";
#use diagnostics;
use strict;
use Data::Dumper;

use CGI qw(header param Vars);
$CGI::POST_MAX        = 1000;
$CGI::DISABLE_UPLOADS = 1;

use params();
use db();
use markup();
use cache();
use log();
use config();
use template();
use project();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);
my $config = config::get('config/config.cgi');

my $debug = $config->{system}->{debug};

#get request
my $request = {
	url    => $ENV{QUERY_STRING},
	params => {
		original => $params,
		checked  => check_params( $config, $params )
	},
};

$params = $request->{params}->{checked};

#read cache
my $cache = {};
if ( $config->{cache}->{use_cache} eq '1' ) {
	cache::configure('series_names.html');
	$cache = cache::load( $config, $params );
	if ( defined $cache->{content} ) {
		print $cache->{content};
		return;
	}
}

#connect
my $dbh = db::connect($config);

#fill template
my $template_parameters = {};
$template_parameters->{projects}         = getProjects( $dbh, $config, $params );
$template_parameters->{debug}            = $config->{system}->{debug};
$template_parameters->{server_cache}     = $config->{cache}->{server_cache} if ( $config->{cache}->{server_cache} );
$template_parameters->{use_client_cache} = $config->{cache}->{use_client_cache} if ( $config->{cache}->{use_client_cache} );

#output template
my $template = $params->{template};
my $out      = '';
template::process( $out, $params->{template}, $template_parameters );
print $out;

#write to cache
if ( $config->{cache}->{use_cache} eq '1' ) {
	$cache->{content} = $out;
	cache::save($cache);
}
$cache = undef;
$out   = undef;

sub getProjects {
	my $dbh    = shift;
	my $config = shift;
	my $params = shift;

	my $prev_series_names = undef;
	my $projects          = project::get_sorted($config);

	my $excludedProjects = {};
	if ( defined $config->{filter}->{projects_to_exclude} ) {
		for my $project ( split( /\,/, $config->{filter}->{projects_to_exclude} ) ) {
			$project =~ s/^\s+//g;
			$project =~ s/\s+$//g;
			$excludedProjects->{$project} = 1;
		}
	}

	my $results = [];
	for my $project (@$projects) {
		next if defined $excludedProjects->{ $project->{name} };

		my $series_names = getSeriesNames( $dbh, $config, $project->{name}, $params );
		$project->{isEmpty} = 1 if scalar(@$series_names) == 0;
		$project->{series_names} = $series_names;

		$project->{js_name} = $project->{name};
		$project->{js_name} =~ s/[^a-zA-Z\_0-9]/\_/g;
		$project->{js_name} =~ s/\_+/\_/g;

		#mark last series_name entry of all non empty projects
		if ( ( defined $series_names ) && ( @$series_names > 0 ) ) {
			$series_names->[-1]->{last}      = 1;
			$prev_series_names->[-1]->{last} = 0 if ( ( defined $prev_series_names ) && ( @$prev_series_names > 0 ) );
			$prev_series_names               = $series_names;
		}
		push @$results, $project;
	}
	return $results;
}

sub getSeriesNames {
	my $dbh     = shift;
	my $config  = shift;
	my $project = shift;
	my $params  = shift;

	my $debug       = $config->{system}->{debug};
	my $bind_values = [];

	my @conds = ();
	if ( defined $config->{filter}->{locations_to_exclude} ) {
		my @exclude = ();
		for my $location ( split( /\,/, $config->{filter}->{locations_to_exclude} ) ) {
			$location =~ s/^\s+//g;
			$location =~ s/\s+$//g;
			push @exclude,      '?';
			push @$bind_values, $location;
		}
		push @conds, 'location not in (' . join( ',', @exclude ) . ')';
	}

	if ( defined $config->{filter}->{projects_to_exclude} ) {
		my @exclude = ();
		for my $project ( split( /\,/, $config->{filter}->{projects_to_exclude} ) ) {
			$project =~ s/^\s+//g;
			$project =~ s/\s+$//g;
			push @exclude,      '?';
			push @$bind_values, $project;
		}
		push @conds, 'project not in (' . join( ',', @exclude ) . ')';
	}

	if ( ( $project ne '' ) && ( $project ne 'all' ) ) {
		push @conds,        'project=?';
		push @$bind_values, $project;
	}

	if ( ( $params->{search} ne '' ) ) {
		push @conds,        'series_name like ?';
		push @$bind_values, '%' . $params->{search} . '%';
	}

	my $where = '';
	if ( @conds > 0 ) {
		$where = 'where ' . join( ' and ', @conds );
	}

	my $query = qq{
        select series_name, count(series_name) sum 
        from calcms_events
        $where
        group by series_name
        order by series_name
    };

	my $series_names = db::get( $dbh, $query, $bind_values );

	for my $series (@$series_names) {
		$series->{series_name} = '' unless defined $series->{series_name};
		$series->{series_name} =~ s/\"//g;
		$series->{series_name} = 'ohne'          if $series->{series_name} eq '';
		$series->{series_name} = 'Einzelsendung' if $series->{series_name} eq '_single_';
	}

	return $series_names;
}

sub check_params {
	my $config = shift;
	my $params = shift;

	my $template = template::check( $params->{template}, 'series_names.html' );

	my $debug = $params->{debug} || '';
	if ( $debug =~ /([a-z\_\,]+)/ ) {
		$debug = $1;
	}

	my $search = $params->{q} || $params->{search} || $params->{term} || '';
	if ( $search =~ /([a-z0-9A-Z\_\,]+)/ ) {
		$search = $1;
	}

	return {
		template => $template,
		debug    => $debug,
		search   => $search,
	};
}

