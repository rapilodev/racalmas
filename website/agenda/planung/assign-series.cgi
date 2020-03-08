#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use Encode();

use params();
use config();
use log();
use template();
use auth();
use uac();
use roles();
use project();
use studios();
use events();
use series();
use series_schedule();
use series_events();
use series_dates();
use markup();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( !defined $user ) || ( $user eq '' );

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
$params = uac::setDefaultStudio( $params, $user_presets );
$params = uac::setDefaultProject( $params, $user_presets );

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
template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
	<script src="js/datetime.js" type="text/javascript"></script>
	<script src="js/event.js" type="text/javascript"></script>
	<script src="js/localization.js" type="text/javascript"></script>
	<link rel="stylesheet" href="css/series.css" type="text/css" /> 
};

my $permissions = $request->{permissions};
unless ( $permissions->{scan_series_events} == 1 ) {
    uac::permissions_denied('scan_series_events');
    return;
}

if ( defined $params->{action} ) {
    assign_series( $config, $request ) if $params->{action} eq 'assign_series';
}
show_events( $config, $request );

sub show_events {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return;
    }

    my $projects = project::get( $config, { project_id => $params->{project_id} } );
    my $project = $projects->[0];
    return unless scalar @$projects == 1;

    my $studios = studios::get( $config,
        { project_id => $params->{project_id}, studio_id => $params->{studio_id} } );
    my $studio = $studios->[0];
    return unless scalar @$studios == 1;

    my $project_name = $project->{name};
    my $studio_name  = $studio->{location};

    #get series_names
    my $dbh   = db::connect($config);
    my $query = q{
        select project_id, studio_id, series_id, series_name, title 
        from   calcms_series s, calcms_project_series ps 
        where  s.id=ps.series_id
        order  by series_name, title
    };
    my $results = db::get( $dbh, $query );

    # get projects by id
    my $projects_by_id = {};
    $projects = project::get($config);
    for my $project (@$projects) {
        $projects_by_id->{ $project->{project_id} } = $project;
    }

    # get studios by id
    my $studios_by_id = {};
    $studios = studios::get($config);
    for my $studio (@$studios) {
        $studios_by_id->{ $studio->{id} } = $studio;
    }

    #add project and studio name to series
    for my $result (@$results) {
        $result->{project_name} = $projects_by_id->{ $result->{project_id} }->{name};
        $result->{studio_name}  = $studios_by_id->{ $result->{studio_id} }->{location};
        $result->{series_name}  = 'Einzelsendung' if $result->{series_name} eq '_single_';
    }
    $params->{series} = $results;

    #fill template
    $params->{project_name} = $project_name;
    $params->{studio_name}  = $studio_name;

    template::process( $config, 'print', $params->{template}, $params );
}

sub assign_series {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{assign_series_events} == 1 ) {
        uac::permissions_denied('assign_series_events');
        return;
    }

    my $entry = {};
    for my $attr ( 'project_id', 'studio_id', 'series_id' ) {
        if ( defined $params->{$attr} ) {
            $entry->{$attr} = $params->{$attr};
        } else {
            uac::print_error( $attr . ' not given!' );
            return;
        }
    }

    $config->{access}->{write} = 1;

    #check if series is assigned to project/studio
    my $series = series::get(
        $config,
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            series_id  => $entry->{series_id},
        }
    );

    if ( @$series == 0 ) {

        # assign series to project/studio
        project::assign_series(
            $config,
            {
                project_id => $entry->{project_id},
                studio_id  => $entry->{studio_id},
                series_id  => $entry->{series_id},
            }
        );

    } else {
        print STDERR
"event $entry->{event_id} already assigned to project $entry->{project_id}, studio $entry->{studio_id}, series $entry->{series_id}\n";
    }

    $config->{access}->{write} = 0;
    uac::print_info("event successfully assigned to series");
    return;
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
        if ( $params->{action} =~ /^(assign_series)$/ ) {
            $checked->{action} = $params->{action};
        }
    }

    #numeric values
    $checked->{exclude} = 0;
    entry::set_numbers( $checked, $params, [
        'id', 'project_id', 'studio_id', 'series_id'
    ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check( $config, $params->{template}, 'assign-series' );

    return $checked;
}

__DATA__

SELECT ps.project_id, ps.studio_id, ps.series_id,p.name,s.name,se.series_name,se.title
FROM calcms_project_series ps ,calcms_projects p,calcms_studios s,calcms_series se
where ps.project_id=p.project_id and ps.studio_id=s.id and ps.series_id=se.id
order by se.series_name,p.name,s.name

