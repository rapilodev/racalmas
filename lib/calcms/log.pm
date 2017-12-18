use warnings "all";
use strict;
use template;
use config;

package log;
use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);
#our @EXPORT = qw(all);
our @EXPORT_OK = qw(init write read error mem);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

#our $debug=0;
our $debug_params='';
our $header="Content-type:text/html\n\n";

our $gtop = undef;
our $proc = undef;

sub init{
	my $request		=$_[0];
	$log::debug_params	=$request->{params}->{checked}->{debug}||'';
	$log::header		=$request->{header}if (defined $request->{header});

	#if ($config->{system}->{debug_memory}>0){
		#use GTop();
		#$log::gtop=GTop->new;
		#$log::proc=$gtop->proc_mem($$);
	#}
}

sub write{
    my $config  = shift;
	my $key     = shift;
	my $data    = shift;
	my $dump    = shift;

	return unless(defined $config::config->{system}->{debug});
	return unless(($config::config->{system}->{debug}>0) &&($log::debug_params=~/$key/));

	my $line=Dumper($data);
	$line=~s/^\$VAR1 = \{\n/<code>/g;
	$line=~s/\};\n$/<\/code>/g;
	$line=~s/\n/\\n/g;
	my $msg=localtime()." [$key] ".$ENV{REQUEST_URI}."\\n".$line;
	$msg.=Dumper($dump) if (defined $dump);
	$msg.="\n";

	log::print($config, $msg);
}

sub print{
    my $config = $_[0];
	my $message= $_[1];

    unless (defined $config){
        print STDERR "missing config at log::error\n";
        return;
    }

	my $filename=$config->{system}->{log_debug_file}||'';
	if ($filename eq ''){
		print STDERR "calcms config parameter 'system/log_debug_file' not set!\n";
		return;
	};

	open my	$FILE, ">>:utf8", $filename or warn("cant write log file '$filename'");
	print	$FILE $message;
	close	$FILE;
}

sub error{
    my $config = $_[0];
	my $message="Error: $_[1]\n";

    unless (defined $config){
        print STDERR "missing config at log::error\n";
    }

    print STDERR $message."\n";
	if($config::config->{system}->{debug}){
	    log::write($config, '', $message);# if ($config::config->{system}->{debug}>1);

	    my $out='';
	    #do not call template::check to avoid deep recursion!
	    template::process('print','templates/default.html', {
		    static_files_url => $config::config->{locations}->{static_files_url},
		    error=>$message
	    });
	}
    # TODO: remove exit
    die();
	#exit;
}

sub mem{
    my $config = $_[0];
	return unless $config::config->{system}->{debug_memory};
	my $size=$log::gtop->proc_mem($$)->size();
	my $format_size=$size;
	$format_size=~s/(\d)(\d\d\d)$/$1\.$2/g;
	$format_size=~s/(\d)(\d\d\d)(\d\d\d)$/$1\.$2\.$3/g;
	my $line=localtime(time())."\t".$$."\t".$format_size."\t".$_[0];
	$line.="\t\t".($size-$_[1]) if(defined $_[1]);
	log::error($config, "log_memory_file is not defined!") if (!defined $config::config->{system}->{log_debug_memory_file});
	log::append_file($config::config->{system}->{log_debug_memory_file} , $line);
}

sub load_file{
	my $filename=$_[0];
#	my $content=$_[1];

#	binmode STDOUT, ":utf8";
	my $content='';
	if (-e $filename){
		my $FILE=undef;
		open $FILE, "<:utf8", $filename || warn "cant read file '$filename'";
		$content=join "",(<$FILE>);
		close $FILE;
		return $content;
	}
}

sub save_file{
	my $filename=$_[0];
	my $content=$_[1];

	#check if directory is writeable
	if ($filename=~/^(.+?)\/[^\/]+$/){
		my $dir=$1;
		unless (-w $dir){
			print STDERR `pwd;id -a;`;
			print STDERR "log::save_file : cannot write to directory ($dir)\n";
			return;
		}
	}

	open my	$FILE, ">:utf8", $filename || warn("cant write file '$filename'");
	if (defined $FILE){
		print	$FILE $content."\n";
		close	$FILE;
	}

}

sub append_file{
	my $filename =$_[0];
	my $content  =$_[1];

    unless ( (defined $filename) && ($filename ne'') && (-e $filename) ){
    	print STDERR "cannot append, file '$filename' does not exist\n";
        return;
    }

	if (defined $content){
		open my	$FILE, ">>:utf8", $filename or warn("cant write file '$filename'");
		print	$FILE $content."\n";
		close	$FILE;
	}
}


#do not delete last line!
1;
