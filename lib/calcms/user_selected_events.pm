package user_selected_events;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Exception::Class (
    'ParamError',
);

# table:   calcms_user_selected_events
# columns:  user, project_id, studio_id, series_id, <- selection
#           project_studio_filter, series_filter    <- optional filter params
#           selected_project, selected_studio, selected_series, selected_event <-result

sub get_columns($) {
    my ($config) = @_;

    my $dbh  = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_user_selected_events' );
}

sub get ($$) {
    my ($config, $condition) = @_;

    my @conditions  = ();
    my @bind_values = ();

    for ('user', 'project_id', 'studio_id', 'series_id', 'selected_event') {
        ParamError->throw(error => "user_selected_event:get: missing $_") unless defined $condition->{$_}
    };

    for my $field ('user', 'project_id', 'studio_id', 'series_id',
        'filter_project_studio', 'filter_series'
    ){
        if ( ( defined $condition->{$field} ) && ( $condition->{$field} ne '' ) ) {
            push @conditions,  $field.'=?';
            push @bind_values, $condition->{$field};
        }
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if scalar(@conditions) > 0;

    my $query = qq{
		select *
		from   calcms_user_selected_events
		$conditions
	};

    my $dbh = db::connect($config);
    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries->[0] || undef;
}

sub insert ($$) {
    my ($config, $entry) = @_;

    for ('user', 'project_id', 'studio_id', 'series_id', 'selected_event') {
        ParamError->throw("missing $_") unless defined $entry->{$_}
    };

    my $dbh = db::connect($config);
    return db::insert( $dbh, 'calcms_user_selected_events', $entry );
}

sub update($$) {
    my ($config, $entry) = @_;

    my $fields = [ 
        'user', 'project_id', 'studio_id', 'series_id', 
        'filter_project_studio', 'filter_series' 
    ];
    for (@$fields) {
        ParamError->throw("missing $_") unless defined $entry->{$_}
    };

    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } ( @keys, @$fields );
    my $conditions  = join (' and ', map { $_.'=?' } @$fields );

    my $query = qq{
		update calcms_user_selected_events 
		set    $values
		where  $conditions
	};

    print STDERR "update".Dumper($query ).Dumper(\@bind_values);
    my $dbh = db::connect($config);
    return db::put( $dbh, $query, \@bind_values );
}

sub delete ($$) {
    my ($config, $entry) = @_;

    for ('user', 'project_id', 'studio_id', 'series_id') {
        ParamError->throw("missing $_") unless defined $entry->{$_}
    };

    my $query = qq{
		delete 
		from calcms_user_selected_events
		where user=? and project_id=? and studio_id=? and series_id=?
	};
    my $bind_values = [ $entry->{user}, $entry->{project_id}, $entry->{studio_id}, $entry->{series_id} ];

    my $dbh = db::connect($config);
    return db::put( $dbh, $query, $bind_values );
}

#do not delete last line!
1;
