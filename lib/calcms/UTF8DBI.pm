# UTF8DBI.pm re-implementation by Pavel Kudinov http://search.cpan.org/~kudinov/
# originally from: http://dysphoria.net/code/perl-utf8/
# And patched again by Andrew Forrest, Jan 2007

use DBI 1.21;
use utf8;
use Encode();

package UTF8DBI;
use base DBI;

sub _utf8_ {
	if    ( ref $_ eq 'ARRAY' ) { _utf8_() foreach @$_ }
	elsif ( ref $_ eq 'HASH' )  { _utf8_() foreach values %$_ }
	else {
		Encode::_utf8_on($_);
		if ( Encode::is_utf8($_) && !Encode::is_utf8( $_, 1 ) ) {

			#$_ = '⁂malformed-UTF8‼' #die "Malformed utf8 string in database"
			#print data_string_desc($_)."\n"
			#data_string_desc(STRING);
			#Encode::decode_utf8($_);
			#;
			#Encode::_utf8_off($_);
			#Encode::decode_utf8($_);
			#Encode::encode_utf8($_);
		}
	}
	$_;
}

package UTF8DBI::db;
use base DBI::db;

sub selectrow_arrayref { return UTF8DBI::_utf8_ for shift->SUPER::selectrow_arrayref(@_) }
sub selectrow_hashref  { return UTF8DBI::_utf8_ for shift->SUPER::selectrow_hashref(@_) }
sub selectall_arrayref { return UTF8DBI::_utf8_ for shift->SUPER::selectall_arrayref(@_) }
sub selectall_hashref  { return UTF8DBI::_utf8_ for shift->SUPER::selectall_hashref(@_) }
sub selectcol_arrayref { return UTF8DBI::_utf8_ for shift->SUPER::selectcol_arrayref(@_) }

sub selectrow_array { @{ shift->selectrow_arrayref(@_) } }

package UTF8DBI::st;
use base DBI::st;

sub fetch { return UTF8DBI::_utf8_ for shift->SUPER::fetch(@_) }

1;
