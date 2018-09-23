package params;

use warnings "all";
use strict;

use Data::Dumper;
use Apache2::Request();

use base 'Exporter';
our @EXPORT_OK = qw(get isJson);

sub debug;
my $isJson = 0;

sub isJson {
    return $isJson;
}

sub get {

    #get the Apache2::RequestRec
    my $r = shift;

    my $tmp_dir      = '/var/tmp/';
    my $upload_limit = 1000 * 1024;

    my $cgi    = undef;
    my $status = undef;
    my $params = {};

    $isJson = 0;

    if ( defined $r ) {

        #print STDERR "Apache2::Request\n";
        #get Apache2::Request
        my $req = Apache2::Request->new( $r, POST_MAX => $upload_limit, TEMP_DIR => $tmp_dir );

        for my $key ( $req->param ) {
            $params->{ scalar($key) } = scalar( $req->param($key) );
        }

        #copy params to hash
        #my $body=$req->body();
        #if (defined $body){
        #	for my $key (keys %$body){
        #		$params->{scalar($key)}=scalar($req->param($key));
        #	}
        #}
        $status = $req->parse;    #parse
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
        $status = '' if ( $status eq 'Success' );
        $status = '' if ( $status eq 'Missing input data' );
        print $cgi->header . $status . "\n" if ( $status ne '' );
    }

    #print STDERR Dumper($params);
    #print $cgi->header.Dumper($params).$status;

    return ( $cgi, $params, $status );
}

sub debug {
    my $message = shift;
}

#do not delete last line!
1;
