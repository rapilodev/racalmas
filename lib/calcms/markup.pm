package markup;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Text::WikiCreole();
use HTML::Parse();
use HTML::FormatText();
use Encode();
use HTML::Entities();
use Text::Markdown();

use log();

#use base 'Exporter';
our @EXPORT_OK =
  qw(fix_line_ends html_to_creole creole_to_html creole_to_plain plain_to_ical ical_to_plain ical_to_xml html_to_plain fix_utf8 uri_encode compress base26);

sub fix_line_ends ($) {
    my $s = shift;
    $s =~ s/\r?\n|\r/\n/g;
    return $s;
}

# convert 1..26 to a..z, 27 to aa, inspired by ConvertAA
sub base26($) {
    my $num = shift;
    return '' if $num <= 0;

    my $s = "";
    while ($num) {
        $s   = chr( --$num % 26 + ord "a" ) . $s;
        $num = int $num / 26;
    }

    return $s;
}

sub html_to_creole($) {
    my $s = shift;

    #remove elements
    $s =~ s/\<\!\-\-[\s\S]*?\-\-\>//gi;
    $s =~ s/<script.*?>.*?<\/script.*?>//gi;
    $s =~ s/<\/?form.*?>//gi;
    $s =~ s/<\/?select.*?>//gi;
    $s =~ s/<\/?option.*?//gi;
    $s =~ s/<\/?input.*?>//gi;
    $s =~ s/<\/?script.*?>//gi;

    #remove line breaks
    $s =~ s/[\r\n]+/ /gi;

    #formats
    $s =~ s/<img.*?src="(.*?)".*?>/{{$1\|}}/gi;
    $s =~ s/<img.*?title="(.*?)".*?>/{{$2\|$1}}/gi;
    $s =~ s/<img.*?src="(.*?)"[^>]*?title="(.*?)".*?>/{{$1\|$2}}/gi;
    $s =~ s/<img.*?title="(.*?)"[^>]*?src="(.*?)".*?>/{{$2\|$1}}/gi;
    $s =~ s/<\/?img.*?>//gi;

    #replace line breaks from images
    $s =~ s/(\{\{[^\}\n]*?)\n([^\}\n]*?\}\})/$1$2/g;
    $s =~ s/(\{\{[^\}\n]*?)\n([^\}\n]*?\}\})/$1$2/g;
    $s =~ s/(\{\{[^\}\n]*?)\n([^\}\n]*?\}\})/$1$2/g;

    $s =~ s/<i.*?>(.*?)<\/i>/\/\/$1\/\//gi;
    $s =~ s/<\/?i.*?>//gi;
    $s =~ s/<b.*?>(.*?)<\/b>/\*\*$1\*\*/gi;

    $s =~ s/<strong.*?>(.*?)<\/strong>/\*\*$1\*\*/gi;
    $s =~ s/<em.*?>(.*?)<\/em>/\/\/$1\/\//gi;
    $s =~ s/<blockquote.*?>((\W+|\w+)*?)<\/blockquote>/{{{$1}}}/gi;

    $s =~ s/<a\s+.*?href="(.*?)".*?>(.*?)(\s*)<\/a>/\[\[$1\|$2\]\]$3/gi;
    $s =~ s/<a.*?>//gi;

    #replace line breaks from links
    $s =~ s/(\[\[[^\]\n]*?)\n([^\]]*?\]\])/$1$2/g;
    $s =~ s/(\[\[[^\]\n]*?)\n([^\]]*?\]\])/$1$2/g;
    $s =~ s/(\[\[[^\]\n]*?)\n([^\]]*?\]\])/$1$2/g;

    $s =~ s/[\s]+/ /gi;

    #line elements, increase head line level to avoid breaking single = chars
    $s =~ s/\s*<h1.*?>/== /gi;
    $s =~ s/\s*<h2.*?>/=== /gi;
    $s =~ s/\s*<h3.*?>/==== /gi;
    $s =~ s/\s*<h\d.*?>/===== /gi;

    my $tree = HTML::Parse::parse_html( '<body>' . $s . '</body>' );
    my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 2000 );
    $s = $formatter->format($tree);

    $s =~ s/\</\&lt;/g;

    #fix line endings
    $s =~ s/\n[ \t]+/\n/gi;

    $s =~ s/\n{3,99}/\n\n/g;
    $s =~ s/\n*\*[\s]+/\n\* /g;

    #enter line break before headlines
    $s =~ s/(={2,99})/\n$1/g;

    #reduce head line level
    $s =~ s/=(=+)/$1/g;

    $s =~ s/^\s+//gi;
    $s =~ s/\s+$//gi;
    $s =~ s/\n{3,99}/\n\n/g;

    $s =~ s/\n/\\\\\n/g;
    $s =~ s/\\\\\n\=/\n\=/g;

    return $s;
}

sub creole_to_html ($) {
    my $s = $_[0] || '';

    $s =~ s/<a\s+.*?href="(.*?)".*?>(.*?)(\s*)<\/a>/\[\[$1\|$2\]\]$3/gi;
    $s =~ s/<a.*?>//gi;

    $s =~ s/(\[\[[^\]\n]*?)\n([^\]]*?\]\])/$1$2/g;
    $s =~ s/(\[\[[^\]\n]*?)\n([^\]]*?\]\])/$1$2/g;
    $s =~ s/(\[\[[^\]\n]*?)\n([^\]]*?\]\])/$1$2/g;
    $s =~ s/^\s+//g;
    $s =~ s/\s+$//g;

    $s = Text::WikiCreole::creole_parse($s) || '';

    #replace line breaks from images
    $s =~ s/(\{\{[^\}\n]*?)\n([^\}\n]*?\}\})/$1$2/g;
    $s =~ s/(\{\{[^\}\n]*?)\n([^\}\n]*?\}\})/$1$2/g;
    $s =~ s/(\{\{[^\}\n]*?)\n([^\}\n]*?\}\})/$1$2/g;

    #remove whitespaces and break lines at start or end of elements
    for my $elem ( 'p', 'li' ) {
        $s =~ s|<$elem>\s*<br/><br/>|<$elem>|g;
        $s =~ s|<br/><br/>\s*</$elem>|</$elem>|g;
    }

    return $s;
}

sub markdown_to_html($){
    my $text = $_[0] // '';
    print STDERR "markwon!\n";
    my $html = Text::Markdown::markdown($text);
    return $html;
}

sub creole_to_plain($) {
    my $s = shift;

    $s =~ s/\<p\>/\n/gi;
    $s =~ s/\{\{\{((\W+|\w+)+?)\}\}\}/<blockquote>$1<\/blockquote>/g;
    $s =~ s/\{\{(.+?)\|(.*?)\}\}//g;
    $s =~ s/\[\[(.+?)\|(.*?)\]\]/$2/g;
    $s =~ s/\/\/([^\/\/]*?)\/\//<em>$1<\/em> /g;
    $s =~ s/\n=== (.*?)\n/\n<h3>$1<\/h3>\n/g;
    $s =~ s/\n== (.*?)\n/\n<h2>$1<\/h2>\n/g;
    $s =~ s/\*\*(.*?)\*\*/<strong>$1<\/strong> /g;
    $s =~ s/^== (.*?)\n/<h2>$1<\/h2>\n/g;
    $s =~ s/\n\* (.*?)\n/\n<li>$1<\/li>\n/g;
    $s =~ s/\n\* (.*?)\n/\n<li>$1<\/li>\n/g;
    $s =~ s/\n\- (.*?)\n/\n<lo>$1<\/lo>\n/g;
    $s =~ s/\n\- (.*?)\n/\n<lo>$1<\/lo>\n/g;
    $s =~ s/\n\n/\n<p>/gi;
    $s =~ s/\n/\n<br\/>/gi;
    return $s;
}

sub html_to_plain ($) {
    my $s = shift;
    return '' unless defined $s;
    my $tree = HTML::Parse::parse_html( '<body>' . $s . '</body>' );
    my $formatter = HTML::FormatText->new( leftmargin => 0, rightmargin => 2000 );
    $s = $formatter->format($tree);
    return $s;
}

sub ical_to_plain ($) {
    return '' unless defined( $_[0] );
    $_[0] =~ s/\\n/\n/gi;
    $_[0] =~ s/   /\t/gi;
    $_[0] =~ s/\\\./\./gi;
    $_[0] =~ s/\\\,/\,/gi;
    $_[0] =~ s/\\\\/\\/gi;
    return $_[0];
}

sub plain_to_ical ($) {
    return '' unless defined( $_[0] );

    #remove images + links
    $_[0] =~ s/\[\[.+?\|(.+?)\]\]/$1/g;
    $_[0] =~ s/\{\{.+?\}\}//g;
    $_[0] =~ s/^\s+//g;
    $_[0] =~ s/\\/\\\\/gi;
    $_[0] =~ s/\,/\\\,/gi;

    #	$_[0]=~s/\./\\\./gi;
    $_[0] =~ s/[\r\n]/\\n/gi;
    $_[0] =~ s/\t/   /gi;
    return $_[0];
}

sub plain_to_xml($) {
    return '' unless defined( $_[0] );
    $_[0] =~ s/\n\={1,6} (.*?)\s+/\n\[\[$1\]\]\n/gi;

    #remove images + links
    $_[0] =~ s/\[\[.+?\|(.+?)\]\]/$1/g;
    $_[0] =~ s/\{\{.+?\}\}//g;
    return encode_xml_element( $_[0] );
}

sub fix_utf8($) {
    $_[0] = Encode::decode( 'cp1252', $_[0] );
    return $_[0];
}

sub uri_encode ($) {
    $_[0] =~ s/([^a-zA-Z0-9_\.\-])/sprintf("%%%02lx",ord($1))/esg;
    return $_[0];
}

sub compress ($) {
    my $header = '';

    if ( $_[0] =~ /(Content\-type\:[^\n]+[\n]+)/ ) {
        $header = $1;
    }
    my $start = index( $_[0], $header );
    return if ( $start < 0 );

    my $header_length = length($header);
    $header = substr( $_[0], 0, $start + $header_length );

    my $content = substr( $_[0], $start + $header_length );

    #remove multiple line breaks
    $content =~ s/[\r\n]+[\s]*[\r\n]+/\n/g;

    #remove leading whitespaces
    $content =~ s/[\r\n]+[\s]+/\n/g;

    #remove tailing whitespaces
    $content =~ s/[\t ]*[\r\n]+/\n/g;

    #remove whitespaces inside tags
    $content =~ s/([\n]\<[^\n]+)[\r\n]+/$1 /g;
    $content =~ s/\"\s+\>/\"\>/g;

    #get closing tags closer
    $content =~ s/[\r\n]+(\<[\/\!])/$1/g;
    $content =~ s/(\>)[\r\n]+([^\<])/$1$2/g;

    #remove leading whitespaces
    #$content=~s/[\r\n]+([\d\S])/$1/g;

    #remove empty lines
    $content =~ s/[\n\r]+/\n/g;

    #remove whitespaces between tags
    $content =~ s/\>[\t ]+\<(^\/T)/\>\<$1/g;

    #multiple whitespaces
    $content =~ s/[\t ]+/ /g;

    #restore content-type line break
    $_[0] = $header . $content;

    #$_[0]=~s/HTTP_CONTENT_TYPE/\n\n/;
    #	return $_[0];
}

#from XML::RSS.pm
my %entity = (
    nbsp   => "&#160;",
    iexcl  => "&#161;",
    cent   => "&#162;",
    pound  => "&#163;",
    curren => "&#164;",
    yen    => "&#165;",
    brvbar => "&#166;",
    sect   => "&#167;",
    uml    => "&#168;",
    copy   => "&#169;",
    ordf   => "&#170;",
    laquo  => "&#171;",
    not    => "&#172;",
    shy    => "&#173;",
    reg    => "&#174;",
    macr   => "&#175;",
    deg    => "&#176;",
    plusmn => "&#177;",
    sup2   => "&#178;",
    sup3   => "&#179;",
    acute  => "&#180;",
    micro  => "&#181;",
    para   => "&#182;",
    middot => "&#183;",
    cedil  => "&#184;",
    sup1   => "&#185;",
    ordm   => "&#186;",
    raquo  => "&#187;",
    frac14 => "&#188;",
    frac12 => "&#189;",
    frac34 => "&#190;",
    iquest => "&#191;",
    Agrave => "&#192;",
    Aacute => "&#193;",
    Acirc  => "&#194;",
    Atilde => "&#195;",
    Auml   => "&#196;",
    Aring  => "&#197;",
    AElig  => "&#198;",
    Ccedil => "&#199;",
    Egrave => "&#200;",
    Eacute => "&#201;",
    Ecirc  => "&#202;",
    Euml   => "&#203;",
    Igrave => "&#204;",
    Iacute => "&#205;",
    Icirc  => "&#206;",
    Iuml   => "&#207;",
    ETH    => "&#208;",
    Ntilde => "&#209;",
    Ograve => "&#210;",
    Oacute => "&#211;",
    Ocirc  => "&#212;",
    Otilde => "&#213;",
    Ouml   => "&#214;",
    times  => "&#215;",
    Oslash => "&#216;",
    Ugrave => "&#217;",
    Uacute => "&#218;",
    Ucirc  => "&#219;",
    Uuml   => "&#220;",
    Yacute => "&#221;",
    THORN  => "&#222;",
    szlig  => "&#223;",
    agrave => "&#224;",
    aacute => "&#225;",
    acirc  => "&#226;",
    atilde => "&#227;",
    auml   => "&#228;",
    aring  => "&#229;",
    aelig  => "&#230;",
    ccedil => "&#231;",
    egrave => "&#232;",
    eacute => "&#233;",
    ecirc  => "&#234;",
    euml   => "&#235;",
    igrave => "&#236;",
    iacute => "&#237;",
    icirc  => "&#238;",
    iuml   => "&#239;",
    eth    => "&#240;",
    ntilde => "&#241;",
    ograve => "&#242;",
    oacute => "&#243;",
    ocirc  => "&#244;",
    otilde => "&#245;",
    ouml   => "&#246;",
    divide => "&#247;",
    oslash => "&#248;",
    ugrave => "&#249;",
    uacute => "&#250;",
    ucirc  => "&#251;",
    uuml   => "&#252;",
    yacute => "&#253;",
    thorn  => "&#254;",
    yuml   => "&#255;",
);

my $entities = join( '|', keys %entity );

sub encode_xml_element($) {
    my $text = shift;

    my $encoded_text = '';

    while ( $text =~ s/(.*?)(\<\!\[CDATA\[.*?\]\]\>)//s ) {
        $encoded_text .= encode_xml_element_text($1) . $2;
    }
    $encoded_text .= encode_xml_element_text($text);

    return $encoded_text;
}

sub encode_xml_element_text ($) {
    my $text = shift;

    $text =~ s/&(?!(#[0-9]+|#x[0-9a-fA-F]+|\w+);)/&amp;/g;
    $text =~ s/&($entities);/$entity{$1}/g;
    $text =~ s/\</\&lt\;/g;
    $text =~ s/\>/\&gt\;/g;

    return $text;
}

sub escapeHtml($) {
    my $s = shift;
    return HTML::Entities::encode_entities( $s, q{&<>"'} );
}

#do not delete last line!
1;
