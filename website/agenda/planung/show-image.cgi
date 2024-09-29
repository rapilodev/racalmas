#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;
use Data::Dumper;

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
(my $cgi, my $params, my $error) = params::get($r);

my $config = config::get('../config/config.cgi');
my ($user, $expires) = auth::get_user($config, $params, $cgi);
return if ((!defined $user) || ($user eq ''));

my $user_presets = uac::get_user_presets(
    $config,
    {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        user       => $user
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

#process header

return unless uac::check($config, $params, $user_presets) == 1;
showImage($config, $request);

#TODO: filter by published, draft
sub showImage {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ($permissions->{read_event} == 1) {
        uac::permissions_denied('read_image');
        return;
    }

    unless (defined $params->{filename}) {
        uac::permissions_denied('missing filename');
        return;
    }

    my $filename = images::getInternalPath($config, $params);
    unless (defined $filename) {
        uac::permissions_denied("could not find path");
        return;
    }

    unless (-e $filename) {
        uac::permissions_denied("read $filename");
        return;
    }

    my $image = images::readFile($filename);
    if (defined $image->{error}) {
        uac::permissions_denied("read $filename, $image->{error}");
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

