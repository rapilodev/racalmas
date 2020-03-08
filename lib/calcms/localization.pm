package localization;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use uac();
use user_settings();

#use base 'Exporter';
our @EXPORT_OK = qw(get getJavascript);

sub debug;

# get localisation
#    file     : po file
#    language : get for selected language
#    user     : get from user settings
#    loc      : add to existing localization, optional
sub get($$) {
    my $config  = shift;
    my $options = shift;

    #get pot file
    unless ( defined $options->{file} ) {
        print STDERR "missing po file\n";
        return $options->{loc} || {};
    }

    my $language = undef;

    #get language from options
    $language = $options->{language} if defined $options->{language};

    #get language from user
    if ( ( !( defined $language ) ) && ( defined $options->{user} ) ) {
        my $user_settings = user_settings::get( $config, { user => $options->{user} } );
        $language = $user_settings->{language};
    }
    $language = 'en' unless defined $language;
    $language = 'en' unless $language eq 'de';

    my $loc = {};
    $loc = $options->{loc} if defined $options->{loc};

    my $files = $options->{file};
    $files =~ s/[^a-zA-Z\,\_\-]//g;

    #get all comma separated po files
    for my $file ( split /\,/, $files ) {

        #read default language
        #my $po_file=$config->{locations}->{admin_pot_dir}.'/en/'.$file.'.po';
        #$loc=read_po_file($po_file, $loc);

        #read selected language
        #if($language ne 'en'){
        my $po_file = $config->{locations}->{admin_pot_dir} . '/' . $language . '/' . $file . '.po';
        $loc = read_po_file( $po_file, $loc );

        #}
    }
    return $loc;
}

sub read_po_file($$) {
    my $po_file = shift;
    my $loc     = shift;

    unless ( -e $po_file ) {
        print STDERR "po file $po_file does not exist\n";
        return $loc;
    }
    unless ( -r $po_file ) {
        print STDERR "cannot read po file $po_file\n";
        return $loc;
    }

    my $key = '';
    open my $file, '<:encoding(UTF-8)', $po_file;
    return $loc unless defined $file;
    while (<$file>) {
        my $line = $_;

        #print STDERR $line;
        if ( $line =~ /^msgid\s*\"(.*)\"\s*$/ ) {
            $key = $1;
            $key =~ s/\'//g;
            $key =~ s/\"//g;
        }
        if ( $line =~ /^msgstr\s*\"(.*)\"\s*$/ ) {
            my $val = $1;
            $val =~ s/\'//g;
            $val =~ s/\"//g;
            $loc->{$key} = $val;
        }
    }
    close $file;
    return $loc;
}

sub getJavascript ($){
    my $loc = shift;

    my $out = '<script>';
    $out .= "var loc={};\n";
    for my $key ( sort keys %$loc ) {
        $out .= qq{loc['$key']='$loc->{$key}';} . "\n";
    }
    $out .= "</script>\n";
    return $out;
}

1;
