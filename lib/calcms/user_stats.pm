#!/bin/perl

package user_stats;
use warnings "all";
use strict;
use Data::Dumper;

require Exporter;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(get_columns get update insert get_stats increase);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

sub debug;

sub get_columns {
    my $config = shift;

    my $dbh     = db::connect($config);
    my $cols    = db::get_columns( $dbh, 'calcms_user_stats' );
    my $columns = {};
    for my $col (@$cols) {
        $columns->{$col} = 1;
    }
    return $columns;
}

sub get {
    my $config    = shift;
    my $condition = shift;

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

    #print STDERR Dumper($query).Dumper(\@bind_values);

    my $results = db::get( $dbh, $query, \@bind_values );
    return $results;
}

sub get_stats {
    my $config    = shift;
    my $condition = shift;

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

    #print STDERR Dumper($query).Dumper(\@bind_values);

    my $results = db::get( $dbh, $query, \@bind_values );
    for my $result (@$results) {
        $result->{score} = 0;
        for my $column ( 'create_events', 'update_events', 'delete_events', 'create_series', 'update_series', 'delete_series' ) {
            $result->{score} += $result->{$column};
        }
    }
    my @results = reverse sort { $a->{score} <=> $b->{score} } @$results;
    return \@results;
}

sub insert {
    my $config = shift;
    my $stats  = shift;

    return undef unless defined $stats->{project_id};
    return undef unless defined $stats->{studio_id};
    return undef unless defined $stats->{series_id};
    return undef unless defined $stats->{user};

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
sub update {
    my $config = shift;
    my $stats  = shift;

    return undef unless defined $stats->{project_id};
    return undef unless defined $stats->{studio_id};
    return undef unless defined $stats->{series_id};
    return undef unless defined $stats->{user};

    my $columns = get_columns($config);
    my $entry   = {};
    for my $column ( keys %$columns ) {
        $entry->{$column} = $stats->{$column} if defined $stats->{$column};
    }
    $entry->{modified_at} = time::time_to_datetime( time() );

    my $values = join( ",", map { $_ . '=?' } ( keys %$entry ) );
    my @bind_values = map { $entry->{$_} } ( keys %$entry );
    push @bind_values, $entry->{user};
    push @bind_values, $entry->{project_id};
    push @bind_values, $entry->{studio_id};
    push @bind_values, $entry->{series_id};

    my $query = qq{
		update calcms_user_stats 
		set $values
		where user=? and project_id=? and studio_id=? and series_id=?
	};

    #print STDERR Dumper($query).Dumper(\@bind_values);
    my $dbh = db::connect($config);
    return db::put( $dbh, $query, \@bind_values );
}

sub increase {
    my $config  = shift;
    my $usecase = shift;
    my $options = shift;

    #print STDERR Dumper($usecase)." ".Dumper($options);

    return undef unless defined $usecase;
    return undef unless defined $options->{project_id};
    return undef unless defined $options->{studio_id};
    return undef unless defined $options->{series_id};
    return undef unless defined $options->{user};

    #print STDERR "ok\n";

    my $columns = get_columns($config);

    #print STDERR "columns:".Dumper($columns);
    return undef unless defined $columns->{$usecase};

    my $entries = get( $config, $options );

    #print STDERR "exist:".Dumper($columns);

    if ( scalar @$entries == 0 ) {
        my $entry = {
            project_id => $options->{project_id},
            studio_id  => $options->{studio_id},
            series_id  => $options->{series_id},
            user       => $options->{user},
            $usecase   => 1,
        };

        #print STDERR "user_stats::insert\n";
        return insert( $config, $entry );
    } elsif ( scalar @$entries == 1 ) {
        my $entry = $entries->[0];
        $entry->{$usecase}++ if defined

          #print STDERR "user_stats::update\n";
          return update( $config, $entry );
    } else {
        print STDERR "user_stats: to few options given: $usecase," . Dumper($options) . "\n";
    }

}

sub error {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
