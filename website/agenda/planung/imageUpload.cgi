#! /usr/bin/perl

use warnings "all";
use strict;
use Data::Dumper;

use Apache2::Request;
use Apache2::Upload;

delete $INC{CGI};
require 'CGI.pm';

use Date::Calc();
use Time::Local();
use Image::Magick();
use Image::Magick::Square();

use config();
use auth();
use uac();
use studios();
use template();
use images();

binmode STDOUT, ":utf8";

my $r   = shift;
my $cgi = undef;

my $config = config::get('../config/config.cgi');
our $debug = $config->{system}->{debug};
my $base_dir     = $config->{locations}->{base_dir};
my $tmp_dir      = '/var/tmp';
my $upload_limit = 2048 * 1000;

#binmode STDOUT, ":utf8";
#binmode STDOUT, ":encoding(UTF-8)";

my $params = {};
my $upload = undef;
my $error  = '';

#get image from multiform before anything else
if ( defined $r ) {

	#Apache2::Request
	#    print "Content-type:text/html; charset=UTF-8; \n\n<br><br><br>Apache2::Request<br>\n";
	my $apr = Apache2::Request->new( $r, POST_MAX => $upload_limit, TEMP_DIR => $tmp_dir );

	#copy params to hash
	my $body = $apr->body();
	if ( defined $body ) {
		for my $key ( keys %$body ) {

			#        print "$key=".$apr->param($key)."<br>\n";
			$params->{ scalar($key) } = scalar( $apr->param($key) );    # unless ($key eq'image');
		}
	}

	#    print Dumper($params);

	#    print Dumper($apr);
	my $status = $apr->parse;

	#    print "Status:$status<br>";
	$status = '' if ( $status =~ /missing input data/i );
	if ( $status =~ /limit/i ) {
		$error = $status;
	} else {
		$upload = $apr->upload('image') if ( defined $params->{image} );
	}

	#dont get params parsed
	#    $CGI::POST_MAX = $upload_limit;
	#    $CGI::TMPDIRECTORY=$tmp_dir;
	$cgi = new CGI();

	#    my %params=$cgi->Vars();
	#    $params=\%params;
	#    $error=$cgi->cgi_error()||$error;
} else {

	#CGI fallback
	#    print "Content-type:text/html; charset=UTF-8; \n\n<br><br><br>CGI<br>\n";
	$CGI::POST_MAX     = $upload_limit;
	$CGI::TMPDIRECTORY = $tmp_dir;
	$cgi               = new CGI();
	$error             = $cgi->cgi_error() || $error;
	my %params = $cgi->Vars();
	$params = \%params;
}
print "Content-type:text/html; charset=UTF-8;\n\n";
my ( $user, $expires ) = auth::get_user( $cgi, $config );
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
$params->{studio_id}         = $params->{default_studio_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );
$params->{project_id} = $user_presets->{project_id}
  if ( ( !( defined $params->{action} ) ) || ( $params->{action} eq '' ) || ( $params->{action} eq 'login' ) );

my $request = {
	url => $ENV{QUERY_STRING} || '',
	params => {
		original => $params,
		checked  => check_params($params),
	},
};

$request = uac::prepare_request( $request, $user_presets );
$params = $request->{params}->{checked};
return unless defined uac::check( $config, $params, $user_presets );

my $permissions = $request->{permissions};

$params->{action} = '' unless ( defined $params->{action} );

if ( $permissions->{create_image} ne '1' ) {
	uac::permissions_denied("create image");
	return 0;
}

my $file_info = undef;
if ( $error ne '' ) {
	if ( $error =~ /limit/ ) {
		$params->{error} .= "Image size is limited to " . int( $upload_limit / 1000000 ) . " MB!" . "Please make it smaller and try again!";
	} else {
		$params->{error} .= "Error:'$error'";
	}
} elsif ( $params->{action} eq 'upload' ) {
	$file_info = upload_file( $config, $cgi, $upload, $user );
	$params->{error} .= $file_info->{error};
	$params = update_database( $config, $params, $file_info, $user ) if ( $params->{error} eq '' );
}
print STDERR $params->{error} . "\n" if defined $params->{error};
my $out = '';
template::process( $config, 'print', $params->{template}, $params );

print $cgi->cgi_error() if defined $cgi;

#return;

return if ( $params->{action} eq '' );

if ( $params->{error} eq '' ) {
	print qq{
    <div id="output">success</div>
    <div id="message">
        $params->{action_result}
        {{thumbs//$params->{filename}}}
        <button onclick="selectThisImage('$params->{filename}')">assign to event</button>
    </div>
    <div id="upload_image_id">$params->{image_id}</div>
    <div id="upload_image_filename">$params->{filename}</div>
    <div id="upload_image_title">$params->{name}</div>
    <div id="upload_image_link">{{thumbs//$params->{filename}}}</div>
    
    };
} else {
	print qq{
    <div id="output">failed</div>
    <div id="message">$params->{error}</div>
    };

}

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
	print STDERR $result . "\n";
	return $result if ( $result->{error} ne '' );

	my $extension = $result->{extension} || '';

	#read file from handle
	my $data;
	my $content = '';
	print STDERR $file . "\n";

	#unless (-e $file){}
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

	my $entries = images::get( $config, { filename => $image->{filename} } );
	if ( ( defined $entries ) && ( scalar(@$entries) > 0 ) ) {
		images::update( $dbh, $image );
		my $entry = $entries->[0];
		$params->{image_id} = $entry->{id};
	} else {
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

	my @valid_extensions = ( 'png', 'jpeg', 'jpg', 'gif', 'pdf', 'txt', 'bmp', 'ps', 'eps', 'wmf' );
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

	my $upload_path = images::getInternalPath( $config, { type => 'upload', filename => $md5_filename . '.' . $extension } );
	my $thumb_path  = images::getInternalPath( $config, { type => 'thumbs', filename => $md5_filename . '.jpg' } );
	my $icon_path   = images::getInternalPath( $config, { type => 'icons',  filename => $md5_filename . '.jpg' } );
	my $image_path  = images::getInternalPath( $config, { type => 'images', filename => $md5_filename . '.jpg' } );

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

	unless ( -e $thumb_path ) {
		return { error => 'could not create thumb file!' };
	}
	unless ( -e $icon_path ) {
		return { error => 'could not create icon file!' };
	}
	unless ( -e $image_path ) {
		return { error => 'could not create image file!' };
	}

	return {
		upload_filename => $filename,

		filename   => $md5_filename . '.jpg',
		thumb_path => $thumb_path,
		icon_path  => $icon_path,
		image_path => $image_path,

		error => ''
	};
}

sub check_params {
	my $params = shift;

	my $checked = {};
	$checked->{template} = template::check($config,  $params->{template}, 'imageUpload' );

	#numeric values
	for my $param ( 'project_id', 'studio_id', 'default_studio_id' ) {
		if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\d+$/ ) ) {
			$checked->{$param} = $params->{$param};
		}
	}
	if ( defined $checked->{studio_id} ) {
		$checked->{default_studio_id} = $checked->{studio_id};
	} else {
		$checked->{studio_id} = -1;
	}

	#string
	for my $param ( 'debug', 'name', 'description', 'licence' ) {
		if ( ( defined $params->{$param} ) && ( $params->{$param} =~ /^\s*(.+?)\s*$/ ) ) {
			$checked->{$param} = $1;
		}
	}

	#Words
	for my $attr ('action') {
		if ( ( defined $params->{$attr} ) && ( $params->{$attr} =~ /(\S+)/ ) ) {
			$checked->{$attr} = $params->{$attr};
		}
	}
	return $checked;
}

