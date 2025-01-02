package audio_recordings;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use db();

our @EXPORT_OK = qw(get_columns get);

# columns:
# id, project_id, studio_id, event_id
# path, size, created_by, created_at
# mastered, processed
# audioDuration, eventDuration, rmsLeft, rmsRight

sub get_columns($) {
    my ($config) = @_;
    my $dbh  = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_audio_recordings');
}

# get playout entries
sub get($$) {
    my ($config, $condition) = @_;

    my $date_range_include = 0;
    $date_range_include = 1
      if (defined $condition->{date_range_include}) && ($condition->{date_range_include} == 1);

    my $dbh = db::connect($config);
    my $conditions  = [];
    my $bind_values = [];

    if ((defined $condition->{id}) && ($condition->{id} ne '')) {
        push @$conditions,  'id=?';
        push @$bind_values, $condition->{id};
    }

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @$conditions,  'project_id=?';
        push @$bind_values, $condition->{project_id};
    }

    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')) {
        push @$conditions,  'studio_id=?';
        push @$bind_values, $condition->{studio_id};
    }

    if ((defined $condition->{event_id}) && ($condition->{event_id} ne '')) {
        push @$conditions,  'event_id=?';
        push @$bind_values, $condition->{event_id};
    }

    if ((defined $condition->{path}) && ($condition->{path} ne '')) {
        push @$conditions,  'path=?';
        push @$bind_values, $condition->{path};
    }

    my $limit = '';
    if ((defined $condition->{limit}) && ($condition->{limit} ne '')) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $whereClause = '';
    $whereClause = " where " . join(" and ", @$conditions) if (scalar @$conditions > 0);

    my $query = qq{
        select    id
                ,project_id
                ,studio_id
                ,event_id
                ,active
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
        from     calcms_audio_recordings
        $whereClause
        order by created_at desc
    };
    my $entries = db::get($dbh, $query, $bind_values);
    return $entries;
}

sub update_active($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'event_id') {
        ParamError->throw(error => "audio-recordings: missing $_") unless defined $entry->{$_}
    };

    local $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{event_id} ];
    my $query = qq{
        update calcms_audio_recordings
        set    active=0
        where  project_id=? and studio_id=? and event_id=? and active=1
    };
    db::put($dbh, $query, $bind_values);

    $query = qq{
        select max(id) id from calcms_audio_recordings
        where  project_id=? and studio_id=? and event_id=?
    };
    my $entries = db::get($dbh, $query, $bind_values);
    my $max = $entries->[0];
    return undef unless defined $max->{id};

    $query = qq{
        update calcms_audio_recordings
        set    active=1
        where  id=?
    };
    return db::put($dbh, $query, [$max->{id}]);
}

# update playout entry if differs to old values
sub update($$) {
    my ($config, $entry) = @_;

    my $day_start = $config->{date}->{day_starting_hour};
    local $config->{access}->{write} = 1;

    my $dbh = db::connect($config);
    my $bind_values = [
        $entry->{path},       $entry->{size},
        $entry->{created_by}, $entry->{created_at},
        $entry->{modified_at} || time::time_to_datetime(time()), $entry->{processed},
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
    if (defined $entry->{id}) {
        $query .= ' and id=?';
        push @$bind_values, $entry->{id};
    }
    my $result = db::put($dbh, $query, $bind_values);
    update_active($config, $entry);
    return $result;
}

# insert playout entry
sub insert ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'event_id', 'path') {
        ParamError->throw(error => "audio-recordings: missing $_") unless defined $entry->{$_}
    };

    local $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    $entry = {
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
    };

    my $result = db::insert($dbh, 'calcms_audio_recordings', $entry);
    update_active($config, $entry);
    return $result;
}

# delete playout entry
sub delete ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'event_id', 'path') {
        ParamError->throw(error => "audio-recordings: missing $_") unless defined $entry->{$_}
    };

    local $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    my $query = qq{
        delete
        from calcms_audio_recordings
        where project_id=? and studio_id=? and event_id=? and path=?
    };
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{event_id}, $entry->{path} ];
    my $result =  db::put($dbh, $query, $bind_values);

    update_active($config, $entry);
    return $result;
}

#do not delete last line!
1;
