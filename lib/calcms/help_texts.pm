package help_texts;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

# table:   calcms_help_texts
# columns: id, studio_id, series_id,
# table, column, text

our @EXPORT_OK = qw(get_columns get insert update delete);

sub get_columns($) {
    my ($config) = @_;
    my $dbh = db::connect($config);
    return db::get_columns_hash($dbh, 'calcms_help_texts');
}

#map schedule id to id
sub get($$) {
    my ($config, $condition) = @_;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();
    for my $col ('project_id', 'studio_id', 'lang', 'table', 'column', 'text') {
        if ((defined $condition->{$col}) && ($condition->{$col} ne '')) {
            push @conditions,  "`calcms_help_texts`.`$col`=?";
            push @bind_values, $condition->{$col};
        }
    }
    my $conditions = '';
    $conditions = " where " . join(" and ", @conditions) if (@conditions > 0);
    my $query = qq{
        select *
        from   calcms_help_texts
        $conditions
    };
    my $entries = db::get($dbh, $query, \@bind_values);
    return $entries;
}

sub insert ($$) {
    my ($config, $entry) = @_;

    for my $col ('project_id', 'studio_id', 'lang', 'table', 'column', 'text') {
        return undef unless defined $entry->{$col};
    }
    my $dbh = db::connect($config);

    return db::insert($dbh, 'calcms_help_texts', $entry);
}

sub update ($$) {
    my ($config, $entry) = @_;

    for my $col ('project_id', 'studio_id', 'lang', 'table', 'column', 'text') {
        return undef unless defined $entry->{$col};
    }
    my $dbh         = db::connect($config);
    my @keys        = sort keys %$entry;
    my $values      = join(",", map { "`$_`" . '=?' } @keys);
    my @bind_values = map { $entry->{$_} } @keys;
    for my $col ('project_id', 'studio_id', 'lang', 'table', 'column') {
        push @bind_values, $entry->{$col};
    }
    my $query = qq{
        update calcms_help_texts
        set    $values
        where
                  `calcms_help_texts`.`project_id`=?
              and `calcms_help_texts`.`studio_id`=?
              and `calcms_help_texts`.`lang`=?
              and `calcms_help_texts`.`table`=?
              and `calcms_help_texts`.`column`=?
    };
    return db::put($dbh, $query, \@bind_values);
    print "done\n";
}

sub delete($$) {
    my ($config, $entry) = @_;

    for my $col ('project_id', 'studio_id', 'lang', 'table', 'column', 'text') {
        return undef unless defined $entry->{$col};
    }
    my $dbh = db::connect($config);
    my $query = qq{
        delete
        from calcms_help_texts
        where  project_id=? and studio_id=? and lang=? and `calcms_help_texts`.`table`=? and `calcms_help_texts`.`column`=?
    };
    my $bind_values = [];
    for my $col ('project_id', 'studio_id', 'lang', 'table', 'column') {
        push @$bind_values, $entry->{$col};
    }
    return db::put($dbh, $query, $bind_values);
}

#do not delete last line!
1;
