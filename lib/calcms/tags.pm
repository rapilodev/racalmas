use warnings "all";
use strict;
use Data::Dumper;

package tags; 

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_tags);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

sub get_tags{
	my $dbh=shift;
	my $query=qq{
		select	name, count(name) sum from calcms_tags
		group by name
		order by sum desc	
	};
	my $tags=db::get($dbh,$query);
	return $tags;
}

#do not delete last line!
1;
