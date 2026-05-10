#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Scalar::Util qw(blessed);
use Try::Tiny;

use params();
use entry();
use uac();

binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    return uac::json($request->{permissions});
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};
    entry::set_numbers($checked, $params, ['project_id', 'studio_id',]);
    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}
