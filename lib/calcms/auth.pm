package auth;

use strict;
use warnings;
no warnings 'redefine';

use CGI::Simple();
use CGI::Cookie();
use Authen::Passphrase::BlowfishCrypt();
use user_sessions();
use localization();

my $defaultExpiration = 60;

sub get_session($$) {
    my ($config, $params) = @_;
    if (defined $params->{authAction}) {
        if ($params->{authAction} eq 'login') {
            my ($user, $password, $uri) = ($params->{user}, $params->{password}, $params->{uri});
            print login($config, $user, $password) .  new CGI::Simple()->redirect($uri);
            return;#exit;
        } elsif($params->{authAction} eq 'logout') {
            print logout($config);
            LogoutDone->throw;
        }
    }
    my $session_id = read_cookie() or die;
    my $session    = read_session($config, $session_id) or die;
    $params->{$_} = $session->{$_} for qw(user expires);
    $session->{params} = $params;
    return $session;
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
    my $timeout    = authenticate($config, $user, $password);
    my $session_id = create_session($config, $user, $timeout * 60);
    return create_cookie($session_id, '+' . $timeout . 'm');
}

sub logout($) {
    my ($config) = @_;
    my $session_id = read_cookie();
    delete_session($config, $session_id);
    delete_cookie();
    my $uri = params::get_uri() || '';
    $uri =~ s/authAction=logout//;
    return CGI::Simple->new()->redirect($uri);
}

#read and write data from browser, http://perldoc.perl.org/CGI/Cookie.html
sub create_cookie($$) {
    my ($session_id, $timeout) = @_;
    my $cookie = CGI::Cookie->new(
        -name    => 'sessionID',
        -value   => $session_id,
        -expires => $timeout,
        -secure  => 1,
        -samesite => "Lax"
   );
    return CGI::Simple->new()->header(-cookie => $cookie);
}

sub read_cookie() {
    my %cookie = CGI::Cookie->fetch;
    my $cookie = $cookie{'sessionID'};
    AuthError->throw(message => 'please_login') unless defined $cookie;
    my $session_id = $cookie->value;
    AuthError->throw(message => 'please_login') unless defined $session_id;
    return $session_id;
}

sub delete_cookie() {
    my $cookie = CGI::Cookie->new(
        -name    => 'sessionID',
        -value   => '',
        -expires => '+1s'
        -secure   => 1,
        -samesite => "Lax"
   )->bake;
}

# read and write server-side session data
# timeout is in seconds
sub create_session ($$$) {
    my ($config, $user, $timeout) = @_;
    return user_sessions::start(
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

    my $dbh   = db::connect($config);
    my $query = qq{
        select    *
        from     calcms_users
        where     name=?
    };
    my $bind_values = [$user];
    my $users = db::get($dbh, $query, $bind_values);
    LoginError->throw(user => $user, message => 'authentication_failed')
        if scalar(@$users) != 1;

    my $salt = $users->[0]->{salt};
    my $ppr = Authen::Passphrase::BlowfishCrypt->from_crypt($users->[0]->{pass},
        $users->[0]->{salt});
    LoginError->throw(user => $user, message => 'authentication_failed')
        unless $ppr->match($password);
    LoginError->throw(user => $user, message => 'authentication_failed')
        if $users->[0]->{disabled} == 1;

    my $timeout = $users->[0]->{session_timeout} || $defaultExpiration;
    $timeout = 60 if $timeout < 60;
    return $timeout;
}

sub show_login_form ($$$) {
    my ($config, $user, $message) = @_;
    my $loc = localization::get($config, { user => $user, file => 'login.po' });
    my $uri = params::get_uri() // '';
    $uri =~ s/_=\d+//;
    my $requestReset = '';
    if ($user && $message) {
        $requestReset = qq{
            <a href="request-password.cgi?user=$user">$loc->{password_lost}</a>
        };
    }

    return qq{Status: 401
Cache-Control: no-store, no-cache, must-revalidate, max-age=01
Pragma: no-cache
Expires: 0
Content-type:text/html

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
        border-radius:1rem;
    }

    button:hover{
        scale:1.1;
        box-shadow: 1rem 1rem 1rem #eee;
        transition: all 0.1s ease;
    }

    #login_form .field{
        width:8rem;
        float:left;
    }

    #login_form .message{
        border-top-left-radius:1rem;
        border-top-right-radius:1rem;
        color:white;
        background:#004f9b;
        text-align:left;
        font-weight:bold;
        padding:1rem;
        margin:-1rem;
        margin-bottom:0;
        box-shadow: 1rem 1rem 1rem #eee;
    }
    input.button,
    button.button{
        padding:1rem;
        margin-left:2rem;
        margin-right:2rem;
        color:#fff;
        background:#39a1f4;
        border:0;
        font-weight:bold;
        cursor:pointer;
        border-radius:1rem;
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
        00%  {transform-origin: 0px; transform: scale(0.9); scaleX(1); opacity:0.7; }
        100% {transform-origin: 0px; transform: scale(1);   scaleX(1); opacity:1;   }
    }

    \@keyframes form{
        00%  { box-shadow: 0rem 0rem 1rem #eee; transform: translateX(1rem) translateY(1rem);}
        100% { box-shadow: 1rem 1rem 1rem #eee; transform: translateX(0) translateY(0);      }
    }
</style>
</head>
<body>

<div class="container">
    <div id="login_form">
        <div class="message">}.($loc->{$message}//$message).qq{</div><br/>
        <form method="post">
            <div class="row">
                <div class="field">$loc->{user}</div>
                <input name="user" value="$user"><br/>
            </div>
            <div class="row">
                <div class="field">$loc->{password}</div>
                <input type="password" name="password"><br/>
            </div>
            <div class="row">
                <button class="button" type="submit" name="authAction" value="logout" style="opacity:0.5">$loc->{logout}</button>
                <button class="button" type="submit" name="authAction" value="login">$loc->{login}</button>
            </div>
            <input type="hidden" name="uri" value="$uri">
        </form>
        $requestReset
    </div>
</container>
</body>
</html>
};
}

#do not delete last line!
1;
