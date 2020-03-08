package entry;

use warnings;
use strict;

sub from_valid($$) {
    my ( $params, $attrs ) = @_;
    return { map { defined $params->{$_} ? { $_ => $params->{$_} } : () } @$attrs };
}

sub set_numbers($$$) {
    my ( $entry, $params, $fields ) = @_;
    for my $field (@$fields) {
        next unless defined $params->{$field};
        if ( $params->{$field} =~ /([\-\d]+)/ ){
            $entry->{$field} = $1;
        }
    }
}


sub set_strings($$$) {
    my ( $entry, $params, $attrs ) = @_;
    for my $field (@$attrs) {
        next unless defined $params->{$field};
        $entry->{$field} = $params->{$field};
        $entry->{$field} =~ s/^\s+//g;
        $entry->{$field} =~ s/\s+$//g;
    }
}

sub element_of($$) {
    my ( $value, $attrs ) = @_;
    return { map { $_ => $_ } @$attrs }->{$value};
}

# do not delete last line
1;
