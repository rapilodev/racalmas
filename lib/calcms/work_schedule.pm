package work_schedule;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use series_dates();

# table:   calcms_work_schedule
# columns: id, studio_id, series_id,
# start (datetime),
# duration (minutes),
# frequency (days),
# end (date),
# weekday (1..7)
# week_of_month (1..5)
# month

#use base 'Exporter';
our @EXPORT_OK = qw(get_columns get insert update delete);

sub debug;

sub get_columns($) {
    my $config = shift;

    my $dbh = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_work_schedule' );
}

#map schedule id to id
sub get($$) {
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

    if ( ( defined $condition->{schedule_id} ) && ( $condition->{schedule_id} ne '' ) ) {
        push @conditions,  'schedule_id=?';
        push @bind_values, $condition->{schedule_id};
    }

    if ( ( defined $condition->{start} ) && ( $condition->{start} ne '' ) ) {
        push @conditions,  'start=?';
        push @bind_values, $condition->{start};
    }

    if ( ( defined $condition->{exclude} ) && ( $condition->{exclude} ne '' ) ) {
        push @conditions,  'exclude=?';
        push @bind_values, $condition->{exclude};
    }

    if ( ( defined $condition->{period_type} ) && ( $condition->{period_type} ne '' ) ) {
        push @conditions,  'period_type=?';
        push @bind_values, $condition->{period_type};
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select *
		from   calcms_work_schedule
		$conditions
		order  by exclude, start
	};

    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries;
}

sub insert ($$) {
    my $config = shift;
    my $entry  = shift;

    return undef unless defined $entry->{project_id};
    return undef unless defined $entry->{studio_id};
    return undef unless defined $entry->{start};
    my $dbh = db::connect($config);
    return db::insert( $dbh, 'calcms_work_schedule', $entry );
}

#schedule id to id
sub update ($$) {
    my $config = shift;
    my $entry  = shift;

    return undef unless defined $entry->{project_id};
    return undef unless defined $entry->{studio_id};
    return undef unless defined $entry->{schedule_id};
    return undef unless defined $entry->{start};

    my $dbh         = db::connect($config);
    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys);
    my @bind_values = map { $entry->{$_} } @keys;

    push @bind_values, $entry->{project_id};
    push @bind_values, $entry->{studio_id};
    push @bind_values, $entry->{schedule_id};

    my $query = qq{
		update calcms_work_schedule 
		set    $values
		where  project_id=? and studio_id=? and schedule_id=?
	};
    return db::put( $dbh, $query, \@bind_values );
    print "done\n";
}

#map schedule id to id
sub delete($$) {
    my $config = shift;
    my $entry  = shift;

    return undef unless defined $entry->{project_id};
    return undef unless defined $entry->{studio_id};
    return undef unless defined $entry->{schedule_id};

    my $dbh = db::connect($config);

    my $query = qq{
		delete 
		from calcms_work_schedule 
		where project_id=? and studio_id=? and schedule_id=?
	};
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{schedule_id} ];

    return db::put( $dbh, $query, $bind_values );
}

sub error($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
