#! /usr/bin/perl -w

#use utf8;
use warnings "all";
use strict;

use CGI qw(header param Vars);
$CGI::POST_MAX        = 1000;
$CGI::DISABLE_UPLOADS = 1;

use Data::Dumper;

#use Apache2::Request;
use JSON;
use params;
use config;
use log;
use playout;

my $r = shift;

#binmode STDOUT, ":utf8";
binmode STDOUT, ":encoding(UTF-8)";

if ( $0 =~ /upload_playout.*?\.cgi$/ ) {

	# read POST content
	my ( $buf, $content );
	while ( $r->read( $buf, 8192 ) ) {
		$content .= $buf;
	}
	$content = "{}" unless $content;

	# parse GET content
	( my $cgi, my $params, my $error ) = params::get($r);

	my $config = config::get('config/config.cgi');
	my $debug  = $config->{system}->{debug};
	my $len    = $r->headers_in()->get('Content-Length');
	print "Content-type:text/plain\n\n";

	my $json = decode_json($content);
	$json->{project_id} = $params->{project_id} if defined $params->{project_id};
	$json->{studio_id}  = $params->{studio_id}  if defined $params->{studio_id};
	$config->{access}->{write} = 1;
	my $result = playout::sync( $config, $json );
	$config->{access}->{write} = 0;

	#print Dumper($content)."\n";
	#print Dumper($r);
	#print Dumper($json);
	print "result:" . Dumper($result);
}

1;
