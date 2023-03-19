package HTML::Template::Compiled::Plugin::Hyphen;
use strict;
use warnings;

HTML::Template::Compiled->register(__PACKAGE__);

sub escape_whitespace {
    my ($s) = @_;
    $s =~ s/\s/-/g;
    $s =~ s/\-+/-/g;
    $s =~ s/\-$//g;
    $s =~ s/^\-//g;
    return $s;
}

sub register {
    my ($class) = @_;
    my %plugs = (
        escape => {
            HYPHEN => \&escape_whitespace
        },
    );
    return \%plugs;
}

return 1;
