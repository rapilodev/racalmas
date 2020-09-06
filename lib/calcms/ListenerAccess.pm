package ListenerAccess;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use Time::Local();

use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::Const -compile => qw(FORBIDDEN OK);

sub handler {
    my $r = shift;

    my $path = $ENV{LISTENER_DIR} . File::Basename::basename( $r->uri() );
    my $file = readlink $path;
    unless ($file) {
        print STDERR "cannot read link for $path\n";
        return Apache2::Const::FORBIDDEN;
    }

    $file = File::Basename::basename($file);
    unless ( $file =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d)_(\d\d)/ ) {
        printf STDERR "access: cannot find datetime pattern in file:'%s'\n", $file;
        return Apache2::Const::FORBIDDEN;
    }
    
    my $start_since = time() - Time::Local::timelocal( 0, $5, $4, $3, $2 - 1, $1 );
    $start_since /= 24 * 60 * 60;
    if ( $start_since > 7 ) {
        printf STDERR "access: file is not availabe anymore:'%s'\n", $file;
        return Apache2::Const::FORBIDDEN;
    }
    return Apache2::Const::OK;
}
1;

__END__

# limit access up to 7 days after datetime given by filename.
# The filename links to a file starting with "yyyy-mm-dd hh_mm" in file name.
# 
# <Directory ${archive_dir}/${domain}>
#        PerlSetEnv PERL5LIB ${perl_lib}/calcms
#        PerlSetEnv LISTENER_DIR ${archive_dir}/${domain}/
#        PerlAccessHandler ListenerAccess
# </Directory>
#