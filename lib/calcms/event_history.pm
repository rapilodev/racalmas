package event_history;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

our @EXPORT_OK   = qw(get_columns get get_by_id insert insert_by_event_id delete);

sub get_columns ($){
    my ($config) = @_;

    my $dbh = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_event_history');
}

sub get ($$){
    my ($config, $condition) = @_;

    for ('studio_id') {
        ParamError->throw(error => "event_history: missing $_") unless defined $condition->{$_}
    };
    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ((defined $condition->{series_id}) && ($condition->{series_id} ne '')) {
        push @conditions,  'series_id=?';
        push @bind_values, $condition->{series_id};
    }

    if ((defined $condition->{event_id}) && ($condition->{event_id} ne '')) {
        push @conditions,  'event_id=?';
        push @bind_values, $condition->{event_id};
    }

    if ((defined $condition->{change_id}) && ($condition->{change_id} ne '')) {
        push @conditions,  'id=?';
        push @bind_values, $condition->{change_id};
    }

    my $limit = '';
    if ((defined $condition->{limit}) && ($condition->{limit} ne '')) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select    *
        from     calcms_event_history
        $conditions
        order by modified_at desc
        $limit
    };

    my $changes = db::get($dbh, $query, \@bind_values);

    for my $change (@$changes) {
        $change->{change_id} = $change->{id};
        delete $change->{id};
    }
    return $changes;
}

sub get_by_id($$) {
    my ($config, $id) = @_;
    my $dbh = db::connect($config);
    my $query = qq{
        select    *
        from     calcms_event_history
        where    event_id=?
    };
    my $studios = db::get($dbh, $query, [$id]);
    return undef if (@$studios != 1);
    return $studios->[0];
}

sub insert($$) {
    my ($config, $entry) = @_;

    $entry->{modified_at} = time::time_to_datetime(time());
    $entry->{event_id} = $entry->{id} if (defined $entry->{id}) && (!(defined $entry->{event_id}));
    delete $entry->{id};

    #TODO:filter for existing attributes
    my $columns = get_columns($config);
    my $event   = {};
    for my $column (keys %$columns) {
        $event->{$column} = $entry->{$column} if defined $entry->{$column};
    }

    my $dbh = db::connect($config);
    my $id = db::insert($dbh, 'calcms_event_history', $event);
    return $id;
}

# insert event
sub insert_by_event_id ($$){
    my ($config, $options) = @_;

    for ('project_id', 'studio_id', 'series_id', 'event_id', 'user') {
        ParamError->throw(error => "event_history: missing $_") unless defined $options->{$_}
    };

    my $sql = q{
        select * from calcms_events
        where id=?
    };
    my $bind_values = [ $options->{event_id} ];
    my $dbh         = db::connect($config);
    my $results     = db::get($dbh, $sql, $bind_values);
    if (@$results != 1) {
        EventError->throw(error=>"cannot find event with event_id=$options->{event_id}");
    }

    # add to history
    my $event = $results->[0];
    $event->{project_id} = $options->{project_id};
    $event->{studio_id}  = $options->{studio_id};
    $event->{series_id}  = $options->{series_id};
    $event->{event_id}   = $options->{event_id};
    $event->{user}       = $options->{user};
    $event->{deleted}    = 1;
    event_history::insert($config, $event);
}

sub delete ($$){
    my ($config, $entry) = @_;

    my $dbh = db::connect($config);
    db::put($dbh, 'delete from calcms_event_history where event_id=?', [ $entry->{id} ]);
}

sub error ($){
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
