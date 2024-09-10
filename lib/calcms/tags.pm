package tags;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
our @EXPORT_OK   = qw(get_tags);

sub get_tags($) {
    my $dbh   = shift;
    my $query = qq{
		select	name, count(name) sum from calcms_tags
		group by name
		order by sum desc	
	};
    my $tags = db::get($dbh, $query);
    return $tags;
}

#do not delete last line!
1;
