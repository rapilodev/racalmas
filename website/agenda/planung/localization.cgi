#! /usr/bin/perl 

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use JSON();
use Scalar::Util qw( blessed );
use Try::Tiny;

use config();
use params();
use log();
use entry();
use auth();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my ($user, $expires) = try {
    auth::get_user($config, $params, $cgi)
} catch {
    auth::show_login_form('',$_->msg) if blessed $_ and $_->isa('AuthError');
};
return unless $user;

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    }
};
$params = $request->{params}->{checked};
my $loc = localization::get( $config, { user => $user, file => $params->{usecase} } );
my $header = "Content-type:application/json; charset=UTF-8;\n\n";
$loc->{usecase} = $params->{usecase};
my $json = JSON::to_json( $loc, { pretty => 1 } );
my @json_lines = ();

for my $line ( split /\n/, $json ) {
    push @json_lines, "'" . $line . "'\n";
}

$json = $header . $json;
print $json;

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = { usecase => '' };

    if ( defined $params->{usecase} ) {
        if ( $params->{usecase} =~ /^([a-z\-\_\,]+)$/ ) {
            $checked->{usecase} = $1;
        }
    }
    return $checked;
}

