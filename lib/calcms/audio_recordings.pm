#!/bin/perl

package audio_recordings;

use warnings "all";
use strict;

use Data::Dumper;
use db();

require Exporter;

our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(get_columns get);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

# columns:
# id, project_id, studio_id, event_id
# path, size, created_by, created_at
# mastered, processed
# audioDuration, eventDuration, rmsLeft, rmsRight

sub debug;

sub get_columns {
	my $config = shift;

	my $dbh     = db::connect($config);
	my $cols    = db::get_columns( $dbh, 'calcms_audio_recordings' );
	my $columns = {};
	for my $col (@$cols) {
		$columns->{$col} = 1;
	}
	return $columns;
}

# get playout entries
sub get {
	my $config    = shift;
	my $condition = shift;

	return undef unless defined $condition->{project_id};
	return undef unless defined $condition->{studio_id};

	my $date_range_include = 0;
	$date_range_include = 1 if ( defined $condition->{date_range_include} ) && ( $condition->{date_range_include} == 1 );

	my $dbh = db::connect($config);

	my $conditions  = [];
	my $bind_values = [];

	if ( ( defined $condition->{id} ) && ( $condition->{id} ne '' ) ) {
		push @$conditions,  'id=?';
		push @$bind_values, $condition->{id};
	}

	if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
		push @$conditions,  'project_id=?';
		push @$bind_values, $condition->{project_id};
	}

	if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
		push @$conditions,  'studio_id=?';
		push @$bind_values, $condition->{studio_id};
	}

	if ( ( defined $condition->{event_id} ) && ( $condition->{event_id} ne '' ) ) {
		push @$conditions,  'event_id=?';
		push @$bind_values, $condition->{event_id};
	}

	if ( ( defined $condition->{path} ) && ( $condition->{path} ne '' ) ) {
		push @$conditions,  'path=?';
		push @$bind_values, $condition->{path};
	}

	my $limit = '';
	if ( ( defined $condition->{limit} ) && ( $condition->{limit} ne '' ) ) {
		$limit = 'limit ' . $condition->{limit};
	}

	my $whereClause = '';
	$whereClause = " where " . join( " and ", @$conditions ) if ( scalar @$conditions > 0 );

	my $query = qq{
		select	id 
		        ,project_id
				,studio_id
				,event_id
				,path
				,size
				,created_by
				,created_at
				,modified_at
				,mastered
				,processed
				,audioDuration
				,eventDuration
				,rmsLeft
				,rmsRight
		from 	calcms_audio_recordings
		$whereClause
		order by created_at desc
	};

	#print STDERR Dumper($query).Dumper($bind_values);
	my $entries = db::get( $dbh, $query, $bind_values );
	return $entries;
}

# update playout entry if differs to old values
sub update {
	my $config = shift;
	my $dbh    = shift;
	my $entry  = shift;

	#print STDERR "update:".Dumper($entry);

	my $day_start = $config->{date}->{day_starting_hour};

	my $bind_values = [
		$entry->{path},       $entry->{size},
		$entry->{created_by}, $entry->{created_at},
		$entry->{modified_at} || time::time_to_datetime( time() ), $entry->{processed},
		$entry->{mastered},      $entry->{eventDuration},
		$entry->{audioDuration}, $entry->{rmsLeft},
		$entry->{rmsRight},      $entry->{project_id},
		$entry->{studio_id},     $entry->{event_id}
	];

	my $query = qq{
        update calcms_audio_recordings
        set    path=?, size=?, 
               created_by=?, created_at=?, 
               modified_at=?,
               processed=?, mastered=?,
               eventDuration=?, audioDuration=?, 
               rmsLeft=?, rmsRight=?
        where  project_id=? and studio_id=? and event_id=?
    };
	if ( defined $entry->{id} ) {
		$query .= ' and id=?';
		push @$bind_values, $entry->{id};
	}

	#print STDERR Dumper($query).Dumper($bind_values);
	return db::put( $dbh, $query, $bind_values );
}

# insert playout entry
sub insert {
	my $config = shift;
	my $dbh    = shift;
	my $entry  = shift;

	return undef unless defined $entry->{project_id};
	return undef unless defined $entry->{studio_id};
	return undef unless defined $entry->{event_id};
	return undef unless defined $entry->{path};

	#print STDERR "insert into audio_recordings:".Dumper($entry);
	return db::insert(
		$dbh,
		'calcms_audio_recordings',
		{
			project_id    => $entry->{project_id},
			studio_id     => $entry->{studio_id},
			event_id      => $entry->{event_id},
			path          => $entry->{path},
			size          => $entry->{size},
			created_by    => $entry->{created_by},
			eventDuration => $entry->{eventDuration},
			audioDuration => $entry->{audioDuration},
			rmsLeft       => $entry->{rmsLeft},
			rmsRight      => $entry->{rmsRight},
			processed     => $entry->{processed},
			mastered      => $entry->{mastered} || '0',
		}
	);

}

# delete playout entry
sub delete {
	my $config = shift;
	my $dbh    = shift;
	my $entry  = shift;

	return undef unless defined $entry->{project_id};
	return undef unless defined $entry->{studio_id};
	return undef unless defined $entry->{event_id};
	return undef unless defined $entry->{path};

	my $query = qq{
		delete 
		from calcms_audio_recordings
		where project_id=? and studio_id=? and event_id=? and path=?
	};
	my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{event_id}, $entry->{path} ];
	return db::put( $dbh, $query, $bind_values );
}

sub error {
	my $msg = shift;
	print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
