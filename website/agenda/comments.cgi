#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use params();
use config();
use comments();
use db();
use markup();
use time();
use log();
my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

binmode STDOUT, ":encoding(UTF-8)";

if ( $0 =~ /comments.*?\.cgi$/ ) {
    my $config = config::get('config/config.cgi');
    my $debug  = $config->{system}->{debug};

    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => comments::check_params( $config, $params ),
        },
    };

    my $output = '';
    comments::get_cached_or_render( $output, $config, $request, 'filter_locked' );
    print $output;
}

#do not delete last line
1;
