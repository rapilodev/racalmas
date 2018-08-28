#! /usr/bin/perl -w

use warnings "all";
use strict;
use Data::Dumper;

use params();
use config();
use template();

use auth();
use uac();
use time();

use series();
use eventOps();

use series_dates();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $cgi, $config );
return if ( ( !defined $user ) || ( $user eq '' ) );

#print STDERR $params->{project_id}."\n";
my $user_presets = uac::get_user_presets(
	$config,
	{
		project_id => $params->{project_id},
		studio_id  => $params->{studio_id},
		user       => $user
	}
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params->{studio_id}         = $params->{default_studio_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );
$params->{project_id} = $user_presets->{project_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );

#print STDERR $params->{project_id}."\n";
my $request = {
	url => $ENV{QUERY_STRING} || '',
	params => {
		original => $params,
		checked  => check_params($params),
	},
};
$request = uac::prepare_request( $request, $user_presets );

$params = $request->{params}->{checked};

#process header
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( 'print', template::check('default.html'), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
	<script src="js/datetime.js" type="text/javascript"></script>
	<script src="js/event.js" type="text/javascript"></script>
	<script src="js/localization.js" type="text/javascript"></script>
	<link rel="stylesheet" href="css/series.css" type="text/css" /> 
};

my $permissions = $request->{permissions};
unless ( $permissions->{create_event_from_schedule} == 1 ) {
	uac::permissions_denied('create_event_from_schedule');
	return;
}

if ( $params->{action} eq 'create_events' ) {
	create_events( $config, $request );
} else {
	show_events( $config, $request );
}

sub show_events {
	my $config  = shift;
	my $request = shift;

	my $params      = $request->{params}->{checked};
	my $permissions = $request->{permissions};
	unless ( $permissions->{assign_series_events} == 1 ) {
		uac::permissions_denied('assign_series_events');
		return;
	}
	template::process( 'print', $params->{template}, $params );

}

sub create_events {
	my $config  = shift;
	my $request = shift;

	my $params      = $request->{params}->{checked};
	my $permissions = $request->{permissions};
	unless ( $permissions->{assign_series_events} == 1 ) {
		uac::permissions_denied('assign_series_events');
		return;
	}

	print STDERR "create events\n";

	my $project_id = $params->{project_id};
	my $studio_id  = $params->{studio_id};
	my $from_date  = $params->{from_date};
	my $till_date  = $params->{till_date};
	my $duration   = $params->{duration};

	$from_date = time::time_to_datetime();
	if ( $from_date =~ /(\d\d\d\d\-\d\d\-\d\d \d\d)/ ) {
		$from_date = $1 . ':00';
	}
	$till_date = time::add_days_to_datetime( $from_date, $duration );
	if ( $from_date =~ /(\d\d\d\d\-\d\d\-\d\d)/ ) {
		$from_date = $1;
	}
	if ( $till_date =~ /(\d\d\d\d\-\d\d\-\d\d)/ ) {
		$till_date = $1;
	}
	$params->{from_date} = $from_date;
	$params->{till_date} = $till_date;

	print STDERR "create events from $from_date to $till_date\n";

	my $dates = series_dates::getDatesWithoutEvent(
		$config,
		{
			project_id => $project_id,
			studio_id  => $studio_id,
			from       => $from_date,
			till       => $till_date
		}
	);
	print STDERR "<pre>found " . ( scalar @$dates ) . " dates\n";
	my $events = [];
	for my $date (@$dates) {

		#print STDERR $date->{start}."\n";
		push @$events, createEvent( $config, $request, $date );
	}
	$params->{created_events} = $events;
	$params->{created_total}  = scalar(@$events);
	template::process( 'print', $params->{template}, $params );
}

sub createEvent {
	my $config  = shift;
	my $request = shift;
	my $date    = shift;

	my $permissions = $request->{permissions};
	my $user        = $request->{user};

	$date->{show_new_event_from_schedule} = 1;
	unless ( $permissions->{create_event_from_schedule} == 1 ) {
		uac::permissions_denied('create_event_from_schedule');
		return;
	}

	$date->{start_date} = $date->{start};
	my $event = eventOps::getNewEvent( $config, $date, 'show_new_event_from_schedule' );

	return undef unless defined $event;

	$event->{start_date} = $event->{start};
	eventOps::createEvent( $request, $event, 'create_event_from_schedule' );
	print STDERR Dumper($date);
	return $event;

}

sub check_params {
	my $params = shift;

	my $checked = {};

	my $debug = $params->{debug} || '';
	if ( $debug =~ /([a-z\_\,]+)/ ) {
		$debug = $1;
	}
	$checked->{debug} = $debug;

	#actions and roles
	$checked->{action} = '';
	if ( defined $params->{action} ) {
		if ( $params->{action} =~ /^(create_events)$/ ) {
			$checked->{action} = $params->{action};
		}
	}

	#numeric values
	$checked->{exclude}  = 0;
	$checked->{duration} = 28;
	for my $param ( 'id', 'project_id', 'studio_id', 'duration' ) {
		if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
			$checked->{$param} = $params->{$param};
		}
	}

	if ( defined $checked->{studio_id} ) {
		$checked->{default_studio_id} = $checked->{studio_id};
	} else {
		$checked->{studio_id} = -1;
	}

	$checked->{template} = template::check( $params->{template}, 'create_events' );

	return $checked;
}

