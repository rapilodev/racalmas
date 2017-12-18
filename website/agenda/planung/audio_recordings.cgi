#!/usr/bin/perl

local $| = 0;

use warnings;
use strict;

use Data::Dumper;

#use CGI;
use CGI::Simple ();

use ModPerl::Util ();
#use Apache2::Request;
#use Apache2::Upload;
#use Apache2::Reload;
#use Apache2::RequestRec ();
#use Apache2::RequestIO ();
#use Apache2::RequestUtil ();
#use Apache2::ServerRec ();
#use Apache2::ServerUtil ();
#use Apache2::Connection ();
#use Apache2::Log ();
#use APR::Table ();
#use ModPerl::Registry ();

use Date::Calc;
use Time::Local;
use File::Temp;
#use File::Copy;
#use Digest::MD5::File;

use config;
use log;
use localization;
use auth;
use uac;
use studios;
use series;
use template;
use audio_recordings;

#$|=1;
binmode STDOUT, ":utf8";
#print "HTTP/1.1 200 OK\n";

my $useCgi=0;

our $config     = config::get('../config/config.cgi');
our $debug      = $config->{system}->{debug};
my $base_dir    = $config->{locations}->{base_dir};

my $tempDir     = '/var/tmp';
my $uploadLimit = 200_000_000;

my %params  = ();
my $error   = '';
my $cgi     = undef;      
my $fh      = undef;

#### MOD_PERL2
# my $req = Apache2::Request->new(
#    Apache2::RequestUtil->request,
#    POST_MAX        => $uploadLimit,
#    DISABLE_UPLOADS => 0
# );
# my $upload      = $req->upload('upload');
# my $filename    = $upload->filename;
# my $fh          = $upload->fh;
# my $file_size   = $upload->size;

#### CGI
# $CGI::POST_MAX     = $uploadLimit;
# $CGI::TMPDIRECTORY = $tempDir;              
# $cgi            = new CGI();
# my $handle      = $cgi->upload('upload');
# $fh = $handle->handle if (defined $handle);
# $error          = $cgi->cgi_error() || '';
# %params         = $cgi->Vars();

#### simple CGI
$CGI::Simple::POST_MAX        = $uploadLimit;
$CGI::Simple::DISABLE_UPLOADS = 0;

$cgi         = $cgi = CGI::Simple->new;              
my $filename = $cgi->param('upload');
$fh          = $cgi->upload($filename); 
$error       = $cgi->cgi_error() || '';
%params      = $cgi->Vars();

my $params=\%params;
binmode $fh if defined $fh;

#print "Content-type:text/html; charset=UTF-8;\n\n";
my ($user, $expires)  = auth::get_user($cgi, $config);
exit if (!defined $user) || ($user eq '');

my $user_presets = uac::get_user_presets( $config, {
    user       => $user, 
    project_id => $params->{project_id}, 
    studio_id  => $params->{studio_id}
});


$params->{default_studio_id} = $user_presets->{studio_id};
$params->{studio_id} = $params->{default_studio_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));
$params->{project_id} = $user_presets->{project_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));

my $request={
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params($params), 
    },
};

#delete $params->{presets};
#print Dumper($request->{params}->{checked});

$request = uac::prepare_request($request, $user_presets);
log::init($request);

$params  = $request->{params}->{checked};

my $headerParams=uac::set_template_permissions($request->{permissions}, $params);
$headerParams->{loc} = localization::get($config, {user=>$user, file=>'menu'});
template::process('print', template::check('default.html'), $headerParams);

exit unless defined uac::check($config, $params, $user_presets);

print q{
    <script src="js/audio_recordings.js" type="text/javascript"></script>
    <link rel="stylesheet" href="css/audio_recordings.css" type="text/css" /> 
}unless(params::isJson);

my $permissions   = $request->{permissions};
$params->{action} = '' unless defined $params->{action};
$params->{error}  = $error || '';

#print STDERR Dumper($params);

if ($params->{action} eq 'upload'){
    uploadRecording($config, $request);
}elsif($params->{action} eq 'delete'){
    deleteRecording($config, $request);
}

showAudioRecordings($config, $request);

print STDERR "$0 ERROR: ".$params->{error}."\n" if $params->{error} ne '';
$params->{loc} = localization::get($config, {user=>$params->{presets}->{user}, file=>'event,comment'});
template::process('print', $params->{template}, $params);
#print Dumper($params->{project_id});
#delete $params->{presets};
#print STDERR Dumper($params);

exit;

sub uploadRecording{
    my $config = shift;
    my $request = shift;
    
    my $params=$request->{params}->{checked};
    my $permissions=$request->{permissions};

    unless ($permissions->{upload_audio_recordings}==1){
        uac::permissions_denied('upload_audio_recordings');
        return;
    }

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id'){
        unless (defined $params->{$attr}){
            uac::print_error("missing ".$attr." to upload productions");
            return;
        }
    }

    if (defined $fh){
        print STDERR "upload\n";
        #print STDERR Dumper($fh)."<br>";
        my $fileInfo         = uploadFile($config, $fh, $params->{event_id}, $user, $params->{upload});
        $params->{error}    .= $fileInfo->{error} if defined $fileInfo->{error};
        $params->{path}      = $fileInfo->{path};
        $params->{size}      = $fileInfo->{size};
        $params->{duration}  = $fileInfo->{duration};
        $params              = updateDatabase($config, $params, $user) if $params->{error} eq '';
    }else{
        $params->{error}.='Could not get file handle';
    }
    
    if ($params->{error} ne ''){
        if ($params->{error}=~/limit/){
            $params->{error} .= "audio file size is limited to ".int( $uploadLimit/1000000 )." MB!"
                    . "Please make it smaller and try again!";
        }else{
            $params->{error} .= "Error:'$error'";
        }
    }
}

# return 1 if file has been deleted
sub deleteFile{
    my $file=shift;
    return 0 unless defined $file;
    
    if (-e $file){
        if ( -w $file ){
            unlink $file;
            # check if file has been deleted
            if ( -e $file ){
                uac::print_error("could not delete audio file '$file', $!\n");
                return 0;
            }
        }else{
            uac::print_error("cannot delete audio file '$file', missing permissions\n");
            return 0;
        }
    }
    return 1;
}

sub deleteRecording{
    my $config = shift;
    my $request = shift;
    
    my $params = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ($permissions->{delete_audio_recordings}==1){
        uac::permissions_denied('delete_audio_recordings');
        return;
    }
        
    for my $attr ('project_id', 'studio_id', 
    #'series_id', 
    'event_id', 'path'){
        unless (defined $params->{$attr}){
            uac::print_error("missing ".$attr." to delete production");
            return;
        }
    }

	my $dbh = db::connect($config);
	$config->{access}->{write} = 0;
		
    my $audioRecordings = audio_recordings::get($config, {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        event_id   => $params->{event_id},
        path       => $params->{path}
    });
 
    unless ( (defined $audioRecordings) && (scalar @$audioRecordings >0)){
        uac::print_error("could not find audio file $params->{path} in database");
        return;
    }

    my $targetDir = $config->{locations}->{local_audio_recordings_dir};
    unless ( defined $targetDir ){
        uac::print_error("'local_audio_recordings_dir' is not configured.");
        return;
    }
    unless ( -d $targetDir ){
        uac::print_error("audio dir '$targetDir' does not exist");
        return;
    }
    
    my $file = $targetDir.'/'.$params->{path};
    print STDERR "ERROR: cannot delete audio file '$file', file does not exist\n" unless -e $file;

    my $isDeleted = deleteFile($file);
    return unless $isDeleted;

	$config->{access}->{write}=1;
    $audioRecordings = audio_recordings::delete($config, $dbh, {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        event_id   => $params->{event_id},
        path       => $params->{path},
    });
    $config->{access}->{write}=0;
    
}

sub showAudioRecordings{
    my $config = shift;
    my $request = shift;
    
    my $params=$request->{params}->{checked};
    my $permissions=$request->{permissions};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id'){
        unless (defined $params->{$attr}){
            uac::print_error("missing ".$attr." to show productions");
            return;
        }
    }

    my $event=series::get_event($config, {
        project_id => $params->{project_id}, 
        studio_id  => $params->{studio_id},
        series_id  => $params->{series_id},
        event_id   => $params->{event_id}
    });
    unless (defined $event){
        uac::print_error("event not found");
    }
    #print '<pre>'.Dumper($event).'</pre>';

    my $audioRecordings = audio_recordings::get($config, {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        event_id   => $params->{event_id},
    });
    for my $recording (@$audioRecordings){
        $recording->{size}=~s/(\d)(\d\d\d)$/$1\.$2/g;
        $recording->{size}=~s/(\d)(\d\d\d\.\d\d\d)$/$1\.$2/g;
    }
    
    my $now = time();
    my $timeZone=$config->{date}->{time_zone};
    my $start = time::datetime_to_utc($event->{start}, $timeZone);
    my $end   = time::datetime_to_utc($event->{end},   $timeZone);
    if ($now > $end){
        uac::print_error("upload is expired due to the show is over");
        $params->{isOver}=1;
    }
    my $days  = 24 * 60 * 60;
    uac::print_warn("show is more than a week ahead") if ( $now + 7 * $days ) < $start;
    
    $params->{event} = $event;
    $params->{audio_recordings} = $audioRecordings;
    
}

sub uploadFile{
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

    $filename =~ s/[^a-zA-Z0-9\.\-\_]//g;
    $filename =~ s/\.(mp3)$//g;
    $filename = join('-', ($time, 'id'.$eventId, $userName, $filename)).'.mp3';

    my $tempFile = $targetDir.'/'.$filename;
    print STDERR "tempFile=$tempFile\n";

    my $start = time();
    open DAT, '>', $tempFile or return { error => 'could not save upload. '.$!." ".$tempFile };
    binmode DAT;
    my $size=0;
    my $data='';
    while( my $bytesRead = $fh->read( $data, 65000) ){
        print DAT $data;
        $size += $bytesRead;
        $data='';
    }
    close DAT;

    # get filename from content
    #my $md5Filename = Digest::MD5::File::file_md5_hex($tempFile);
    #$md5Filename = ~s/[\/\+]+/_/g;
    #print STDERR "md5Filename=$md5Filename\n";

    ## rename file to name from content
    #my $targetFilename = $eventId.'-'.$md5Filename.'-'.$userName.'-'.$time.'.mp3';
    #my $targetFile = $targetDir.'/'.$targetFilename;
    #print STDERR "targetFile=$targetFile\n";
    #File::Copy::move( $tempFile, $targetFile);
    #return { error => 'could not create $targetFile' } unless -e $targetFile;

    return {
        dir      => $targetDir,
        path     => $filename,
        size     => $size,
    };

}

sub updateDatabase{
    my $config   = shift;
    my $params   = shift;
    my $user     = shift;
    
    my $entry={
        project_id  => $params->{project_id},
        studio_id   => $params->{studio_id},
        event_id    => $params->{event_id},
        path        => $params->{path},
        md5         => $params->{md5}||'',
        size        => $params->{size},
        created_by  => $user
    };
    print STDERR "updateDatabase:".Dumper($entry);

    #connect
    $config->{access}->{write}=1;
    my $dbh=db::connect($config);
    
    my $entries = audio_recordings::get( 
        $config, { 
            project_id => $entry->{project_id},
            studio_id  => $entry->{studio_id},
            event_id   => $entry->{event_id},
            path       => $entry->{path} 
        } 
    );

    if ( (defined $entries) && (scalar @$entries > 0) ){
        print STDERR "update\n";
        audio_recordings::update($config, $dbh, $entry);
        my $entry     = $entries->[0];
        $params->{id} = $entry->{id};
    }else{
        print STDERR "insert\n";
        $entry->{created_by} = $user;    
        $params->{id}        = audio_recordings::insert($config, $dbh, $entry);
    }
    $config->{access}->{write} = 0;
    $params->{action_result}   = 'done!';

    return $params;
}

# return filename, filehandle and optionally error from upload
sub getFilename{
    my $cgi    = shift;
    my $upload = shift;

    if (defined $upload){
        # try apache2 module
        my $filename = $upload->filename();
        return {
            filename => $filename,
            fh       => $upload->fh(),
            error    => ''
        };

    }

    #print STDERR "cgi:".Dumper($cgi);
        
    # fallback to CGI module
    my $file = $cgi->param("upload");
    return { error => "is no file" } if (defined $file) && ($file=~/\|/);

    #print STDERR "file:".Dumper($file);
    my $fileInfo = $cgi->uploadInfo($file);
    #print STDERR "fileInfo:".Dumper($fileInfo);

    if (defined $fileInfo){
        my $filename=$fileInfo->{'Content-Disposition'}||'';
        if ($filename=~/filename=\"(.*?)\"/){
            $filename=$1;
            return {
                filename => $filename,
                fh       => $file,
                error    => ''
            };

        }
    }

    #error
    return {
        error => 'Could not detect file name!'
    };
}

# get extension and optionally error
sub checkFilename{
    my $filename = shift;

    my @validExtensions=('mp3');
    if($filename =~ /\.([a-zA-Z]{3,5})$/){
        my $extension = lc $1;
        unless(grep(/$extension/, @validExtensions)) { 
            return {
                error => 'Following file formats are supported: '.join(",", @validExtensions).'!'
            }; 
        }
        return{
            extension => $extension,
            error     => ''
        };
    }
    return {
        error => 'Not matching file extension found! Supported are: '.join(",", @validExtensions).'!'
    };
}


sub check_params{
    my $params=shift;

    my $checked={};
    $checked->{error}='';
    $checked->{template} = template::check($params->{template}, 'upload_audio_recordings');

    #print Dumper($params);
    #numeric values
    for my $param ('project_id', 'studio_id', 'default_studio_id', 'series_id', 'event_id','id'){
        if ((defined $params->{$param})&&($params->{$param}=~/^\d+$/)){
            $checked->{$param} = $params->{$param};
        }
    }
    
    if (defined $checked->{studio_id}){
        $checked->{default_studio_id} = $checked->{studio_id};
    }else{
        $checked->{studio_id} = -1;
    }


    #word
    for my $param ('debug', 'name', 'description'){
        if ((defined $params->{$param}) && ($params->{$param}=~/^\s*(.+?)\s*$/)){
            $checked->{$param} = $1;
        }
    }
    
    # words
    for my $attr('action','path'){
        if ((defined $params->{$attr}) && ($params->{$attr}=~/(\S+)/)){
            $checked->{$attr} = $params->{$attr};
        }
    }
    
    $checked->{upload} = $params->{upload};
    return $checked;
}


