package config;

use warnings;
use strict;

use Config::General();

use base 'Exporter';
our @EXPORT_OK = qw(get set);

my $config = undef;

sub set {
    my $value = shift;
    $config = $value;
    return;
}

sub get {
    my $filename = shift;

    return $config if defined $config;;

    my $configuration = Config::General->new(
        -ConfigFile => $filename,
        -UTF8       => 1
    );
    config::set( $configuration->{DefaultConfig}->{config} );
    return $config;
}

#do not delete last line
1;
