package user_default_studios;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

# table:   calcms_user_default_studios
# columns: user, project_id, studio_id

sub debug;

sub get_columns($) {
    my $config = shift;

    my $dbh  = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_user_default_studios' );
}

sub get ($$) {
    my $config    = shift;
    my $condition = shift;

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }
    if ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        push @conditions,  'project_id=?';
        push @bind_values, $condition->{project_id};
    }
    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  'studio_id=?';
        push @bind_values, $condition->{studio_id};
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if scalar(@conditions) > 0;

    my $query = qq{
		select *
		from   calcms_user_default_studios
		$conditions
	};

    my $dbh = db::connect($config);
    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries->[0] || undef;
}

sub insert ($$) {
    my $config = shift;
    my $entry  = shift;

    return unless defined $entry->{user};

    my $dbh = db::connect($config);
    return db::insert( $dbh, 'calcms_user_default_studios', $entry );
}

sub update($$) {
    my $config = shift;
    my $entry  = shift;

    return unless defined $entry->{user};

    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;

    push @bind_values, $entry->{user};
    push @bind_values, $entry->{project_id};

    my $query = qq{
		update calcms_user_default_studios 
		set    $values
		where  user=? and project_id=?
	};

    my $dbh = db::connect($config);
    return db::put( $dbh, $query, \@bind_values );
}

sub delete ($$) {
    my $config = shift;
    my $entry  = shift;

    return unless defined $entry->{user};

    my $query = qq{
		delete 
		from calcms_user_default_studios
		where user=?
	};
    my $bind_values = [ $entry->{user} ];

    my $dbh = db::connect($config);
    return db::put( $dbh, $query, $bind_values );
}

sub error ($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
