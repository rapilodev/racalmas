package Common;
use warnings;
use strict;

use Fcntl ':flock';

use base 'Exporter';
our @EXPORT_OK = ( 'info', 'error' );

sub checkSingleInstance() {
    open my $self, '<', $0 or die "Couldn't open self: $!";
    flock $self, LOCK_EX | LOCK_NB or die "This script $0 is already running";
}

sub loadFile($) {
    my $filename = shift;

    my $content = '';
    open my $file, '<', $filename || die("cannot load $filename");
    while (<$file>) {
        $content .= $_;
    }
    close $file;
    return $content;
}

sub saveFile($$) {
    my $filename = shift;
    my $content  = shift;
    open my $file, ">:utf8", $filename || die("cannot write $filename");
    print $file $content;
    close $file;

}

sub getModifiedAt {
    my $file  = shift;
    my @stats = stat $file;
    return 0 if scalar @stats == 0;
    my $modifiedAt = $stats[9];
    return $modifiedAt;
}

sub execute($) {
    my $command = shift;
    print "EXEC:\t$command\n";
    my $result   = `$command`;
    my $exitCode = ( $? >> 8 );
    print "ERROR! exitCode=$?\n" if $exitCode > 0;
    return ( $exitCode, $result );
}

my $debug = 0;

sub debug($$) {
    my $level   = shift;
    my $message = shift;
    print $message. "\n" if $debug > $level;
}

sub error ($) {
    print "\nERROR: $_[0]\nsee $0 --help for help";
    exit 1;
}

sub info ($) {
    my $message = shift;
    if ( $message =~ /^\n/ ) {
        $message =~ s/^\n//g;
        print "\n";
    }
    print "INFO:\t$message\n";
}

return 1;
