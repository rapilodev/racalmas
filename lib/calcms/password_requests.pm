package password_requests;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Session::Token();

# table:   calcms_password_requests
#use base 'Exporter';
our @EXPORT_OK = qw(get insert delete get_columns);

use mail;
use uac;
use db;
use auth;

sub debug;

sub get_columns ($) {
    my $config = shift;

    my $dbh     = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_password_requests' );
}

sub get ($$) {
    my $config    = shift;
    my $condition = shift;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ( defined $condition->{user} ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }

    if ( defined $condition->{token} ) {
        push @conditions,  'token=?';
        push @bind_values, $condition->{token};
    }

    return undef if ( scalar @conditions ) == 0;

    my $conditions = " where " . join( " and ", @conditions );
    my $query = qq{
		select *
		from   calcms_password_requests
		$conditions
	};

    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries->[0] || undef;
}

sub update($$) {
    my $config = shift;
    my $entry  = shift;

    return unless defined $entry->{user};

    my $dbh         = db::connect($config);
    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys);
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{token};

    my $query = qq{
		update calcms_password_requests 
		set    $values
		where  token=?
	};
    db::put( $dbh, $query, \@bind_values );
}

sub insert ($$) {
    my $config = shift;
    my $entry  = shift;

    return undef unless defined $entry->{user};

    my $dbh = db::connect($config);
    return db::insert( $dbh, 'calcms_password_requests', $entry );
}

sub delete ($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }

    if ( ( defined $condition->{token} ) && ( $condition->{token} ne '' ) ) {
        push @conditions,  'token=?';
        push @bind_values, $condition->{token};
    }

    return if ( scalar @conditions ) == 0;
    my $conditions = " where " . join( " and ", @conditions );

    my $dbh = db::connect($config);

    my $query = qq{
		delete 
		from calcms_password_requests 
        $conditions
	};

    db::put( $dbh, $query, \@bind_values );
}

sub sendToken ($$) {
    my $config = shift;
    my $entry  = shift;

    return undef unless defined $entry->{user};

    my $user = uac::get_user( $config, $entry->{user} );
    return undef unless defined $user;

    # check age of existing entry
    my $oldEntry = password_requests::get( $config, { user => $entry->{user} } );
    if ( defined $oldEntry ) {
        my $createdAt = $oldEntry->{created_at};
        my $age = time() - time::datetime_to_time($createdAt);
        if ( $age < 60 ) {
            print STDERR "too many requests";
            return undef;
        }
        print STDERR "age=$age\n";
    }
    password_requests::delete( $config, $entry );

    $entry->{max_attempts} = 0;
    $entry->{token}        = Session::Token->new->get;

    my $baseUrl = $config->{locations}->{source_base_url} . $config->{locations}->{editor_base_url};
    my $url     = $baseUrl . "/request-password.cgi?token=" . $entry->{token};
    my $content = "Hi,$user->{full_name}\n\n";
    $content .= "Someone just tried to reset your password for $baseUrl.\n\n";
    $content .= "If you like to set a new password, please follow the link below\n";
    $content .= $url . "\n\n";
    $content .= "If you do not like to set a new password, please ignore this mail.\n";

    mail::send(
        {
            "To"      => $user->{email},
            "Subject" => "request to change password for $baseUrl",
            "Data"    => $content
        }
    );

    password_requests::insert( $config, $entry );
}

sub changePassword ($$$) {
    my $config   = shift;
    my $request  = shift;
    my $userName = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( ( defined $userName ) || ( $userName eq '' ) ) {
        return { error => 'user not found' };
    }

    my $user = uac::get_user( $config, $userName );

    unless ( ( defined $user ) && ( defined $user->{id} ) && ( $user->{id} ne '' ) ) {
        return { error => 'user id not found' };
    }

    unless ( password_requests::checkPassword( $params->{user_password} ) ) {
        return { error => 'password does not meet requirements' };
    }

    if ( $params->{user_password} ne $params->{user_password2} ) {
        return { error => 'entered passwords do not match' };
    }

    my $crypt = auth::crypt_password( $params->{user_password} );
    $user = { id => $user->{id} };
    $user->{salt} = $crypt->{salt};
    $user->{pass} = $crypt->{crypt};

    $config->{access}->{write} = 1;
    my $result = uac::update_user( $config, $user );
    $config->{access}->{write} = 0;
    return { success => "password changed for $userName" };
}

sub checkPassword($) {
    my $password = shift;
    unless ( defined $password || $password eq '' ) {
        error("password is empty");
        return;
    }
    if ( length($password) < 8 ) {
        error("password to short");
        return 0;
    }
    unless ( $password =~ /[a-z]/ ) {
        error("password should contains at least one small character");
        return 0;
    }
    unless ( $password =~ /[A-Z]/ ) {
        error("password should contains at least one big character");
        return 0;
    }
    unless ( $password =~ /[0-9]/ ) {
        error("password should contains at least one number");
        return 0;
    }
    unless ( $password =~ /[^a-zA-Z0-9]/ ) {
        error("password should contains at least one special character");
        return 0;
    }
    return 1;
}

sub error($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
