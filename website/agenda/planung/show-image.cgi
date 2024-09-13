#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Data::Dumper;
use Scalar::Util qw( blessed );
use Try::Tiny;

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use images();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    uac::check($config, $params, $user_presets);
    showImage( $config, $request );
}

#TODO: filter by published, draft
sub showImage {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{read_event} == 1 ) {
        PermissionError->throw(error=>'Missing permission to read_image');
        return;
    }

    unless ( defined $params->{filename} ) {
        PermissionError->throw(error=>'Missing permission to missing filename');
        return;
    }

    my $filename = images::getInternalPath( $config, $params );
    unless ( defined $filename ) {
        PermissionError->throw(error=>"Missing permission to could not find path");
        return;
    }

    unless ( -e $filename ) {
        PermissionError->throw(error=>"Missing permission to read $filename");
        return;
    }

    my $image = images::readFile($filename);
    if ( defined $image->{error} ) {
        PermissionError->throw(error=>"Missing permission to read $filename, $image->{error}");
        return;
    }

    binmode STDOUT;
    print "Content-type:image/jpeg; charset=UTF-8;\n\n";
    print $image->{content};
    return;
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

