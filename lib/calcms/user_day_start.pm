package user_day_start;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
#use Try::Tiny qw(try catch finally);
use Exception::Class (
    'ParamError',
);
use Scalar::Util qw( blessed );

# table:   calcms_user_day_start
# columns:  user, project_id, studio_id, series_id, day_start

sub get_columns($) {
    my ($config) = @_;

    my $dbh  = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_user_day_start' );
}

sub get ($$) {
    my ($config, $condition) = @_;

    my @conditions  = ();
    my @bind_values = ();

    for ('user', 'project_id', 'studio_id') {
        ParamError->throw("missing $_") unless defined $condition->{$_}
    };

    for my $field ('user', 'project_id', 'studio_id'){
        if ( ( defined $condition->{$field} ) && ( $condition->{$field} ne '' ) ) {
            push @conditions,  $field.'=?';
            push @bind_values, $condition->{$field};
        }
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if scalar(@conditions) > 0;

    my $query = qq{
		select *
		from   calcms_user_day_start
		$conditions
	};

    my $dbh = db::connect($config);
    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries->[0] || undef;
}

sub insert_or_update($$){
    my ($config, $entry) = @_;
    if ( get($config, $entry) ){
        update ($config, $entry);
    } else {
        insert ($config, $entry);
    }
}

sub insert ($$) {
    my ($config, $entry) = @_;

    for ('user', 'project_id', 'studio_id', 'day_start') {
        ParamError->throw("missing $_") unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);
    return db::insert( $dbh, 'calcms_user_day_start', $entry );
}

sub update($$) {
    my ($config, $entry) = @_;

    my $fields = [ 'user', 'project_id', 'studio_id' ];
    for (@$fields){
        ParamError->throw("missing $_") unless defined $entry->{$_}
    };

    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } ( @keys, @$fields );
    my $conditions  = join (' and ', map { $_.'=?' } @$fields );

    my $query = qq{
		update calcms_user_day_start 
		set    $values
		where  $conditions
	};

    my $dbh = db::connect($config);
    return db::put( $dbh, $query, \@bind_values );
}

sub delete ($$) {
    my ($config, $entry) = @_;

    for ('user', 'project_id', 'studio_id') {
        ParamError->throw("missing $_") unless defined $entry->{$_}
    };

    my $query = qq{
		delete 
		from calcms_user_day_start
		where user=? and project_id=? and studio_id=?
	};
    my $bind_values = [ $entry->{user}, $entry->{project_id}, $entry->{studio_id} ];

    my $dbh = db::connect($config);
    return db::put( $dbh, $query, $bind_values );
}

sub error ($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
