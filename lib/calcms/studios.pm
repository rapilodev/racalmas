package studios;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Exception::Class (
    'ParamError',
    'StudioError',
);

use images();
our @EXPORT_OK = qw(get_columns get get_by_id insert update delete check check_studio);

sub get_columns($) {
    my ($config) = @_;

    my $dbh = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_studios' );
}
sub get($;$) {
    my ($config, $condition) = @_;
    $condition ||= {};

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{studio_id} ) && ( $condition->{studio_id} ne '' ) ) {
        push @conditions,  's.id=?';
        push @bind_values, $condition->{studio_id};
    }

    if ( ( defined $condition->{name} ) && ( $condition->{name} ne '' ) ) {
        push @conditions,  's.name=?';
        push @bind_values, $condition->{name};
    }

    if ( ( defined $condition->{location} ) && ( $condition->{location} ne '' ) ) {
        push @conditions,  's.location=?';
        push @bind_values, $condition->{location};
    }

    my $limit = '';
    if ( ( defined $condition->{limit} ) && ( $condition->{limit} ne '' ) ) {
        $limit = 'limit ' . $condition->{limit};
    }

    my $query = '';
    unless ( ( defined $condition->{project_id} ) && ( $condition->{project_id} ne '' ) ) {
        my $conditions = '';
        $conditions = " where " . join( " and ", @conditions ) if ( scalar @conditions > 0 );
        $query = qq{
		    select	*
		    from 	calcms_studios s
		    $conditions
		    $limit
	    };
    } else {
        push @conditions,  's.id=ps.studio_id';
        push @conditions,  'ps.project_id=?';
        push @bind_values, $condition->{project_id};

        my $conditions = " where " . join( " and ", @conditions );
        $query = qq{
		    select	*
		    from 	calcms_studios s, calcms_project_studios ps
		    $conditions
		    $limit
	    };
    }
    my $dbh = db::connect($config);
    my $studios = db::get( $dbh, $query, \@bind_values );
    return $studios;
}

sub getImageById($$) {
    my ($config, $conditions) = @_;

    for ('project_id', 'studio_id') {
        ParamError->throw("getImageById: missing $_") unless defined $conditions->{$_}
    };
    my $studios = studios::get( $config, $conditions );
    return undef if scalar(@$studios) != 1;
    return $studios->[0]->{image};
}

sub insert ($$) {
    my ($config, $entry) = @_;

    $entry->{created_at}  = time::time_to_datetime( time() );
    $entry->{modified_at} = time::time_to_datetime( time() );
    $entry->{image}       = images::normalizeName( $entry->{image} ) if defined $entry->{image};

    my $dbh = db::connect($config);
    my $id = db::insert( $dbh, 'calcms_studios', $entry );
    return $id;
}

sub update ($$) {
    my ($config, $studio) = @_;

    $studio->{modified_at} = time::time_to_datetime( time() );

    my $columns = get_columns($config);
    my $entry   = {};
    for my $column ( keys %$columns ) {
        $entry->{$column} = $studio->{$column} if defined $studio->{$column};
    }
    $entry->{image} = images::normalizeName( $entry->{image} ) if defined $entry->{image};

    my @keys = sort keys %$entry;
    my $values = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{id};

    my $query = qq{
		update calcms_studios 
		set $values
		where id=?
	};

    my $dbh = db::connect($config);
    db::put( $dbh, $query, \@bind_values );
}

sub delete ($$) {
    my ($config, $studio) = @_;
    my $dbh = db::connect($config);
    db::put( $dbh, 'delete from calcms_studios where id=?', [ $studio->{id} ] );
}

#TODO rename to check
sub check_studio($$) {
    my ($config, $options) = @_;
    return check( $config, $options );
}

sub check ($$) {
    my ($config, $options) = @_;
    ParamError->throw(error => "missing studio_id") unless defined $options->{studio_id};
    ParamError->throw(error => "Please select a studio") if ( $options->{studio_id} eq '-1' );
    ParamError->throw(error => "Please select a studio") if ( $options->{studio_id} eq '' );
    my $studios = studios::get( $config, { studio_id => $options->{studio_id} } );
    StudioError->throw(error => "unknown studio") unless defined $studios;
    StudioError->throw(error => "unknown studio") unless scalar @$studios == 1;
    return 1;
}

#do not delete last line!
1;
