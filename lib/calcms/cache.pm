use warnings "all";
use strict;
#use Data::Dumper;

use config;
use time;
use log;
use markup;

package cache;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(init add_map get_map get_map_keys load save get_filename escape_regexp escape_regexp_line);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

my $cache_map		={};
my $cache_map_keys	=[];
my $header_printed	=0;

our $date_pattern	='(\d{4})\-(\d{2})\-(\d{2})';
our $datetime_pattern	='(\d{4})\-(\d{2})\-(\d{2})[T\+](\d{2})\:(\d{2})(\:\d{2})?';

sub init{
	$cache_map	={};
	$cache_map_keys	=[];
	$header_printed	=0;
}

sub add_map{
	my $key		=$_[0];
	my $value	=$_[1];

	$key='^'.$key.'$';
	push @$cache_map_keys,$key;
	$cache_map->{$key}=$value;
}

sub get_map{
	return $cache_map;
}

sub get_map_keys{
	return $cache_map_keys;
}

#get cache from params
sub load{
	my $params=shift;

	my $filename=get_filename($params);

	my $result={
		filename=>$filename
	};

	if (defined $filename){
		my @file_info=stat($filename);
		my $modified=$file_info[9]||'';
		if ($modified ne ''){
			#file exists
			my @now	=localtime(time());
			my @modified	=localtime($modified);
			if ($now[2]==$modified[2]){
				#file is elder than a hour
				my $content=log::load_file($filename);	
				if (defined $content){
					$result->{content}	=$content;
					$result->{action}	='read';
					return $result;
				}
			}
		}
	}

	$result->{action}='save';
	return $result;
}

#get filename from params
sub get_filename{
    my $config = shift;
	my $params = shift;

#	my $url=$ENV{REQUEST_URI};
	my $url=$ENV{QUERY_STRING}||'';
	if ($url ne''){
		$url=~s/(^|\&)update\=\d//gi;
		$url=~s/(^|\&)debug\=.*//gi;
		$url=~s/\?\&/\?/g;
		$url=~s/\&{2,99}/\&/g;
		$url=~s/\&$//g;
		$url=~s/^\/\//\//g;
	}
	foreach my $pattern (@$cache_map_keys){

		my $filename=$url;
		log::write($config, 'cache_trace',"look at \"$filename\" for $pattern") if ($config->{system}->{debug});
		if ($filename =~/$pattern/){
			my $m1=$1;
			my $m2=$2;
			my $m3=$3;
			my $m4=$4;
			my $m5=$5;
			my $m6=$6;
			my $m7=$7;
			my $m8=$8;
#			my $m9=$9;

			my $result=$cache_map->{$pattern};

			$filename=~s/$pattern/$result/;
			$filename=~s/\$1/$m1/ if (defined $m1);
			$filename=~s/\$2/$m2/ if (defined $m2);
			$filename=~s/\$3/$m3/ if (defined $m3);
			$filename=~s/\$4/$m4/ if (defined $m4);
			$filename=~s/\$5/$m5/ if (defined $m5);
			$filename=~s/\$6/$m6/ if (defined $m6);
			$filename=~s/\$7/$m7/ if (defined $m7);
			$filename=~s/\$8/$m8/ if (defined $m8);
#			$filename=~s/\$9/$m9/ if (defined $m9);
			$filename=$config->{cache}->{cache_dir}.$filename;
			return $filename;
		}
	}
	return undef;
}

#deprecated: set file from params
sub set{
	my $params=shift;
	my $content=shift;

	my $filename=get_filename($params);
	my $cache={
		filename => $filename,
		content  => $content
	};
#	print $filename.":file\n";

	if (defined $filename){
		cache::save($cache);
	}
}


sub save{
	my $cache=shift;

	return if ($cache->{action}ne'save');
	return if ((!defined $cache->{filename}) || ($cache->{filename}eq''));

	log::save_file($cache->{filename},$cache->{content});
	chmod 0664, $cache->{filename};
}


sub escape_regexp{
	my $reg_exp=shift;
	$reg_exp=~s/([\^\$\\(\)\[\]\{\}\|\/\*\+\.\-\&\:])/\\$1/gi;
	return $reg_exp;
}

sub escape_regexp_line{
	my $reg_exp=shift;
	$reg_exp=~s/([\^\$\\(\)\[\]\{\}\|\/\*\+\.\-\&\:])/\\$1/gi;
	return '^'.$reg_exp.'$';
}

sub configure{
	my $file_name=shift;

	cache::init();
	cache::add_map('',$file_name);
}


#do not delete last line!
1;
