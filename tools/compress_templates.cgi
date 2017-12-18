#! /usr/bin/perl -w 

BEGIN{
	my $dir=$ENV{SCRIPT_FILENAME}||'';
	$dir=~s/(.*\/)[^\/]+/$1/;
	$dir=$ENV{PWD} if ($dir eq'');
	$dir=`pwd` if ($dir eq'');

	#if located below extern CMS go on more down
	#$dir.='../';

	#local perl installation libs
	unshift(@INC,$dir.'/../../perl/lib/');
	unshift(@INC,$dir.'/../../calcms/calcms/');
}

use warnings "all";
use strict;
use Data::Dumper;

use File::stat;
use Time::localtime;
use CGI qw(header param Vars escapeHTML uploadInfo cgi_error);
use time;
use config;
use log;
use projects;
use markup;
use template;

my $config	=config::get('../config/config.cgi');

my $debug		=$config->{system}->{debug};
my $base_dir		=$config->{locations}->{base_dir};
my $local_base_url	=$config->{locations}->{local_base_url};

$CGI::POST_MAX = 1024*10;
my $cgi=new CGI();
my %params=$cgi->Vars();
#print $cgi->header();
#print STDERR Dumper($config);

#print "a\n";
template::exit_on_missing_permission('access_system');
#print "b\n";

my $request={
	url	=> $ENV{QUERY_STRING}||'',
	params	=> {
		original => \%params,
		checked  => check_params(\%params), 
	},
	config	=> $config
};
my $params=$request->{params}->{checked};

log::init($request);
log::mem('pic_manager init')if($debug>2);

my $errors='';
my $action_result='';

log::error("base_dir '$base_dir' does not exist")unless(-e $base_dir);

my $template_dirs=[
	$base_dir.'/templates/', 
	$base_dir.'/admin/templates/',
	$base_dir.'/planung/templates/',
];
my @results=();
#print "<pre>\n";

for my $template_dir(@$template_dirs){
	my $dest_dir=$template_dir.'compressed/';
	log::error('template directory "'.$dest_dir.'" does not exist') 	unless(-e $dest_dir);
	log::error('cannot write into template directory "'.$dest_dir.'"') 	unless(-w $dest_dir);

	#compress only: html, xml
	my @files=glob("$template_dir*.*ml");
	for my $file (@files){
		$file=~s/[\n\r]+$//g;
		next if ($file=~/\~$/);
		next if ($file=~/compressed/);
		next if ($file=~/\.old$/);
		push @results,$file;

		my $content=log::load_file($file);
#		print "$file\n";
		markup::compress($content);

		my $filename=(split(/\//,$file))[-1];
		my $dest_file=$template_dir.'compressed/'.$filename;
		log::error("cannot write '$dest_file'") if((-e $dest_file) && (!(-w $dest_file)));
		log::save_file($dest_file,$content);
	}
}

my $out='';
template::process('print',$params->{template},{
	'error'		=> $errors,
	'projects'	=> projects::get({all=>0}),

	}
);

print '<pre>';
for my $result(@results){
	$result=~s/$base_dir//g;
	print $local_base_url.$result."\n";
}
print '</pre>';
log::mem('pic_manager init')if($debug>1);


sub check_params{
	my $params=shift;

	my $result={};
	
	#avoid checking templates 
	$result->{template}='templates/default.html';

	return $result;
}

