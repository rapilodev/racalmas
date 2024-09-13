package series_schedule;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use series_dates();

# table:   calcms_series_schedule
# columns: id, studio_id, series_id,
# start (datetime),
# duration (minutes),
# frequency (days),
# end (date),
# weekday (1..7)
# week_of_month (1..5)
# month
# nextDay (add 24 hours to start)

our @EXPORT_OK = qw(get_columns get insert update delete);

sub get_columns ($) {
    my ($config) = @_;

    my $dbh     = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_series_schedule');
}

#map schedule id to id
sub get($$) {
    my ($config, $condition) = @_;

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

    if ((defined $condition->{schedule_id}) && ($condition->{schedule_id} ne '')) {
        push @conditions,  'id=?';
        push @bind_values, $condition->{schedule_id};
    }

    if ((defined $condition->{schedule_ids}) && (ref($condition->{schedule_ids}) eq 'ARRAY')) {
        my @scheduleIds = @{ $condition->{schedule_ids} };
        push @conditions, 'id in (' . (join(',', (map { '?' } @scheduleIds))) . ')';
        for my $id (@scheduleIds) {
            push @bind_values, $id;
        }
    }

    if ((defined $condition->{start}) && ($condition->{start} ne '')) {
        push @conditions,  'start=?';
        push @bind_values, $condition->{start};
    }

    if ((defined $condition->{exclude}) && ($condition->{exclude} ne '')) {
        push @conditions,  'exclude=?';
        push @bind_values, $condition->{exclude};
    }

    if ((defined $condition->{period_type}) && ($condition->{period_type} ne '')) {
        push @conditions,  'period_type=?';
        push @bind_values, $condition->{period_type};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select *
        from   calcms_series_schedule
        $conditions
        order  by exclude, start
    };

    my $entries = db::get($dbh, $query, \@bind_values);
    for my $entry (@$entries) {
        $entry->{schedule_id} = $entry->{id};
        delete $entry->{id};
    }
    return $entries;
}

sub insert($$) {
    my ($config, $entry) = @_;
    for ('project_id', 'studio_id', 'series_id', 'start') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    }
    my $dbh = db::connect($config);
    return db::insert($dbh, 'calcms_series_schedule', $entry);
}

#schedule id to id
sub update($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id', 'start', 'schedule_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    $entry->{nextDay} = 0 unless defined $entry->{nextDay};

    $entry->{id} = $entry->{schedule_id};
    delete $entry->{schedule_id};

    my $dbh         = db::connect($config);
    my @keys        = sort keys %$entry;
    my $values      = join(",", map { $_ . '=?' } @keys);
    my @bind_values = map { $entry->{$_} } @keys;

    push @bind_values, $entry->{project_id};
    push @bind_values, $entry->{studio_id};
    push @bind_values, $entry->{id};

    my $query = qq{
        update calcms_series_schedule
        set    $values
        where  project_id=? and studio_id=? and id=?
    };

    db::put($dbh, $query, \@bind_values);
}

#map schedule id to id
sub delete($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id', 'schedule_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);

    my $query = qq{
        delete
        from calcms_series_schedule
        where project_id=? and studio_id=? and series_id=? and id=?
    };
    my $bind_values = [ $entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{schedule_id} ];

    db::put($dbh, $query, $bind_values);
}

#do not delete last line!
1;
