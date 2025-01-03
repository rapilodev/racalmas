package project;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Date::Calc;

use config();
use log();
use images();

our @EXPORT_OK = qw(
  check get_columns get insert delete get_date_range
  get_studios assign_studio unassign_studio is_studio_assigned get_studio_assignments
  get_series_ids assign_series unassign_series is_series_assigned get_series_assignments
  get_with_dates get_sorted
);

#TODO: globally replace get_studios by get_studio_assignments

# get project columns
sub get_columns ($) {
    my ($config) = @_;

    my $dbh = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_projects');
}

# get projects
sub get ($;$) {
    my ($config, $condition) = @_;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }

    if ((defined $condition->{name}) && ($condition->{name} ne '')) {
        push @conditions,  'name=?';
        push @bind_values, $condition->{name};
    }

    my $limit = '';
    if ((defined $condition->{limit}) && ($condition->{limit} ne '')) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select    *
        from     calcms_projects
        $conditions
        order by start_date
        $limit
    };

    my $projects = db::get($dbh, $query, \@bind_values);
    return $projects;
}

# requires at least project_id
sub getImageById($$) {
    my ($config, $conditions) = @_;

    for ('project_id') {
        ParamError->throw(error => "missing $_") unless defined $conditions->{$_};
    };

    my $projects = project::get($config, $conditions);
    return undef if scalar(@$projects) != 1;
    return $projects->[0]->{image};
}

sub get_date_range($) {
    my ($config) = @_;

    my $query = qq{
        select min(start_date) start_date, max(end_date) end_date
        from   calcms_projects
    };
    my $dbh = db::connect($config);

    my $projects = db::get($dbh, $query);
    return $projects->[0];
}

# insert project
sub insert($$) {
    my ($config, $entry) = @_;

    my $columns = get_columns($config);
    my $project = {};
    for my $column (keys %$columns) {
        $project->{$column} = $entry->{$column} if defined $entry->{$column};
    }

    $project->{image} = images::normalizeName($project->{image}) if defined $project->{image};

    my $dbh = db::connect($config);
    my $id = db::insert($dbh, 'calcms_projects', $project);
    return $id;
}

# update project
sub update($$) {
    my ($config, $project) = @_;

    my $columns = project::get_columns($config);
    my $entry   = {};
    for my $column (keys %$columns) {
        $entry->{$column} = $project->{$column} if defined $project->{$column};
    }

    $entry->{image} = images::normalizeName($entry->{image}) if defined $entry->{image};

    my @keys = sort keys %$entry;
    my $values = join(",", map { $_ . '=?' } @keys);
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{project_id};

    my $query = qq{
        update calcms_projects
        set $values
        where project_id=?
    };
    my $dbh = db::connect($config);
    db::put($dbh, $query, \@bind_values);
}

# delete project
sub delete ($$) {
    my ($config, $entry) = @_;
    my $dbh = db::connect($config);
    db::put($dbh, 'delete from calcms_projects where project_id=?', [ $entry->{project_id} ]);
}

# get studios of a project
sub get_studios($$) {
    my ($config, $options) = @_;

    for ('project_id') {
        ParamError->throw(error => "missing $_") unless defined $options->{$_}
    };
    my $project_id = $options->{project_id};

    my $query = qq{
        select    *
        from     calcms_project_studios
        where    project_id=?
    };
    my $dbh = db::connect($config);
    my $project_studios = db::get($dbh, $query, [$project_id]);

    return $project_studios;
}

sub get_studio_assignments($$) {
    my ($config, $options) = @_;

    my @conditions  = ();
    my @bind_values = ();

    if ((defined $options->{project_id}) && ($options->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $options->{project_id};
    }

    if ((defined $options->{studio_id}) && ($options->{studio_id} ne '')) {
        push @conditions,  'studio_id=?';
        push @bind_values, $options->{studio_id};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select    *
        from     calcms_project_studios
        $conditions
    };

    my $dbh = db::connect($config);
    my $results = db::get($dbh, $query, \@bind_values);

    return $results;
}

# is studio assigned to project
sub is_studio_assigned ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $project_id = $entry->{project_id};
    my $studio_id  = $entry->{studio_id};

    my $query = qq{
        select    *
        from     calcms_project_studios
        where    project_id=? and studio_id=?
    };
    my $bind_values = [ $project_id, $studio_id ];

    my $dbh = db::connect($config);
    my $project_studios = db::get($dbh, $query, $bind_values);
    return 1 if scalar @$project_studios == 1;
    return 0;
}

# assign studio to project
sub assign_studio($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };
    my $project_id = $entry->{project_id};
    my $studio_id  = $entry->{studio_id};

    if (is_studio_assigned($config, $entry)) {
        print STDERR "studio $entry->{studio_id} already assigned to project $entry->{project_id}\n";
        return 1;
    }
    my $dbh = db::connect($config);
    my $id = db::insert($dbh, 'calcms_project_studios', $entry);
    return $id;
}

# unassign studio from project
sub unassign_studio($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };
    my $project_id = $entry->{project_id};
    my $studio_id  = $entry->{studio_id};

    my $sql         = 'delete from calcms_project_studios where project_id=? and studio_id=?';
    my $bind_values = [ $project_id, $studio_id ];
    my $dbh         = db::connect($config);
    return db::put($dbh, $sql, $bind_values);
}

# get series by project and studio
sub get_series ($$) {
    my ($config, $options) = @_;

    for ('project_id', 'studio_id') {
        ParamError->throw(error => "missing $_") unless defined $options->{$_}
    };
    my $project_id = $options->{project_id};
    my $studio_id  = $options->{studio_id};

    my $query = qq{
        select    *
        from     calcms_project_series
        where    project_id=? and studio_id=?
    };
    my $bind_values    = [ $project_id, $studio_id ];
    my $dbh            = db::connect($config);
    my $project_series = db::get($dbh, $query, $bind_values);

    return $project_series;
}

sub get_series_assignments ($$) {
    my ($config, $options) = @_;

    my @conditions  = ();
    my @bind_values = ();

    if ((defined $options->{project_id}) && ($options->{project_id} ne '')) {
        push @conditions,  'project_id=?';
        push @bind_values, $options->{project_id};
    }

    if ((defined $options->{studio_id}) && ($options->{studio_id} ne '')) {
        push @conditions,  'studio_id=?';
        push @bind_values, $options->{studio_id};
    }

    if ((defined $options->{series_id}) && ($options->{series_id} ne '')) {
        push @conditions,  'series_id=?';
        push @bind_values, $options->{series_id};
    }

    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);

    my $query = qq{
        select    *
        from     calcms_project_series
        $conditions
    };

    my $dbh = db::connect($config);
    my $results = db::get($dbh, $query, \@bind_values);

    return $results;
}

# is series assigned to project and studio
sub is_series_assigned ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $project_id = $entry->{project_id};
    my $studio_id  = $entry->{studio_id};
    my $series_id  = $entry->{series_id};

    my $query = qq{
        select    *
        from     calcms_project_series
        where    project_id=? and studio_id=? and series_id=?
    };
    my $bind_values = [ $project_id, $studio_id, $series_id ];

    my $dbh = db::connect($config);
    my $project_series = db::get($dbh, $query, $bind_values);
    return 1 if scalar @$project_series == 1;
    return 0;
}

# assign series to project and studio
sub assign_series($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $project_id = $entry->{project_id};
    my $studio_id  = $entry->{studio_id};
    my $series_id  = $entry->{series_id};

    if (is_series_assigned($config, $entry)) {
        print STDERR "series $series_id already assigned to project $project_id and studio $studio_id\n";
        return return undef;
    }
    my $dbh = db::connect($config);
    my $id = db::insert($dbh, 'calcms_project_series', $entry);
    print STDERR "assigned series $series_id to project $project_id and studio $studio_id\n";
    return $id;
}

# unassign series from project
# TODO: remove series _single_ if no event is assigned to
sub unassign_series ($$) {
    my ($config, $entry) = @_;

    for ('project_id', 'studio_id', 'series_id') {
        ParamError->throw(error => "missing $_") unless defined $entry->{$_}
    };

    my $project_id = $entry->{project_id};
    my $studio_id  = $entry->{studio_id};
    my $series_id  = $entry->{series_id};

    my $sql         = 'delete from calcms_project_series where project_id=? and studio_id=? and series_id=?';
    my $bind_values = [ $project_id, $studio_id, $series_id ];
    my $dbh         = db::connect($config);
    return db::put($dbh, $sql, $bind_values);
}

sub get_with_dates($;$) {
    my ($config, $options) = @_;

    my $language = $config->{date}->{language} || 'en';
    my $projects = project::get($config, {});

    foreach my $project (reverse sort { $a->{end_date} cmp $b->{end_date} } (@$projects)) {
        $project->{months}  = get_months($config, $project, $language);
        $project->{user}    = $ENV{REMOTE_USER};
        $project->{current} = 1 if ($project->{name} eq $config->{project});
    }

    return $projects;
}

#TODO: add config
sub get_sorted($) {
    my ($config) = @_;
    my $projects = project::get($config, {});
    my @projects = reverse sort { $a->{end_date} cmp $b->{end_date} } (@$projects);

    unshift @projects,
      {
        name       => 'all',
        title      => 'alle',
        priority   => '0',
        start_date => $projects[-1]->{start_date},
        end_date   => $projects[0]->{end_date},
      };
    return \@projects;
}

# internal
sub get_months ($$;$) {
    my ($config, $project, $language) = @_;
    $language ||= $config->{date}->{language} || 'en';

    my $start = $project->{start_date};
    my $end   = $project->{end_date};

    (my $start_year, my $start_month, my $start_day) = split(/\-/, $start);
    my $last_day = Date::Calc::Days_in_Month($start_year, $start_month);
    $start_day = 1         if ($start_day < 1);
    $start_day = $last_day if ($start_day gt $last_day);

    (my $end_year, my $end_month, my $end_day) = split(/\-/, $end);
    $last_day = Date::Calc::Days_in_Month($end_year, $end_month);
    $end_day = 1         if ($end_day < 1);
    $end_day = $last_day if ($end_day gt $last_day);

    my $monthNamesShort = time::getMonthNamesShort($language);
    my @months          = ();
    for my $year ($start_year .. $end_year) {
        my $m1 = 1;
        my $m2 = 12;
        $m1 = $start_month if $year eq $start_year;
        $m2 = $end_month   if $year eq $end_year;

        for my $month ($m1 .. $m2) {
            my $d1 = 1;
            my $d2 = Date::Calc::Days_in_Month($year, $month);
            $d1 = $start_day if $month eq $start_month;
            $d2 = $end_day   if $month eq $end_month;
            push @months,
              {
                start      => time::array_to_date($year, $month, $d1),
                end        => time::array_to_date($year, $month, $d2),
                year       => $year,
                month      => $month,
                month_name => $monthNamesShort->[ $month - 1 ],
                title      => $project->{title},
                user       => $ENV{REMOTE_USER}
              };
        }
    }
    @months = reverse @months;
    return \@months;
}

# check project_id
sub check ($$) {
    my ($config, $options) = @_;
    ParamError->throw(error=> "missing project_id at checking project") unless defined $options->{project_id};
    ParamError->throw(error=> "Please select a project") if ($options->{project_id} eq '-1');
    ParamError->throw(error=> "Please select a project") if ($options->{project_id} eq '');
    my $projects = project::get($config, { project_id => $options->{project_id} });
    ProjectError->throw(error=> "Unknown project") unless defined $projects;
}

#do not delete last line!
1;
