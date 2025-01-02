#! /usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use JSON();
use Scalar::Util qw(blessed);

use config();
use params();
use log();
use entry();
use auth();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    my $loc = localization::get( $config, { user => $session->{user}, file => $params->{usecase} } );
    my $header = "Content-type:application/json; charset=utf-8;\n\n";
    $loc->{usecase} = $params->{usecase};
    my $json = JSON::to_json( $loc, { pretty => 1 } );
    return $header . $json;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = { usecase => '' };

    if (defined $params->{usecase}) {
        if ($params->{usecase} =~ /^([a-z\-\_\,]+)$/) {
            $checked->{usecase} = $1;
        }
    }
    return $checked;
}

