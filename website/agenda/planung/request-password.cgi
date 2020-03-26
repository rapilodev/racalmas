#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use params();
use config();
use entry();
use db();
use auth();
use password_requests();

binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};

$params = check_params( $config, $params );

print "Content-type:text/html\n\n";
print qq{<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
</head>
<body>
};

if ( defined $params->{user} ) {
    sendToken( $config, $params );
    return;
} else {
    my $result = checkToken( $config, $params );
    return;
}

sub sendToken {
    my $config = shift;
    my $params = shift;
    my $entry  = password_requests::sendToken( $config, { user => $params->{user} } );
    if ( defined $entry ) {
        print "Please check you mails\n";
    } else {
        print "Sorry\n";
    }
}

sub checkToken {
    my $config = shift;
    my $params = shift;

    my $token = $params->{token};

    my $entry = password_requests::get( $config, { token => $token } );
    unless ( defined $entry ) {
        print "invalid token\n";
        return undef;
    }

    print STDERR Dumper($entry);
    my $created_at = $entry->{created_at};
    unless ( defined $created_at ) {
        print "invalid token age\n";
        return undef;
    }

    my $age = time() - time::datetime_to_time($created_at);
    if ( $age > 600 ) {
        print "token is too old\n";
        password_requests::delete( $config, { token => $token } );
        return undef;
    }

    $config->{access}->{write} = 1;
    $entry->{max_attempts}++;
    password_requests::update( $config, $entry );
    $config->{access}->{write} = 0;

    if ( $entry->{max_attempts} > 10 ) {
        print "too many failed attempts, please request a new token by mail\n";
        password_requests::delete( $config, { token => $token } );
        return undef;
    }

    unless ( ( defined $params->{user_password} ) && ( defined $params->{user_password2} ) ) {
        printForm($token);
        return undef;
    }

    if ( $params->{action} eq 'change' ) {
        my $user    = $entry->{user};
        my $request = {
            config => $config,
            params => { checked => $params }
        };
        my $result = password_requests::changePassword( $config, $request, $user );

        if ( defined $result->{error} ) {

            #print "sorry\n";
            print $result->{error} . "\n";
            printForm($token);
        }

        if ( defined $result->{success} ) {

            #print "success\n";
            print $result->{success} . "\n";
            password_requests::delete( $config, { user => $user } );
            my $url = $config->{locations}->{editor_base_url};
            print qq{
                <script type="text/javascript">
                window.location = "$url";
                </script>
            };
        }
    }

}

sub printForm {
    my $token = shift;
    print qq{
        <form method="post">
            <input type="hidden" name="token" value="$token">
            <input type="password" name="user_password" placeholder="enter new password">
            <input type="password" name="user_password2" placeholder="repeat password">
            <input type="submit" name="action" value="change">
        </form>
    };

}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked = {};

    entry::set_strings( $checked, $params, [
        'user', 'token', 'user_password', 'user_password2']);

    $checked->{action} = entry::element_of($params->{action}, ['change']);

    return $checked;
}

