package entry;

use warnings;
use strict;

sub from_valid($$) {
    my ($params, $attrs) = @_;
    return { map { defined $params->{$_} ? { $_ => $params->{$_} } :() } @$attrs };
}

sub set_numbers($$$) {
    my ($entry, $params, $fields) = @_;
    for my $field(@$fields) {
        my $value = $params->{$field};
        next unless defined $value;
        if ($value =~ /([\-\d]+)/){
            $entry->{$field} = $1;
        }
    }
}

sub set_bools($$$) {
    my ($entry, $params, $fields) = @_;
    for my $field(@$fields) {
        my $value = $params->{$field};
        next unless defined $value;
        if ($value=~/([01])/){
            $entry->{$field} = $1;
        }
    }
}

sub set_strings($$$) {
    my ($entry, $params, $attrs) = @_;
    for my $field(@$attrs) {
        my $value = $params->{$field};
        next unless defined $value;
        $entry->{$field} = $value;
        $entry->{$field} =~ s/^\s+//g;
        $entry->{$field} =~ s/\s+$//g;
    }
}

sub element_of($$) {
    my ($value, $attrs) = @_;
    return unless $value;
    return { map { $_ => $_ } @$attrs }->{$value} //'';
}

# do not delete last line
1;
