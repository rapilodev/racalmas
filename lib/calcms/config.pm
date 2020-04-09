package config;

use strict;
use warnings;
no warnings 'redefine';

use FindBin();

#use base 'Exporter';
our @EXPORT_OK = qw(get set);

my $config = undef;


sub get($) {
    my $filename = shift;
    return read_config($filename);
}

sub getFromScriptLocation() {
    FindBin::again();
    my $configFile = $FindBin::Bin . '/config/config.cgi';
    return config::get($configFile);
}

sub read_config {
    my $file = $_[0];

    my $vars  = {};
    my @stack = ();
    my $entry = {};

    open my $fh, '<', $file or die;
    while ( my $line = <$fh> ) {
        chomp $line;

        # comments
        $line =~ s/\#.*//;

        # trim
        $line =~ s/(^\s+)|(\s+)$//;
        next unless length $line;
        if ( $line =~ /^<\/([^>]+)>$/ ) {

            # close tag
            my $name   = $1;
            my $sentry = pop @stack;
            die unless $sentry->{name} eq $name;
            $entry = $sentry->{value};
        } elsif ( $line =~ /^<([^>]+)>$/ ) {

            # open tag
            my $name = $1;
            $entry->{$name} = {};
            push @stack, { name => $name, value => $entry };
            $entry = $entry->{$name};
        } elsif ( $line =~ /^Define\s/ ) {
            # define vars
            my ( $attr, $key, $value ) = split /\s+/, $line, 3;
            for my $var ( keys %$vars ) {
                $value =~ s/\$\{$var\}/$vars->{$var}/;
            }
            $vars->{$key} = $value;
        } else {
            # attributes
            my ( $key, $value ) = split /\s+/, $line, 2;
            for my $var ( keys %$vars ) {
                $value =~ s/\$\{$var\}/$vars->{$var}/;
            }
            $entry->{$key} = $value;
        }
    }
    close $fh or die;
    return $entry->{config};
}

#do not delete last line
1;
