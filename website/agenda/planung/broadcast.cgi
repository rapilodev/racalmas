#!/usr/bin/perl

use strict;
use warnings;

use Encode();
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use MIME::Base64();
use Encode::Locale();
use File::Basename qw(basename);
use Scalar::Util qw(blessed);
use Try::Tiny qw(try catch finally);

use params();
use config();
use entry();
use log();
use template();
use db();
use auth();
use uac();

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

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    my $out = $session->{header} // '';
    if ($params->{action} =~ m/^(edit|show_new_event|show_new_event_from_schedule)$/) {
        my $headerParams =
            uac::set_template_permissions($request->{permissions}, $params);
        $headerParams->{loc} = localization::get($config,
            { user => $session->{user}, file => 'menu' });
        $out .=
            template::process($config,
            template::check($config, 'event-header.html'),
            $headerParams);
    }
    uac::check($config, $params, $user_presets);
    $params->{action} //= 'edit';
    return $out . show_event($config, $request) if $params->{action} eq 'edit';
    return $out . show_new_event($config, $request) if ($params->{action} eq 'show_new_event')
        || ($params->{action} eq 'show_new_event_from_schedule');
    return $out . create_event($config, $request)if ($params->{action} eq 'create_event')
        || ($params->{action} eq 'create_event_from_schedule');
    return $out . get_json($config, $request) if $params->{action} eq 'get_json';
    return $out . delete_event($config, $request) if $params->{action} eq 'delete';
    return $out . save_event($config, $request) if $params->{action} eq 'save';
    return $out . download($config, $request) if $params->{action} eq 'download';
    return $out . download_audio($config, $request) if $params->{action} eq 'download_audio';
    ActionError->throw(error => "invalid action");
}

#show existing event for edit
sub show_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "missing $attr to show event")
            unless defined $params->{$attr};
    }

    series_events::check_permission(
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
    $permissions->{update_event} = 1;

    #TODO: move to JS
    my @durations = ();
    for my $duration (@{ time::getDurations() }) {
        my $entry = {
            name  => sprintf("%02d:%02d", $duration / 60, $duration % 60),
            value => $duration
        };
        push @durations, $entry;
    }

    my $event = series::get_event(
        $config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id') }
    );
    unless (defined $event) {
        EventExistError->throw(error => "event not found");
    }

    my $editLock = 1;
    if ((defined $permissions->{update_event_after_week})
        && ($permissions->{update_event_after_week} eq '1'))
    {
        $editLock = 0;
    } else {
        $editLock = 0
          if (
            series::is_event_older_than_days(
                $config,
                {
                    uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id'),
                    max_age    => 14
                }
            ) == 0
          );
    }

    # for rerun, deprecated
    if (defined $params->{source_event_id}) {
        my $event2 = series::get_event(
            $config,
            {
                allow_any => 1,
                event_id => $params->{source_event_id},
                draft    => 0,
            }
        );
        if (defined $event2) {
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

    $event->{rerun} = 1 if ($event->{rerun} =~ /a-z/);
    $event->{series_id} = $params->{series_id};

    $event->{duration} = events::get_duration($config, $event);
    $event->{durations} = \@durations;
    if (defined $event->{duration}) {
        for my $duration (@{ $event->{durations} }) {
            $duration->{selected} = 1 if ($event->{duration} eq $duration->{value});
        }
    }
    $event->{start} =~ s/(\d\d:\d\d)\:\d\d/$1/;
    $event->{end} =~ s/(\d\d:\d\d)\:\d\d/$1/;

    if ((defined $params->{setImage}) and ($params->{setImage} ne $event->{image})) {
        $event->{image}          = $params->{setImage};
        $params->{forced_change} = 1;
    }

    # get event series
    my $series = series::get(
        $config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id') }
    );
    if (scalar(@$series) == 1) {
        $event->{has_single_events} = $series->[0]->{has_single_events};
    }

    my $users = series::get_users(
        $config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id') }
    );
    $params->{series_users} = $users;

    $params->{series_users_email_list} = join(',', (map { $_->{email} } (@$users)));
    $params->{series_user_names} =
      join(' und ', (map { (split(/\s+/, $_->{full_name}))[0] } (@$users)));

    for my $permission (sort keys %{$permissions}) {
        $params->{'allow'}->{$permission} = $permissions->{$permission};
    }

    for my $key (sort keys %$event) {
        $params->{$key} = $event->{$key};
    }
    $params->{event_edited} = 1
      if (($params->{action} eq 'save') && (!(defined $params->{error})));
    $params->{event_edited} = 1 if ($params->{action} eq 'delete');
    $params->{event_edited} = 1
      if (($params->{action} eq 'create_event') && (!(defined $params->{error})));
    $params->{event_edited} = 1
      if (($params->{action} eq 'create_event_from_schedule')
        && (!(defined $params->{error})));
    $params->{user} = $params->{presets}->{user};

    # remove all edit permissions if event is over for more than 2 weeks
    if ($editLock == 1) {
        for my $key (keys %$params) {
            unless ($key =~ /create_download/) {
                delete $params->{allow}->{$key} if $key =~ /^(update|delete|create|assign)/;
            }
        }
        $params->{edit_lock} = 1;
    }

    for my $value ('markdown', 'creole') {
        $params->{"content_format_$value"}=1 if ($params->{content_format}//'') eq $value;
    }

    $params->{loc} =
        localization::get($config,
        { user => $params->{presets}->{user}, file => 'event' });
    return template::process($config, template::check($config, 'edit-event'),
        $params);
}

sub get_json {
    my ($config, $request) = @_;
    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        unless (defined $params->{$attr}) {
            ParamError->throw(error => "missing " . $attr . " to show event");
    }
    }

    series_events::check_permission(
        $request,
        {
            permission => 'update_event_of_series,update_event_of_others',
            check_for  => [ 'studio', 'user', 'series', 'events' ],
            uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id')
        }
    );
    $permissions->{update_event} = 1;

    my $event = series::get_event(
        $config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id') }
    );
    unless (defined $event) {
        ParamError->throw(error => "event not found");
    }

    $event->{rerun} = 1 if ($event->{rerun} =~ /a-z/);
    $event->{series_id} = $params->{series_id};
    $event->{start} =~ s/(\d\d:\d\d)\:\d\d/$1/;
    $event->{end} =~ s/(\d\d:\d\d)\:\d\d/$1/;

    # get event series
    my $series = series::get(
        $config,
        { uac::set($params, 'project_id', 'studio_id', 'series_id') }
    );

    if (scalar @$series == 1) {
        my $serie = $series->[0];
        $event->{has_single_events} = $serie->{has_single_events};
        if ($event->{has_single_events} eq '1') {
            $event->{has_single_events} = 1;
            $event->{series_name}       = undef;
            $event->{episode}           = undef;
        }
    }

    $event->{duration} = events::get_duration($config, $event);

    # for rerun
    if ($params->{get_rerun} == 1) {
        $event->{recurrence} = eventOps::getRecurrenceBaseId($event);
        for my $key ('live', 'published', 'playout', 'archived', 'disable_event_sync', 'draft'){
            $event->{$key} = 0;
        }
        $event->{rerun} = 1;
    }
    return template::process($config, 'json-p', $event);
}

#show new event from schedule
sub show_new_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    if ($params->{action} eq 'show_new_event') {
        $params->{show_new_event} = 1;
        unless ($permissions->{create_event} == 1) {
            PermissionError->throw(
                error => 'Missing permission to create_event');
        }
    } elsif ($params->{action} eq 'show_new_event_from_schedule') {
        $params->{show_new_event_from_schedule} = 1;
        unless ($permissions->{create_event_from_schedule} == 1) {
            PermissionError->throw(
                error => 'Missing permission to create_event_from_schedule');
        }
    } else {
        ActionError->throw(error => "invalid action");
    }

    my $event = eventOps::getNewEvent($config, $params, $params->{action});

    #copy event to template params
    for my $key (keys %$event) {
        $params->{$key} = $event->{$key};
    }

    #add duration selectbox
    #TODO: move to javascript
    my @durations = ();
    for my $duration (@{ time::getDurations() }) {
        my $entry = {
            name  => sprintf("%02d:%02d", $duration / 60, $duration % 60),
            value => $duration
        };
        push @durations, $entry;
    }
    $params->{durations} = \@durations;

    #set duration preset
    for my $duration (@{ $params->{durations} }) {
        $duration->{selected} = 1 if ($event->{duration} eq $duration->{value});
    }

    #check user permissions and then:
    $permissions->{update_event} = 1;

    #set permissions to template
    for my $permission (keys %{ $request->{permissions} }) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    for my $value ('markdown', 'creole'){
        $params->{"content_format_$value"}=1 if ($params->{content_format}//'') eq $value;
    }

    $params->{loc} =
        localization::get($config,
        { user => $params->{presets}->{user}, file => 'event,comment' });
    return template::process($config, template::check($config, 'edit-event'),
        $params);
}

sub delete_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    my $event = {};
    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "missing " . $attr)
            unless defined $params->{$attr};
        $event->{$attr} = $params->{$attr};
    }

    series_events::check_permission(
        $request,
        {
            permission => 'delete_event',
            check_for  => [ 'studio', 'user', 'series', 'events', 'event_age' ],
            uac::set($event, 'project_id', 'studio_id', 'series_id', 'event_id')
        }
    );
    local $config->{access}->{write} = 1;

    #set user to be added to history
    $event->{user} = $params->{presets}->{user};
    series_events::delete_event($config, $event);

    user_stats::increase($config, 'delete_events', {
        uac::set($event, 'project_id', 'studio_id', 'series_id', 'user')
    });
    return uac::json(
        {
            "entry" => {
            uac::set($event, 'project_id', 'studio_id', 'series_id', 'event_id')
            },
            "status" => "deleted"
        }
    );
}

#save existing event
sub save_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "missing " . $attr . " to show event")
            unless defined $params->{$attr};
    }

    my $start = $params->{start_date};
    my $end = time::add_minutes_to_datetime($params->{start_date}, $params->{duration});

    #check permissions
    my $options = {
        permission => 'update_event_of_series,update_event_of_others',
        check_for  => [ 'studio', 'user', 'series', 'events', 'studio_timeslots', 'event_age' ],
        uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id'),
        draft      => $params->{draft},
        start      => $start,
        end        => $end,
    };

    series_events::check_permission($request, $options);

    #changed columns depending on permissions
    my $entry = { id => $params->{event_id} };

    my $found = 0;

    #content fields
    for my $key (
        'content',            'topic',       'title',        'excerpt',
        'episode',            'image',       'series_image', 'image_label',
        'series_image_label', 'podcast_url', 'archive_url',  'content_format'
    ) {
        next unless defined $permissions->{ 'update_event_field_' . $key };
        if ($permissions->{ 'update_event_field_' . $key } eq '1') {
            next unless defined $params->{$key};
            $entry->{$key} = $params->{$key};
            $found++;
        }
    }

    #user extension fields
    for my $key ('title', 'excerpt') {
        next unless defined $permissions->{ 'update_event_field_' . $key . '_extension' };
        if ($permissions->{ 'update_event_field_' . $key . '_extension' } eq '1') {
            next unless defined $params->{ 'user_' . $key };
            $entry->{ 'user_' . $key } = $params->{ 'user_' . $key };
            $found++;
        }
    }

    #status field
    for my $key ('live', 'published', 'playout', 'archived', 'rerun', 
      'disable_event_sync', 'draft'
    ) {
        next unless defined $permissions->{ 'update_event_status_' . $key };
        if ($permissions->{ 'update_event_status_' . $key } eq '1') {
            $entry->{$key} = $params->{$key} || 0;
            $found++;
        }
    }

    $entry->{modified_by} = $params->{presets}->{user};

    #get event from database (for history)
    my $event = series::get_event(
        $config,
        {
            uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id')
        }
    );
    unless (defined $event) {
        ExistError->throw(error => "event not found");
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
    unless (defined $serie) {
        ExistError->throw(error => "series not found");
        return;
    }
    $entry->{image} = $serie->{series_image}
        if !$serie->{image} && $serie->{series_image};
    $entry->{image}        = images::normalizeName($entry->{image});
    $entry->{series_image} = images::normalizeName($serie->{series_image});

    local $config->{access}->{write} = 1;

    #update content
    if ($found > 0) {
        $entry = series_events::save_content($config, $entry);
        for my $key (keys %$entry) {
            $event->{$key} = $entry->{$key};
        }
    }

    #update time
    if ((defined $permissions->{update_event_time})
        && ($permissions->{update_event_time} eq '1'))
    {
        my $entry = {
            id         => $params->{event_id},
            start_date => $params->{start_date},
            duration   => $params->{duration},
        };
        $entry = series_events::save_event_time($config, $entry);
        for my $key (keys %$entry) {
            $event->{$key} = $entry->{$key};
        }
    }

    $event->{project_id} = $params->{project_id};
    $event->{studio_id}  = $params->{studio_id};
    $event->{series_id}  = $params->{series_id};
    $event->{event_id}   = $params->{event_id};
    $event->{user}       = $params->{presets}->{user};

    #update recurrences
    series::update_recurring_events($config, $event);

    #update history
    event_history::insert($config, $event);

    user_stats::increase($config, 'update_events',{
        uac::set($event, 'project_id', 'studio_id', 'series_id', 'user')
    });
    $config->{access}->{write} = 0;
    return uac::json(
        {
            "entry" => {
                project_id => $event->{project_id},
                studio_id  => $event->{studio_id},
                series_id  => $event->{series_id},
                event_id   => $params->{event_id}
            },
            "status" => "saved"
        }
    );
}

sub create_event {
    my ($config, $request) = @_;

    my $params = $request->{params}->{checked};
    my $event  = $request->{params}->{checked};
    my $action = $params->{action};
    my $event_id = eventOps::createEvent($request, $event, $action);
    EventError->throw(error => "cannot create event") unless $event_id;
    return uac::json(
        {
            "entry" => {
                uac::set($event, 'project_id', 'studio_id', 'series_id'),
                event_id   => $event_id
            },
            "status" => "created"
        }
    );
}

sub get_download_event {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    series_events::check_permission(
        $request,
        {
            permission => 'update_event_of_series,update_event_of_others',
            check_for  => [ 'studio', 'user', 'series', 'events' ],
            uac::set($params, 'project_id', 'studio_id', 'series_id', 'event_id')
        }
    );
    $permissions->{update_event} = 1;

    my $request2 = {
        params => {
            checked => events::check_params(
                $config,
                {
                    event_id => $params->{event_id},
                    template => 'no',
                    limit    => 1,
                }
            )
        },
        config      => $request->{config},
        permissions => $request->{permissions}
    };

    $request2->{params}->{checked}->{published} = 'all';
    $request2->{params}->{checked}->{phase} = 'all';
    my $events = events::get($config, $request2);
    my $event  = $events->[0];
    return $event;
}

#TODO: replace permission check with download
sub download {
    my ($config, $request) = @_;

    my $event = get_download_event($config, $request);
    my $datetime = $event->{start_datetime};
    if ($datetime =~ /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d)\:(\d\d)/) {
        $datetime = $1 . '\ ' . $2 . '_' . $3;
    } else {
        print STDERR "broadcast.cgi::download no valid datetime found $datetime\n";
        return;
    }
    my $archive_dir = $config->{locations}->{local_archive_dir};
    my $archive_url = $config->{locations}->{local_archive_url};
    my @files = glob($archive_dir . '/' . $datetime . '*.mp3');

    if (@files > 0) {
        my $file = $files[0];
        my $key  = int(rand(99999999999999999));
        $key = MIME::Base64::encode_base64($key);
        $key =~ s/[^a-zA-Z0-9]//g;
        $key = 'shared-' . $key;

        #decode filename
        $file = Encode::decode("UTF-8", $file);

        my $cmd = "ln -s '" . $file . "' '" . $archive_dir . '/' . $key . ".mp3'";
        my $url = $archive_url . '/' . $key . '.mp3';

        #print $cmd."\n";
        print `$cmd`;

        $request->{params}->{checked}->{download} = ''
          . qq{<a href="$url" style="color:#39a1f4;" download="$event->{series_name}#$event->{episode}.mp3">}
          . q{Download: }
          . $event->{start_date_name} . ", "
          . $event->{start_time_name} . " - "
          . $event->{full_title}
          . qq{</a>\n}
          . qq{<pre>$url</pre>\n}
          . qq{\nDer Link wird nach 7 Tagen geloescht.};
    }
}

sub download_audio {
    my ($config, $request) = @_;

    my $event = get_download_event($config, $request);
    my $datetime = $event->{start_datetime};
    if ($datetime =~ /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d)\:(\d\d)/) {
        $datetime = $1 . '\ ' . $2 . '_' . $3;
    } else {
        print STDERR "broadcast.cgi::download no valid datetime found $datetime\n";
        return;
    }
    my $archive_dir = $config->{locations}->{local_archive_dir};
    print STDERR "archive_dir: " . $archive_dir . "\n";
    print STDERR "broadcast.cgi::download look for : $archive_dir/$datetime*.mp3\n";
    my @files = glob($archive_dir . '/' . $datetime . '*.mp3');
    if (@files > 0) {
        my $file = $files[0];
        $file = Encode::decode("UTF-8", $file);
        print qq{Content-Disposition: attachment; filename="}.basename($file).qq{"\n};
        print qq{Content-Type: audio/mpeg\n\n};
        binmode STDOUT;
        open my $fh, '<:raw', $file;
        while (<$fh>) {
            print $_;
        }
        close $fh;
    }
}

sub check_params {
    my ($config, $params) = @_;

    my $checked  = {};
    my $template = '';
    $checked->{template} = template::check($config, $params->{template}, 'edit-event');

    entry::set_numbers($checked, $params, [
        'id',      'project_id', 'studio_id', 'default_studio_id',
        'user_id', 'series_id',  'event_id',  'source_event_id',
        'episode'
    ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    #scalars
    entry::set_strings($checked, $params,
        [ 'studio', 'search', 'from', 'till', 'hide_series' ]);

    entry::set_numbers($checked, $params, [ 'duration', 'recurrence' ]);

    entry::set_bools($checked, $params, [
        'live',  'published', 'playout',            'archived',
        'rerun', 'draft',     'disable_event_sync', 'get_rerun'
    ]);

    entry::set_strings($checked, $params, [
        'series_name',  'title',        'excerpt',    'content',
        'topic',        'program',      'image',
        'series_image', 'user_content', 'user_title', 'user_excerpt',
        'podcast_url',  'archive_url',  'setImage',   'content_format'
    ]);

    #dates
    for my $param ('start_date', 'end_date') {
        if ((defined $params->{$param})
            && ($params->{$param} =~ /(\d\d\d\d\-\d\d\-\d\d \d\d\:\d\d)/))
        {
            $checked->{$param} = $1 . ':00';
        }
    }

    $checked->{action} = entry::element_of($params->{action},
        [ 'save', 'delete', 'download', 'download_audio', 'show_new_event',
            'show_new_event_from_schedule',
          'create_event', 'create_event_from_schedule', 'get_json', 'edit'
        ]
    ) // '';
    return $checked;
}
