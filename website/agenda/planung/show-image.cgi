#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
no warnings 'prototype';
use utf8;

use Scalar::Util qw(blessed);
use Try::Tiny;

use params();
use config();
use entry();
use auth();
use uac();
use images();

binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    uac::check($config, $params, $user_presets);
    return showImage($config, $request);
}

#TODO: filter by published, draft
sub showImage {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    PermissionError->throw(error=>'Missing permission to read_image') unless $permissions->{read_event};
    PermissionError->throw(error=>'Missing permission to missing filename') unless defined $params->{filename};

    my $path = images::getInternalPath($config, $params);
    PermissionError->throw(error=>"Missing permission to could not find path") unless defined $path;
    PermissionError->throw(error=>"Missing permission to read $path") unless -e $path;
    
    my $image = images::readFile($path);
    PermissionError->throw(error=>"Missing permission to read $path, $image->{error}") if defined $image->{error};

    binmode STDOUT;
    return "Content-type:image/jpeg; charset=UTF-8;\n\n" . $image->{content};
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    for my $param ('filename') {
        if ((defined $params->{$param}) && ($params->{$param} =~ /^[A-Za-z\_\-\.\d\/]+$/)) {
            $checked->{$param} = $params->{$param};
            $checked->{$param} =~ s/^.*\///g;
        }
    }

    $checked->{type} = 'thumbs';
    for my $param ('type') {
        if ((defined $params->{$param}) && ($params->{$param} =~ /^(thumbs|images|icons)$/)) {
            $checked->{$param} = $params->{$param};
        }
    }

    entry::set_numbers($checked, $params, [
        'project_id', 'studio_id', 'series_id', 'event_id'
    ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}
