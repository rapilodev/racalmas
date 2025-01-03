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
my ($params, $error) = params::get($r);

binmode STDOUT, ":encoding(UTF-8)";

if ($0 =~ /comments.*?\.cgi$/) {
    my $config = config::get('config/config.cgi');
    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => comments::check_params($config, $params),
        },
    };

    print comments::get_cached_or_render($config, $request, 'filter_locked');
}

#do not delete last line
1;
