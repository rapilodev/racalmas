package playout;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc();

use db();
use time();
use series_events();

our @EXPORT_OK = qw(get_columns get sync);

sub get_columns ($) {
    my ($config) = @_;
    my $dbh = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_playout' );
}

# get playout entries
sub get_scheduled($$) {
    my ($config, $condition) = @_;

    my $date_range_include = 0;
    $date_range_include = 1
      if ( defined $condition->{date_range_include} ) && ( $condition->{date_range_include} == 1 );

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'p.project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'p.studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ( ( defined $condition->{start_at} ) && ( $condition->{start_at} ne '' ) ) {
        push @conditions,  'p.start=?';
        push @bind_values, $condition->{start_at};
    }

    if ( ( defined $condition->{from} ) && ( $condition->{from} ne '' ) ) {
        if ( $date_range_include == 1 ) {
            push @conditions,  'p.end_date>=?';
            push @bind_values, $condition->{from};
        } else {
            push @conditions,  'p.start_date>=?';
            push @bind_values, $condition->{from};
        }
    }

    if ( ( defined $condition->{till} ) && ( $condition->{till} ne '' ) ) {
        if ( $date_range_include == 1 ) {
            push @conditions,  'p.start_date<=?';
            push @bind_values, $condition->{till};
        } else {
            push @conditions,  'p.end_date<=?';
            push @bind_values, $condition->{till};
        }
    }

    my $limit = '';
    if ( ( defined $condition->{limit} ) && ( $condition->{limit} ne '' ) ) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $conditions = '';
    $conditions = " and " . join( " and ", @conditions ) if scalar @conditions > 0;

    my $order = 'p.start';
    $order = $condition->{order} if ( defined $condition->{order} ) && ( $condition->{order} ne '' );

    my $query = qq{
		select	  date(p.start) 	start_date
				, date(p.end) 		end_date
				, dayname(p.start) 	weekday
				, p.start_date      day
				, p.start
				, p.end
				, p.studio_id
				, p.project_id
                , p.duration
                , p.file
                , p.errors
                , p.channels
                , p.format
                , p.format_version
                , p.format_profile
                , p.format_settings
                , p.stream_size
                , p.bitrate
                , p.bitrate_mode
                , p.sampling_rate
                , p.writing_library
                , p.rms_left
                , p.rms_right
                , p.rms_image
                , p.modified_at
                , p.updated_at
                , TIMESTAMPDIFF(SECOND,e.start,e.end) "event_duration"
        from    calcms_playout p, calcms_events e, calcms_series_events se
		where   p.start=e.start
		and     e.id=se.event_id
        and     p.studio_id=se.studio_id
        and     p.project_id=se.project_id
		$conditions
		order by $order
        $limit
	};

    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries;
}


# get playout entries
sub get($$) {
    my ($config, $condition) = @_;
    for ('studio_id') {
        ParamError->throw(error => "missing $_") unless defined $condition->{$_}
    };

    my $date_range_include = 0;
    $date_range_include = 1
      if ( defined $condition->{date_range_include} ) && ( $condition->{date_range_include} == 1 );

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

    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries;
}

# update playout entries for a given date span
# insert, update and delete entries
sub sync ($$) {
    my ($config, $options) = @_;

    for ('project_id', 'studio_id', 'from', 'till', 'events') {
        ParamError->throw(error => "missing $_") unless defined $options->{$_}
    };

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

    # get database entries by date
    my $entries_by_date = {};
    for my $entry (@$entries) {

        # store entry by date
        my $start = $entry->{start};
        $entries_by_date->{$start} = $entry;

        # remove outdated entries
        unless ( defined $update_by_date->{$start} ) {
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
            print STDERR "delete playout_status result=" . ($result // 'undef') . "\n";
            next;
        }

        # update existing entries
        if ( defined $update_by_date->{$start} ) {
            #next if has_changed( $entry, $update_by_date->{$start} ) == 0;
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
            print STDERR "update playout_status result=" . ($result // 'undef') . "\n";
            next;
        }
    }

    # insert new entries
    for my $entry (@$updates) {
        my $start = $entry->{start};
        unless ( defined $entries_by_date->{$start} ) {
            $entry->{project_id} = $project_id;
            $entry->{studio_id}  = $studio_id;
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
            print STDERR "insert playout_status result=" . ($result // 'undef'). "\n";
        }
    }
    return 1;
}

sub has_changed ($$) {
    my ($oldEntry, $newEntry) = @_;
    for my $key (
        'duration',        'errors',         'file',           'channels',
        'format',          'format_version', 'format_profile', 'format_settings',
        'stream_size',     'bitrate',        'bitrate_mode',   'sampling_rate',
        'writing_library', 'modified_at'
      )
    {
        return 1 if ( $oldEntry->{$key} // '' ) ne ( $newEntry->{$key} // '' );
    }
    return 0;
}

# update playout entry if differs to old values
sub update ($$$$) {
    my ($config, $dbh, $oldEntry, $newEntry) = @_;
    for my $key (
        'duration',        'errors',         'file',           'channels',
        'format',          'format_version', 'format_profile', 'format_settings',
        'stream_size',     'bitrate',        'bitrate_mode',   'sampling_rate',
        'writing_library', 'rms_left',       'rms_right',      'rms_image',
        'replay_gain',     'modified_at'
      )
    {
        if ( ( $oldEntry->{$key} || '' ) ne ( $newEntry->{$key} || '' ) ) {
            $oldEntry->{$key} = $newEntry->{$key};
        }
    }

    my $entry = $oldEntry;
    my $day_start = $config->{date}->{day_starting_hour};
    $entry->{end} = playout::get_end( $entry->{start}, $entry->{duration} );
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
sub insert ($$$) {
    my ($config, $dbh, $entry) = @_;

    for ('project_id', 'studio_id', 'start', 'duration', 'file') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $day_start = $config->{date}->{day_starting_hour};
    $entry->{end} = playout::get_end( $entry->{start}, $entry->{duration} );
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
sub delete($$$) {
    my ($config, $dbh, $entry) = @_;
    for ('project_id', 'studio_id', 'start') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };
    my $query = qq{
		delete
		from calcms_playout
		where project_id=? and studio_id=? and start=?
	};
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{start} ];
    return db::put( $dbh, $query, $bind_values );
}

sub get_end ($$) {
    my ($start, $duration) = @_;
    # calculate end from start + duration
    my @start = @{ time::datetime_to_array($start) };
    next unless @start >= 6;

    my @end_datetime = Date::Calc::Add_Delta_DHMS(
        $start[0], $start[1], $start[2],    # start date
        $start[3], $start[4], $start[5],    # start time
        0, 0, 0, int($duration)             # delta days, hours, minutes, seconds
    );
    return time::array_to_datetime( \@end_datetime );
}

#do not delete last line!
1;
