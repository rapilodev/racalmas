#!/usr/bin/perl 

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();

use series();
use localization();
use user_selected_events();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( ( !defined $user ) || ( $user eq '' ) );

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

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    },
};
$request = uac::prepare_request( $request, $user_presets );

$params = $request->{params}->{checked};
$params = uac::set_template_permissions( $request->{permissions}, $params );
$params->{loc} = localization::get( $config, { user => $user, file => 'select-event' } );

#process header
print "Content-type:text/html; charset=UTF-8;\n\n";

return unless uac::check( $config, $params, $user_presets ) == 1;
show_events( $config, $request );

#TODO: filter by published, draft
sub show_events {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_event} == 1 ) {
        uac::permissions_denied('read_event');
        return;
    }

    my $entry = {
        user                    => $request->{user},
        project_id              => $params->{p_id},
        studio_id               => $params->{s_id},
        series_id               => $params->{series_id},
        filter_project_studio   => $params->{selectProjectStudio},
        filter_series           => $params->{selectSeries},
    };
    my $preset = user_selected_events::get($config, $entry);
    
    # get user projects
    my $user_projects = uac::get_projects_by_user( $config, { user => $request->{user} } );
    my $project_by_id = {};
    for my $project (@$user_projects) {
        $project_by_id->{ $project->{project_id} } = $project;
    }

    # get user studios
    my $user_studios = uac::get_studios_by_user( $config, { user => $request->{user} } );
    for my $studio (@$user_studios) {
        my $project_id = $studio->{project_id};
        my $studio_id  = $studio->{id};
        $studio->{project_name} = $project_by_id->{$project_id}->{name};
        if ($preset) {
            $studio->{selected} = 1 if $project_id eq $preset->{selected_project} and $studio_id eq $preset->{selected_studio};
        } else {
            $studio->{selected} = 1 if $project_id eq $params->{p_id} and $studio_id eq $params->{s_id};
        }   
    }

    # get series
    my $options = {};
    if ($preset){
        $options->{project_id} = $preset->{selected_project};
        $options->{studio_id}  = $preset->{selected_studio};
    }else{
        $options->{project_id} = $params->{p_id} if defined $params->{p_id};
        $options->{studio_id}  = $params->{s_id} if defined $params->{s_id};
    }
    my $series = series::get( $config, $options );

    for my $serie (@$series) {
        if ( defined $params->{series_id} ){
            if ($preset){
                $serie->{selected} = 1 if $serie->{series_id} eq $preset->{selected_series};
            } else {
                $serie->{selected} = 1 if $serie->{series_id} eq $params->{series_id};
            }
        } 
        $serie->{series_name} = 'Einzelsendung' if $serie->{series_name} eq '_single_';
    }

    # get events
    if ($preset){
        $options->{series_id} = $preset->{selected_series};
    }else{
        $options->{series_id} = $params->{series_id} if defined $params->{series_id};
    }
    $options->{from_date} = $params->{from_date} if defined $params->{from_date};
    $options->{till_date} = $params->{till_date} if defined $params->{till_date};
    $options->{set_no_listen_keys} = 1;
    my $events = series::get_events( $config, $options );

    my $preset_year = '';
    for my $event ( @$events ) {
        if ($preset and $preset->{selected_event} eq $event->{id}){
            $event->{selected} = 1;
            $preset_year = (split /\-/, $event->{start_date})[0];
        }
    }

    # filter by year
    my $years = [];
    for my $year ( 2005 .. 2025 ) {
        my $date = { year => $year };
        if ( $preset ){
            $date->{selected} = 1 if $preset_year eq $year;
        }else{
            $date->{selected} = 1 if ( defined $params->{from_date} ) && ( $params->{from_date} eq $year . '-01-01' );
        }
        push @$years, $date;
    }

    $params->{studios} = $user_studios;
    $params->{series}  = $series;
    $params->{events}  = $events;
    $params->{years}   = $years;
    template::process( $config, 'print', $params->{template}, $params );
    return;
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    entry::set_numbers( $checked, $params, [
        'id', 'project_id', 'studio_id', 'series_id', 'event_id', 'p_id', 's_id'
    ]);

    entry::set_bools( $checked, $params, 
        [ 'selectProjectStudio', 'selectSeries', 'selectRange' ] 
    );

    for my $param ('resultElemId') {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^[a-zA-ZöäüÖÄÜß_\d]+$/ ) ) {
            $checked->{$param} = $params->{$param};
        }
    }

    for my $param ( 'from_date', 'till_date' ) {
        if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /(\d\d\d\d\-\d\d\-\d\d)/ ) ) {
            $checked->{$param} = $1;
        }
    }

    if ( ( defined $params->{year} ) && ( $params->{year} =~ /^\d\d\d\d$/ ) ) {
        $checked->{year} = $params->{year};
    }

    # set defaults for project and studio id if not given
    $checked->{s_id} = $params->{studio_id}  || '-1' unless defined $params->{s_id};
    $checked->{p_id} = $params->{project_id} || '-1' unless defined $params->{p_id};

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check( $config, $params->{template}, 'select-event' );

    return $checked;
}

