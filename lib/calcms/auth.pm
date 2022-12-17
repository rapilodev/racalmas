package auth;

use strict;
use warnings;
no warnings 'redefine';

use CGI::Simple();
use CGI::Cookie();
use Exception::Class (
    'AuthError',
    'SessionError' => { isa => 'AuthError' },
    'LoginError'   => { isa => 'AuthError', fields => [ 'user' ] },
    'LogoutError'  => { isa => 'AuthError', fields => [ 'user' ] },
    'LogoutDone'   => { isa => 'AuthError' }
);
use Authen::Passphrase::BlowfishCrypt();
use user_sessions ();

our @EXPORT_OK = qw(get_user login logout crypt_password);
my $defaultExpiration = 60;

sub get_user($$$) {
    my ($config, $params, $cgi) = @_;

    if (defined $params->{authAction}) {
        if ($params->{authAction} eq 'login') {
            login($config, $params->{user}, $params->{password});
            $cgi->delete('user', 'password', 'uri', 'authAction')
                if defined $cgi;
            return ($params->{user});
        } elsif ($params->{authAction} eq 'logout') {
            $cgi = new CGI::Simple() unless defined $cgi;
            logout($config, $cgi);
            $cgi->delete('user', 'password', 'uri', 'authAction');
            return ();
        }
    }
    my $session_id = read_cookie();
    my $session    = read_session($config, $session_id);
    $params->{$_} = $session->{$_} for qw (user expires);
    return $session->{user}, $session->{expires};
}

sub crypt_password($) {
    my ($password) = @_;

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
    my ($config, $user, $password) = @_;
    print STDERR "l1\n";
    my $timeout    = authenticate($config, $user, $password);
    print STDERR "l2\n";
    my $session_id = create_session($config, $user, $timeout * 60);
    print STDERR "l3\n";
    create_cookie($session_id, '+' . $timeout . 'm');
    print STDERR "l4\n";
}

#TODO: remove cgi
sub logout($$) {
    my ($config, $cgi) = @_;
    my $session_id = read_cookie();
    delete_session($config, $session_id);
    delete_cookie($cgi);
    my $uri = $ENV{HTTP_REFERER} || '';
    $uri =~ s/authAction=logout//g;
    print $cgi->redirect($uri);
}

#read and write data from browser, http://perldoc.perl.org/CGI/Cookie.html
sub create_cookie($$) {
    my ($session_id, $timeout) = @_;
    use Data::Dumper;print STDERR Dumper($timeout);
    my $cookie = CGI::Cookie->new(
        -name     => 'sessionID',
        -value    => $session_id,
        -expires  => $timeout,
        -secure   => 1,
        -samesite => "Lax"
    );
    print STDERR "Set-Cookie: " . $cookie->as_string . "\n";
    #print "HTTP/1.1 200 OK\nSet-Cookie: " . $cookie->as_string . "\n";
    #print "HTTP1/1 200 OK\n".
    #"Set-Cookie: " . $cookie->as_string . "\n";
    my $cgi = CGI::Simple->new();
    print $cgi->header(-cookie => $cookie);
}

sub read_cookie() {
    my %cookie = CGI::Cookie->fetch;
    my $cookie = $cookie{'sessionID'};
    SessionError->throw(message => 'Please login1') unless defined $cookie;
    my $session_id = $cookie->value;
    SessionError->throw(message => 'Please login2') unless defined $session_id;
    return $session_id;
}

sub delete_cookie($) {
    my ($cgi) = @_;
    my $cookie = $cgi->cookie(
        -name    => 'sessionID',
        -value   => '',
        -expires => '+1s'
    );
    print $cgi->header(-cookie => $cookie);
}

# read and write server-side session data
# timeout is in seconds
sub create_session ($$$) {
    my ($config, $user, $timeout) = @_;
    return my $session_id = user_sessions::start(
        $config,
        {
            user    => $user,
            timeout => $timeout,
        }
    );
}

sub read_session($$) {
    my ($config, $session_id) = @_;
    my $session = user_sessions::check($config, { session_id => $session_id });
    return {
        user    => $session->{user},
        expires => $session->{expires_at}
    };
}

sub delete_session($$) {
    my ($config, $session_id) = @_;
    return unless defined $session_id;
    user_sessions::stop($config, { session_id => $session_id });
}

#check user authentication
sub authenticate($$$) {
    my ($config, $user, $password) = @_;

    $config->{access}->{write} = 0;
    my $dbh   = db::connect($config);
    my $query = qq{
		select	*
		from 	calcms_users
		where 	name=?
	};
    my $bind_values = [$user];
    my $users       = db::get($dbh, $query, $bind_values);
    LoginError->throw(user => $user, message => 'Could not authenticate you')
        if scalar(@$users) != 1;

    my $salt = $users->[0]->{salt};
    my $ppr = Authen::Passphrase::BlowfishCrypt->from_crypt($users->[0]->{pass},
        $users->[0]->{salt});
    LoginError->throw(user => $user, message => 'Could not authenticate you')
        unless $ppr->match($password);
    LoginError->throw(user => $user, message => 'Could not authenticate you')
        if $users->[0]->{disabled} == 1;

    my $timeout = $users->[0]->{session_timeout} || $defaultExpiration;
    $timeout = 60 if $timeout < 60;
    return $timeout;
}

sub show_login_form ($$) {
    my ($user, $message) = @_;
    my $uri          = $ENV{HTTP_REFERER} || '';
    my $requestReset = '';
    if ($user and $message) {
        $requestReset = qq{
            <a href="request-password.cgi?user=$user">Passwort vergessen?</a>
        };
    }

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

#do not delete last line!
1;
