#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Try::Tiny;

use File::stat();
use Time::localtime();
use URI::Escape();

use time();
use images();
use params();
use config();
use entry();
use log();
use template();
use db();
use auth();
use uac();
use project();
use time();
use markup();
use studios();
use series();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;

uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    uac::check($config, $params, $user_presets);
    my $local_media_dir = $config->{locations}->{local_media_dir};
    my $local_media_url = $config->{locations}->{local_media_url};

    PermissionError->throw(error=>"cannot locate media dir $local_media_dir") unless -e $local_media_dir;
    PermissionError->throw(error=>'Missing permission to read from local media dir') unless -r $local_media_dir;
    PermissionError->throw(error=>'Missing permission to write to local media dir' . $local_media_dir)   unless -w $local_media_dir;

    my $action = $params->{action} or ParamError->throw("invalid action");
    return show($config, $request, $session->{user}, $local_media_url)   if $action eq 'show';
    return get_image($config, $request, $session->{user}, $local_media_dir) if $action eq 'get';
        return delete_image( $config, $request, $session->{user}, $local_media_dir) if $action eq 'delete';
    return save_image( $config, $request, $session->{user} ) if $action eq 'save';
}

sub show {
    my ($config, $request, $user, $local_media_url) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    ParamError->throw(error => "missing project id") unless defined $params->{project_id};
    ParamError->throw(error => "missing studio id") unless defined $params->{studio_id};
    PermissionError->throw(error => "Missing permission to read image") if $permissions->{read_image} ne '1';

    $params->{loc} = localization::get($config, {user => $params->{presets}->{user}, file => 'image' });
    my $label_key = 'label_assign_to_'.$params->{target};
    $params->{label_assign_to_by_label} = $params->{loc}->{$label_key};
    $label_key = 'label_warn_not_public_'.$params->{target};
    $params->{label_warn_not_public_by_label} = $params->{loc}->{$label_key};

    # set global values for update and delete, per image values are evaluated later
    $params = uac::set_template_permissions($permissions, $params);
    $params->{allow}->{update_image} =
      $params->{allow}->{update_image_own} || $params->{allow}->{update_image_others};
    $params->{allow}->{delete_image} =
      $params->{allow}->{delete_image_own} || $params->{allow}->{delete_image_others};
    return template::process($config, $params->{template}, $params);
}

sub get_image {
    my ($config, $request, $user, $local_media_url) = @_;
    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    if ($permissions->{read_image} ne '1') {
        PermissionError->throw(error => "Missing permission to read image");
        return 0;
    }

    my $images;
    if (defined $params->{series_id}) {
        die "empty series_id" if defined $params->{series_id} && $params->{series_id} !~ /\S/;
        $images = series::get_images( $config, {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id}
        });
        
    } else {
        for my $field (qw(sid pid search filename)) {
            die "empty $field" if defined $params->{$field} && $params->{$field} !~ /\S/;
        }
        my %conds;
        $conds{filename}   = $params->{filename} if $params->{filename};
        $conds{search}     = $params->{search} if $params->{search};
        $conds{project_id} = $params->{pid} if $params->{pid};
        $conds{studio_id}  = $params->{sid} if $params->{sid};
        $images = images::get($config, \%conds);
    }
    my $results = modify_results($images, $permissions, $user, $local_media_url);
    return template::process($config, 'json-p', {images => $results});
}

sub save_image {
    my ($config, $request, $user) = @_;
    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless (check_permission($config, $user, $permissions, 'update_image', $params->{filename}) eq '1') {
        die("missing permission to update image");
        return 0;
    }
    die "empty name" unless ($params->{name} // '');
    die "empty description" unless ($params->{description} // '');

    my $image = {};
    $image->{filename}    = $params->{filename};
    $image->{name}        = $params->{name};
    $image->{description} = $params->{description};
    $image->{project_id}  = $params->{project_id};
    $image->{studio_id}   = $params->{studio_id};
    $image->{licence}     = $params->{licence};
    $image->{public}      = $params->{public};
    $image->{modified_by} = $user;
    $image->{name} = 'new' if $image->{name} eq '';

    images::checkLicence($config, $image);

    my $entries = images::get($config, {
    filename   => $image->{filename},
    project_id => $image->{project_id},
    studio_id  => $image->{studio_id}
    });

    die 'more than one matching result found' if scalar @$entries > 1;
    die 'image not found in database (for this studio)' if @$entries == 0;
    my $entry = $entries->[0];
    if (defined $entry) {
        images::update($config, $image);
        images::publish($config, $image->{filename}) if (($image->{public} == 1) && ($entry->{public} == 0));
        images::depublish($config, $image->{filename}) if (($image->{public} == 0) && ($entry->{public} == 1));
    } else {
        $image->{created_by} = $user;
        images::insert($config, $image);
    }
    return template::process($config, 'json-p', {result => "saved"});

}

sub delete_image {
    my ($config, $request, $user, $local_media_dir) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    PermissionError->throw(error=>'Missing permission to delete image') 
        unless check_permission($config, $user, $permissions, 'delete_image', $params->{filename}) eq '1';
    my $result = images::delete($config, {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        filename   => $params->{filename},
    });
    return template::process($config, 'json-p', {result => "deleted"});
}

sub check_permission {
    my ($config, $user, $permissions, $permission, $filename) = @_;
    return 0 unless defined $user && $user ne '';
    if ($permissions->{$permission . '_others'} eq '1') {
        print STDERR "$user has update_image_others\n";
        return 1;
    } elsif ($permissions->{$permission . '_own'} eq '1') {
        print STDERR "$user has update_image_own\n";
        my $results = images::get($config, {
            filename   => $filename,
            created_by => $user
        });
        return (@$results == 1) ? 1 : 0;
    }
    return 0;
}

sub modify_results {
    my ($results, $permissions, $user, $local_media_url) = @_;
    for my $result (@$results) {
        unless (defined $result->{filename}) {
            $result = undef;
            next;
        }
        $result->{image_url} = $local_media_url . '/images/' . $result->{filename};
        $result->{thumb_url} = $local_media_url . '/thumbs/' . $result->{filename};
        $result->{icon_url}  = $local_media_url . '/icons/' . $result->{filename};

        #reduce
        $result->{missing_licence} = 1 if (!defined $result->{licence}) || ($result->{licence} !~ /\S/);
        for my $permission ('update_image', 'delete_image') {
            if ((defined $permissions->{$permission . '_others'})
                && ($permissions->{$permission . '_others'} eq '1'))
            {
                $result->{permissions}->{$permission} = 1;
            } elsif ((defined $permissions->{$permission . '_own'})
                && ($permissions->{$permission . '_own'} eq '1'))
            {
                next if $user eq '';
                $result->{permissions}->{$permission} = 1 if $user eq $result->{created_by};
            }
        }
    }
    return $results;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {
        template => template::check( $config, $params->{template}, 'image.html' )
    };

    $checked->{action} = entry::element_of($params->{action}, ['show', 'get', 'save', 'delete']);

    entry::set_numbers($checked, $params, [
        'project_id', 'studio_id', 'series_id', 'event_id', 'pid', 'sid', 'default_studio_id', 'limit'
    ]);
    $checked->{limit} = 100 if $checked->{limit} < 0 or $checked->{limit} > 100;

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    entry::set_strings($checked, $params, [
        'search', 'description', 'licence', 'filename', 'target' ]);

    entry::set_bools($checked, $params, [ 'public']);
    return $checked;
}
