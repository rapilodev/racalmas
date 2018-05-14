#! /usr/bin/perl -w

#use utf8;
use warnings "all";
use strict;

use CGI qw(header param Vars);
$CGI::POST_MAX        = 1000;
$CGI::DISABLE_UPLOADS = 1;

use Data::Dumper;
use params;
use config;
use log;
use calendar;

my $r = shift;

#binmode STDOUT, ":utf8";
binmode STDOUT, ":encoding(UTF-8)";

if ( $0 =~ /cal.*?\.cgi$/ ) {
	( my $cgi, my $params, my $error ) = params::get($r);

	my $config = config::get('config/config.cgi');
	my $debug  = $config->{system}->{debug};

	my $request = {
		url    => $ENV{QUERY_STRING},
		params => {
			original => $params,
			checked  => calendar::check_params( $config, $params ),
		},
	};
	$params = $request->{params}->{checked};

	log::init($request);

	my $out = '';
	calendar::get_cached_or_render( $out, $config, $request );
	print $out. "\n";
}

1;
