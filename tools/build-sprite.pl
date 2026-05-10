#!/usr/bin/env perl
use strict;
use warnings;
use File::Find;
use File::Basename;
use XML::LibXML;

my $base_dir   = "../website/agenda/planung/icons/";
my $output = "$base_dir/sprite.svg";
my $dom = XML::LibXML::Document->new('1.0', 'UTF-8');
my $svg = $dom->createElement('svg');

$svg->setAttribute('xmlns', 'http://www.w3.org/2000/svg');
$svg->setAttribute('style', 'display:none');
$dom->setDocumentElement($svg);

find(
    {
        wanted => sub {
            return unless /\.svg$/;
            return if /sprite.svg/;
            process_svg($_);
        },
        no_chdir => 1
    },
    $base_dir
);

open my $fh, '>', $output or die "Cannot write $output: $!";
print $fh $dom->toString(1);
close $fh;

print "✔ Sprite written to $output\n";

# -----------------------

sub process_svg {
    my ($file) = @_;

    my $parser = XML::LibXML->new;
    my $doc    = eval { $parser->parse_file($file) } or return;

    my $root = $doc->documentElement;
    return unless $root->nodeName eq 'svg';

    my ($name) = fileparse($file, '.svg');
    my $symbol = $dom->createElement('symbol');
    $symbol->setAttribute('id', "icon-$name");
    $symbol->setAttribute('viewBox', $root->getAttribute('viewBox') || '0 0 24 24');
    $symbol->setAttribute('width', "1.3em");
    $symbol->setAttribute('height', "1.3em");
    $symbol->setAttribute('fill', 'currentColor');

    for my $child ($root->childNodes) {
        next if $child->nodeType == XML::LibXML::XML_COMMENT_NODE;
        $symbol->appendChild($child->cloneNode(1));
    }

    $svg->appendChild($symbol);
}

