#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use ModPerl::Util ();
use Date::Calc();
use Time::Local();
use File::Temp();
use Scalar::Util qw(blessed);
use Try::Tiny;

use config();
use params();
use log();
use entry();
use localization();
use auth();
use uac();
use studios();
use series();
use template();
use audio_recordings();
use series_events();
use events();
use audio();
use time();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main, {upload => {limit => 700_000_000}});

sub main {
    my ($config, $session, $params, $user_presets, $request, $fh) = @_;

    $params = $request->{params}->{checked};
    uac::check($config, $params, $user_presets);
    my $permissions = $request->{permissions};

    if ($params->{action} eq 'show') {
        my $headerParams
            = uac::set_template_permissions($request->{permissions}, $params);
        $headerParams->{loc} = localization::get($config,
            {user => $session->{user}, file => 'menu'});
        my $out
            = template::process($config,
                template::check($config, 'default.html'),
                $headerParams);
        $out
            .= template::process($config,
                template::check($config, 'audio-recordings-header.html'),
                $headerParams)
            unless params::is_json;
        show_audio_recording($config, $request);
        print STDERR "$0 ERROR: " . $params->{error} . "\n"
            if $params->{error} ne '';
        $params->{loc} = localization::get($config,
            {user => $params->{presets}->{user}, file => 'audio-recordings'});
        $out .= template::process($config, $params->{template}, $params);
        return $out;

    } elsif ($params->{action} eq 'upload') {
        return upload_recording($config, $request, $session->{user}, $fh);
    } elsif ($params->{action} eq 'delete') {
        return delete_recording($config, $request);
    }
}

sub upload_recording {
    my ($config, $request, $user, $fh) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    PermissionError->throw(
        error => 'Missing permission to upload_audio_recordings')
        unless $permissions->{upload_audio_recordings};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "missing $attr to upload productions")
            unless defined $params->{$attr};
    }

    ParamError->throw(error => 'Could not get file handle') unless defined $fh;

    print STDERR "start upload\n";
    events::set_upload_status($config,
        {event_id => $params->{event_id}, upload_status => 'uploading'});
    my $fileInfo = upload_file($config, $fh, $params->{event_id}, $user,
        $params->{upload});
    $params->{error} .= $fileInfo->{error} if defined $fileInfo->{error};
    $params->{path} = $fileInfo->{path};
    $params->{size} = $fileInfo->{size};

    #print STDERR Dumper($params);
    #$params->{duration} = $fileInfo->{duration};

    if ($params->{error} eq '') {
        $params = update_database($config, $params, $user);
        events::set_upload_status(
            $config,
            {   event_id      => $params->{event_id},
                upload_status => 'uploaded'
            }
        );
    }

    if ($params->{error} ne '') {
        events::set_upload_status(
            $config,
            {   event_id      => $params->{event_id},
                upload_status => 'upload failed'
            }
        );
        AppError->throw(error => "audio file size is limited to "
                . int(70000000 / 1000000) . " MB!"
                . "Please make it smaller and try again!")
            if $params->{error} =~ /limit/;
    }
}

sub delete_file {
    my ($file) = @_;
    ConfigError->throw(error => "missing file") unless $file;
    if (-e $file) {
        if (-w $file) {
            unlink $file
                or PermissionError->throw(
                    error => "could not delete audio file '$file', $!\n");
        } else {
            PermissionError->throw(error =>
                    "cannot delete audio file '$file', missing permissions\n");
        }
    }
}

sub delete_recording {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    PermissionError->throw(
        error => 'Missing permission to delete_audio_recordings')
        unless $permissions->{delete_audio_recordings} == 1;

    for my $attr (
        'project_id', 'studio_id', 'event_id', 'path'
    ) {
        ParamError->throw(error => "missing " . $attr . " to delete production")
            unless defined $params->{$attr};
    }

    $config->{access}->{write} = 0;

    my $audioRecordings = audio_recordings::get(
        $config,
        {   project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            event_id   => $params->{event_id},
            path       => $params->{path}
        }
    );

    ParamError->throw(
        error => "could not find audio file $params->{path} in database")
        unless defined $audioRecordings && scalar @$audioRecordings > 0;

    my $targetDir = $config->{locations}->{local_audio_recordings_dir};
    my $file      = $targetDir . '/' . $params->{path};
    ConfigError->throw(
        error => "local_audio_recordings_dir' is not configured.")
        unless defined $targetDir;
    ConfigError->throw(error => "audio dir '$targetDir' does not exist")
        unless -d $targetDir;
    ConfigError->throw(
        error => "Cannot delete audio file '$file', file does not exist\n")
        unless -e $file;
    delete_file($file);

    $config->{access}->{write} = 1;
    $audioRecordings = audio_recordings::delete(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            event_id   => $params->{event_id},
            path       => $params->{path},
        }
    );
    $config->{access}->{write} = 0;
    return uac::json{status=>"deleted"};
}

sub show_audio_recording {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        ParamError->throw(error => "missing " . $attr . " to show productions")
            unless defined $params->{$attr};
    }

    my $event = series::get_event(
        $config,
        {   project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
            event_id   => $params->{event_id}
        }
    );
    AppError->throw(error => "event not found") unless defined $event;

    my $audioRecordings = audio_recordings::get(
        $config,
        {   project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            event_id   => $params->{event_id},
        }
    );
    for my $recording (@$audioRecordings) {
        $recording->{size} =~ s/(\d)(\d\d\d)$/$1\.$2/g;
        $recording->{size} =~ s/(\d)(\d\d\d\.\d\d\d)$/$1\.$2/g;

        $recording->{processed} = $recording->{processed} ? 'yes' : 'no';
        $recording->{mastered}  = $recording->{mastered}  ? 'yes' : 'no';

        $recording->{eventDuration} = get_duration($recording->{eventDuration});
        $recording->{audioDuration} = audio::formatDuration(
            $recording->{audioDuration},
            $recording->{eventDuration},
            get_duration($recording->{audioDuration})
        );

        $recording->{rmsLeft}
            = audio::formatLoudness($recording->{rmsLeft}, 'L:');
        $recording->{rmsRight}
            = audio::formatLoudness($recording->{rmsRight}, 'R:');
    }

    my $now      = time();
    my $timeZone = $config->{date}->{time_zone};
    my $start    = time::datetime_to_utc($event->{start}, $timeZone);
    my $end      = time::datetime_to_utc($event->{end},   $timeZone);
    if ($now > $end) {
        $params->{error}  = "upload is expired due to the show is over";
        $params->{isOver} = 1;
    }
    my $days = 24 * 60 * 60;
    $params->{error} = "show is more than a week ahead"
        if ($now + 7 * $days) < $start;

    $params->{event}            = $event;
    $params->{audio_recordings} = $audioRecordings;

}

sub get_duration {
    my ($duration) = @_;
    my $hour = int($duration / 3600);
    $duration -= $hour * 3600;

    my $minutes = int($duration / 60);
    $duration -= $minutes * 60;

    my $seconds = int($duration);
    $duration -= $seconds;

    my $milli = int(100 * $duration);
    return sprintf("%02d:%02d:%02d.%02d", $hour, $minutes, $seconds, $milli);
}

sub upload_file {
    my $config   = $_[0];
    my $fh       = $_[1];
    my $eventId  = $_[2];
    my $user     = $_[3] || '';
    my $filename = $_[4] || '';

    # check target directory
    my $targetDir = $config->{locations}->{local_audio_recordings_dir};
    ConfigError->throw(error => "local_audio_recordings_dir not configured")
        unless defined $targetDir;
    ConfigError->throw(error => "local_audio_recordings_dir does not exist")
        unless -e $targetDir;
    print STDERR Dumper("upload $fh");;

    # save file to disk
    my $userName = $user;
    $userName =~ s/[^a-zA-Z0-9\.\-\_]//g;

    my $time = time::time_to_datetime();
    $time =~ s/\:/\-/g;
    $time =~ s/\s/\_/g;
    $time =~ s/[^a-zA-Z0-9\.\-\_]//g;

    my $extension =~ (split(/\./, $filename))[-1];
    $filename     =~ s/\.$extension$//;
    $extension    =~ s/[^a-zA-Z0-9\.\-\_]//g;

    $filename = join('-', ($time, 'id' . $eventId, $userName, $filename));
    $filename =~ s/[^a-zA-Z0-9\.\-\_]//g;
    $filename .= $extension;

    my $tempFile = "$targetDir/$filename";
    print STDERR "tempFile=$tempFile\n";

    my $start = time();
    open my $out, '>', $tempFile
        or AppError->throw("error" => "Could not save upload $! $tempFile");
    binmode $out;
    my $buffer = '';
    print $out $buffer while read($fh, $buffer, 4096);
    close $out
        or AppError->throw("error" => "Could not save upload $! $tempFile");

    my $size = (stat($tempFile))[7];
    return {
        dir  => $targetDir,
        path => $filename,
        size => $size,
    };

}

sub update_database {
    my ($config, $params, $user) = @_;

    my $eventDuration = get_event_duration($config, $params->{event_id});

    my $entry = {
        project_id    => $params->{project_id},
        studio_id     => $params->{studio_id},
        event_id      => $params->{event_id},
        path          => $params->{path},
        size          => $params->{size},
        created_by    => $user,
        eventDuration => $eventDuration
    };

    #connect
    my $entries = audio_recordings::get(
        $config,
        {   project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            event_id   => $entry->{event_id},
            path       => $entry->{path}
        }
    );

    if ((defined $entries) && (scalar @$entries > 0)) {
        print STDERR "update\n";
        audio_recordings::update( $config, $entry );
        my $entry = $entries->[0];
        $params->{id} = $entry->{id};
    } else {
        print STDERR "insert\n";
        $entry->{created_by}    = $user;
        $entry->{processed}     = 0;
        $entry->{mastered}      = 0;
        $entry->{rmsLeft}       = 0.0;
        $entry->{rmsRight}      = 0.0;
        $entry->{audioDuration} = 0.0;
        $entry->{modified_at}   = time();
        $entry->{id} = audio_recordings::insert( $config, $entry );
        $params->{id} = $entry->{id};
    }
    call_hooks($config, $entry, $params);
    $params->{action_result} = 'done!';

    return $params;
}

sub call_hooks {
    my ($config, $entry, $params) = @_;
    print STDERR Dumper($config->{"audio-upload-hooks"});

    $entry = audio_recordings::get(
        $config,
        {   project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            event_id   => $entry->{event_id},
            path       => $entry->{path}
        }
    )->[0] or AppError->throw(error=>"Cannot find recording");

    for my $cmd (sort values %{$config->{"audio-upload-hooks"}}) {
        my $audio_file
            = $config->{locations}->{local_audio_recordings_dir} . '/'
            . $entry->{path};
        open(my $fh, '-|', $cmd, $audio_file)
            or AppError->throw(error=> "Failed to execute hook: $!");
        while (defined(my $line = (<$fh>))) {
            if ($line
                =~ m/^calcms_audio_recordings\.([a-zA-Z0-9_-]+)\s*=\s*(\S+)/
            ) {
                my ($key, $value) = ($1, $2);
                $entry->{$key} = $value;
                DbError->throw(error =>
                        "invalid column $key for table calcms_audio_recordings")
                    unless
                    exists audio_recordings::get_columns($config)->{$key};
                audio_recordings::update($config, $entry);
            } elsif ($line =~ m/^calcms_events\.([a-zA-Z0-9_-]+)\s*=\s*(\S+)/) {
                my ($key, $value) = ($1, $2);
                DbError->throw(
                    error => "invalid column $key for calcms_events\n")
                    unless exists {map {$_ => 1}
                        series_events::get_content_columns($config)}->{$key};
                series_events::save_content(
                    $config,
                    {   id   => $entry->{event_id},
                        $key => $value
                    }
                );
            }
        }
        close $fh or AppError->throw(error => "error in hook $cmd");
    }
}


# return event duration in seconds
sub get_event_duration {
    my ($config, $eventId) = @_;

    AppError->throw(error => "invalid eventId $eventId\n") if $eventId < 1;
    my $request = {
        params => {
            checked => events::check_params(
                $config,
                {   event_id => $eventId,
                    template => 'no',
                    limit    => 1,
                }
            )
        },
        config => $config
    };
    $request->{params}->{checked}->{published} = 'all';
    my $events = events::get($config, $request);
    AppError->throw(error =>
            "get_event_duration: no event found with event_id=$eventId\n")
        if scalar @$events == 0;
    my $event    = $events->[0];
    my $duration = time::get_duration_seconds($event->{start}, $event->{end},
        $config->{date}->{time_zone});
    return $duration;
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};
    $checked->{error}    = '';
    $checked->{template} = template::check($config, $params->{template},
        'upload-audio-recordings');

    entry::set_numbers(
        $checked, $params,
        [   'project_id',        'studio_id',
            'default_studio_id', 'series_id',
            'event_id',          'id'
        ]
    );

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    print STDERR Dumper($params);
    $checked->{action}
        = entry::element_of($params->{action}, ['upload', 'delete', 'show'])
        or ActionError->throw(error => "invalid or missing action");

    entry::set_strings($checked, $params, ['name', 'description', 'path']);

    $checked->{upload} = $params->{upload};
    return $checked;
}

