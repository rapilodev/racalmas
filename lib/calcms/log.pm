use warnings "all";
use strict;
use template();
use config();

package log;

sub error {
	my $config  = $_[0];
	my $message = "Error: $_[1]\n";

	print STDERR $message;
	unless ( defined $config ) {
		print STDERR "missing config at log::error\n";
		die();
	}

	#do not call template::check to avoid deep recursion!
	if ( $config::config->{system}->{debug} ) {

		template::process(
			'print',
			'templates/default.html',
			{
				static_files_url => $config::config->{locations}->{static_files_url},
				error            => $message
			}
		);
	}

	die();
}

#do not delete last line!
1;

sub load_file {
	my $filename = $_[0];

	#	my $content=$_[1];

	#	binmode STDOUT, ":utf8";
	my $content = '';
	if ( -e $filename ) {
		my $FILE = undef;
		open $FILE, "<:utf8", $filename || warn "cant read file '$filename'";
		$content = join "", (<$FILE>);
		close $FILE;
		return $content;
	}
}

sub save_file {
	my $filename = $_[0];
	my $content  = $_[1];

	#check if directory is writeable
	if ( $filename =~ /^(.+?)\/[^\/]+$/ ) {
		my $dir = $1;
		unless ( -w $dir ) {
			print STDERR `pwd;id -a;`;
			print STDERR "log::save_file : cannot write to directory ($dir)\n";
			return;
		}
	}

	open my $FILE, ">:utf8", $filename || warn("cant write file '$filename'");
	if ( defined $FILE ) {
		print $FILE $content . "\n";
		close $FILE;
	}

}

sub append_file {
	my $filename = $_[0];
	my $content  = $_[1];

	unless ( ( defined $filename ) && ( $filename ne '' ) && ( -e $filename ) ) {
		print STDERR "cannot append, file '$filename' does not exist\n";
		return;
	}

	if ( defined $content ) {
		open my $FILE, ">>:utf8", $filename or warn("cant write file '$filename'");
		print $FILE $content . "\n";
		close $FILE;
	}
}

#do not delete last line!
return 1;
