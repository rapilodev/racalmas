#! /usr/bin/perl -w 

use warnings "all";
use strict;
use Data::Dumper;

use lib '../calcms';

use CGI;
use config;
use time;
use uac;

my $cgi=new CGI();
my $params=$cgi->Vars();

my $config		=config::get('../../piradio.de/agenda/config/config.cgi');

$params=check_params($params);
our $errors=[];
change_password($config, $params);


sub change_password{
	my $config=shift;
	my $params=shift;

    my $userName=$params->{user_name}||'';
	if ($userName eq ''){
		error ("user '$userName' not found");
        exit;
	}

    my $user=uac::get_user($config, $userName);

	unless ( (defined $user) && (defined $user->{id}) && ($user->{id}ne'') ){
        error( "user id not found");
        exit;
	}

    unless (defined $params->{user_password}){
        error("missing password for $userName");
        exit;
    }

    unless(check_password($params->{user_password})){
		error ("password does not meet requirements");
        exit;
    }

    my $crypt=auth::crypt_password($params->{user_password});
    $user={
        id => $user->{id}
    };
    $user->{salt}=$crypt->{salt};
    $user->{pass}=$crypt->{crypt};
    #print '<pre>'.Dumper($user).'</pre>';
    local $config->{access}->{write}=1;
    uac::update_user($config, $user);
    print STDERR "password changed for $userName\n";
    print STDERR Dumper($user);
    
}

sub check_password{
    my $password=shift;
    unless(defined $password || $password eq ''){
        error("password is empty");
        return 0;
    }
    if(length($password)<8){
        error("password to short");
        return 0;
    }
    unless($password=~/[a-z]/){
        error("password should contains at least one small character");
        return 0;
    }
    unless($password=~/[A-Z]/){
        error("password should contains at least one big character");
        return 0;
    }
    unless($password=~/[0-9]/){
        error("password should contains at least one number");
        return 0;
    }
    unless($password=~/[^a-zA-Z0-9]/){
        error("password should contains at least one special character");
        return 0;
    }
    return 1;
}


sub check_params{
	my $params=shift;

	my $checked={};

	for my $param ('user_name', 'user_password', 'user_password2'){
		if (defined $params->{$param}){
			$checked->{$param}=$params->{$param};
		}
	}

	#print Dumper($params);
	#print '<pre>'.Dumper($checked).'</pre>';
	return $checked;
}

sub error{
	print STDERR "ERROR - ".$_[0]."\n";
}


