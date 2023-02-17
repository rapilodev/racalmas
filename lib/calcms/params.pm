package params;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Apache2::Request();
use Exception::Class (
    'ParamError'
);

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
    } else {
        require "CGI.pm";
        $CGI::POST_MAX     = $upload_limit;
        $CGI::TMPDIRECTORY = $tmp_dir;
        $cgi               = new CGI();
        $status            = $cgi->cgi_error();
        my %params = $cgi->Vars();
        $params = \%params;
    }

    $isJson = 1 if ( defined $params->{json} ) && ( $params->{json} eq '1' );
    if (defined $status) {
        $status = '' if $status eq 'Success';
        $status = '' if $status eq 'Missing input data';
        ParamError->throw(error => $status) if $status;
    }
    return ($cgi, $params);
}

#do not delete last line!
1;