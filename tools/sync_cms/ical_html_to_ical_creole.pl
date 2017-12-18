require '../lib/text_markup.pl';

open FILE,"<$ARGV[0]";
while (<FILE>){
	my $line=$_;
	if ($line=~/^DESCRIPTION:/){
		my $description=substr($line,length('DESCRIPTION:'));
		my $html=markup::ical_to_plain($description);
		my $creole=markup::html_to_creole($html);
		my $ical=markup::plain_to_ical($creole);
		$line= 'DESCRIPTION:'.$ical."\n";
	}
	print $line;
}
close FILE;


