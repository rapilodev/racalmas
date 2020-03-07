package user_settings;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use series_dates();

# table:   calcms_user_settings
# columns: user, colors
use base 'Exporter';
our @EXPORT_OK = qw(getColors getColorCss get insert update delete get_columns defaultColors);

sub debug;

our $defaultColors = [
    {
        name  => 'color_event',
        css   => '#content .event',
        color => '#c5e1a5'
    },
    {
        name  => 'color_draft',
        css   => '#content .draft',
        color => '#eeeeee',
    },
    {
        name  => 'color_schedule',
        css   => '#content .schedule',
        color => '#dde4e6',
    },
    {
        name  => 'color_published',
        css   => '#content .event.published',
        color => '#a5d6a7',
    },
    {
        name  => 'color_no_series',
        css   => '#content .event.no_series',
        color => '#fff59d',
    },
    {
        name  => 'color_marked',
        css   => '#content .event.marked',
        color => '#81d4fa',
    },
    {
        name  => 'color_event_error',
        css   => '#content.conflicts .event.error',
        color => '#ffab91',
    },
    {
        name  => 'color_schedule_error',
        css   => '#content.conflicts .schedule.error',
        color => '#ffcc80'
    },
    {
        name  => 'color_work',
        css   => '#content .work',
        color => '#b39ddb'
    },
    {
        name  => 'color_playout',
        css   => '#content .play',
        color => '#90caf9'
    }
];

sub getColors($$) {
    my $config     = shift;
    my $conditions = shift;

    return unless defined $conditions->{user};
    my $user = $conditions->{user};

    #get defaultColors
    my $colors   = [];
    my $colorMap = {};
    for my $defaultColor (@$defaultColors) {
        my $color = {
            name  => $defaultColor->{name},
            css   => $defaultColor->{css},
            color => $defaultColor->{color},
        };
        push @$colors, $color;
        $colorMap->{ $color->{css} } = $color;
    }

    my $settings = user_settings::get( $config, { user => $user } );
    $settings->{colors} |= '';

    #overwrite colors from user settings
    for my $line ( split( /\n+/, $settings->{colors} ) ) {
        my ( $key, $value ) = split( /\=/, $line );
        $key =~ s/^\s+//;
        $key =~ s/\s+$//;
        $value =~ s/^\s+//;
        $value =~ s/\s+$//;
        $colorMap->{$key}->{color} = $value if ( $key ne '' ) && ( $value ne '' ) && ( defined $colorMap->{$key} );
    }
    return $colors;
}

sub getColorCss ($$) {
    my $config     = shift;
    my $conditions = shift;
    return unless defined $conditions->{user};

    my $shift = 20;
    my $limit = 220;

    my $colors = getColors( $config, $conditions );
    my $style = "<style>\n";
    for my $color (@$colors) {
        $style .= $color->{css} . "{\n\tbackground-color:" . $color->{color} . ";\n}\n";
        my $c = $color->{color};
        if ( $c =~ /#([a-fA-F0-9][a-fA-F0-9])([a-fA-F0-9][a-fA-F0-9])([a-fA-F0-9][a-fA-F0-9])/ ) {
            my $r = hex($1);
            my $g = hex($2);
            my $b = hex($3);
            if ( $r > $limit ) { $r -= $shift; }
            else               { $r += $shift; }
            if ( $g > $limit ) { $g -= $shift; }
            else               { $g += $shift; }
            if ( $b > $limit ) { $b -= $shift; }
            else               { $b += $shift; }
            $c = sprintf( "#%x%x%x", $r, $g, $b );
            $style .= $color->{css} . ":hover{\n\tbackground-color:" . $c . ";\n}\n";
        }
    }
    $style .= "</style>\n";
    return $style;
}

sub get_columns($) {
    my $config = shift;

    my $dbh = db::connect($config);
    return db::get_columns_hash( $dbh, 'calcms_user_settings' );
}

sub get ($$) {
    my $config    = shift;
    my $condition = shift;

    my $dbh = db::connect($config);

    my @conditions  = ();
    my @bind_values = ();

    if ( ( defined $condition->{user} ) && ( $condition->{user} ne '' ) ) {
        push @conditions,  'user=?';
        push @bind_values, $condition->{user};
    }

    my $conditions = '';
    $conditions = " where " . join( " and ", @conditions ) if ( @conditions > 0 );

    my $query = qq{
		select *
		from   calcms_user_settings
		$conditions
	};

    my $entries = db::get( $dbh, $query, \@bind_values );
    return $entries->[0] || undef;
}

sub insert ($$) {
    my $config = shift;
    my $entry  = shift;

    return unless defined $entry->{user};
   
    my $dbh = db::connect($config);
    return db::insert( $dbh, 'calcms_user_settings', $entry );
}

sub update($$) {
    my $config = shift;
    my $entry  = shift;

    return unless ( defined $entry->{user} );

    my $dbh         = db::connect($config);
    my @keys        = sort keys %$entry;
    my $values      = join( ",", map { $_ . '=?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;
    push @bind_values, $entry->{user};

    my $query = qq{
		update calcms_user_settings 
		set    $values
		where  user=?
	};

    db::put( $dbh, $query, \@bind_values );
    print "done\n";
}

sub delete ($$) {
    my $config = shift;
    my $entry  = shift;

    return unless ( defined $entry->{user} );

    my $dbh = db::connect($config);

    my $query = qq{
		delete 
		from calcms_user_settings 
		where user=?
	};
    my $bind_values = [ $entry->{user} ];

    db::put( $dbh, $query, $bind_values );
}

sub error ($) {
    my $msg = shift;
    print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
