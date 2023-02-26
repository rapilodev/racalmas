#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use params();
use config();
use log();
use calendar();

my $r = shift;

#binmode STDOUT, ":utf8";
binmode STDOUT, ":encoding(UTF-8)";

if ( $0 =~ /cal.*?\.cgi$/ ) {
    ( my $cgi, my $params, my $error ) = params::get($r);

    my $config = config::getFromScriptLocation();
    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => calendar::check_params( $config, $params ),
        },
    };
    $params = $request->{params}->{checked};

    my $out = '';
    calendar::get_cached_or_render( $out, $config, $request );
    print $out. "\n";
}

1;
