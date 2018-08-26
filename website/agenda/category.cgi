#! /usr/bin/perl -w 

use strict;
use warnings;

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

my $request = {
	url    => $ENV{QUERY_STRING},
	params => {
		original => $params,
		checked  => check_params( $config, $params ),
	},
};

log::init($request);

$params = $request->{params}->{checked};

my $cache = {};
if ( $config->{cache}->{use_cache} eq '1' ) {
	cache::configure('categories.html');
	$cache = cache::load( $config, $params );
	if ( defined $cache->{content} ) {
		print $cache->{content};
		return;
	}
}

my $dbh = db::connect($config);

my $template_parameters = {};
$template_parameters->{projects} = getProjects( $dbh, $config );

#$template_parameters->{categories}	= get_categories($dbh,$params->{project});
$template_parameters->{debug}            = $config->{system}->{debug};
$template_parameters->{server_cache}     = $config->{cache}->{server_cache} if ( $config->{cache}->{server_cache} );
$template_parameters->{use_client_cache} = $config->{cache}->{use_client_cache} if ( $config->{cache}->{use_client_cache} );

my $template = $params->{template};
my $out      = '';
template::process( $out, $params->{template}, $template_parameters );
print $out;

#write to cache
if ( $config->{cache}->{use_cache} eq '1' ) {
	$cache->{content} = $out;
	cache::save($cache);
}

sub getProjects {
	my $dbh    = shift;
	my $config = shift;

	my $excludedProjects = {};
	if ( defined $config->{filter}->{projects_to_exclude} ) {
		for my $project ( split( /\,/, $config->{filter}->{projects_to_exclude} ) ) {
			$project =~ s/^\s+//g;
			$project =~ s/\s+$//g;
			$excludedProjects->{$project} = 1;
		}
	}

	my $projects = project::get_sorted($config);
	my $results  = [];
	for my $project (@$projects) {
		next if defined $excludedProjects->{ $project->{name} };
		my $categories = getCategories( $dbh, $config, $project->{name} );
		$project->{isEmpty} = 1 if scalar(@$categories) == 0;
		$project->{categories} = $categories;

		$project->{js_name} = $project->{name};
		$project->{js_name} =~ s/[^a-zA-Z\_0-9]/\_/g;
		$project->{js_name} =~ s/\_+/\_/g;
		push @$results, $project;
	}
	return $results;
}

sub getCategories {
	my $dbh     = shift;
	my $config  = shift;
	my $project = shift;

	my $cond        = '';
	my $bind_values = [];
	if ( ( $project ne '' ) && ( $project ne 'all' ) ) {
		$cond        = 'where project=?';
		$bind_values = [$project];
	}

	my $query = qq{
		select	name, count(name) sum 
		from 	calcms_categories
		$cond
		group 	by name
		order by sum desc, name
	};
	my $categories = db::get( $dbh, $query, $bind_values );

	my $results = [];
	for my $category (@$categories) {
		push @$results, $category if $category->{sum} > 1;
	}

	return $results;
}

sub check_params {
	my $config = $_[0];
	my $params = $_[1];

	my $template = template::check( $params->{template}, 'categories.html' );

	my $debug = $params->{debug} || '';
	if ( $debug =~ /([a-z\_\,]+)/ ) {
		$debug = $1;
	}

	return {
		template => $template,
		debug    => $debug
	};
}

