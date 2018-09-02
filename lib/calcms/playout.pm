package playout;

use warnings "all";
use strict;

use Data::Dumper;
use Date::Calc();
use db();
use time();
use series_events();

use base 'Exporter';
our @EXPORT_OK   = qw(get_columns get sync);

sub debug;

sub get_columns {
	my $config = shift;

	my $dbh     = db::connect($config);
	my $cols    = db::get_columns( $dbh, 'calcms_playout' );
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

	return undef unless defined $condition->{studio_id};

	my $date_range_include = 0;
	$date_range_include = 1 if ( defined $condition->{date_range_include} ) && ( $condition->{date_range_include} == 1 );

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

	if ( ( defined $condition->{start_at} ) && ( $condition->{start_at} ne '' ) ) {
		push @conditions,  'start=?';
		push @bind_values, $condition->{start_at};
	}

	if ( ( defined $condition->{from} ) && ( $condition->{from} ne '' ) ) {
		if ( $date_range_include == 1 ) {
			push @conditions,  'end_date>=?';
			push @bind_values, $condition->{from};
		} else {
			push @conditions,  'start_date>=?';
			push @bind_values, $condition->{from};
		}
	}

	if ( ( defined $condition->{till} ) && ( $condition->{till} ne '' ) ) {
		if ( $date_range_include == 1 ) {
			push @conditions,  'start_date<=?';
			push @bind_values, $condition->{till};
		} else {
			push @conditions,  'end_date<=?';
			push @bind_values, $condition->{till};
		}
	}

	my $limit = '';
	if ( ( defined $condition->{limit} ) && ( $condition->{limit} ne '' ) ) {
		$limit = 'limit ' . $condition->{limit};
	}

	my $conditions = '';
	$conditions = " where " . join( " and ", @conditions ) if ( @conditions > 0 );

	my $order = 'start';
	$order = $condition->{order} if ( defined $condition->{order} ) && ( $condition->{order} ne '' );

	my $query = qq{
		select	 date(start) 		start_date
				,date(end) 			end_date
				,dayname(start) 	weekday
				,start_date         day
				,start
				,end
				,studio_id
				,project_id
                ,duration
                ,file
                ,errors
                ,channels
                ,format
                ,format_version
                ,format_profile
                ,format_settings
                ,stream_size
                ,bitrate
                ,bitrate_mode
                ,sampling_rate
                ,writing_library
                ,rms_left
                ,rms_right
                ,rms_image
                ,modified_at
                ,updated_at
		from 	calcms_playout
		$conditions
		order by $order
        $limit
	};

	#print STDERR Dumper($query).Dumper(\@bind_values);
	my $entries = db::get( $dbh, $query, \@bind_values );
	return $entries;
}

# update playout entries for a given date span
# insert, update and delete entries
sub sync {
	my $config  = shift;
	my $options = shift;

	#print STDERR Dumper($config);
	print STDERR "upload " . Dumper($options);
	return undef unless defined $options->{project_id};
	return undef unless defined $options->{studio_id};
	return undef unless defined $options->{from};
	return undef unless defined $options->{till};
	return undef unless defined $options->{events};

	my $project_id = $options->{project_id};
	my $studio_id  = $options->{studio_id};
	my $updates    = $options->{events};

	# get new entries by date
	my $update_by_date = {};
	for my $entry (@$updates) {
		$update_by_date->{ $entry->{start} } = $entry;
	}

	# get database entries
	my $bind_values = [ $options->{project_id}, $options->{studio_id}, $options->{from}, $options->{till} ];

	my $query = qq{
		select  *
		from 	calcms_playout
		where   project_id=?
		        and studio_id=?
		        and start >=?
		        and end <= ?
		order by start
	};
	print STDERR "from:$options->{from} till:$options->{till}\n";
	my $dbh = db::connect($config);
	my $entries = db::get( $dbh, $query, $bind_values );

	#print STDERR "entries:".Dumper($entries);

	# get database entries by date
	my $entries_by_date = {};
	for my $entry (@$entries) {

		# store entry by date
		my $start = $entry->{start};
		$entries_by_date->{$start} = $entry;

		# remove outdated entries
		unless ( defined $update_by_date->{$start} ) {
			print STDERR "delete:" . Dumper($entry);
			playout::delete( $config, $dbh, $entry );
			my $result = series_events::set_playout_status(
				$config,
				{
					project_id => $project_id,
					studio_id  => $studio_id,
					start      => $entry->{start},
					playout    => 0,
				}
			);
			print STDERR "delete playout_status result=" . $result . "\n";
			next;
		}

		# update existing entries
		if ( defined $update_by_date->{$start} ) {
			next if has_changed( $entry, $update_by_date->{$start} ) == 0;
			print STDERR "update:" . Dumper($entry);
			playout::update( $config, $dbh, $entry, $update_by_date->{$start} );
			my $result = series_events::set_playout_status(
				$config,
				{
					project_id => $project_id,
					studio_id  => $studio_id,
					start      => $entry->{start},
					playout    => 1,
				}
			);
			print STDERR "update playout_status result=" . $result . "\n";
			next;
		}
	}

	# insert new entries
	for my $entry (@$updates) {
		my $start = $entry->{start};
		unless ( defined $entries_by_date->{$start} ) {
			$entry->{project_id} = $project_id;
			$entry->{studio_id}  = $studio_id;
			print STDERR "insert:" . Dumper($entry);
			playout::insert( $config, $dbh, $entry );
			my $result = series_events::set_playout_status(
				$config,
				{
					project_id => $project_id,
					studio_id  => $studio_id,
					start      => $entry->{start},
					playout    => 1,
				}
			);
			print STDERR "insert playout_status result=" . $result . "\n";
		}
	}
	return 1;
}

sub has_changed {
	my $oldEntry = shift;
	my $newEntry = shift;

	my $update = 0;
	for my $key (
		'duration',        'errors',          'file',        'channels', 'format',       'format_version',
		'format_profile',  'format_settings', 'stream_size', 'bitrate',  'bitrate_mode', 'sampling_rate',
		'writing_library', 'modified_at'
	  )
	{
		return 1 if ( $oldEntry->{$key} || '' ) ne ( $newEntry->{$key} || '' );
	}
	return 0;
}

# update playout entry if differs to old values
sub update {
	my $config   = shift;
	my $dbh      = shift;
	my $oldEntry = shift;
	my $newEntry = shift;

	return if has_changed( $oldEntry, $newEntry ) == 0;

	for my $key (
		'duration',        'errors',          'file',        'channels',  'format',       'format_version',
		'format_profile',  'format_settings', 'stream_size', 'bitrate',   'bitrate_mode', 'sampling_rate',
		'writing_library', 'rms_left',        'rms_right',   'rms_image', 'replay_gain',  'modified_at'
	  )
	{
		if ( ( $oldEntry->{$key} || '' ) ne ( $newEntry->{$key} || '' ) ) {
			$oldEntry->{$key} = $newEntry->{$key};
		}
	}

	my $entry = $oldEntry;
	print STDERR "update:" . Dumper($entry);

	my $day_start = $config->{date}->{day_starting_hour};
	$entry->{end} = playout::getEnd( $entry->{start}, $entry->{duration} );
	$entry->{start_date} = time::add_hours_to_datetime( $entry->{start}, -$day_start );
	$entry->{end_date}   = time::add_hours_to_datetime( $entry->{end},   -$day_start );

	my $bind_values = [
		$entry->{end},            $entry->{duration},       $entry->{file},            $entry->{errors},
		$entry->{start_date},     $entry->{end_date},       $entry->{channels},        $entry->{'format'},
		$entry->{format_version}, $entry->{format_profile}, $entry->{format_settings}, $entry->{stream_size},
		$entry->{bitrate},        $entry->{bitrate_mode},   $entry->{sampling_rate},   $entry->{writing_library},
		$entry->{rms_left},       $entry->{rms_right},      $entry->{rms_image},       $entry->{replay_gain},
		$entry->{modified_at},    $entry->{project_id},     $entry->{studio_id},       $entry->{start}
	];
	my $query = qq{
        update calcms_playout
        set    end=?, duration=?, file=?, errors=?, 
               start_date=?, end_date=?, 
               channels=?, format=?, format_version=?, format_profile=?, format_settings=?, stream_size=?,
               bitrate=?, bitrate_mode=?, sampling_rate=?, writing_library=?, 
               rms_left=?, rms_right=?, rms_image=?,
               replay_gain=?, modified_at=?
        where  project_id=? and studio_id=? and start=?
    };
	return db::put( $dbh, $query, $bind_values );
}

# insert playout entry
sub insert {
	my $config = shift;
	my $dbh    = shift;
	my $entry  = shift;

	return undef unless defined $entry->{project_id};
	return undef unless defined $entry->{studio_id};
	return undef unless defined $entry->{start};
	return undef unless defined $entry->{duration};
	return undef unless defined $entry->{file};

	my $day_start = $config->{date}->{day_starting_hour};
	$entry->{end} = playout::getEnd( $entry->{start}, $entry->{duration} );
	$entry->{start_date} = time::add_hours_to_datetime( $entry->{start}, -$day_start );
	$entry->{end_date}   = time::add_hours_to_datetime( $entry->{end},   -$day_start );

	return db::insert(
		$dbh,
		'calcms_playout',
		{
			project_id      => $entry->{project_id},
			studio_id       => $entry->{studio_id},
			start           => $entry->{start},
			end             => $entry->{end},
			start_date      => $entry->{start_date},
			end_date        => $entry->{end_date},
			duration        => $entry->{duration},
			rms_left        => $entry->{rms_left},
			rms_right       => $entry->{rms_right},
			rms_image       => $entry->{rms_image},
			replay_gain     => $entry->{replay_gain},
			file            => $entry->{file},
			errors          => $entry->{errors},
			channels        => $entry->{channels},
			"format"        => $entry->{"format"},
			format_version  => $entry->{format_version},
			format_profile  => $entry->{format_profile},
			format_settings => $entry->{format_settings},
			stream_size     => $entry->{stream_size},
			bitrate         => $entry->{bitrate},
			bitrate_mode    => $entry->{bitrate_mode},
			sampling_rate   => $entry->{sampling_rate},
			writing_library => $entry->{writing_library},
			modified_at     => $entry->{modified_at}
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
	return undef unless defined $entry->{start};

	my $query = qq{
		delete 
		from calcms_playout
		where project_id=? and studio_id=? and start=?
	};
	my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{start} ];
	return db::put( $dbh, $query, $bind_values );
}

sub getEnd {
	my $start    = shift;
	my $duration = shift;

	# calculate end from start + duration
	my @start = @{ time::datetime_to_array($start) };
	next unless @start >= 6;

	#print STDERR Dumper(\@start);
	my @end_datetime = Date::Calc::Add_Delta_DHMS(
		$start[0], $start[1], $start[2],    # start date
		$start[3], $start[4], $start[5],    # start time
		0, 0, 0, int($duration)             # delta days, hours, minutes, seconds
	);

	#print STDERR Dumper(\@end_datetime);
	return time::array_to_datetime( \@end_datetime );
}

sub error {
	my $msg = shift;
	print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
