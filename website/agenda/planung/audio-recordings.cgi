#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use CGI::Simple();
use ModPerl::Util ();
use Date::Calc();
use Time::Local();
use File::Temp();
use Scalar::Util qw( blessed );
use Try::Tiny;

use config();
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

#$|=1;
binmode STDOUT, ":utf8";

our $config = config::get('../config/config.cgi');
my $base_dir = $config->{locations}->{base_dir};

my $tempDir     = '/var/tmp';
my $uploadLimit = 700_000_000;

my %params = ();
my $error  = '';
my $cgi    = undef;
my $fh     = undef;

#### simple CGI
$CGI::Simple::POST_MAX        = $uploadLimit;
$CGI::Simple::DISABLE_UPLOADS = 0;

$cgi = CGI::Simple->new;
my $filename = $cgi->param('upload');
$fh     = $cgi->upload($filename);
$error  = $cgi->cgi_error() || '';
%params = $cgi->Vars();

my $params = \%params;
binmode $fh if defined $fh;

my ($user, $expires) = try {
    auth::get_user($config, $params, $cgi)
} catch {
    auth::show_login_form('',$_->message // $_->error) if blessed $_ and $_->isa('AuthError');
};
return unless $user;

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

$request = uac::prepare_request( $request, $user_presets );

$params = $request->{params}->{checked};

my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );

exit unless uac::check( $config, $params, $user_presets ) == 1;
template::process( $config, 'print', template::check( $config, 'audio-recordings-header.html' ), $headerParams )
    unless params::isJson;

my $permissions = $request->{permissions};
$params->{action} = '' unless defined $params->{action};
$params->{error} = $error || '';

if ( $params->{action} eq 'upload' ) {
    uploadRecording( $config, $request );
} elsif ( $params->{action} eq 'delete' ) {
    deleteRecording( $config, $request );
}

showAudioRecordings( $config, $request );

print STDERR "$0 ERROR: " . $params->{error} . "\n" if $params->{error} ne '';
$params->{loc} =
  localization::get( $config, { user => $params->{presets}->{user}, file => 'event,comment' } );
template::process( $config, 'print', $params->{template}, $params );

exit;

sub uploadRecording {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{upload_audio_recordings} == 1 ) {
        uac::permissions_denied('upload_audio_recordings');
        return;
    }

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to upload productions" );
            return;
        }
    }

    if ( defined $fh ) {
        print STDERR "upload\n";
        $config->{access}->{write} = 1;
        events::set_upload_status($config, {event_id=>$params->{event_id}, upload_status=>'uploading' });
        my $fileInfo = uploadFile( $config, $fh, $params->{event_id}, $user, $params->{upload} );
        $params->{error} .= $fileInfo->{error} if defined $fileInfo->{error};
        $params->{path} = $fileInfo->{path};
        $params->{size} = $fileInfo->{size};

        #$params->{duration} = $fileInfo->{duration};
        if ($params->{error} eq ''){
            $params = updateDatabase( $config, $params, $user ) ;
            events::set_upload_status($config, {event_id=>$params->{event_id}, upload_status=>'uploaded' });
        }
        $config->{access}->{write} = 0;
        
    } else {
        print STDERR "could not get file handle\n";
        $params->{error} .= 'Could not get file handle';
    }

    if ( $params->{error} ne '' ) {
        $config->{access}->{write} = 1;
        events::set_upload_status($config, {event_id=>$params->{event_id}, upload_status=>'upload failed' });
        $config->{access}->{write} = 0;
        if ( $params->{error} =~ /limit/ ) {
            $params->{error} .=
                "audio file size is limited to "
              . int( $uploadLimit / 1000000 ) . " MB!"
              . "Please make it smaller and try again!";
        } else {
            $params->{error} .= "Error:'$error'";
        }
    }
}

# return 1 if file has been deleted
sub deleteFile {
    my $file = shift;
    return 0 unless defined $file;

    if ( -e $file ) {
        if ( -w $file ) {
            unlink $file;

            # check if file has been deleted
            if ( -e $file ) {
                uac::print_error("could not delete audio file '$file', $!\n");
                return 0;
            }
        } else {
            uac::print_error("cannot delete audio file '$file', missing permissions\n");
            return 0;
        }
    }
    return 1;
}

sub deleteRecording {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{delete_audio_recordings} == 1 ) {
        uac::permissions_denied('delete_audio_recordings');
        return;
    }

    for my $attr (
        'project_id', 'studio_id',

        #'series_id',
        'event_id', 'path'
      )
    {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to delete production" );
            return;
        }
    }

    $config->{access}->{write} = 0;

    my $audioRecordings = audio_recordings::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            event_id   => $params->{event_id},
            path       => $params->{path}
        }
    );

    unless ( ( defined $audioRecordings ) && ( scalar @$audioRecordings > 0 ) ) {
        uac::print_error("could not find audio file $params->{path} in database");
        return;
    }

    my $targetDir = $config->{locations}->{local_audio_recordings_dir};
    unless ( defined $targetDir ) {
        uac::print_error("'local_audio_recordings_dir' is not configured.");
        return;
    }
    unless ( -d $targetDir ) {
        uac::print_error("audio dir '$targetDir' does not exist");
        return;
    }

    my $file = $targetDir . '/' . $params->{path};
    print STDERR "ERROR: cannot delete audio file '$file', file does not exist\n" unless -e $file;

    my $isDeleted = deleteFile($file);
    return unless $isDeleted;

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

}

sub showAudioRecordings {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show productions" );
            return;
        }
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
        return;
    }

    my $audioRecordings = audio_recordings::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            event_id   => $params->{event_id},
        }
    );
    for my $recording (@$audioRecordings) {
        $recording->{size} =~ s/(\d)(\d\d\d)$/$1\.$2/g;
        $recording->{size} =~ s/(\d)(\d\d\d\.\d\d\d)$/$1\.$2/g;

        $recording->{processed} = $recording->{processed} ? 'yes' : 'no';
        $recording->{mastered}  = $recording->{mastered}  ? 'yes' : 'no';

        $recording->{eventDuration} = getDuration( $recording->{eventDuration} );
        $recording->{audioDuration} = audio::formatDuration(
            $recording->{audioDuration},
            $recording->{eventDuration},
            getDuration( $recording->{audioDuration} )
        );

        $recording->{rmsLeft}  = audio::formatLoudness( $recording->{rmsLeft}, 'L:' );
        $recording->{rmsRight} = audio::formatLoudness( $recording->{rmsRight}, 'R:' );
    }

    my $now      = time();
    my $timeZone = $config->{date}->{time_zone};
    my $start    = time::datetime_to_utc( $event->{start}, $timeZone );
    my $end      = time::datetime_to_utc( $event->{end}, $timeZone );
    if ( $now > $end ) {
        uac::print_error("upload is expired due to the show is over");
        $params->{isOver} = 1;
    }
    my $days = 24 * 60 * 60;
    uac::print_warn("show is more than a week ahead") if ( $now + 7 * $days ) < $start;

    $params->{event}            = $event;
    $params->{audio_recordings} = $audioRecordings;

}

sub getDuration {
    my $duration = shift;
    my $hour     = int( $duration / 3600 );
    $duration -= $hour * 3600;

    my $minutes = int( $duration / 60 );
    $duration -= $minutes * 60;

    my $seconds = int($duration);
    $duration -= $seconds;

    my $milli = int( 100 * $duration );
    return sprintf( "%02d:%02d:%02d.%02d", $hour, $minutes, $seconds, $milli );
}

sub uploadFile {
    my $config   = $_[0];
    my $fh       = $_[1];
    my $eventId  = $_[2];
    my $user     = $_[3] || '';
    my $filename = $_[4] || '';

    # check target directory
    my $targetDir = $config->{locations}->{local_audio_recordings_dir};
    return { error => "could not find local_audio_recordings_dir" } unless defined $targetDir;
    return { error => "local_audio_recordings_dir does not exist" } unless -e $targetDir;

    # save file to disk
    my $userName = $user;
    $userName =~ s/[^a-zA-Z0-9\.\-\_]//g;

    my $time = time::time_to_datetime();
    $time =~ s/\:/\-/g;
    $time =~ s/\s/\_/g;
    $time =~ s/[^a-zA-Z0-9\.\-\_]//g;

    my $extension =~ ( split( /\./, $filename) ) [-1];
    $filename =~ s/\.$extension$//;
    $extension =~ s/[^a-zA-Z0-9\.\-\_]//g;

    $filename = join( '-', ( $time, 'id' . $eventId, $userName, $filename ) );
    $filename =~ s/[^a-zA-Z0-9\.\-\_]//g;
    $filename .= $extension;

    my $tempFile = "$targetDir/$filename";
    print STDERR "tempFile=$tempFile\n";

    my $start = time();
    open my $out, '>', $tempFile
      or return { error => 'could not save upload. ' . $! . " " . $tempFile };
    binmode $out;
    my $buffer='';
    print $out $buffer while read( $fh, $buffer, 4096 );
    close $out;

    my $size = (stat($tempFile))[7];

    return {
        dir  => $targetDir,
        path => $filename,
        size => $size,
    };

}

sub updateDatabase {
    my $config = shift;
    my $params = shift;
    my $user   = shift;

    my $eventDuration = getEventDuration( $config, $params->{event_id} );

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
        {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            event_id   => $entry->{event_id},
            path       => $entry->{path}
        }
    );

    if ( ( defined $entries ) && ( scalar @$entries > 0 ) ) {
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
        $config, {
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            event_id   => $entry->{event_id},
            path       => $entry->{path}
        }
    )->[0] or die;

    for my $cmd (sort values %{$config->{"audio-upload-hooks"}}) {
        my $audio_file = $config->{locations}->{local_audio_recordings_dir}.'/'.$entry->{path};
        open(my $fh, '-|', $cmd, $audio_file) or die "Failed to execute hook: $!";
        while (defined (my $line = (<$fh>))) {
            if ($line =~ m/^calcms_audio_recordings\.([a-zA-Z0-9_-]+)\s*=\s*(\S+)/) {
                my ($key, $value) = ($1, $2);
                $entry->{$key} = $value;
                die "invalid column $key for table calcms_audio_recordings"
                    unless exists audio_recordings::get_columns($config)->{$key};
                audio_recordings::update( $config, $entry );
            } elsif ($line =~ m/^calcms_events\.([a-zA-Z0-9_-]+)\s*=\s*(\S+)/) {
                my ($key, $value) = ($1, $2);
                die "invalid column $key for calcms_events\n"
                    unless exists {map {$_=>1} series_events::get_content_columns($config)}->{$key};
                series_events::save_content($config, {
                    id   => $entry->{event_id},
                    $key => $value
                });
            }
        }
        close $fh or die $!;
    }
}

# return filename, filehandle and optionally error from upload
sub getFilename {
    my $cgi    = shift;
    my $upload = shift;

    if ( defined $upload ) {

        # try apache2 module
        my $filename = $upload->filename();
        return {
            filename => $filename,
            fh       => $upload->fh(),
            error    => ''
        };

    }

    # fallback to CGI module
    my $file = $cgi->param("upload");
    return { error => "is no file" } if ( defined $file ) && ( $file =~ /\|/ );

    my $fileInfo = $cgi->uploadInfo($file);

    if ( defined $fileInfo ) {
        my $filename = $fileInfo->{'Content-Disposition'} || '';
        if ( $filename =~ /filename=\"(.*?)\"/ ) {
            $filename = $1;
            return {
                filename => $filename,
                fh       => $file,
                error    => ''
            };

        }
    }

    #error
    return { error => 'Could not detect file name!' };
}

# get extension and optionally error
sub checkFilename {
    my $filename = shift;

    my @validExtensions = ('mp3','mp4','m4a','wav','ogg','flac');
    if ( $filename =~ /\.([a-zA-Z]{3,5})$/ ) {
        my $extension = lc $1;
        unless ( grep( /$extension/, @validExtensions ) ) {
            return {error => 'Following file formats are supported: '
                  . join( ",", @validExtensions )
                  . '!' };
        }
        return {
            extension => $extension,
            error     => ''
        };
    }
    return {error => 'Not matching file extension found! Supported are: '
          . join( ",", @validExtensions )
          . '!' };
}

# return event duration in seconds
sub getEventDuration {
    my $config  = shift;
    my $eventId = shift;

    if ( $eventId < 1 ) {
        print STDERR "invalid eventId $eventId\n";
        return 0;
    }

    my $request = {
        params => {
            checked => events::check_params(
                $config,
                {
                    event_id => $eventId,
                    template => 'no',
                    limit    => 1,
                }
            )
        },
        config => $config
    };
    $request->{params}->{checked}->{published} = 'all';
    my $events = events::get( $config, $request );
    if ( scalar @$events == 0 ) {
        print STDERR "getEventDuration: no event found with event_id=$eventId\n";
    }
    my $event = $events->[0];
    my $duration =
      time::get_duration_seconds( $event->{start}, $event->{end}, $config->{date}->{time_zone} );
    return $duration;
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};
    $checked->{error} = '';
    $checked->{template} = template::check( $config, $params->{template}, 'upload-audio-recordings' );

    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id', 'default_studio_id', 'series_id', 'event_id', 'id']);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{action} = entry::element_of( $params->{action}, ['upload', 'delete'] );

    entry::set_strings( $checked, $params, [ 'name', 'description', 'path' ]);

    $checked->{upload} = $params->{upload};
    return $checked;
}

