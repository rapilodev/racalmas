#!/usr/bin/perl -I ../lib #-w

BEGIN{
	my $dir='';
	$ENV{SCRIPT_FILENAME}||'' if ($dir eq'');
	$dir=~s/(.*\/)[^\/]+/$1/ if ($dir ne '');
	$dir=$ENV{PWD} if ($dir eq'');
	$dir=`pwd` if ($dir eq'');

	#local perl installation libs
	unshift(@INC,$dir.'/../../perl/lib/');

	#calcms libs + configuration
	unshift(@INC,$dir.'/../calcms/');
}

#use utf8;
use Data::Dumper;
#require 'time.pl';
use Getopt::Long;
use time;
use DateTime;
use DateTime::Duration;
use strict;
use warnings;

check_running_processes();


my $read_mode='';
my $update_mode='';
my $all_events='';
my $modified_events='';
my $source_config_file='';
my $target_config_file='';
my $block_number=0;
my $block_size=2000;
my $from='';
my $till='';
my $read_only=0;
my $project='';

GetOptions(
    "read"		=> \$read_mode,
    "update"		=> \$update_mode,
    "all"		=> \$all_events,
    "modified"		=> \$modified_events,
    "from=s"		=> \$from,
    "till=s"		=> \$till,
    "source=s"		=> \$source_config_file,
    "target=s"		=> \$target_config_file,
    "project=s"		=> \$project,
    "block_number:i"	=> \$block_number,
    "block_size:i"	=> \$block_size
);

$|=1;

BEGIN {
	our $utf8dbi=1;
	$ENV{LANG}="en_US.UTF-8";
#	print Dumper(\%ENV);
}

#source and taget settings are loaded from config files
our $settings={
};

#user interface
our $ask_before_insert=0;
our $ask_before_update=0;

# end of configuration

if ($update_mode){
	$db::write=1;
#	print "enter update mode\n";
}elsif($read_mode){
	#default
	$db::write=0;
#	print "enter read-only mode\n";
}else{
	print_error("set parameter >read< or >update<");
}

unless ($modified_events || $all_events || $from || $till){
	print_error("set one of folling parameters: --modified, --from, --till");
}

init();
my $project_target=$source::settings->{sources}->{$project};
unless (defined $project){
	print_error("missing parameter --project") unless(defined $project_target);
	print_error("cant find project configuration '$project_target'") unless (-f $project_target);
	print_error("cant read project configuration '$project_target'") unless (-r $project_target);
}

my $events=[];
print "TIME_GATE: READ ALL CALENDARS\n";
sync();
$events=compress_events($events);
my $c=0;
if ($project eq ''){
	for my $event (@$events){
		print_event("[".($c+1)."]",$event);
		print "\n";
		$c++;
	}
}else{
	my $source=$source::settings->{sources}->{$project};
	my $target='config/target/calcms.cfg';

	for my $event (@$events){
		my $from=$event->{start};
		#print Dumper($event->{end});
		#remove a second
		my $till=source::get_datetime($event->{end}, $source::settings->{date}->{time_zone})->add(seconds=>-1)->datetime();
		print_event("STATION TIMESLOT [".($c+1)."]\t",$event);
		print "\n";
		$c++;
		my $command="perl sync_cms.pl --update --all --from=$from --till=$till --source $source --target $target ";
		print_info($command);
		print `$command`;
		#exit;
	}

}
print "\ndone.\n";
exit 0;

sub compress_events{
	my $events=shift;

	my @results=();
	my $old_event={end=>'', start=>'', title=>''};
	for my $event(sort {$a->{start} gt $b->{start}} @$events){
#		print "$event->{start}\t$event->{end}\t$event->{title}\n";
		if (
#			(defined $event) && (defined $event->{start}) && (defined $event->{end}) && (defined $event->{title})
			(	#station continues
				($event->{start} eq $old_event->{end})
			     || (#multiple entries for same event
				   ($event->{start} ge $old_event->{start}) 
				&& ($event->{end} eq $old_event->{end})
				)
			)
			&& ($event->{title} eq $old_event->{title})
			&& (@results>0)
		){
			$results[-1]->{end}=$event->{end};
#			print @results."\tmerge \n";
		}else{
			push @results,{
				start 	=> $event->{start},
				end	=> $event->{end},
				title	=> $event->{title},
			};
#			print @results."\tinsert \n";
		}
		$old_event=$results[-1];
	}
#	print Dumper(\@results);

	return \@results;	
}

#sync all events, splitting multi-day-requests into multiple 1-day-requests to avoid large result sets
sub sync{
	#prepare target
	target::init($settings->{target});
	print_info("last update: $settings->{source}->{last_update}");

	if (my $days=source::split_request($settings->{source})){
		#set 1-day start-min and start-max parameters, requires --from and --till values
		for my $date (@$days){
			for my $key(keys %$date){
				$settings->{source}->{$key}=$date->{$key};
			}
			print "\nrequest ".$settings->{source}->{"start_min"}." to ".$settings->{source}->{"start_max"}."\n";
			sync_timespan();
		}
	}else{
		#update without time span (e.g. --modified)
		sync_timespan();
	}

	print_info("\nset last-update time: $settings->{event}->{update_start}");
	set_last_update_time($source_config_file,$target_config_file,$settings->{event}->{update_start});
}

#sync all events of a given source timespan
sub sync_timespan{
	#get a list of all days and their events
	#print Dumper($settings->{source});
	my $source_events=source::get_events($settings->{source},$settings->{target});
	#print Dumper($source_events);
	my @dates=(keys %$source_events);

	if (@dates==0){
		my $more='';
		if ((defined $settings->{source}->{block_number}) && ($settings->{source}->{block_number} ne '0')){
			$more='more ';
		}elsif ($modified_events){
			$more.='modified ';
		}
		print_info("\n".'no '.$more."entries found.");
	}else{
		#sort lists of date and time (same time events should be preserved)
		for my $date(sort {$a cmp $b} @dates){
#		for my $date(@dates){
#			print "\n$date:\n";
			sync_events($source_events->{$date}, $settings);
		}
	}

}

#syncronize a list of source events to target events
sub sync_events{
	my $source_events=shift;
	my $settings=shift;

	my $c=0;
	$c=$source::settings->{start_index}+0 if (defined $source::settings->{start_index});

#	print "<events>\n";

	#order processing by start time (TODO: order by last-modified date)
	for my $event (sort{$a->{calcms_start} cmp $b->{calcms_start}} @$source_events){
		#read event attributes
		$event=source::get_event_attributes($event);

		$event->{title}=~s/\s//g;

		$event->{event}={
			title		=> $event->{title},
			start		=> $event->{start},
			end		=> $event->{end},
			status		=> $event->{status},
		};

#		print "\n";
		#print_event("[".($c+1)."]",$event);
		#print "\n".$event->{event}->{title}." ".$project."\n";

		if ($event->{event}->{status}eq'canceled'){
			print "canceled event:".qq{$event};
		}elsif ($event->{event}->{start} eq ''){
			print ('WARNING: Cannot read start of event'."\n");
		}elsif ($event->{event}->{end} eq ''){
			print ('WARNING: Cannot read start of end'."\n");
		}elsif ($event->{event}->{title} eq ''){
			print ('WARNING: Cannot read start of title'."\n");
		}elsif ($project ne ''){
			if ($event->{event}->{title} eq $project){
				push @$events, $event->{event};
			}
		}else{
			push @$events, $event->{event};
		}
		$event=undef;
		$c++;
	}
}


#import requested source and target libs
sub init{
	binmode STDOUT, ":utf8";

	#require source config file
	print_error ("missing source parameter!") 				unless ($source_config_file=~/\S/);
	print_error ("source file: '$source_config_file' does not exist") 	unless (-e $source_config_file);
	print_error ("cannot read source file: '$source_config_file'") 		unless (-r $source_config_file);
	#$settings->{source}=require $source_config_file;
	my $configuration = new Config::General($source_config_file);
	$settings->{source}=$configuration->{DefaultConfig}->{source};

	#require source import lib from config file
	my $source_import_lib='lib/source/'.$settings->{source}->{type}.'.pl';
	print_error ("missing 'type' in 'source' config ") 			unless ($settings->{source}->{type}=~/\S/);
	print_error ("cannot read source type import lib: '$source_import_lib'")unless (-r $source_import_lib);
	require $source_import_lib;

	#require target config file
	print_error ("missing target parameter!") 				unless ($target_config_file=~/\S/);
	print_error ("target file: '$target_config_file' does not exist") 	unless (-e $target_config_file);
	print_error ("cannot read target file: '$target_config_file'") 		unless (-r $target_config_file);
	#$settings->{target}=require $target_config_file;
	$configuration = new Config::General($target_config_file);
	$settings->{target}=$configuration->{DefaultConfig}->{target};

	#require target import lib from config file
	my $target_import_lib='lib/target/'.$settings->{target}->{type}.'.pl';
	print_error ("missing 'type' in 'target' config ") 			unless ($settings->{target}->{type}=~/\S/);
	print_error ("cannot read target type import lib: '$target_import_lib'")unless (-r $target_import_lib);
	require $target_import_lib;

	#print Dumper($settings);
	if ((defined $settings->{source}->{read_blocks}) && ($settings->{source}->{read_blocks}==1)){
		$settings->{source}->{block_number}	=$block_number;
		$settings->{source}->{block_size}	=$block_size;
	}
	$settings->{source}->{last_update}	=get_last_update_time($source_config_file,$target_config_file);
	$settings->{source}->{modified_events}	=$modified_events;

	if ($from=~/^\d\d\d\d\-\d\d\-\d\d$/){
		$from.='T00:00';
	}

	if ($till=~/^\d\d\d\d\-\d\d\-\d\d$/){
		$till.='T23:59';
	}

	if ($from=~/^([-+]?\d+$)/){
		my $days=$1;
		my $duration=new DateTime::Duration(days=>$days);
		$from=DateTime->today->add_duration($duration);
#		print "from:$from\t";
	}
	if ($till=~/^([-+]?\d+$)/){
		my $days=$1+1;
		my $duration=new DateTime::Duration(days=>$days);
		$till=DateTime->today->add_duration($duration);
#		print "till:$till\t";
		 
	}


	$settings->{source}->{start_min}	=$from if defined ($from);
	$settings->{source}->{start_max}	=$till if defined ($till);

	my $gmt_difference	=0;#*=3600;
	my $now			=time();
	my $now_gmt		=$now-$gmt_difference;
	$now			=time::time_to_datetime($now);
	$now_gmt		=time::time_to_datetime($now_gmt);

	$settings->{event}={
		update_start	=> time::time_to_datetime(time()),
		modified_at	=> $now,
		modified_at_gmt	=> $now_gmt
	};
	source::init($settings->{source});

}

# print date/time, title and excerpt of an calendar event
# TODO: replace by output filter (text, html)
sub print_event{
	my $header=shift;
	my $event=shift;

	my $s=$header;
	$s=$s." "x (8-length($s));

#	print Dumper($event);
	my $start=$event->{start}||'';
	$start=~s/T/  /g;
	$start=~s/\:00$//g;

	my $end=$event->{end}||'';
	$end=~s/T/  /g;
	$end=~s/\:00$//g;

	$s.="$start\t$end\t'$event->{title}'";

#	print Dumper($event->{event});
	print $s;
#excerpt:	>$event->{excerpt}<
#content:	>$event->{content}<
#content:	>$event->{content}<

}

#output usage on error or --help parameter
sub print_usage{
	print qq{
update all/modified events from source at target.

USAGE: $0 [--read,--update] [--modified,--all] --source s --target t [--block_number b] [--block_size s]

on using --from and --till requests will be processed as multiple single-day-requests.
	
parameters:
	--read          show all events without updating database
	--update        update target database with source events

	--modified      process only modified events.
	--all'          process all events

	--source        source configuration file
	--target        target configuration file

	--from          start of date range: datetime (YYYY-MM-DDTHH:MM::SS) or days from today (e.g. -1 for yesterday, +1 for tomorrow)
	--till          end of date range: datetime (YYYY-MM-DDTHH:MM::SS) or days from today (e.g. -1 for yesterday, +1 for tomorrow)

	--block_number  which block is to be syncronized [0..n]. To split up processing into multiple blocks (for machines with small memory resources).
	--block_size    size of a block, default=20 events

examples: 
	perl $0 --update --modified --source=config/source/einheit.cfg --target=config/target/calcms.cfg
	perl $0 --update --all --from=2009-09-01T00:00:00 --till=2009-11-22T23:59:59 --source=config/source/einheit.cfg --target=config/target/calcms.cfg
};
	exit 1;
};

#load last update time out of sync.data
sub get_last_update_time{
	my $source=shift;
	my $target=shift;

	my $date=undef;
	return undef unless(-r "sync.data");

	open my $DATA, "<:utf8","sync.data" || die ('cannot read update timestamp');
	while (<$DATA>){
		my $line=$_;
		if ($line=~/$source\s+\->\s+$target\s+:\s+(\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2})/){
			$date=$1;
			last;
		}
	}
	close $DATA;
	return $date;
}

#save last update time to sync.data
sub set_last_update_time{
	my $source	=shift;
	my $target	=shift;
	my $date	=shift;

	my $data='';
	if (-r "sync.data"){
		open my $DATA, "<:utf8","sync.data";
		$data=join("\n",(<$DATA>));
		close $DATA;
	}

	if ($data=~/$source\s+\->\s+$target\s+:\s+(\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2})/){
		$data=~s/($source\s+\->\s+$target\s+:)\s+\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}/$1\t$date/gi;
	}else{
		$data.="$source\t\->\t$target\t:\t$date\n";
	}

	$data=~s/[\r\n]+/\n/g;

	open my $DATA2, ">:utf8","sync.data" || die ('cannot write update timestamp');
	print $DATA2 $data;
	close $DATA2;

#	print $data;
}

#default error handling
sub print_error{
	print "\nERROR:\t$_[0]\n" ;
	print_usage();
}

sub print_info{
	my $message=shift;
	if ($message=~/^\n/){
		$message=~s/^\n//g;
		print "\n";
	}
	print "INFO:\t$message\n";
}

#avoid to run more than one sync process simultaniously
sub check_running_processes{
	my $cmd="ps -afex 2>/dev/null | grep $0.pl | grep -v nice | grep -v grep ";
	my $ps=`$cmd`;
#	print "$ps";
	my @lines=(split(/\n/,$ps));
	if (@lines>1){
		print "ERROR:\tanother ".@lines." synchronization processes '$0.pl' instances are running!".qq{

$cmd
$ps
-> program will exit
};
	exit;
	}

}
