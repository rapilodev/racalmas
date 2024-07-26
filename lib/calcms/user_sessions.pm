package user_sessions;

use strict;
use warnings;
no warnings 'redefine';
use Digest::MD5();

use time;
# access user name by session id

# table:   calcms_user_sessions
# columns: id,
# user,
# timeout,
# pid,
# start (timestamp),
# end (timestamp),

#use base 'Exporter';
our @EXPORT_OK = qw(get_columns get insert update delete);

sub get_columns($) {
    my ($config) = @_;

    my $dbh = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_user_sessions' );
}

#map schedule id to id
sub get($$) {
    my ($config, $condition) = @_;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{id} ) && ( $condition->{id} ne '' ) ) {
        push @conditions,  'id=?';
        push @bind_values, $condition->{id};
    }

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }

    if ((defined $condition->{session_id}) && ($condition->{session_id} ne ''))
    {
        push @conditions,  'session_id=?';
        push @bind_values, $condition->{session_id};
    }

    if ( ( defined $condition->{start} ) && ( $condition->{start} ne '' ) ) {
        push @conditions,  'start>?';
        push @bind_values, $condition->{start};
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if @conditions;

    my $query = qq{
        select *
        from   calcms_user_sessions
        $conditions
        order  by start
    };

    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries;
}

# insert entry and return database id
sub insert ($$) {
    my ($config, $entry) = @_;

    for ('user', 'timeout') {
        return undef unless defined $entry->{$_}
    };

    unless ( defined $entry->{session_id} ) {
        my $md5 = Digest::MD5->new();
        $md5->add( $$, time(), rand(time) );
        $entry->{session_id} = $md5->hexdigest();
    }

    $entry->{pid}        = $$;
    $entry->{expires_at} = time::time_to_datetime( time() + $entry->{timeout} );
    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    my $result =  db::insert( $dbh, 'calcms_user_sessions', $entry );
    $config->{access}->{write} = 0;
    return $result;
}

# start session and return generated session id
sub start($$) {
    my ($config, $entry) = @_;

    for ('user', 'timeout') {
        return undef unless defined $entry->{$_}
    };

    my $id = insert(
        $config,
        {
            user    => $entry->{user},
            timeout => $entry->{timeout},
        }
    );
    return undef unless defined $id;

    my $sessions = get( $config, { id => $id } );
    return undef unless defined $sessions;

    my $session = $sessions->[0];
    return undef unless defined $session;

    return $session->{session_id};
}

# expand session by timeout
sub keep_alive ($$) {
    my ($config, $entry) = @_;

    return undef unless defined $entry;

    $entry->{pid}        = $$;
    $entry->{expires_at} = time::time_to_datetime( time() + $entry->{timeout} );

    my $dbh = db::connect($config);
    return update( $config, $entry );
}

# get session by session id and expand session if valid
sub check($$) {
    my ($config, $entry) = @_;

    return undef unless defined $entry;
    my $entries = get( $config, { session_id => $entry->{session_id} } );
    return undef unless defined $entry;

    $entry = $entries->[0];
    return undef unless defined $entry;

    my $now = time::time_to_datetime( time() );
    return undef unless defined $entry->{expires_at};
    return undef unless defined $entry->{user};

    return undef if $entry->{expires_at} le $now;
    return undef if $entry->{end} && ( $entry->{end} le $now );

    keep_alive( $config, $entry );
    return $entry;
}

# stop session
sub stop ($$) {
    my ($config, $entry) = @_;

    return undef unless defined $entry;

    my $entries = get( $config, { session_id => $entry->{session_id} } );
    return undef unless defined $entries;

    $entry = $entries->[0];
    return undef unless defined $entry;

    $entry->{end} = time::time_to_datetime( time() );

    my $dbh = db::connect($config);
    return update( $config, $entry );
}

#schedule id to id
sub update ($$) {
    my ($config, $entry) = @_;

    return undef unless defined $entry->{session_id};

    $config->{access}->{write} = 1;
    my $dbh         = db::connect($config);
    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{session_id};

    my $query = qq{
        update calcms_user_sessions 
        set    $values
        where  session_id=?
    };
    my $result = db::put( $dbh, $query, \@bind_values );
    $config->{access}->{write} = 0;
    return $result;
}

#map schedule id to id
sub delete($$) {
    my ($config, $entry) = @_;

    return undef unless defined $entry->{session_id};

    my $dbh = db::connect($config);
    my $query = qq{
        delete 
        from calcms_user_sessions 
        where session_id=?
    };
    my $bind_values = [ $entry->{session_id} ];
    return db::put( $dbh, $query, $bind_values );
}

sub error($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
