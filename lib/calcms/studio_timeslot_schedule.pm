package studio_timeslot_schedule;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use studio_timeslot_dates();

# table:   calcms_studio_timeslot_schedule
# columns: id, project_id, studio_id, start(datetime), end(datetime), end_date(date),
#          frequency(days), duration(minutes), create_events(days), publish_events(days)
#use base 'Exporter';
our @EXPORT_OK   = qw(get_columns get insert update delete);

sub debug;

sub get_columns($) {
	my $config = shift;

	my $dbh = db::connect($config);
	return db::get_columns_hash( $dbh, 'calcms_studio_timeslot_schedule' );
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
		push @conditions,  'id=?';
		push @bind_values, $condition->{schedule_id};
	}

	my $conditions = '';
	$conditions = " where " . join( " and ", @conditions ) if ( @conditions > 0 );

	my $query = qq{
		select *
		from   calcms_studio_timeslot_schedule
		$conditions
		order  by start
	};

	my $entries = db::get( $dbh, $query, \@bind_values );
	for my $entry (@$entries) {
		$entry->{schedule_id} = $entry->{id};
		delete $entry->{id};
	}
	return $entries;
}

sub insert($$) {
	my $config = shift;
	my $entry  = shift;

	return unless defined $entry->{project_id};
	return unless defined $entry->{studio_id};
	return unless defined $entry->{start};
	return unless defined $entry->{end};
	return unless defined $entry->{frequency};

	my $dbh = db::connect($config);
	return db::insert( $dbh, 'calcms_studio_timeslot_schedule', $entry );
}

#schedule id to id
sub update($$) {
	my $config = shift;
	my $entry  = shift;

	return unless defined $entry->{project_id};
	return unless defined $entry->{studio_id};
	return unless defined $entry->{schedule_id};
	return unless defined $entry->{start};
	return unless defined $entry->{end};
	return unless defined $entry->{frequency};

	$entry->{id} = $entry->{schedule_id};
	delete $entry->{schedule_id};

	my $dbh         = db::connect($config);
	my @keys        = sort keys %$entry;
	my $values      = join( ",", map { $_ . '=?' } @keys );
	my @bind_values = map { $entry->{$_} } @keys;
	push @bind_values, $entry->{id};

	my $query = qq{
		update calcms_studio_timeslot_schedule 
		set    $values
		where  id=?
	};
	db::put( $dbh, $query, \@bind_values );

	#print "done\n";

	$entry->{schedule_id} = $entry->{id};
	delete $entry->{id};

}

#map schedule id to id
sub delete ($$){
	my $config = shift;
	my $entry  = shift;

	return unless defined $entry->{schedule_id};

	my $dbh = db::connect($config);

	my $query = qq{
		delete 
		from calcms_studio_timeslot_schedule 
		where id=?
	};
	my $bind_values = [ $entry->{schedule_id} ];

	db::put( $dbh, $query, $bind_values );
}

sub error($) {
	my $msg = shift;
	print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
