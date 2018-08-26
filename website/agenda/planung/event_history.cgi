#! /usr/bin/perl -w 

use warnings "all";
use strict;

use URI::Escape();
use Encode();
use Data::Dumper;
use MIME::Base64();
use Text::Diff::FormattedHTML();

use params();
use config();
use log();
use template();
use db();
use auth();
use uac();
use time();
use markup();
use studios();
use event_history();
use events();
use series_events();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $cgi, $config );
return if ( ( !defined $user ) || ( $user eq '' ) );

my $user_presets = uac::get_user_presets( $config, { user => $user, studio_id => $params->{studio_id} } );
$params->{default_studio_id} = $user_presets->{studio_id};
$params->{studio_id}         = $params->{default_studio_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );

my $request = {
	url => $ENV{QUERY_STRING} || '',
	params => {
		original => $params,
		checked  => check_params($params),
	},
};

#print STDERR Dumper($request)."\n";

#set user at params->presets->user
$request = uac::prepare_request( $request, $user_presets );
log::init($request);

$params = $request->{params}->{checked};

#show header
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( 'print', template::check('default.html'), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
    <script src="js/datetime.js" type="text/javascript"></script>
    <script src="js/event.js" type="text/javascript"></script>
    <link rel="stylesheet" href="css/event.css" type="text/css" /> 
};

$config->{access}->{write} = 0;
if ( $params->{action} eq 'diff' ) {
	compare( $config, $request );
	return;
}
show_history( $config, $request );

#show existing event history
sub show_history {
	my $config  = shift;
	my $request = shift;

	my $params      = $request->{params}->{checked};
	my $permissions = $request->{permissions};
	for my $attr ('studio_id') {    # 'series_id','event_id'
		unless ( defined $params->{$attr} ) {
			uac::print_error( "missing " . $attr . " to show changes" );
			return;
		}
	}

	unless ( $permissions->{read_event} == 1 ) {
		uac::print_error("missing permissions to show changes");
		return;
	}

	my $options = {
		project_id => $params->{project_id},
		studio_id  => $params->{studio_id},
		limit      => 200
	};
	$options->{series_id} = $params->{series_id} if defined $params->{series_id};
	$options->{event_id}  = $params->{event_id}  if defined $params->{event_id};

	my $events = event_history::get( $config, $options );

	#print STDERR Dumper($events);
	return unless defined $events;
	$params->{events} = $events;

	for my $permission ( keys %{$permissions} ) {
		$params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
	}

	#print STDERR Dumper($params);
	$params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'event_history' } );

	template::process( 'print', template::check('event_history'), $params );
}

#show existing event history
sub compare {
	my $config  = shift;
	my $request = shift;

	my $params      = $request->{params}->{checked};
	my $permissions = $request->{permissions};
	for my $attr ( 'project_id', 'studio_id', 'event_id', 'v1', 'v2' ) {
		unless ( defined $params->{$attr} ) {
			uac::print_error( "missing " . $attr . " to show changes" );
			return;
		}
	}

	unless ( $permissions->{read_event} == 1 ) {
		uac::print_error("missing permissions to show changes");
		return;
	}

	print qq{<link href="css/diff.css" rel="stylesheet">} . "\n";

	if ( $params->{v1} > $params->{v2} ) {
		my $t = $params->{v1};
		$params->{v1} = $params->{v2};
		$params->{v2} = $t;
	}

	my $options = {
		project_id => $params->{project_id},
		studio_id  => $params->{studio_id},
		series_id  => $params->{series_id},
		event_id   => $params->{event_id},
		change_id  => $params->{v1},
		limit      => 2
	};

	my $events = event_history::get( $config, $options );
	return unless @$events == 1;
	my $v1 = $events->[0];

	$options->{change_id} = $params->{v2};
	$events = event_history::get( $config, $options );
	return unless @$events == 1;
	my $v2 = $events->[0];

	my $t1 = eventToText($v1);
	my $t2 = eventToText($v2);

	if ( $t1 eq $t2 ) {
		print "no changes\n";
		return;
	}

	#print "<style>".diff_css."</style>";
	#print '<pre>';
	#my $diff=diff_strings( { vertical => 1 }, $t1, $t2);
	my $diff = diff_strings( {}, $t1, $t2 );

	#print Text::Diff::diff(\$t1, \$t2, { STYLE => "Table" });
	#print Text::Diff::diff($v1, $v2, { STYLE => "Table" });
	print $diff;

	#print '</pre>';
}

sub eventToText {
	my $event = shift;

	my $s = events::get_keys($event)->{full_title} . "\n";
	$s .= $event->{excerpt} . "\n";
	$s .= $event->{user_excerpt} . "\n";
	$s .= $event->{topic} . "\n";
	$s .= $event->{content} . "\n";

	#print STDERR "DUMP\n$s";
	return $s;

}

sub check_params {
	my $params = shift;

	my $checked  = {};
	my $template = '';
	$checked->{template} = template::check( $params->{template}, 'event_history' );

	my $debug = $params->{debug} || '';
	if ( $debug =~ /([a-z\_\,]+)/ ) {
		$debug = $1;
	}
	$checked->{debug} = $debug;

	#numeric values
	for my $param ( 'id', 'project_id', 'studio_id', 'default_studio_id', 'user_id', 'series_id', 'event_id', 'v1', 'v2' ) {
		if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
			$checked->{$param} = $params->{$param};
		}
	}

	if ( defined $checked->{studio_id} ) {
		$checked->{default_studio_id} = $checked->{studio_id};
	} else {
		$checked->{studio_id} = -1;
	}

	#actions and roles
	$checked->{action} = '';
	if ( defined $params->{action} ) {
		if ( $params->{action} =~ /^(show|diff)$/ ) {
			$checked->{action} = $params->{action};
		}
	}

	#print STDERR Dumper($checked);
	return $checked;
}

