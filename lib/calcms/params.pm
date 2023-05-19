package params;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Apache2::Request();

#use base 'Exporter';
our @EXPORT_OK = qw(get isJson);

my $isJson = 0;

sub isJson () {
    return $isJson;
}

sub get ($) {
    my ($r) = @_;

    my $tmp_dir      = '/var/tmp/';
    my $upload_limit = 1000 * 1024;

    my $cgi    = undef;
    my $status = undef;
    my $params = {};

    $isJson = 0;

    if ( defined $r ) {
        my $req = Apache2::Request->new( $r, POST_MAX => $upload_limit, TEMP_DIR => $tmp_dir );

        for my $key ( $req->param ) {
            $params->{ scalar($key) } = scalar( $req->param($key) );
        }

        $status = $req->parse;
    } else {
        print STDERR "$0: require CGI\n";
        require "CGI.pm";
        $CGI::POST_MAX     = $upload_limit;
        $CGI::TMPDIRECTORY = $tmp_dir;
        $cgi               = new CGI();
        $status            = $cgi->cgi_error() || $status;
        my %params = $cgi->Vars();
        $params = \%params;
    }

    $isJson = 1 if ( defined $params->{json} ) && ( $params->{json} eq '1' );

    if ( defined $status ) {
        $status = '' if $status eq 'Success';
        $status = '' if $status eq 'Missing input data';
        if ( $status ne '' ) {
            $cgi = new CGI::Simple() unless defined $cgi;
            print $cgi->header . $status . "\n";
        }
    }

    return ( $cgi, $params, $status );
}

#do not delete last line!
1;
