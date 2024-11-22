#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Data::Dumper;
use Image::Magick();
use Image::Magick::Square;
use Try::Tiny;

use config();
use params();
use entry();
use auth();
use uac();
use template();
use images();
use localization();

local $SIG{__DIE__} = sub  {
#    my $error_message = shift;
    print "200 OK\n";
    #Content-type:text/html\n\n";
#    uac::print_error($error_message);
#    warn "Caught fatal error: $error_message\n";
#    exit 0;
};

binmode STDOUT, ":utf8";

my $r   = shift;
my $config = config::get('../config/config.cgi');
my $upload_limit = try {
    config::parse_size($config->{permissions}->{audio_upload_limit});
} catch {
    exit;
};

my ($cgi, $params, $error, $fh) = params::get($r,
    {upload => { limit => $upload_limit } }
);
die $error if $error;
my ($user, $expires) = auth::get_user($config, $params, $cgi);
exit if (!defined $user) || ($user eq '');

my $user_presets = uac::get_user_presets(
    $config, {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
    }
);

$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio($params, $user_presets);
$params = uac::setDefaultProject($params, $user_presets);

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params($config, $params),
    },
};

$request = uac::prepare_request($request, $user_presets);
$params = $request->{params}->{checked};
my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
$headerParams->{loc} = localization::get($config, { user => $user, file => 'menu' });
template::process($config, 'print', template::check($config, 'header.html'), $headerParams);

exit unless uac::check($config, $params, $user_presets) == 1;

my $permissions = $request->{permissions};
$params->{action} //= '';
if ($permissions->{create_image} ne '1') {
    uac::permissions_denied("create image");
    return 0;
}
if ($params->{action} eq 'upload') {
    try {
        my $file_info = upload_file($config, $params, $fh, $user);
        $params = update_database($config, $params, $file_info, $user);
    } catch {
        $params->{error} = $_;
        print STDERR "upload error: $params->{error}\n";
    };
}

$params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'image' });
template::process($config, 'print', $params->{template}, $params);

sub upload_file {
    my ($config, $params, $fh, $user) = @_;

    my $filename = $params->{upload} // die "missing file\n";
    my $extension = get_extension($filename);
    binmode $fh;
    my $content = '';
    while (read $fh, my $data, 1024) {
        $content .= $data;
    }
    my $md5_filename = Digest::MD5::md5_base64($content);
    $md5_filename =~ s/[\/\+]/_/gi;
    return process_image($config, $filename, $extension, $md5_filename, $content);
}

sub update_database {
    my ($config, $params, $file_info, $user) = @_;

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

    my $entries = images::get(
        $config,
        {
            filename   => $image->{filename},
            project_id => $image->{project_id},
            studio_id  => $image->{studio_id}
        }
    );
    if ((defined $entries) && (scalar(@$entries) > 0)) {
        images::update($config, $image);
        my $entry = $entries->[0];
        $params->{image_id} = $entry->{id};
    } else {
        $image->{created_by} = $user;
        $params->{image_id} = images::insert($config, $image);
    }
    $params->{action_result} = 'done!';
    return $params;
}

sub get_extension {
    my ($filename) = @_;
    die "missing file\n" unless $filename;
    my @valid_extensions = ('png', 'jpeg', 'jpg', 'gif', 'pdf', 'txt', 'bmp', 'ps', 'eps', 'wmf', 'svg');
    if ($filename =~ /\.([a-zA-Z]{3,5})$/) {
        my $extension = lc $1;
        return $extension if grep /$extension/, @valid_extensions;
        die 'Following file formats are supported: ' . join(",", @valid_extensions) . "!\n";
    }
    die 'No matching file extension found! Supported are: ' . join(",", @valid_extensions) . "!\n";
}

sub process_image {
    my ($config, $filename, $extension, $md5_filename, $content) = @_;

    my $upload_path =
      images::getInternalPath($config, { type => 'upload', filename => $md5_filename . '.' . $extension });
    my $thumb_path = images::getInternalPath($config, { type => 'thumbs', filename => $md5_filename . '.jpg' });
    my $icon_path  = images::getInternalPath($config, { type => 'icons',  filename => $md5_filename . '.jpg' });
    my $image_path = images::getInternalPath($config, { type => 'images', filename => $md5_filename . '.jpg' });

    my $result = images::writeFile($upload_path, $content);
    die $result->{error} if defined $result->{error};

    my $image = new Image::Magick;
    $image->Read($upload_path);
    my $x = $image->Get('width')  || 0;
    my $y = $image->Get('height') || 0;
    if (($x == 0) || ($y == 0)) {
        die "Could not read image!\n";
    }

    if ($x > 0 && $y > 0) {
        if ($x > $y) {
            $image->Resize(width => '600', height => int(600 * $y / $x));
        } else {
            $image->Resize(width => int(600 * $x / $y), height => '600');
        }
    }
    $image->Write('jpg:' . $image_path);
    die "Could not create image file!\n" unless -e $image_path;

    my $thumb = $image;
    $thumb->Trim2Square;
    $thumb->Resize(width => 150, height => 150);
    $thumb->Write('jpg:' . $thumb_path);
    die "Could not create thumb file!\n" unless -e $thumb_path;

    my $icon = $image;
    $icon->Trim2Square;
    $icon->Resize(width => 25, height => 25);
    $icon->Write('jpg:' . $icon_path);
    die "Could not create icon file!\n"  unless -e $icon_path;

    return {
        upload_filename => $filename,
        filename        => $md5_filename . '.jpg',
        thumb_path      => $thumb_path,
        icon_path       => $icon_path,
        image_path      => $image_path,
    };
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};
    $checked->{template} = template::check($config, $params->{template}, 'image-upload');
    entry::set_numbers($checked, $params, ['project_id', 'studio_id', 'default_studio_id']);
    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }
    entry::set_strings($checked, $params, [ 'action', 'name', 'description', 'licence', 'upload' ]);
    entry::set_bools($checked, $params, [ 'public' ]);
    return $checked;
}
