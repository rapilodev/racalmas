#! /usr/bin/perl -I../lib

use warnings "all";
use strict;
use Data::Dumper;
use HTML::Template;

#use URI::Escape;
#use Encode;

use config;
use log;
use template;
use params;
use config;
use auth;
use localization;
use studios;
binmode STDOUT, ":utf8";
my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $cgi, $config );
return if ( !defined $user ) || ( $user eq '' );

my $user_presets = uac::get_user_presets( $config, { user => $user, studio_id => $params->{studio_id} } );
my $request = {
	url => $ENV{QUERY_STRING} || '',
	params => {
		original => $params,
		checked  => $params

		  #		checked  => check_params($params),
	},
};
$request = uac::prepare_request( $request, $user_presets );
log::init($request);

#process header
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( 'print', template::check('default.html'), $headerParams );

#filter
my $lines = $cgi->param('lines');
$lines = 100 if $lines eq '';

my $filter = '';
$filter = ' |grep -v "Use of uninitialized value in | grep -v redefined " ' if ( $cgi->param('warn') eq '1' );

#get file
my $file = $config->{system}->{log_file};
if ( $cgi->param('log') eq 'app' ) {
	$file = $config->{system}->{log_debug_file};
}
if ( $cgi->param('log') eq 'mem' ) {
	$file = $config->{system}->{log_debug_memory_file};
}
if ( $cgi->param('log') eq 'job' ) {
	$file = $config->{system}->{job_log};
}

#output header
my $out = '';
template::process( 'print', 'templates/error_log.html', $params );

#get log
my $cmd = "tail -$lines " . $file . $filter;
print '<pre>' . $cmd . '</pre>';

my $log = `$cmd`;
$log = join( "\n", reverse( split( "\n", $log ) ) );

#replace
if ( $cgi->param('log') eq 'app' ) {
	$log =~ s/\\n/<br>/gi;
} else {
	$log =~ s/</\&lt;/gi;
	$log =~
s/\\n/<\/pre><pre>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;/gi;
}

#output content
print $log;

