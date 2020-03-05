package studios;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use images();

use base 'Exporter';
our @EXPORT_OK = qw(get_columns get get_by_id insert update delete check check_studio);

sub debug;

sub get_columns($) {
    my $config = shift;

    my $dbh     = db::connect($config);
    my $cols    = db::get_columns( $dbh, 'calcms_studios' );
    return { map { $_ => undef } @$cols };
}
sub get($;$) {
    my $config = shift;
    my $condition = shift || {};

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
    my $config     = shift;
    my $conditions = shift;

    return undef unless defined $conditions->{project_id};
    return undef unless defined $conditions->{studio_id};
    my $studios = studios::get( $config, $conditions );
    return undef if scalar(@$studios) != 1;
    return $studios->[0]->{image};
}

sub insert ($$) {
    my $config = shift;
    my $entry  = shift;

    $entry->{created_at}  = time::time_to_datetime( time() );
    $entry->{modified_at} = time::time_to_datetime( time() );
    $entry->{image}       = images::normalizeName( $entry->{image} ) if defined $entry->{image};

    my $dbh = db::connect($config);
    my $id = db::insert( $dbh, 'calcms_studios', $entry );
    return $id;
}

sub update ($$) {
    my $config = shift;
    my $studio = shift;

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
    my $config = shift;
    my $studio = shift;

    my $dbh = db::connect($config);
    db::put( $dbh, 'delete from calcms_studios where id=?', [ $studio->{id} ] );
}

#TODO rename to check
sub check_studio($$) {
    my $config  = shift;
    my $options = shift;
    return check( $config, $options );
}

sub check ($$) {
    my $config  = shift;
    my $options = shift;
    return "missing studio_id" unless defined $options->{studio_id};
    return "Please select a studio" if ( $options->{studio_id} eq '-1' );
    return "Please select a studio" if ( $options->{studio_id} eq '' );
    my $studios = studios::get( $config, { studio_id => $options->{studio_id} } );
    return "Sorry. unknown studio" unless defined $studios;
    return "Sorry. unknown studio" unless scalar @$studios == 1;
    return 1;
}

sub error {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;

