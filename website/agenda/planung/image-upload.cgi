#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;
use Data::Dumper;
use Scalar::Util qw( blessed );
use Try::Tiny;
use Apache2::Request;
use Apache2::Upload;

delete $INC{CGI};
require 'CGI.pm';

use Date::Calc();
use Time::Local();
use Image::Magick();
use Image::Magick::Square;

use config();
use entry();
use auth();
use uac();
use studios();
use template();
use images();
use localization();

#binmode STDOUT, ":utf8"; #<! does not work here!
print "Content-type:text/html; charset=UTF-8;\n\n";

my $r   = shift;
my $cgi = undef;

my $config = config::get('../config/config.cgi');
my $base_dir     = $config->{locations}->{base_dir};
my $tmp_dir      = '/var/tmp';
my $upload_limit = 2048 * 1000;

sub upload_file {
    my $config = shift;
    my $cgi    = shift;
    my $upload = shift;
    my $user   = shift;

    my $result = get_filename( $cgi, $upload );
    return $result if ( $result->{error} ne '' );

    my $file     = $result->{fh};
    my $filename = $result->{filename};

    $result = check_filename($filename);

    #print STDERR $result . "\n";
    return $result if ( $result->{error} ne '' );

    my $extension = $result->{extension} || '';

    #read file from handle
    my $data;
    my $content = '';

    #print STDERR $file . "\n";

    binmode $file;
    while ( read $file, $data, 1024 ) {
        $content .= $data;
    }

    #set filename to MD5 from content
    my $md5_filename = Digest::MD5::md5_base64($content);
    $md5_filename =~ s/[\/\+]/_/gi;

    return process_image( $config, $filename, $extension, $md5_filename, $content );
}

sub update_database {
    my $config    = shift;
    my $params    = shift;
    my $file_info = shift;
    my $user      = shift;

    $params->{upload_path}     = $file_info->{upload_path};
    $params->{upload_filename} = $file_info->{upload_filename};
    $params->{filename}        = $file_info->{filename};
    $params->{thumb_path}      = $file_info->{thumb_path};
    $params->{image_path}      = $file_info->{image_path};
    $params->{icon_path}       = $file_info->{icon_path};
    $params->{local_media_url} = $config->{locations}->{local_media_url};

    my $name = $params->{name} || '';
    $name = 'neu' unless $params =~ /\S/;

    my $image = {
        filename    => $params->{filename},
        name        => $name,
        description => $params->{description},
        modified_by => $user,
        project_id  => $params->{project_id},
        studio_id   => $params->{studio_id},
        licence     => $params->{licence}
    };

    #connect
    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);

    my $entries = images::get(
        $config,
        {
            filename   => $image->{filename},
            project_id => $image->{project_id},
            studio_id  => $image->{studio_id}
        }
    );
    if ( ( defined $entries ) && ( scalar(@$entries) > 0 ) ) {
        print STDERR "update image\n".Dumper($image);
        images::update( $dbh, $image );
        my $entry = $entries->[0];
        $params->{image_id} = $entry->{id};
    } else {
        print STDERR "insert image\n";
        $image->{created_by} = $user;
        $params->{image_id} = images::insert( $dbh, $image );
    }
    $config->{access}->{write} = 0;
    $params->{action_result} = 'done!';

    return $params;
}

#get filename and filehandle from upload
sub get_filename {
    my $cgi    = shift;
    my $upload = shift;

    # try apache2 module
    if ( defined $upload ) {
        my $filename = $upload->filename();
        return {
            filename => $filename,
            fh       => $upload->fh(),
            error    => ''
        };
    }

    # fallback to CGI module
    my $file = $cgi->param("image");
    if ( $file =~ /\|/ ) {
        return { error => "is no file" };
    }

    my $file_info = $cgi->uploadInfo($file);
    if ( defined $file_info ) {
        my $filename = $file_info->{'Content-Disposition'} || '';
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

sub check_filename {
    my $filename = shift;

    my @valid_extensions = ( 'png', 'jpeg', 'jpg', 'gif', 'pdf', 'txt', 'bmp', 'ps', 'eps', 'wmf', 'svg' );
    if ( $filename =~ /\.([a-zA-Z]{3,5})$/ ) {
        my $extension = lc $1;
        unless ( grep( /$extension/, @valid_extensions ) ) {
            return { error => 'Following file formats are supported: ' . join( ",", @valid_extensions ) . '!' };
        }
        return {
            extension => $extension,
            error     => ''
        };
    } else {
        return { error => 'Not matching file extension found! Supported are: ' . join( ",", @valid_extensions ) . '!' };
    }
}

sub process_image {
    my $config       = shift;
    my $filename     = shift;
    my $extension    = shift;
    my $md5_filename = shift;
    my $content      = shift;

    my $upload_path =
      images::getInternalPath( $config, { type => 'upload', filename => $md5_filename . '.' . $extension } );
    my $thumb_path = images::getInternalPath( $config, { type => 'thumbs', filename => $md5_filename . '.jpg' } );
    my $icon_path  = images::getInternalPath( $config, { type => 'icons',  filename => $md5_filename . '.jpg' } );
    my $image_path = images::getInternalPath( $config, { type => 'images', filename => $md5_filename . '.jpg' } );

    #copy file to upload space
    my $result = images::writeFile( $upload_path, $content );
    return $result if defined $result->{error};

    #write image
    my $image = new Image::Magick;
    $image->Read($upload_path);
    my $x = $image->Get('width')  || 0;
    my $y = $image->Get('height') || 0;
    if ( ( $x == 0 ) || ( $y == 0 ) ) {
        return { error => 'Could not read image!' };
        log::error( $config, 'Cannot read image $filename!' );
    }

    #set max size image
    if ( $x > 0 && $y > 0 ) {
        if ( $x > $y ) {
            $image->Resize( width => '600', height => int( 600 * $y / $x ) );
        } else {
            $image->Resize( width => int( 600 * $x / $y ), height => '600' );
        }
    }

    #$image->Normalize();
    $image->Write( 'jpg:' . $image_path );

    #write thumb
    my $thumb = $image;
    $thumb->Trim2Square;
    $thumb->Resize( width => 150, height => 150 );
    $thumb->Write( 'jpg:' . $thumb_path );

    my $icon = $image;
    $icon->Trim2Square;
    $icon->Resize( width => 25, height => 25 );
    $icon->Write( 'jpg:' . $icon_path );

    return { error => 'could not create thumb file!' } unless -e $thumb_path;
    return { error => 'could not create icon file!' }  unless -e $icon_path;
    return { error => 'could not create image file!' } unless -e $image_path;

    return {
        upload_filename => $filename,
        filename        => $md5_filename . '.jpg',
        thumb_path      => $thumb_path,
        icon_path       => $icon_path,
        image_path      => $image_path,
        error           => ''
    };
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};
    $checked->{template} = template::check( $config, $params->{template}, 'image-upload' );

    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id', 'default_studio_id'
    ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    entry::set_strings( $checked, $params, [ 'action', 'name', 'description', 'licence' ]);

    entry::set_bools( $checked, $params, [ 'public' ] );
    return $checked;
}


my $params = {};
my $upload = undef;
my $error  = '';

#get image from multiform before anything else
if ( defined $r ) {

    #$cgi               = new CGI();

    #Apache2::Request
    my $apr = Apache2::Request->new( $r, POST_MAX => $upload_limit, TEMP_DIR => $tmp_dir );

    $params = {
        studio_id  => $apr->param('studio_id'),
        project_id => $apr->param('project_id'),
    };

    #copy params to hash
    my $body = $apr->body();
    if ( defined $body ) {
        for my $key ( keys %$body ) {
            $params->{ scalar($key) } = scalar( $apr->param($key) );
        }
    }

    my $status = $apr->parse;
    $status = '' if ( $status =~ /missing input data/i );
    if ( $status =~ /limit/i ) {
        $error = $status;
    } else {
        $upload = $apr->upload('image') if defined $params->{image};
    }
    print STDERR "apr\n";
} else {

    #CGI fallback
    $CGI::POST_MAX     = $upload_limit;
    $CGI::TMPDIRECTORY = $tmp_dir;
    $cgi               = new CGI();
    $error             = $cgi->cgi_error() || $error;
    my %params = $cgi->Vars();
    $params = \%params;
    print STDERR "fallback\n";
}

my ($user, $expires) = try {
    auth::get_user($config, $params, $cgi)
} catch {
    print auth::show_login_form($config, '',$_->message // $_->error) if blessed $_ and $_->isa('AuthError');
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
uac::check($config, $params, $user_presets);

my $permissions = $request->{permissions};

$params->{action} = '' unless defined $params->{action};

if ( $permissions->{create_image} ne '1' ) {
    PermissionError->throw(error=>"Missing permission to create image");
}

my $file_info = undef;
if ( $error ne '' ) {
    if ( $error =~ /limit/ ) {
        $params->{error} .=
            "Image size is limited to "
          . int( $upload_limit / 1000000 ) . " MB!"
          . "Please make it smaller and try again!";
    } else {
        $params->{error} .= "Error:'$error'";
    }
} elsif ( $params->{action} eq 'upload' ) {
    $file_info = upload_file( $config, $cgi, $upload, $user );
    $params->{error} .= $file_info->{error};
    $params = update_database( $config, $params, $file_info, $user ) if $params->{error} eq '';
}

print STDERR "upload error: $params->{error}\n" if $params->{error};
$params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'image' } );
return template::process( $config, $params->{template}, $params );

return $cgi->cgi_error() if ( defined $cgi ) && ( defined $cgi->cgi_error() );
return if $params->{action} eq '';

$params->{action_result} ||= '';
$params->{filename}      ||= '';
$params->{image_id}      ||= '';
$params->{name}          ||= '';

