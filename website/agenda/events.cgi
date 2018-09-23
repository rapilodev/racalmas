#! /usr/bin/perl -w

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use params();
use config();
use log();
use events();
use time();

binmode STDOUT, ":encoding(UTF-8)";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);
if ( $0 =~ /events.*?\.cgi$/ ) {

    my $config = config::getFromScriptLocation();

    $params->{template} = '' unless defined $params->{template};
    $params->{recordings} = 1 if $params->{template} =~ /events_playout/;

    $params->{exclude_locations}    = 1;
    $params->{exclude_projects}     = 1;
    $params->{exclude_event_images} = 1;

    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => events::check_params( $config, $params ),
        },
    };

    my $output = '';
    events::get_cached_or_render( $output, $config, $request );
    print $output. "\n";
}

1;
