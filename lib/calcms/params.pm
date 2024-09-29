package params;
use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use CGI::Simple();
use Apache2::Request();

{
    my $uri;
    sub set_uri($) { ($uri) = @_; }
    sub get_uri()  { return $uri; }
}

{
    my $is_json = 0;
    sub set_json()   { $is_json = 1; }
    sub reset_json() { $is_json = 0; }
    sub is_json()    { return $is_json; }
}

sub get($;$) {
    my ($r, $options) = @_;
    my $MB           = 1000 * 1000;
    my $tmp_dir      = '/var/tmp/';
    my $upload_limit = 5 * $MB;
    my $cgi          = undef;
    my $status       = undef;
    my $fh           = undef;
    my $params       = {};
    reset_json();
    set_uri(undef);

    # fallback to CGI::Simple if uploads can take more than 64 MB
    if (defined $r && ($options->{upload}->{limit} // 0) < 64 * $MB) {
        my $req = Apache2::Request->new($r,
            POST_MAX => $upload_limit,
            TEMP_DIR => $tmp_dir
        );
        params::set_uri($r->unparsed_uri);
        for my $key ($req->param) {
            $params->{scalar($key)} = scalar($req->param($key));
        }
    } else {
        $CGI::Simple::POST_MAX = $options->{upload}->{limit} // $upload_limit;
        $CGI::Simple::DISABLE_UPLOADS = 0;
        $cgi = CGI::Simple->new;
        params::set_uri($cgi->self_url);
        my $filename = $cgi->param('upload');
        $fh     = $cgi->upload($filename);
        $status = $cgi->cgi_error() || '';
        my %params = $cgi->Vars();
        $params = \%params;
    }

    set_json() if ($params->{json} // '') eq '1';
    if (defined $status) {
        $status = '' if $status eq 'Success';
        $status = '' if $status eq 'Missing input data';
        if ($status ne '') {
            $cgi = new CGI::Simple() unless defined $cgi;
            print $cgi->header . $status . "\n";
        }
    }
    return ($cgi, $params, $status, $fh);

}

#do not delete last line!
1;
