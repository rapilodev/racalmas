#!/usr/bin/perl -I ../lib #-w

BEGIN{
	my $dir='';
	$ENV{SCRIPT_FILENAME} if ($dir eq'');
	$dir=~s/(.*\/)[^\/]+/$1/;
	$dir=$ENV{PWD} if ($dir eq'');
	$dir=`pwd` if ($dir eq'');

	#local perl installation libs
	unshift(@INC,$dir.'/../../perl/lib/');

	#calcms libs + configuration
	unshift(@INC,$dir.'/../calcms/');
}

#use utf8;
use warnings "all";
use strict;
use Data::Dumper;

#use CGI;
#use HTML::Template;
use Date::Calc;
#use calendar;
#use time;
#use log;

if(@ARGV<2){
	print qq{ERROR: $0 yyyy-mm-dd yyyy-mm-dd
syncronize from given start date to end date, day by day
};
	exit 1;
}

my $start	=$ARGV[0];
my $end		=$ARGV[1];

(my $start_year,my $start_month,my $start_day)=split(/\-/,$start);
my $last_day=Date::Calc::Days_in_Month($start_year,$start_month);
$start_day	= 1 if ($start_day<1);
$start_day	= $last_day if ($start_day gt $last_day);

(my $end_year,my $end_month,my $end_day)=split(/\-/,$end);
$last_day=Date::Calc::Days_in_Month($end_year,$end_month);
$end_day	= 1 if ($end_day<1);
$end_day	= $last_day if ($end_day gt $last_day);



for my $year($start_year..$end_year){
	my $m1=1;
	my $m2=12;
	$m1=$start_month if($year eq $start_year);
	$m2=$end_month	 if($year eq $end_year);

	for my $month($m1..$m2){
		$month='0'.$month if (length($month)==1);
		my $d1=1;
		my $d2=Date::Calc::Days_in_Month($year,$month);
		$d1=$start_day	if($month eq $start_month);
		$d2=$end_day	if($month eq $end_month);

		for my $day($d1..$d2){
			$day='0'.$day if (length($day)==1);
			my $date=join('-',($year,$month,$day));
			my $cmd="perl sync_cms.pl --update --all --source config/source/program.cfg --target config/target/calcms.cfg --from ".$date."T00:00:00 --till ".$date."T23:59:59";
			#print "$cmd\n";
			print `nice -n 10 $cmd`;
		}
	}

}

