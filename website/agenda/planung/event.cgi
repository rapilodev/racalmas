#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Encode();
use Data::Dumper;
$Data::Dumper::SortKeys=1;
use MIME::Base64();
use Encode::Locale();

use params();
use config();
use entry();
use log();
use template();
use db();
use auth();
use uac();

#use roles;
use time();
use markup();
use project();
use studios();
use events();
use series();
use series_dates();
use series_events();
use user_stats();
use localization();
use eventOps();
use images();

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
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
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

#set user at params->presets->user
$request = uac::prepare_request( $request, $user_presets );

$params = $request->{params}->{checked};

#show header
unless ( params::isJson() ) {
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
    template::process( $config, 'print', template::check( $config, 'default.html' ),
        $headerParams );
}
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
    <script src="js/datetime.js" type="text/javascript"></script>
    <script src="js/event.js" type="text/javascript"></script>
    <link rel="stylesheet" href="css/event.css" type="text/css" /> 
} unless (params::isJson);

if ( defined $params->{action} ) {
    if (   ( $params->{action} eq 'show_new_event' )
        || ( $params->{action} eq 'show_new_event_from_schedule' ) )
    {
        show_new_event( $config, $request );
        return;
    }

    if (   ( $params->{action} eq 'create_event' )
        || ( $params->{action} eq 'create_event_from_schedule' ) )
    {
        $params->{event_id} = create_event( $config, $request );
        unless ( defined $params->{event_id} ) {
            uac::print_error("failed");
            return;
        }
    }
    if ( $params->{action} eq 'get_json' ) {
        getJson( $config, $request );
        return;
    }
    if ( $params->{action} eq 'delete' ) { delete_event( $config, $request ) }
    if ( $params->{action} eq 'save' ) { save_event( $config, $request ) }
    if ( $params->{action} eq 'download' ) { download( $config, $request ) }
}
$config->{access}->{write} = 0;
show_event( $config, $request );

#show existing event for edit
sub show_event {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show event" );
            return;
        }
    }

    my $result = series_events::check_permission(
        $request,
        {
            permission => 'update_event_of_series,update_event_of_others',
            check_for  => [ 'studio', 'user', 'series', 'events' ],
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return undef;
    }
    $permissions->{update_event} = 1;
    print STDERR "check series permission ok\n";

    #TODO: move to JS
    my @durations = ();
    for my $duration ( @{ time::getDurations() } ) {
        my $entry = {
            name  => sprintf( "%02d:%02d", $duration / 60, $duration % 60 ),
            value => $duration
        };
        push @durations, $entry;
    }

    my $event = series::get_event(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    unless ( defined $event ) {
        uac::print_error("event not found");
    }

    my $editLock = 1;
    if (   ( defined $permissions->{update_event_after_week} )
        && ( $permissions->{update_event_after_week} eq '1' ) )
    {
        $editLock = 0;
    } else {
        $editLock = 0
          if (
            series::is_event_older_than_days(
                $config,
                {
                    project_id => $params->{project_id},
                    studio_id  => $params->{studio_id},
                    series_id  => $params->{series_id},
                    event_id   => $params->{event_id},
                    max_age    => 14
                }
            ) == 0
          );
    }

    # for rerun, deprecated
    if ( defined $params->{source_event_id} ) {
        my $event2 = series::get_event(
            $config,
            {
                allow_any => 1,

                #project_id => $params->{project_id},
                #studio_id  => $params->{studio_id},
                #series_id  => $params->{series_id},
                event_id => $params->{source_event_id},
                draft    => 0,
            }
        );
        if ( defined $event2 ) {
            for my $attr (
                'title',              'user_title',
                'excerpt',            'user_excerpt',
                'content',            'topic',
                'image',              'image_label',
                'series_image',       'series_image_label',
                'live no_event_sync', 'podcast_url',
                'archive_url',        'content_format'
              )
            {
                $event->{$attr} = $event2->{$attr};
            }
            $event->{recurrence} = eventOps::getRecurrenceBaseId($event2);
            $event->{rerun}      = 1;
        }
    }

    $event->{rerun} = 1 if ( $event->{rerun} =~ /a-z/ );
    $event->{series_id} = $params->{series_id};

    $event->{duration} = events::get_duration( $config, $event );
    $event->{durations} = \@durations;
    if ( defined $event->{duration} ) {
        for my $duration ( @{ $event->{durations} } ) {
            $duration->{selected} = 1 if ( $event->{duration} eq $duration->{value} );
        }
    }
    $event->{start} =~ s/(\d\d:\d\d)\:\d\d/$1/;
    $event->{end} =~ s/(\d\d:\d\d)\:\d\d/$1/;

    if ( ( defined $params->{setImage} ) and ( $params->{setImage} ne $event->{image} ) ) {
        $event->{image}          = $params->{setImage};
        $params->{forced_change} = 1;
    }

    # overwrite event with old one
    #my $series_events=get_series_events($config,{
    #    project_id => $params->{project_id},
    #    studio_id  => $params->{studio_id},
    #    series_id  => $params->{series_id}
    #});
    #my @series_events=();
    #for my $series_event (@$series_events){
    #    push @series_events, $series_event if ($series_event->{start} lt $event->{start});
    #}
    #$params->{series_events}=\@series_events;

    # get all series
    #my $series=series::get(
    #    $config,{
    #        project_id => $params->{project_id},
    #        studio_id  => $params->{studio_id},
    #    }
    #);
    #for my $serie (@$series){
    #    $serie->{selected}=1 if $params->{series_id}==$serie->{series_id};
    #}
    #$params->{series}=$series;

    # get event series
    my $series = series::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id}
        }
    );
    if ( scalar(@$series) == 1 ) {
        $event->{has_single_events} = $series->[0]->{has_single_events};
    }

   #$event->{rerun}=1 if ((defined $event->{rerun})&&($event->{rerun}ne'0')&&($event->{rerun}ne''));

    my $users = series::get_users(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id}
        }
    );
    $params->{series_users} = $users;

    $params->{series_users_email_list} = join( ',', ( map { $_->{email} } (@$users) ) );
    $params->{series_user_names} =
      join( ' und ', ( map { ( split( /\s+/, $_->{full_name} ) )[0] } (@$users) ) );

    for my $permission ( sort keys %{$permissions} ) {
        $params->{'allow'}->{$permission} = $permissions->{$permission};
    }

    for my $key ( keys %$event ) {
        $params->{$key} = $event->{$key};
    }
    $params->{event_edited} = 1
      if ( ( $params->{action} eq 'save' ) && ( !( defined $params->{error} ) ) );
    $params->{event_edited} = 1 if ( $params->{action} eq 'delete' );
    $params->{event_edited} = 1
      if ( ( $params->{action} eq 'create_event' ) && ( !( defined $params->{error} ) ) );
    $params->{event_edited} = 1
      if ( ( $params->{action} eq 'create_event_from_schedule' )
        && ( !( defined $params->{error} ) ) );
    $params->{user} = $params->{presets}->{user};

    # remove all edit permissions if event is over for more than 2 weeks
    if ( $editLock == 1 ) {
        for my $key ( keys %$params ) {
            unless ( $key =~ /create_download/ ) {
                delete $params->{allow}->{$key} if $key =~ /^(update|delete|create|assign)/;
            }
        }
        $params->{edit_lock} = 1;
    }
    
    for my $value ('markdown', 'creole'){
        $params->{"content_format_$value"}=1 if ($params->{content_format}//'') eq $value;
    }

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'event' } );
    template::process( $config, 'print', template::check( $config, 'edit-event' ), $params );
}

sub getJson {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show event" );
            return;
        }
    }

    my $result = series_events::check_permission(
        $request,
        {
            permission => 'update_event_of_series,update_event_of_others',
            check_for  => [ 'studio', 'user', 'series', 'events' ],
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return undef;
    }
    $permissions->{update_event} = 1;

    my $event = series::get_event(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    unless ( defined $event ) {
        uac::print_error("event not found");
    }

    $event->{rerun} = 1 if ( $event->{rerun} =~ /a-z/ );
    $event->{series_id} = $params->{series_id};
    $event->{start} =~ s/(\d\d:\d\d)\:\d\d/$1/;
    $event->{end} =~ s/(\d\d:\d\d)\:\d\d/$1/;

    # get event series
    my $series = series::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id}
        }
    );

    if ( scalar @$series == 1 ) {
        my $serie = $series->[0];
        $event->{has_single_events} = $serie->{has_single_events};
        if ( $event->{has_single_events} eq '1' ) {
            $event->{has_single_events} = 1;
            $event->{series_name}       = undef;
            $event->{episode}           = undef;
        }
    }

    $event->{duration} = events::get_duration( $config, $event );

    # for rerun
    if ( $params->{get_rerun} == 1 ) {
        $event->{recurrence} = eventOps::getRecurrenceBaseId($event);
        for my $key ( 'live', 'published', 'playout', 'archived', 'disable_event_sync', 'draft' ){
            $event->{$key}=0;
        }
        $event->{rerun}      = 1;

        #$event=events::calc_dates($config, $event);
    }

    #print to_json($event);
    template::process( $config, 'print', 'json-p', $event );
}

#show new event from schedule
sub show_new_event {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    if ( $params->{action} eq 'show_new_event' ) {
        $params->{show_new_event} = 1;
        unless ( $permissions->{create_event} == 1 ) {
            uac::permissions_denied('create_event');
            return;
        }
    } elsif ( $params->{action} eq 'show_new_event_from_schedule' ) {
        $params->{show_new_event_from_schedule} = 1;
        unless ( $permissions->{create_event_from_schedule} == 1 ) {
            uac::permissions_denied('create_event_from_schedule');
            return;
        }
    } else {
        uac::print_error("invalid action");
        return 1;
    }

    my $event = eventOps::getNewEvent( $config, $params, $params->{action} );

    #copy event to template params
    for my $key ( keys %$event ) {
        $params->{$key} = $event->{$key};
    }

    #add duration selectbox
    #TODO: move to javascript
    my @durations = ();
    for my $duration ( @{ time::getDurations() } ) {
        my $entry = {
            name  => sprintf( "%02d:%02d", $duration / 60, $duration % 60 ),
            value => $duration
        };
        push @durations, $entry;
    }
    $params->{durations} = \@durations;

    #set duration preset
    for my $duration ( @{ $params->{durations} } ) {
        $duration->{selected} = 1 if ( $event->{duration} eq $duration->{value} );
    }

    #check user permissions and then:
    $permissions->{update_event} = 1;

    #set permissions to template
    for my $permission ( keys %{ $request->{permissions} } ) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    for my $value ('markdown', 'creole'){
        $params->{"content_format_$value"}=1 if ($params->{content_format}//'') eq $value;
    }

    $params->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'event,comment' } );
    template::process( $config, 'print', template::check( $config, 'edit-event' ), $params );
}

sub delete_event {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $event = {};
    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr );
            return;
        }
        $event->{$attr} = $params->{$attr};
    }

    my $result = series_events::check_permission(
        $request,
        {
            permission => 'delete_event',
            check_for  => [ 'studio', 'user', 'series', 'events', 'event_age' ],
            project_id => $params->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
            event_id   => $event->{event_id}
        }
    );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return undef;
    }

    $config->{access}->{write} = 1;

    #set user to be added to history
    $event->{user} = $params->{presets}->{user};
    $result = series_events::delete_event( $config, $event );
    unless ( defined $result ) {
        uac::print_error('could not delete event');
        return undef;
    }

    user_stats::increase(
        $config,
        'delete_events',
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
            user       => $event->{user}
        }
    );

    uac::print_info("event deleted");
}

#save existing event
sub save_event {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show event" );
            return;
        }
    }

    my $start = $params->{start_date};
    my $end = time::add_minutes_to_datetime( $params->{start_date}, $params->{duration} );

    #check permissions
    my $options = {
        permission => 'update_event_of_series,update_event_of_others',
        check_for  => [ 'studio', 'user', 'series', 'events', 'studio_timeslots', 'event_age' ],
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        series_id  => $params->{series_id},
        event_id   => $params->{event_id},
        draft      => $params->{draft},
        start      => $start,
        end        => $end,
    };

    my $result = series_events::check_permission( $request, $options );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return;
    }

    #changed columns depending on permissions
    my $entry = { id => $params->{event_id} };

    my $found = 0;

    #content fields
    for my $key (
        'content',            'topic',       'title',        'excerpt',
        'episode',            'image',       'series_image', 'image_label',
        'series_image_label', 'podcast_url', 'archive_url',  'content_format'
      )
    {
        next unless defined $permissions->{ 'update_event_field_' . $key };
        if ( $permissions->{ 'update_event_field_' . $key } eq '1' ) {
            next unless defined $params->{$key};
            $entry->{$key} = $params->{$key};
            $found++;
        }
    }

    #user extension fields
    for my $key ( 'title', 'excerpt' ) {
        next unless defined $permissions->{ 'update_event_field_' . $key . '_extension' };
        if ( $permissions->{ 'update_event_field_' . $key . '_extension' } eq '1' ) {
            next unless defined $params->{ 'user_' . $key };
            $entry->{ 'user_' . $key } = $params->{ 'user_' . $key };
            $found++;
        }
    }

    #status field
    for
      my $key ( 'live', 'published', 'playout', 'archived', 'rerun', 'disable_event_sync', 'draft' )
    {
        next unless defined $permissions->{ 'update_event_status_' . $key };
        if ( $permissions->{ 'update_event_status_' . $key } eq '1' ) {
            $entry->{$key} = $params->{$key} || 0;
            $found++;
        }
    }

    $entry->{modified_by} = $params->{presets}->{user};

    #get event from database (for history)
    my $event = series::get_event(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    unless ( defined $event ) {
        uac::print_error("event not found");
        return;
    }

    # set series image
    my $series = series::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
        }
    );
    my $serie = $series->[0];
    unless ( defined $serie ) {
        uac::print_error("series not found");
        return;
    }
    $entry->{image}        = images::normalizeName( $serie->{image} );
    $entry->{series_image} = images::normalizeName( $serie->{series_image} );

    $config->{access}->{write} = 1;

    #update content
    if ( $found > 0 ) {
        $entry = series_events::save_content( $config, $entry );
        for my $key ( keys %$entry ) {
            $event->{$key} = $entry->{$key};
        }
    }

    #update time
    if (   ( defined $permissions->{update_event_time} )
        && ( $permissions->{update_event_time} eq '1' ) )
    {
        my $entry = {
            id         => $params->{event_id},
            start_date => $params->{start_date},
            duration   => $params->{duration},

            #        end                  => $params->{end_date} ,
        };
        $entry = series_events::save_event_time( $config, $entry );
        for my $key ( keys %$entry ) {
            $event->{$key} = $entry->{$key};
        }
    }

    $event->{project_id} = $params->{project_id};
    $event->{studio_id}  = $params->{studio_id};
    $event->{series_id}  = $params->{series_id};
    $event->{event_id}   = $params->{event_id};
    $event->{user}       = $params->{presets}->{user};

    #update recurrences
    series::update_recurring_events( $config, $event );

    #update history
    event_history::insert( $config, $event );

    user_stats::increase(
        $config,
        'update_events',
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id},
            user       => $event->{user}
        }
    );

    #print "error" unless (defined $result);
    $config->{access}->{write} = 0;
    uac::print_info("event saved");
}

sub create_event {
    my $config  = shift;
    my $request = shift;

    my $params = $request->{params}->{checked};
    my $event  = $request->{params}->{checked};
    my $action = $params->{action};
    return eventOps::createEvent( $request, $event, $action );

}

#TODO: replace permission check with download
sub download {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $result = series_events::check_permission(
        $request,
        {
            permission => 'update_event_of_series,update_event_of_others',
            check_for  => [ 'studio', 'user', 'series', 'events' ],
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    unless ( $result eq '1' ) {
        uac::print_error($result);
        return undef;
    }
    $permissions->{update_event} = 1;

    my $request2 = {
        params => {
            checked => events::check_params(
                $config,
                {
                    event_id => $params->{event_id},
                    template => 'no',
                    limit    => 1,

                    #no_exclude => 1
                }
            )
        },
        config      => $request->{config},
        permissions => $request->{permissions}
    };

    $request2->{params}->{checked}->{published} = 'all';
    my $events   = events::get( $config, $request2 );
    my $event    = $events->[0];
    my $datetime = $event->{start_datetime};
    if ( $datetime =~ /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d)\:(\d\d)/ ) {
        $datetime = $1 . '\ ' . $2 . '_' . $3;
    } else {
        print STDERR "event.cgi::download no valid datetime found $datetime\n";
        return;
    }
    my $archive_dir = $config->{locations}->{local_archive_dir};
    my $archive_url = $config->{locations}->{local_archive_url};
    print STDERR "archive_dir: " . $archive_dir . "\n";
    print STDERR "archive_url: " . $archive_url . "\n";
    print STDERR "event.cgi::download look for : $archive_dir/$datetime*.mp3\n";
    my @files = glob( $archive_dir . '/' . $datetime . '*.mp3' );

    if ( @files > 0 ) {
        my $file = $files[0];
        my $key  = int( rand(99999999999999999) );
        $key = MIME::Base64::encode_base64($key);
        $key =~ s/[^a-zA-Z0-9]//g;

        #decode filename
        $file = Encode::decode( "UTF-8", $file );

        my $cmd = "ln -s '" . $file . "' '" . $archive_dir . '/' . $key . ".mp3'";
        my $url = $archive_url . '/' . $key . '.mp3';

        #print $cmd."\n";
        print `$cmd`;

        $request->{params}->{checked}->{download} = ''
          . qq{<a href="$url" style="padding:8px;background:#39a1f4;color:white;border-radius:4px;" download="$event->{series_name}#$event->{episode}.mp3">}
          . q{Download: }
          . $event->{start_date_name} . ", "
          . $event->{start_time_name} . " - "
          . $event->{full_title}
          . qq{</a>\n}
          . qq{<pre>$url</pre>\n}
          . qq{\nDer Link wird nach 7 Tagen geloescht.};
    }
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked  = {};
    my $template = '';
    $checked->{template} = template::check( $config, $params->{template}, 'series' );

    entry::set_numbers( $checked, $params, [
        'id',      'project_id', 'studio_id', 'default_studio_id',
        'user_id', 'series_id',  'event_id',  'source_event_id',
        'episode'
    ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    #scalars
    entry::set_strings( $checked, $params, [
        'studio', 'search', 'from', 'till', 'hide_series'
    ]);

    entry::set_numbers( $checked, $params, [
        'duration', 'recurrence' ]);

    entry::set_bools( $checked, $params, [
        'live',  'published', 'playout',            'archived',
        'rerun', 'draft',     'disable_event_sync', 'get_rerun'
    ]);

    entry::set_strings( $checked, $params, [
        'series_name',  'title',        'excerpt',    'content',
        'topic',        'program',      'category',   'image',
        'series_image', 'user_content', 'user_title', 'user_excerpt',
        'podcast_url',  'archive_url',  'setImage',   'content_format'
    ]);
    
    #dates
    for my $param ( 'start_date', 'end_date' ) {
        if (   ( defined $params->{$param} )
            && ( $params->{$param} =~ /(\d\d\d\d\-\d\d\-\d\d \d\d\:\d\d)/ ) )
        {
            $checked->{$param} = $1 . ':00';
        }
    }

    $checked->{action} = entry::element_of( $params->{action}, 
        [ 'save', 'delete', 'download', 'show_new_event', 'show_new_event_from_schedule', 
          'create_event', 'create_event_from_schedule', 'get_json'
        ]
    )//'';
    return $checked;
}
