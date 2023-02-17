#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Scalar::Util qw( blessed );
use Try::Tiny;

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
$params = check_params( $config, $params );

print "Content-type:text/html\n\n";
print qq{<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<style>
    * {text-align:center; font-family: sans-serif;}
    div,input {padding:6px;margin:6px;}
    .error {background:red; color:white;}
    .info {background:blue; color:white;}
</style>
<body>
<h1>Change your password</h1>
};

sub info{
    print qq{<div class="info">$_[0]</div>\n};
}
sub error{
    print qq{<div class="error">$_[0]</div>\n};
}

if ( defined $params->{user} ) {
    sendToken( $config, $params );
} else {
    checkToken( $config, $params );
}

sub sendToken {
    my $config = shift;
    my $params = shift;
    $config->{access}->{write} = 1;
    my $entry  = password_requests::sendToken( $config, { user => $params->{user} } );
    $config->{access}->{write} = 0;
    if ( defined $entry ) {
        info "Please check you mails.";
    } else {
        error "Sorry.";
    }
}

sub checkToken {
    my $config = shift;
    my $params = shift;

    my $token = $params->{token};

    my $entry = password_requests::get( $config, { token => $token } );
    unless ( defined $entry ) {
        return error "The token is invalid.";
    }

    my $created_at = $entry->{created_at};
    unless ( defined $created_at ) {
        return error "The token age is invalid.";
    }

    my $age = time() - time::datetime_to_time($created_at);
    if ( $age > 600 ) {
        error "The token is too old.";
        $config->{access}->{write} = 1;
        password_requests::delete( $config, { token => $token } );
        $config->{access}->{write} = 0;
        return undef;
    }

    $config->{access}->{write} = 1;
    $entry->{max_attempts}++;
    password_requests::update( $config, $entry );
    $config->{access}->{write} = 0;

    if ( $entry->{max_attempts} > 10 ) {
        error "Too many failed attempts. Please request a new token by mail.";
        $config->{access}->{write} = 1;
        password_requests::delete( $config, { token => $token } );
        $config->{access}->{write} = 0;
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
            error $result->{error};
            printForm($token);
        }

        if ( defined $result->{success} ) {
            info $result->{success};
            $config->{access}->{write} = 1;
            password_requests::delete( $config, { user => $user } );
            $config->{access}->{write} = 0;
            my $url = $config->{locations}->{editor_base_url};
            print qq{
                <script type="text/javascript">
                setTimeout( () => window.location = "$url", 3000);
                </script>
                You will be forwarded to $url …
            };
        }
    }

}

sub printForm {
    my $token = shift;
    print qq{
        <form method="post">
            <input type="hidden" name="token" value="$token">
            <input type="password" name="user_password" placeholder="Please enter a password">
            <input type="password" name="user_password2" placeholder="Please repeat the password">
            <input type="submit" name="action" value="change">
        </form>
    };

}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    entry::set_strings( $checked, $params, [
        'user', 'token', 'user_password', 'user_password2']);

    $checked->{action} = entry::element_of($params->{action}, ['change']);

    return $checked;
}

