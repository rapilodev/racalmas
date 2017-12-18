#! /usr/bin/perl -w 

use warnings "all";
use strict;
use Data::Dumper;

use params;
use config;
use log;
use template;
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

my $user_presets=uac::get_user_presets($config, {
    project_id => $params->{project_id}, 
    studio_id  => $params->{studio_id},
    user       => $user
});
$params->{default_studio_id}=$user_presets->{studio_id};
$params->{studio_id}  = $params->{default_studio_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));
$params->{project_id} = $user_presets->{project_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));

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
$params=uac::set_template_permissions($request->{permissions}, $params);
$params->{loc} = localization::get($config, {user=>$user, file=>'selectEvent'});

#process header
print "Content-type:text/html; charset=UTF-8;\n\n";

return unless uac::check($config, $params, $user_presets)==1;
show_events($config, $request);

sub show_events{
	my $config=shift;
	my $request=shift;

	my $params=$request->{params}->{checked};
	my $permissions=$request->{permissions};
	unless ($permissions->{read_event}==1){
		uac::permissions_denied('read_event');
		return;
	}

    # get user projects
    my $user_projects=uac::get_projects_by_user($config, { user => $request->{user} });
    my $projects={};
    for my $project (@$user_projects){
        $projects->{$project->{project_id}}=$project;
    }
    
    # get user studios
    my $user_studios=uac::get_studios_by_user($config, { user => $request->{user} });
    for my $studio (@$user_studios){
        my $project_id = $studio->{project_id};
        my $studio_id  = $studio->{id};
        $studio->{project_name} = $projects->{$project_id}->{name};
        $studio->{selected} = 1 if ($project_id eq $params->{p_id} ) && ($studio_id eq $params->{s_id} );
    }

    # get series
    my $options={};
    $options->{project_id}= $params->{p_id} if defined $params->{p_id}; 
    $options->{studio_id}= $params->{s_id} if defined $params->{s_id};
    my $series = series::get($config, $options);
    
    for my $serie(@$series){
        $serie->{selected}    = 1 if (defined $params->{series_id}) && ($serie->{series_id} eq $params->{series_id});
        $serie->{series_name} = 'Einzelsendung' if $serie->{series_name} eq '_single_';
    }

    # get events
    $options->{series_id} = $params->{series_id} if defined $params->{series_id};
    $options->{from_date} = $params->{from_date} if defined $params->{from_date};
    $options->{till_date} = $params->{till_date} if defined $params->{till_date};
    my $events = series::get_events($config, $options);

    # filter by year
    my $years=[];
    for my $year(2005..2025){
        my $date={
            year => $year
        };
        $date->{selected}=1 if (defined $params->{from_date}) && ($params->{from_date} eq $year.'-01-01');
        push @$years, $date;
    }
    #print Dumper($params->{loc});
    $params->{studios}= $user_studios;
    $params->{series} = $series;
    $params->{events} = $events;
    $params->{years}  = $years;
    
    #print STDERR Dumper($params);
    template::process('print', $params->{template}, $params);
    return;
}


sub check_params{
	my $params=shift;

	my $checked={};

	my $debug=$params->{debug} || '';
	if ($debug=~/([a-z\_\,]+)/){
		$debug=$1;
	}
	$checked->{debug}=$debug;

	#numeric values
	for my $param ('id', 'project_id', 'studio_id', 'series_id', 'event_id', 'p_id', 's_id'){
		if ((defined $params->{$param})&&($params->{$param}=~/^[\-\d]+$/)){
			$checked->{$param}=$params->{$param};
		}
	}

	for my $param ('selectProjectStudio', 'selectSeries', 'selectRange'){
		if ((defined $params->{$param})&&($params->{$param} eq '1')){
			$checked->{$param}=$params->{$param};
		}
	}

	for my $param ('resultElemId'){
		if ((defined $params->{$param})&&($params->{$param}=~/^[a-zA-ZöäüÖÄÜß_\d]+$/)){
			$checked->{$param}=$params->{$param};
		}
	}

    for my $param ('from_date','till_date'){
        if((defined $params->{$param})&&($params->{$param}=~/(\d\d\d\d\-\d\d\-\d\d)/)){
            $checked->{$param}=$1;
        }
    }

	if ((defined $params->{year})&&($params->{year}=~/^\d\d\d\d$/)){
		$checked->{year}=$params->{year};
	}
	# set defaults for project and studio id if not given
	$checked->{s_id} = $params->{studio_id}  || '-1' unless defined $params->{s_id};
	$checked->{p_id} = $params->{project_id} || '-1' unless defined $params->{p_id};

    if (defined $checked->{studio_id}){
        $checked->{default_studio_id}=$checked->{studio_id};
    }else{
        $checked->{studio_id}=-1;
    }

  	$checked->{template}=template::check($params->{template},'selectEvent');

	return $checked;
}


