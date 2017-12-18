#! /usr/bin/perl -w 

use warnings "all";
use strict;
use Data::Dumper;

use params;
use config;
#use log;
#use template;
use auth;
use uac;
#use roles;
#use project;
#use studios;
#use events;
use series;
#use series_schedule;
#use series_events;
#use series_dates;
#use markup;
#use URI::Escape;
#use Encode;
use localization;

binmode STDOUT, ":utf8";

my $r=shift;
(my $cgi, my $params, my $error)=params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ($user,$expires)  = auth::get_user($cgi, $config);
return if ((!defined $user) || ($user eq ''));

#print STDERR $params->{project_id}."\n";
my $user_presets=uac::get_user_presets($config, {
    project_id => $params->{project_id}, 
    studio_id  => $params->{studio_id},
    user       => $user
});
$params->{default_studio_id}=$user_presets->{studio_id};
$params->{studio_id}  = $params->{default_studio_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));
$params->{project_id} = $user_presets->{project_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));
#print STDERR $params->{project_id}."\n";
my $request={
	url	=> $ENV{QUERY_STRING}||'',
	params	=> {
		original => $params,
		checked  => check_params($params), 
	},
};
$request = uac::prepare_request($request, $user_presets);
log::init($request);

$params=$request->{params}->{checked};

#process header
my $headerParams=uac::set_template_permissions($request->{permissions}, $params);
$headerParams->{loc} = localization::get($config, {user=>$user, file=>'menu'});
template::process('print', template::check('default.html'), $headerParams);
return unless uac::check($config, $params, $user_presets)==1;

print q{
	<script src="js/datetime.js" type="text/javascript"></script>
	<script src="js/event.js" type="text/javascript"></script>
	<script src="js/localization.js" type="text/javascript"></script>
	<link rel="stylesheet" href="css/series.css" type="text/css" /> 
};

my $permissions=$request->{permissions};
unless ($permissions->{create_event_from_schedule}==1){
	uac::permissions_denied('create_event_from_schedule');
	return;
}

if (defined $params->{action}){
#    assign_series ($config, $request)    if ($params->{action} eq 'assign_series');
}
#print Dumper($params);
show_events($config, $request);

sub show_events{
    my $config=shift;
    my $request=shift;
    
	my $params=$request->{params}->{checked};
	my $permissions=$request->{permissions};
	unless ($permissions->{assign_series_events}==1){
		uac::permissions_denied('assign_series_events');
		return;
	}

    #print STDERR Dumper($params);
    #print '<pre>'.Dumper($eventsByStart);
    #return;
    
    my $scheduleDates=getScheduleDates($config, $request);
    my $schedulesByStart=getEventsByDate($scheduleDates);

    my $events=getEvents($config, $request);
    my $eventsByStart=getEventsByDate($events);

    print "<pre>\n";
    for my $date (sort keys %$schedulesByStart){
        my $schedules=$schedulesByStart->{$date};
        my $scheduleCount=scalar(@$schedules);
        if ($scheduleCount==0){
            print "skip datetime $date, no schedule found\n";
            next;
        }
        if ($scheduleCount>1){
            print "skip datetime $date, $scheduleCount schedules found\n";
            next;
        }
        my $schedule=$schedules->[0];
        
        if (defined $eventsByStart->{$date}){
            my $events=$eventsByStart->{$date};
            my $eventCount=scalar(@$events);
            if ($eventCount>0){
                print "skip datetime $date, $eventCount events already exist\n";
                next;
            }
        }
        print "found schedule without event for $date"
            ." - "
            . $schedule->{series_name}." - ".$schedule->{title}
            . "\n";
        #createEvent($config, $request, $schedule);
    }
}

# get a list of events with given start datetime
sub getEventsByDate{
    my $events=shift;
    
    my $eventsByDate={};
    for my $event (@$events){
        my $startDate=$event->{start};
        push @{$eventsByDate->{$startDate}}, $event;
    }
    return $eventsByDate;
}

sub getScheduleDates{
    my $config=shift;
    my $request=shift;

	my $params=$request->{params}->{checked};
	my $permissions=$request->{permissions};

    my $options  = {};

    my $from=$params->{from_date};
    my $till=$params->{till_date};
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #build series filter
    $options={
        project_id => $project_id,
        studio_id  => $studio_id,
        from       => $from,
        till       => $till,
        date_range_include => 1,
        exclude    => 0
    };
    
    #get all series dates
    my $series_dates=series_dates::get_series($config, $options);
    return $series_dates;
}

sub getEvents{
    my $config=shift;
    my $request=shift;
    
	my $params=$request->{params}->{checked};
	my $permissions=$request->{permissions};

    my $options  = {};

    my $from=$params->{from_date};
    my $till=$params->{till_date};
    my $project_id = $params->{project_id};
    my $studio_id  = $params->{studio_id};

    #build event filter
    $options={
        project_id  => $project_id,
        template    => 'no',
        limit       => 600,
        get	        => 'no_content',
        from_date   => $from,
        till_date   => $till,
        date_range_include => 1,
        archive     => 'all',
        no_exclude  => '1',
    };
    
    my $events=getSeriesEvents($config, $request, $options, $params);
    return $events;
}

sub getSeriesEvents{
    my $config  = shift;
	my $request = shift;
    my $options = shift;
    my $params  = shift;

    #get events by series id
	my $series_id=$request->{params}->{checked}->{series_id};
    if (defined $series_id){
    	my $events=series::get_events($request->{config}, $options);
        return $events;
    }

    #get events (directly from database to get the ones, not assigned, yet)
    delete $options->{studio_id};
    delete $options->{project_id};

	my $request2={
		params=>{
			checked => events::check_params($config, $options)
		},
		config      => $request->{config},
		permissions => $request->{permissions}
	};
    $request2->{params}->{checked}->{published}='all';
    delete $request2->{params}->{checked}->{exclude_locations} if (($params->{studio_id}==-1)&&(defined $request2->{params}->{checked}->{exclude_locations}));

	my $events=events::get($config, $request2);
    #print STDERR Dumper($request2->{params}->{checked});
    #print STDERR Dumper($events);
	series::add_series_ids_to_events($request->{config}, $events);

	my $studios=studios::get($request->{config},{
        project_id => $options->{project_id}
    });
	my $studio_id_by_location={};
	for my $studio (@$studios){
		$studio_id_by_location->{$studio->{location}}=$studio->{id};
	}

    for my $event (@$events){
        $event->{project_id}= $options->{project_id}                       unless defined $event->{project_id};
        $event->{studio_id} = $studio_id_by_location->{$event->{location}} unless defined $event->{studio_id};
    }
		
	return $events;
}
sub check_params{
	my $params=shift;

	my $checked={};

	my $debug=$params->{debug} || '';
	if ($debug=~/([a-z\_\,]+)/){
		$debug=$1;
	}
	$checked->{debug}=$debug;

	#actions and roles
    $checked->{action}='';
	if (defined $params->{action}){
		if ($params->{action}=~/^(create_events)$/){
			$checked->{action}=$params->{action};
		}
	}

	#numeric values
	$checked->{exclude}=0;
	for my $param ('id', 'project_id', 'studio_id', 'series_id'){
		if ((defined $params->{$param})&&($params->{$param}=~/^\d+$/)){
			$checked->{$param}=$params->{$param};
		}
	}

    if (defined $checked->{studio_id}){
        $checked->{default_studio_id}=$checked->{studio_id};
    }else{
        $checked->{studio_id}=-1;
    }

	for my $param ('date','from_date','till_date'){
			$checked->{$param}=time::check_date($params->{$param});
	}

  	$checked->{template}=template::check($params->{template},'create_events');

	return $checked;
}


__DATA__

https://piradio.de/agenda/planung/create_events.cgi?project_id=1&studio_id=1&from_date=2016-09-01&till_date=2016-10-01
