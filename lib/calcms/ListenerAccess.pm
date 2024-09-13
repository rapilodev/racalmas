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
    my ($r) = @_;

    my $DAYS = 24 * 60 * 60;
    my $OK = Apache2::Const::OK;
    my $FORBIDDEN = Apache2::Const::FORBIDDEN;

    my $path = $ENV{LISTENER_DIR} . File::Basename::basename($r->uri());
    my $file = readlink $path;

    # granted access by temporary symlinks only
    return $FORBIDDEN unless ($file);

    # use link age for authorized downloads
    if (File::Basename::basename($path) =~ /^shared\-/) {
        my $age = time() - (lstat($path))[9];
        return ($age > 7 * $DAYS) ? $FORBIDDEN : $OK;
    }

    # use age from file name for public access
    return $FORBIDDEN unless
        File::Basename::basename($file) =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d)_(\d\d)/;

    my $age =  time() - Time::Local::timelocal(0, $5, $4, $3, $2 - 1, $1);
    return ($age > 7 * $DAYS) ? $FORBIDDEN : $OK;
}
1;

__END__

# limit access up to 7 days after datetime given by filename.
# The filename links to a file starting with "yyyy-mm-dd hh_mm" in file name.
#
# Access to links starting with "shared-" are allowed up to 7 days after creation.
#
# <Directory ${archive_dir}/${domain}>
#        PerlSetEnv PERL5LIB ${perl_lib}/calcms
#        PerlSetEnv LISTENER_DIR ${archive_dir}/${domain}/
#        PerlAccessHandler ListenerAccess
# </Directory>
#
