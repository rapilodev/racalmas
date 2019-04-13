package config;

use strict;
use warnings;
no warnings 'redefine';

use FindBin();
use Config::General();

use base 'Exporter';
our @EXPORT_OK = qw(get set);

my $config = undef;

sub set($) {
    my $value = shift;
    $config = $value;
    return;
}

sub get($) {
    my $filename = shift;

    return $config if ( defined $config ) && ( $config->{cache}->{cache_config} == 1 );

    my $configuration = Config::General->new(
        -ConfigFile => $filename,
        -UTF8       => 1
    );
    config::set( $configuration->{DefaultConfig}->{config} );
    return $config;
}

sub getFromScriptLocation() {
    FindBin::again();
    my $configFile = $FindBin::Bin . '/config/config.cgi';
    return config::get($configFile);
}

#do not delete last line
1;
