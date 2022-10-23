package auth;

use strict;
use warnings;
no warnings 'redefine';

use CGI::Simple();
use CGI::Cookie();

use Data::Dumper;
use Authen::Passphrase::BlowfishCrypt();
use time();
use user_sessions ();

#use base 'Exporter';
our @EXPORT_OK = qw(get_user login logout crypt_password);
my $defaultExpiration = 60;

my $debug             = 0;
sub debug($);

#TODO: remove CGI
sub get_user($$$) {
    my ($config, $params, $cgi) = @_;

    debug("get_user") if $debug;

    # login or logout on action
    if ( defined $params->{authAction} ) {
        if ( $params->{authAction} eq 'login' ) {
            my $user = login( $config, $params->{user}, $params->{password} );
            $cgi->delete( 'user', 'password', 'uri', 'authAction' ) if defined $cgi;
            return $user;
        } elsif ( $params->{authAction} eq 'logout' ) {
            $cgi = new CGI::Simple() unless defined $cgi;
            logout($config, $cgi);
            $cgi->delete( 'user', 'password', 'uri', 'authAction' );
            return undef;
        }
    }

    # read session id from cookie
    my $session_id = read_cookie();

    # login if no cookie found
    return show_login_form( $params->{user}, 'Please login' ) unless defined $session_id;

    # read session
    my $session = read_session($config, $session_id);

    # login if user not found
    return show_login_form( $params->{user}, 'unknown User' ) unless defined $session;

    $params->{user}    = $session->{user};
    $params->{expires} = $session->{expires};
    return $session->{user}, $session->{expires};
}

sub crypt_password($) {
    my $password = shift;

    my $ppr = Authen::Passphrase::BlowfishCrypt->new(
        cost        => 8,
        salt_random => 1,
        passphrase  => $password
    );
    return {
        salt  => $ppr->salt_base64,
        crypt => $ppr->as_crypt
    };
}

sub login($$$) {
    my $config   = shift;
    my $user     = shift;
    my $password = shift;
    debug("login") if $debug;

    my $result = authenticate( $config, $user, $password );

    return show_login_form( $user, 'Could not authenticate you' ) unless defined $result;
    return unless defined $result->{login} eq '1';

    my $timeout = $result->{timeout} || $defaultExpiration;
    my $session_id = create_session( $config, $user, $timeout * 60 );

    # here timeout is in minutes
    $timeout = '+' . $timeout . 'm';
    return $user if create_cookie( $session_id, $timeout );
    return undef;
}

#TODO: remove cgi
sub logout($$) {
    my $config = shift;
    my $cgi = shift;

    my $session_id = read_cookie();
    debug("logout") if $debug;
    unless ( delete_session($config, $session_id) ) {
        return show_login_form( 'Cant delete session', 'logged out' );
    }
    unless ( delete_cookie($cgi) ) {
        return show_login_form( 'Cant remove cookie', 'logged out' );
    }
    my $uri = $ENV{HTTP_REFERER} || '';
    $uri =~ s/authAction=logout//g;
    print $cgi->redirect($uri);
    return;
}

#read and write data from browser, http://perldoc.perl.org/CGI/Cookie.html
sub create_cookie($$) {
    my $session_id = shift;
    my $timeout    = shift;

    my $cookie = CGI::Cookie->new(
        -name    => 'sessionID',
        -value   => $session_id,
        -expires => $timeout,
        -secure  => 1,
        -samesite=>  "Lax"
    );
    print "Set-Cookie: " . $cookie->as_string . "\n";

    return 1;
}

sub read_cookie() {
    debug("read_cookie") if $debug;
    my %cookie = CGI::Cookie->fetch;
    debug( "cookies: " . Dumper( \%cookie ) ) if $debug;
    my $cookie = $cookie{'sessionID'};
    debug( "cookie: " . $cookie ) if $debug;
    return undef unless defined $cookie;
    my $session_id = $cookie->value || undef;
    debug( "sid: " . $session_id ) if $debug;
    return $session_id;
}

#TODO: remove CGI
sub delete_cookie($) {
    my $cgi = shift;

    debug("delete_cookie") if $debug;
    my $cookie = $cgi->cookie(
        -name    => 'sessionID',
        -value   => '',
        -expires => '+1s'
    );
    print $cgi->header( -cookie => $cookie );
    return 1;
}

# read and write server-side session data
# timeout is in seconds
sub create_session ($$$) {
    my $config     = shift;
    my $user       = shift;
    my $timeout    = shift;

    debug("create_session") if $debug;
    
    my $session_id = user_sessions::start( 
        $config, {
            user       => $user,
            timeout    => $timeout,
        }
    );
    return $session_id;
}

sub read_session($$) {
    my $config     = shift;
    my $session_id = shift;

    return undef unless defined $session_id;

    my $session = user_sessions::check( $config, { session_id => $session_id } );
    return undef unless defined $session;

    return {
        user    => $session->{user},
        expires => $session->{expires_at}
    };
}

sub delete_session($$) {
    my $config = shift;
    my $session_id = shift;

    debug("delete_session") if $debug;
    return undef unless defined $session_id;
    
    user_sessions::stop( $config, { session_id => $session_id } );
    return 1;
}

#check user authentication
sub authenticate($$$) {
    my $config   = shift;
    my $user     = shift;
    my $password = shift;

    $config->{access}->{write} = 0;
    my $dbh   = db::connect($config);
    my $query = qq{
		select	*
		from 	calcms_users
		where 	name=?
	};
    my $bind_values = [$user];

    my $users = db::get( $dbh, $query, $bind_values );

    if ( scalar(@$users) != 1 ) {
        print STDERR "auth: did not find user '$user'\n";
        return undef;
    }

    my $salt = $users->[0]->{salt};
    my $ppr = Authen::Passphrase::BlowfishCrypt->from_crypt( $users->[0]->{pass}, $users->[0]->{salt} );

    return undef unless $ppr->match($password);
    if ( $users->[0]->{disabled} == 1 ) {
        print STDERR "user '$user' is disabled\n";
        return undef;
    }

    # timeout in seconds
    my $timeout = $users->[0]->{session_timeout} || 120;
    $timeout = 60 if $timeout < 60;

    return {
        timeout => $timeout,
        login   => 1
    };
}

sub show_login_form ($$) {
    my $user    = shift              || '';
    my $uri     = $ENV{HTTP_REFERER} || '';
    my $message = shift              || '';
    my $requestReset = '';

    if ( ( $user ne '' ) && ( $message ne '' ) ) {
        $requestReset = qq{
            <a href="request-password.cgi?user=$user">Passwort vergessen?</a>
        };
    }

    debug("show_login_form") if $debug;
    print qq{Content-type:text/html

<!DOCTYPE HTML>        
<html>
<head>
<meta charset="UTF-8"> 
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style type="text/css">
    *{
        font-family:Roboto,sans-serif;
        margin:0;
        padding:0;
        border:0;
    }

    html,body{
        height: 100%;
    }

    body{
        display: table; 
        margin: 0 auto;
    }

    input, .row, .field{
        padding:0.5rem;
    }

    input:hover{
        cursor:pointer;
    }

    .container{
        height: 100%;
        display: table-cell;   
        vertical-align: middle;    
    }

    input{
        border:0;
        border-bottom: 1px solid #39a1f4;
        margin-right:1rem;
    }

	#login_form{
		background:#fff;
        box-shadow: 1rem 1rem 1rem #eee;
		margin:1rem;
		padding:1rem;
        text-align:center;
        animation-name:form;
        animation-duration: 1s;
        animation-timing-function:ease;

	}

	#login_form .field{
		width:8rem;
		float:left;
	}

	#login_form .message{
        color:white;
		background:#004f9b;
		text-align:left;
		font-weight:bold;
        padding:1rem;
        margin:-1rem;
        margin-bottom:0;
	}
    input.button{
        padding:1rem;        
        color:#fff;
        background:#39a1f4;
        border:0;
        font-weight:bold;
    }
    a{
        text-decoration:none;
        color:#ccf;
    }
    .container{
        animation-name: login;
        animation-duration: 1s;
        animation-timing-function:ease;
    }
    \@keyframes login{
        00%   {transform-origin: 0px; transform: scale(0.9); scaleX(1); opacity:0.7; }
        100% {transform-origin: 0px;  transform: scale(1);   scaleX(1); opacity:1;   }
    }

    \@keyframes form{
        00%   { box-shadow: 0rem 0rem 1rem #eee; transform: translateX(1rem) translateY(1rem);}
        100% { box-shadow: 1rem 1rem 1rem #eee; transform: translateX(0) translateY(0);}
    }
    
</style>
</head>
<body>

<div class="container">
    <div id="login_form">
	    <div class="message">$message</div><br/>
	    <form method="post">
            <div class="row">
		        <div class="field">user</div>
		        <input name="user" value="$user"><br/>
            </div>
            <div class="row">
		        <div class="field">password</div>
		        <input type="password" name="password"><br/>
            </div>
            <div class="row">
		        <input class="button" type="submit" name="authAction" value="login">
		        <input class="button" type="submit" name="authAction" value="logout">
            </div>
		    <input type="hidden" name="uri" value="$uri">
	    </form>
        $requestReset
    </div>
</container>
</body>
</html>
};
    return undef;
}

sub debug ($) {
    my $message = shift;
    print STDERR "$message\n" if $debug > 0;
    return;
}

#do not delete last line!
1;
