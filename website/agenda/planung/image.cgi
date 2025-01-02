#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;
use Data::Dumper;
use Scalar::Util qw( blessed );
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

    #show header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );

    my $out;
    if ( $params->{search} ) {
        $out .=  template::process( $config, template::check( $config, 'default.html' ), $headerParams );
    } else {
        $out .= template::process( $config, template::check( $config, 'ajax-header.html' ), $headerParams );
    }

    uac::check($config, $params, $user_presets);

    my $local_media_dir = $config->{locations}->{local_media_dir};
    my $local_media_url = $config->{locations}->{local_media_url};

    log::error( $config, 'cannot locate media dir ' . $local_media_dir ) unless -e $local_media_dir;
    PermissionError->throw(error=>'Missing permission to read from local media dir') unless -r $local_media_dir;
    PermissionError->throw(error=>'Missing permission to write to local media dir' . $local_media_dir)   unless -w $local_media_dir;

    if ( $params->{delete_image} ne '' ) {
        delete_image( $config, $request, $session->{user}, $local_media_dir );
        return;
    } elsif ( $params->{save_image} ne '' ) {
        save_image( $config, $request, $session->{user} );
        return;
    }
    show_image( $config, $request, $session->{user}, $local_media_url );
}

sub show_image {
    my $config          = shift;
    my $request         = shift;
    my $user            = shift;
    my $local_media_url = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless (defined $params->{project_id}) {
        ParamError->throw(error => "missing project id");
    }
    unless (defined $params->{studio_id}) {
        ParamError->throw(error => "missing studio id");
        return undef;
}

    if ($permissions->{read_image} ne '1') {
        PermissionError->throw(error => "Missing permission to read image");
        return 0;
    }

    my $dbh = db::connect($config, undef);

    my $projectId        = $params->{project_id};
    my $studioId         = $params->{studio_id};
    my $selectedFilename = $params->{filename} || '';

    my $filenames = {};
    my $results   = [];

    # add images from series
    if (defined $params->{series_id}) {
        my $seriesImages = series::get_images(
            $config,
            {
                project_id => $projectId,
                studio_id  => $studioId,
                series_id  => $params->{series_id}
            }
        );

        for my $image (@$seriesImages) {
            my $filename = $image->{filename};
            next if defined $filenames->{$filename};
            $filenames->{$filename} = $image;
            push @$results, $image;
        }
    }

    #load images matching by search
    if (($params->{search}//'') =~ /\S/) {

        #remove filename from search
        #delete $params->{filename};
        #delete $params->{series_id};
        my $searchImages = images::get(
            $config,
            {
                project_id => $projectId,
                studio_id  => $studioId,
                search     => $params->{search}
            }
        );

        for my $image (@$searchImages) {
            my $filename = $image->{filename};
            next if defined $filenames->{$filename};
            $filenames->{$filename} = $image;
            push @$results, $image;
        }
    }

    #load selected image, if not already loaded
    my $selectedImage = undef;
    if ($selectedFilename ne '') {
        if (defined $filenames->{$selectedFilename}) {
            $selectedImage = $filenames->{$selectedFilename};
        } else {

            #put selected image to the top
            my $imagesByNames = images::get(
                $config,
                {
                    project_id => $projectId,
                    studio_id  => $studioId,
                    filename   => $selectedFilename
                }
            );
            $selectedImage = $imagesByNames->[0] if scalar @$imagesByNames > 0;
        }

        my $finalResults = [];

        # put selected image first
        $selectedFilename = 'not-found';
        if (defined $selectedImage) {
            push @$finalResults, $selectedImage;
            $selectedFilename = $selectedImage->{filename};
        }

        # then other images
        for my $image (@$results) {
            push @$finalResults, $image if $image->{filename} ne $selectedFilename;
        }
        $results = $finalResults;
    }

    if (scalar @$results != 0) {
        if ($params->{template} =~ /edit/) {
            my $result = $results->[0];
            $result->{missing_licence} = 1 if (!defined $result->{licence}) || ($result->{licence} !~ /\S/);
            $results = [$result];
        }

        $results = modify_results($results, $permissions, $user, $local_media_url);
    }

    my $search = $params->{search} || '';
    $search =~ s/\%+/ /g;

    $params->{target} //= '';

    my $template_params = {
        'search'     => $search,
        'images'     => $results,
        'count'      => scalar @$results,
        'projects'   => project::get_with_dates($config),
        'project_id' => $params->{project_id},
        'studio_id'  => $params->{studio_id},
        'series_id'  => $params->{series_id},
        'event_id'   => $params->{event_id},
        'pid'        => $params->{pid},
        'target'     => $params->{target},
        'filename'   => $params->{filename}
    };

    #    print STDERR
    $template_params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'image' });

    my $label_key = 'label_assign_to_'.$params->{target};
    $template_params->{label_assign_to_by_label} = $template_params->{loc}->{$label_key};

    $label_key = 'label_warn_not_public_'.$params->{target};
    $template_params->{label_warn_not_public_by_label} = $template_params->{loc}->{$label_key};

    $template_params = uac::set_template_permissions($permissions, $template_params);
    $template_params->{no_results} = 1 if scalar @$results == 0;

    #set global values for update and delete, per image values are evaluated later
    $template_params->{allow}->{update_image} =
      $template_params->{allow}->{update_image_own} || $template_params->{allow}->{update_image_others};
    $template_params->{allow}->{delete_image} =
      $template_params->{allow}->{delete_image_own} || $template_params->{allow}->{delete_image_others};
    print template::process($config, $params->{template}, $template_params);
}

sub print_js_error {
    my $message = shift;
    print qq{<!--
    ERROR: $message
    -->
    };
    print STDERR $message . "\n";
}

sub save_image {
    my ($config, $request, $user) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless (check_permission($config, $user, $permissions, 'update_image', $params->{save_image}) eq '1') {
        print_js_error("missing permission to update image");
        return 0;
    }

    if (($params->{update_name} eq '') && ($params->{update_description} eq '')) {
        print_js_error("empty name or empty description!");
        return 0;
    }
    my $image = {};
    $image->{filename}    = $params->{save_image};
    $image->{name}        = $params->{update_name} if $params->{update_name} ne '';
    $image->{description} = $params->{update_description} if $params->{update_description} ne '';
    $image->{project_id}  = $params->{project_id};
    $image->{studio_id}   = $params->{studio_id};
    $image->{licence}     = $params->{licence};
    $image->{public}      = $params->{public};
    $image->{modified_by} = $user;

    $image->{name} = 'new' if $image->{name} eq '';

    images::checkLicence($config, $image);

    my $entries = images::get(
        $config,
        {
            filename   => $image->{filename},
            project_id => $image->{project_id},
            studio_id  => $image->{studio_id}
        }
    );

    if (scalar @$entries > 1) {
        print_js_error('more than one matching result found');
        return 0;
    }
    if (scalar @$entries == 0) {
        print_js_error('image not found in database (for this studio)');
        return 0;
    }
    my $entry = $entries->[0];
    if (defined $entry) {
        images::update($config, $image);
        images::publish($config, $image->{filename}) if (($image->{public} == 1) && ($entry->{public} == 0));
        images::depublish($config, $image->{filename}) if (($image->{public} == 0) && ($entry->{public} == 1));
    } else {
        $image->{created_by} = $user;
        images::insert($config, $image);
    }
}

sub delete_image {
    my $config          = shift;
    my $request         = shift;
    my $user            = shift;
    my $local_media_dir = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless (check_permission($config, $user, $permissions, 'delete_image', $params->{delete_image}) eq '1') {
        PermissionError->throw(error=>'Missing permission to delete image');
    }

    my $image = {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        filename   => $params->{delete_image},
    };
    my $result = images::delete($config, $image);

    return;
}

sub check_permission {
    my $config      = shift;
    my $user        = shift;
    my $permissions = shift;
    my $permission  = shift;
    my $filename    = shift;

    return 0 unless defined $user;
    return 0 if ($user eq '');

    if ($permissions->{ $permission . '_others' } eq '1') {
        print STDERR "$user has update_image_others\n";
        return 1;
    } elsif ($permissions->{ $permission . '_own' } eq '1') {
        print STDERR "$user has update_image_own\n";

        #check if image was created by user
        my $results = images::get(
            $config,
            {
                filename   => $filename,
                created_by => $user
            }
        );
        return 1 if (@$results == 1);
        return 0;
    }
    return 0;
}

sub modify_results {
    my $results         = shift;
    my $permissions     = shift;
    my $user            = shift;
    my $local_media_url = shift;

    for my $result (@$results) {
        unless (defined $result->{filename}) {
            $result = undef;
            next;
        }
        $result->{image_url} = $local_media_url . '/images/' . $result->{filename};
        $result->{thumb_url} = $local_media_url . '/thumbs/' . $result->{filename};
        $result->{icon_url}  = $local_media_url . '/icons/' . $result->{filename};

        #reduce
        for my $permission ('update_image', 'delete_image') {
            if ((defined $permissions->{ $permission . '_others' })
                && ($permissions->{ $permission . '_others' } eq '1'))
            {
                $result->{$permission} = 1;
            } elsif ((defined $permissions->{ $permission . '_own' })
                && ($permissions->{ $permission . '_own' } eq '1'))
            {
                next if ($user eq '');
                $result->{$permission} = 1 if ($user eq $result->{created_by});
            }
        }
    }
    return $results;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = { template => template::check( $config, $params->{template}, 'image.html' ) };

    $checked->{limit} = 100;
    entry::set_numbers($checked, $params, [
        'project_id', 'studio_id', 'series_id', 'event_id', 'pid', 'default_studio_id', 'limit'
    ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{limit} = 100 unless defined $checked->{limit};
    $checked->{limit} = 100 if ($checked->{limit} > 100);

    $checked->{delete_image} = '';
    $checked->{save_image}   = '';
    entry::set_strings($checked, $params, [
        'search',
        'update_name', 'update_description', 'licence',
        'save_image', 'delete_image', 'show', 'filename', 'target' ]);

    #checkboxes
    entry::set_bools($checked, $params, [ 'public']);

    #map show to filename, but overwrite if filename given
    if (($checked->{show}//'') ne '') {
        $checked->{filename} = $checked->{show};
        delete $checked->{show};
        $checked->{limit} = 1;
    } elsif (($checked->{filename}//'') ne '') {
        delete $checked->{show};
    }

    $checked->{from} = time::check_date($params->{from});
    $checked->{till} = time::check_date($params->{till});

    return $checked;
}

