package config;

require Exporter;
my @ISA         = qw(Exporter);
my @EXPORT_OK   = qw(get $config);
my %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

use Config::General();

our $modified_at = -999;
our $config      = undef;

sub get {
	my $filename = shift;

	#return config if known
	#my $age=(-M $filename);
	#return $config::config if ((defined $config::config) && ($age <= $config::modified_at));

	#reload config if changed
	my $configuration = new Config::General(
		-ConfigFile => $filename,
		-UTF8       => 1
	);
	$config::config      = $configuration->{DefaultConfig}->{config};
	$config::modified_at = $age;

	#print STDERR "reload $filename\n";

	return $config::config;
}

#do not delete last line
1;
