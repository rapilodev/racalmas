package config;

use strict;
use warnings;
no warnings 'redefine';

use FindBin();
our @EXPORT_OK = qw(get set parse_size);

my $config = undef;
sub get($) {
    my ($filename) = @_;
    return read_config($filename);
}

sub getFromScriptLocation() {
    FindBin::again();
    my $configFile = $FindBin::Bin . '/config/config.cgi';
    return config::get($configFile);
}

sub parse_size {
    my ($size) = @_;
    my %units = (B => 1, KB => 1024, MB => 1024**2, GB => 1024**3);
    $size =~ /^(\d+)\s*([kmgtp]?b)$/i or die "Invalid size format: $size\n";
    return $1 * $units{uc($2)};
}

sub read_config {
    my ($file) = @_;

    my $vars  = {};
    my @stack = ();
    my $entry = {};

    open my $fh, '<:encoding(UTF-8)', $file or die;
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
