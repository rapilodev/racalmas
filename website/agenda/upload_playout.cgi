#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use JSON();
use params();
use config();
use log();
use playout();

my $r = shift;

binmode STDOUT, ":encoding(UTF-8)";

if ( $0 =~ /upload_playout.*?\.cgi$/ ) {

    # read POST content
    my $buffer     = '';
    my $content = '';
    while ( $r->read( $buffer, 65536 ) ) {
        $content .= $buffer;
    }
    $content = "{}" unless $content;

    # parse GET content
    ( my $cgi, my $params, my $error ) = params::get($r);

    my $config = config::getFromScriptLocation();
    my $debug  = $config->{system}->{debug};
    print "Content-type:text/plain\n\n";

    my $json = JSON::decode_json($content);
    $json->{project_id} = $params->{project_id} if defined $params->{project_id};
    $json->{studio_id}  = $params->{studio_id}  if defined $params->{studio_id};
    $config->{access}->{write} = 1;
    my $result = playout::sync( $config, $json );
    $config->{access}->{write} = 0;

    print "upload playout result:" . Dumper($result);
}

1;
