#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use params();
use config();
use events();

binmode STDOUT, ":encoding(UTF-8)";

my $r = shift;
(my $cgi, my $params, my $error) = params::get($r);
if ($0 =~ /all-events.*?\.cgi$/) {

    my $config = config::getFromScriptLocation();

    $params->{template} = '' unless defined $params->{template};
    $params->{exclude_event_images} = 1;

    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => events::check_params($config, $params),
        },
    };

    events::get_cached_or_render('print', $config, $request);
}

1;
