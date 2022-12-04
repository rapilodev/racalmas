package user_stats;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

our @EXPORT_OK = qw(get_columns get update insert get_stats increase);

sub get_columns($) {
    my ($config) = @_;
    my $dbh = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_user_stats' );
}

sub get ($$) {
    my ($config, $condition) = @_;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ( ( defined $condition->{series_id} ) && ( $condition->{series_id} ne '' ) ) {
        push @conditions,  'series_id=?';
        push @bind_values, $condition->{series_id};
    }

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }

    my $limit = '';
    if ( ( defined $condition->{limit} ) && ( $condition->{limit} ne '' ) ) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	*
		from 	calcms_user_stats
		$conditions
		order by modified_at desc
        $limit
	};

    my $results = db::get( $dbh, $query, \@bind_values );
    return $results;
}

sub get_stats($$) {
    my ($config, $condition) = @_;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ( ( defined $condition->{series_id} ) && ( $condition->{series_id} ne '' ) ) {
        push @conditions,  'series_id=?';
        push @bind_values, $condition->{series_id};
    }

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }

    my $limit = '';
    if ( ( defined $condition->{limit} ) && ( $condition->{limit} ne '' ) ) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select	user, project_id, studio_id,
		        max(modified_at)   modified_at,
		        sum(create_events) create_events,
		        sum(update_events) update_events,
		        sum(delete_events) delete_events,
		        sum(create_series) create_series,
		        sum(update_series) update_series,
		        sum(delete_series) delete_series
		from 	calcms_user_stats
		$conditions
		group by user, project_id, studio_id
        $limit
	};

    my $results = db::get( $dbh, $query, \@bind_values );
    for my $result (@$results) {
        $result->{score} = 0;
        for my $column ( 'create_events', 'update_events', 'delete_events', 'create_series', 'update_series',
            'delete_series' )
        {
            $result->{score} += $result->{$column};
        }
    }
    my @results = reverse sort { $a->{score} <=> $b->{score} } @$results;
    return \@results;
}

sub insert($$) {
    my ($config, $stats) = @_;

    for ('user', 'project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $stats->{$_}
    };

    #TODO:filter for existing attributes
    my $columns = get_columns($config);
    my $entry   = {};
    for my $column ( keys %$columns ) {
        $entry->{$column} = $stats->{$column} if defined $stats->{$column};
    }
    $entry->{modified_at} = time::time_to_datetime( time() );

    my $dbh = db::connect($config);
    my $id = db::insert( $dbh, 'calcms_user_stats', $entry );
    return $id;
}

# update project
sub update ($$) {
    my ($config, $stats) = @_;

    for ('user', 'project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $stats->{$_}
    };

    my $columns = get_columns($config);
    my $entry   = {};
    for my $column ( keys %$columns ) {
        $entry->{$column} = $stats->{$column} if defined $stats->{$column};
    }
    $entry->{modified_at} = time::time_to_datetime( time() );

    my @keys = sort keys %$entry;
    my $values = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{user};
    push @bind_values, $entry->{project_id};
    push @bind_values, $entry->{studio_id};
    push @bind_values, $entry->{series_id};

    my $query = qq{
		update calcms_user_stats
		set $values
		where user=? and project_id=? and studio_id=? and series_id=?
	};

    my $dbh = db::connect($config);
    return db::put( $dbh, $query, \@bind_values );
}

sub increase ($$$) {
    my ($config, $usecase, $options) = @_;

    return undef unless defined $usecase;
    for ('user', 'project_id', 'studio_id', 'series_id', ) {
        ParamError->throw(error => "missing $_") unless defined $options->{$_}
    };

    my $columns = get_columns($config);
    return undef unless exists $columns->{$usecase};

    my $entries = get( $config, $options );
    if ( scalar @$entries == 0 ) {
        my $entry = {
            project_id => $options->{project_id},
            studio_id  => $options->{studio_id},
            series_id  => $options->{series_id},
            user       => $options->{user},
            $usecase   => 1,
        };

        return insert( $config, $entry );
    } elsif ( scalar @$entries == 1 ) {
        my $entry = $entries->[0];
        $entry->{$usecase}++ if defined
        return update( $config, $entry );
    } else {
        print STDERR "user_stats: to few options given: $usecase," . Dumper($options) . "\n";
    }

}

sub get_active_users{
    my ($config) = @_;

    my $dbh = db::connect($config);

    my $query=qq{
        select u.name login, u.full_name,
            s.last_login, s.login_count,
            u.disabled, u.created_at, u.created_by
        from calcms_users u left join (
            SELECT user , max(start) last_login, count(user) login_count
            FROM calcms_user_sessions
            group by user
        ) s on s.user=u.name
        order by u.disabled, s.last_login desc, u.created_at desc
    };
    my $results = db::get( $dbh, $query, [] );
    return $results;
}

#do not delete last line!
1;
