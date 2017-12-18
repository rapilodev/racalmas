#! /usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use Date::Calc;
use config;
use template;
use projects;

my $perlPath='-I /home/calcms/lib/calcms';
my $configPath=$ARGV[0]||'/home/calcms/website/agenda/config/config.cgi';

unless (defined $config::config){
    config::get($configPath);
}
clean_up_cache();

sub clean_up_cache{
	my $base_dir =$config::config->{locations}->{base_dir}||'';
	my $cache    =$config::config->{cache}->{cache_dir}||'';
    my $cache_dir=$base_dir.'/'.$cache.'/';

    print_error("'base_dir' directory not configured! Please check config!") if($base_dir eq'');
    print_error("invalid 'base_dir' directory '$base_dir'! Please check config!") unless ($base_dir=~/[a-zA-Z]\/[a-zA-Z]/);
    print_error("'base_dir' directory '$base_dir' does not exist! Please check config!") unless (-e $base_dir);
    print_error("cannot read 'base_dir' directory '$base_dir'! Please check permissions!") unless (-r $base_dir);

	print_error("'cache_dir' directory $cache_dir not configured! Please check config!") if ($cache_dir eq '/');
    print_error("invalid 'cache_dir' directory '$cache_dir'! Please check config!") unless ($cache_dir=~/[a-zA-Z]\/[a-zA-Z]/);
    print_error("'cache_dir' directory '$cache_dir' does not exist! Please check filesystem!") unless (-e $cache_dir);
    print_error("cannot write to 'cache_dir' directory '$cache_dir'! Please check filesystem!") unless (-w $cache_dir);

    # update basic layout
	print_header("update basic layout");

	my $file="$base_dir/index.html";
	if ((-e $file) && (!-w $file)){
		print_error("Please check write permission on '$file'");
	}else{
		my $config=$base_dir.'/config/config.cgi';
		my $cmd="perl $perlPath get_source_page.pl --config $config --output $file 2>&1";
		execute($cmd);
	}

    # clear all files from cache
	print_header("clear cache");

	for my $controller (qw(sendung sendungen kalender kommentare)){
		clear($cache_dir.'/'.$controller.'/*');
		clear($cache_dir.'/programm/'.$controller.'/*');
	}

    # update start page
	print_header("update agenda start page");
	$file="$base_dir/programm.html";
	if ((-e $file) && (!-w $file)){
		print_error("Please check write permission on '$file'\n");
	}else{
		my $cmd="cd $base_dir; perl $perlPath aggregate.cgi date=today >$file 2>&1";
		execute($cmd);
	}
}

sub clear{
	my $path=shift;
	
	print_error("invalid path '$path' to delete!") unless ($path=~/cache/);
	return if ($path=~/\.htaccess$/);

	print_info("clear $path:");

	for my $file (glob($path) ){
		if (-f $file){
			print_info($file);
			unlink $file;
		}
	}
}

sub print_header{
    print "\n# $_[0]\n";
}

sub execute{
	my $cmd=$_[0];
	print_info($cmd."\n");
	print eval{`$cmd`}."\n";
	print_info('ok') 			if ($? == 0);
	print_error("error $! $?")	if ($? != 0);
}

sub print_info{
    print $_[0]."\n";
}

sub print_error{
	print STDERR "ERROR: $_[0]\n";
	exit 1;
}


1;
