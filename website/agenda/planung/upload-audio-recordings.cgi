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
use File::Copy();
use Scalar::Util qw( blessed );
use Try::Tiny;
use Exception::Class (
    'ParamError',
    'PermissionError'
);

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
use events();
use audio();
use time();

#$|=1;
binmode STDOUT, ":utf8";

my $useCgi = 0;

our $config = config::get('../config/config.cgi');
my $base_dir = $config->{locations}->{base_dir};

my $tempDir     = '/var/tmp';
my $uploadLimit = 400_000_000;

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

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );

    exit unless uac::check( $config, $params, $user_presets ) == 1;
    print q{Content-type: text/plain; char-set:utf-8;\n\n};

    uploadRecording( $config, $request );
}

sub uploadRecording {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{upload_audio_recordings} == 1 ) {
        PermissionError->throw(error=>'Missing permission to upload_audio_recordings');
        return;
    }

    for my $attr ( 'project_id', 'studio_id', 'series_id', 'event_id' ) {
        unless ( defined $params->{$attr} ) {
            ParamError->throw(error=> "missing " . $attr . " to upload productions" );
            return;
        }
    }

    if ( defined $fh ) {
        print STDERR "upload\n";

        events::set_upload_status($config, {event_id=>$params->{event_id}, upload_status=>'uploading' });

        my $fileInfo = uploadFile( $config, $fh, $params->{event_id}, $session->{user}, $params->{upload} );
        $params->{error} .= $fileInfo->{error} if defined $fileInfo->{error};
        $params->{path} = $fileInfo->{path};
        $params->{size} = $fileInfo->{size};

        if ($params->{error} eq ''){
            events::set_upload_status($config, {event_id=>$params->{event_id}, upload_status=>'uploaded' });
            $params = updateDatabase( $config, $params, $session->{user} );
        }else{
            events::set_upload_status($config, {event_id=>$params->{event_id}, upload_status=>'upload failed' });
        }
    } else {
        print STDERR "could not get file handle\n";
        $params->{error} .= 'Could not get file handle';
    }

    if ( $params->{error} ne '' ) {
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

    $filename =~ s/\.(mp3)$//g;
    $filename = join( '-', ( $time, 'id' . $eventId, $userName, $filename ) ) . '.mp3';
    $filename =~ s/[^a-zA-Z0-9\.\-\_]//g;

    my $tempFile = $targetDir . '/' . $filename . '.tmp';

    my $start = time();
    open DAT, '>', $tempFile
      or return { error => 'could not save upload. ' . $! . " " . $tempFile };
    binmode DAT;
    my $size = 0;
    my $data = '';
    $time = time();
    while ( my $bytesRead = $fh->read( $data, 65000 ) ) {
        print DAT $data;
        $size += $bytesRead;
        $data = '';
        if ( time() - $start >= 1){
            print "$size\n";
            $start = $time;
        }
    }
    close DAT;
    File::Copy::move($tempFile, $targetDir . '/' . $filename);

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
    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);

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
        audio_recordings::update( $config, $dbh, $entry );
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
        $params->{id}           = audio_recordings::insert( $config, $dbh, $entry );
    }
    $config->{access}->{write} = 0;
    $params->{action_result} = 'done!';

    return $params;
}


# return event duration in seconds
sub getEventDuration {
    my $config  = shift;
    my $eventId = shift;

    InvalidIdError->throw(error=>"invalid eventId $eventId\n") if $eventId<=0;

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
    my ($config, $params) = @_;
    my $checked = {};
    $checked->{error} = '';
    $checked->{template} = template::check( $config, $params->{template}, 'upload-audio-recordings2' );

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

