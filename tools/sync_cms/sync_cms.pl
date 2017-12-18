#!/usr/bin/perl

BEGIN{
	my $dir='';
	$ENV{SCRIPT_FILENAME}||'' if ($dir eq'');
	$dir=~s/(.*\/)[^\/]+/$1/ if ($dir ne '');
	$dir=$ENV{PWD} if ($dir eq'');
	$dir=`pwd` if ($dir eq'');

	#add calcms libs
	unshift(@INC,$dir.'/../calcms/');
}

use Data::Dumper;
use Getopt::Long;
use Config::General;
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
our $from='';
our $till='';
my $read_only=0;
our $output_type='text';
our $debug=0;

GetOptions(
    "read"		=> \$read_mode,
    "update"		=> \$update_mode,
    "all"		=> \$all_events,
    "modified"		=> \$modified_events,
    "from=s"		=> \$from,
    "till=s"		=> \$till,
    "source=s"		=> \$source_config_file,
    "target=s"		=> \$target_config_file,
    "block_number:i"	=> \$block_number,
    "block_size:i"	=> \$block_size,
    "output_type=s"	=> \$output_type,
);

$|=1;

BEGIN {
	our $utf8dbi=1;
	$ENV{LANG}="en_US.UTF-8";
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
#	print_info("enter update mode");
}elsif($read_mode){
	#default
	$db::write=0;
#	print_info("enter read-only mode");
}else{
	print_error("set parameter >read< or >update<");
}

unless ($modified_events || $all_events || $from || $till){
	print_error("set one of folling parameters: --modified, --from, --till");
}

init();
sync();
print_info("$0 done.");
exit 0;

#sync all events, splitting multi-day-requests into multiple 1-day-requests to avoid large result sets
sub sync{
	#prepare target
	print_info("$0 inited");
	print_info("last update: $settings->{source}->{last_update}");

	if (my $days=source::split_request()){
		#set 1-day start-min and start-max parameters, requires --from and --till values
		for my $date (@$days){
			for my $key(keys %$date){
				$settings->{source}->{$key}=$date->{$key};
			}
			#print "\nrequest ".$settings->{source}->{"start_min"}." to ".$settings->{source}->{"start_max"}."\n";
			sync_timespan();
		}
	}else{
		#update without time span (e.g. --modified)
		sync_timespan();
	}

	print_info("\nclean up old database entries...");
	target::clean_up();

	print_info("\nset last-update time: $settings->{event}->{update_start}");
	set_last_update_time($source_config_file,$target_config_file,$settings->{event}->{update_start});
}

#sync all events of a given source timespan
sub sync_timespan{
	#get a list of all days and their events
	#print Dumper($settings->{source});
	my $source_events=source::get_events($settings->{source},$settings->{target});
	my @dates=(keys %$source_events);

	#print "2\n";
	if (@dates==0){
		my $more='';
		if ((defined $settings->{source}->{block_number}) && ($settings->{source}->{block_number} ne '0')){
			$more='more ';
		}elsif ($modified_events){
			$more.='modified ';
		}
		print_info("\n".'no '.$more."entries found.");
	}else{
		print "<table>" if ($output_type eq 'html');
		#sort lists of date and time (same time events should be preserved)
		for my $date(sort {$a cmp $b} @dates){
#		for my $date(@dates){
#			print "\n$date:\n";
			sync_events($source_events->{$date}, $settings);
		}
		print "</table>" if ($output_type eq 'html');
	}

}

#syncronize a list of source events to target events
sub sync_events{
	my $source_events=shift;
	my $settings=shift;

#	my $source_settings	=$settings->{source};
#	my $target_settings	=$settings->{target};
	my $event_settings	=$settings->{event};

	my $c=0;
	$c=$source::settings->{start_index}+0 if (defined $source::settings->{start_index});
	
#	print "<events>\n";
	print html_table_header() if ($output_type eq 'html');
	#order processing by start time (TODO: order by last-modified date)
	for my $event (sort{$a->{calcms_start} cmp $b->{calcms_start}} @$source_events){
		target::pre_sync({
			start	=>$source_events->[0]->{start},
			end	=>$source_events->[-1]->{end}
		});

		print "<tr><td>"if ($output_type eq 'html');

		#read event
		$event=source::get_event_attributes($event);

		#convert to calcms schema
		$event=source::map_to_schema($event);

		#map event to target schema		
		$event=target::map_to_schema($event);

		#deprecated: override defined attributes by configuration
		if ((defined $source::settings->{override}) && (ref($source::settings->{override})eq 'HASH')){
			for my $key (keys %{$source::settings->{override}}){
				my $value=$source::settings->{override}->{$key};
				if ($source::settings->{override} ne ''){
					print_info("override '$key'='$value'");
					$event->{event}->{$key}=$value;
				}
			}
		}

		if ($output_type eq'html'){
			print_event_html("[".($c+1)."]",$event);
		}else{
			print_event_text("[".($c+1)."]",$event);
		}

		if ($event->{event}->{start} eq '' || $event->{event}->{end} eq ''){
			print ('WARNING: Cannot read start or end of event');
			print "\n";
		}else{
#			print Dumper($event);
			sync_event($event);
		}

	#	last;
		$event=undef;
		$c++;
		print "</td></tr>"if ($output_type eq 'html');
	}
#	print "\n</events>\n";

}

#syncronize a single source event with target
sub sync_event{
	my $event=shift;

	#look if target_event exists by reference id incl. recurrence counter
	#print Dumper($event);
	my $target_event=target::get_event_by_reference_id($event->{event}->{reference});

	#if target_event exists
	if (defined $target_event){
		#delete canceled events
		if ($event->{event}->{status}eq'canceled'){
			print cell("delete canceled event:".qq{$target_event});
#			target::delete($target_event->{id});		
			return;
		}

		$event->{event_id}=$target_event->{id};

		target::update_event($event,$target_event);
		print cell("(ref. update)");

	}else{
		#find by date, time and title
		$target_event=target::find_event($event);

		if (defined $target_event){
			target::update_event($event,$target_event);
			#print Dumper($event);
			$event->{event_id}=$target_event->{id};
			print cell("(update)");
		}else{
			target::insert_event($event);
			#print Dumper($event);
			$target_event=target::get_event_by_reference_id($event->{event}->{reference});
			#print Dumper($target_event);
			$event->{event_id}=$target_event->{id};
			print cell("(new)");
		}
	}
	print "\n";

	for my $category (@{$event->{categories}}){
			target::assign_category_to_event($category,$event);
	}

	for my $meta (@{$event->{meta}}){
			target::assign_meta_to_event($meta,$event);
	}
#	print Dumper($event);
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
	$configuration = new Config::General($target_config_file);
	$settings->{target}=$configuration->{DefaultConfig}->{target};
	#$settings->{target}=require $target_config_file;

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
#		print "from:$from\t";
	}

	if ($till=~/^\d\d\d\d\-\d\d\-\d\d$/){
		$till.='T23:59';
#		print "till:$till\t";
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
	target::init($settings->{target});

}

# print date/time, title and excerpt of an calendar event
# TODO: replace by output filter (text, html)
sub print_event_text{
	my $header=shift;
	my $event=shift;

	my $s=$header;
	$s=$s." "x (8-length($s));

	my $start=$event->{event}->{start}||'';
	$start=~s/T/  /g;
	$start=~s/\:00$//g;

    if (defined $event->{event}->{program}){
	    $s.="$start   $event->{event}->{program}";
	    $s=$s." "x (45-length($s));
    }

    if (defined $event->{event}->{series_name}){
	    $s.=" : $event->{event}->{series_name}";
	    $s=$s." "x (75-length($s));
    }

    if (defined $event->{event}->{title}){
	    $s.=" - $event->{event}->{title}";
	    $s=$s." "x (110-length($s));
    }

	if ($event->{categories}){
		$s.= "(".join(", ",(@{$event->{categories}})).")";
	}
	$s=$s." "x (135-length($s));

	my $status=$event->{event}->{status};
	$s.=$status.' ' if (defined $status);
	$s=$s." "x (140-length($s));	

	my $reference=$event->{event}->{reference};
	$s.=substr($reference,length($reference)-25) if (defined $reference);

	print $s;
}

sub print_event_html{
	my $header=shift;
	my $event=shift;

	#close error block
	my $s='</td>';

	my $start=$event->{event}->{start}||'';
	$start=~s/T/  /g;
	$start=~s/\:00$//g;
	$s.=cell($start);
	$s.=cell($event->{event}->{program});
	$s.=cell($event->{event}->{series_name});
	$s.=cell($event->{event}->{title});

	if ($event->{categories}){
		$s.=cell( join(", " , ( @{$event->{categories}} ) ) );
	}

	my $status=$event->{event}->{status};
	$s.=cell($status) if (defined $status);

	my $reference=$event->{event}->{reference};
	$reference=substr($reference,length($reference)-25) if (defined $reference);
	$s.=cell($reference);

	$s.="<td>";

	print $s;
}

sub cell{
	if ($output_type eq 'html'){
		return  "<td>$_[0]</td>";
	}else{
		return  "\t".$_[0];
	};
}

#output usage on error or --help parameter
sub print_usage{
	print qq{
update all/modified events from source at target.

USAGE: sync_cms.pl [--read,--update] [--modified,--all] --source s --target t [--block_number b] [--block_size s]

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
	--output_type   log output format [text,html]

	--block_number  which block is to be syncronized [0..n]. To split up processing into multiple blocks (for machines with small memory resources).
	--block_size    size of a block, default=20 events

examples: 
   update modified
	perl sync_cms.pl --update --modified --source=config/source/program.cfg --target=config/target/calcms.cfg
   update a given time range
	perl sync_cms.pl --update --all --from=2009-09-01T00:00:00 --till=2009-11-22T23:59:59 --source=config/source/program.cfg --target=config/target/calcms.cfg
   update from last 2 days until next 3 days
	perl sync_cms.pl --update --all --from=-2 --till=+3 --source=config/source/program.cfg --target=config/target/calcms.cfg
};
	exit 1;
};

#default error handling
sub print_error{
	print "\nERROR: $_[0]\n" ;
	print_usage();
}

sub print_info{
	my $message=shift;
	if ($message=~/^\n/){
		$message=~s/^\n//g;
		print "\n";
	}
	if ($output_type eq 'html'){
		print "$message<br/>";
	}else{
		print "INFO:\t$message\n";
	}
}
sub html_table_header{
		return qq{
<tr>
	<th> </th>
	<th>start date</th>
	<th>project</th>
	<th>series</th>
	<th>title</th>
	<th>category</th>
	<th>status</th>
	<th>id</th>
	<th> </th>
	<th>action</th>
</tr>
	};
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

#avoid to run more than one sync process in parallel
sub check_running_processes{
	my $cmd="ps -afex 2>/dev/null | grep sync_cms.pl | grep -v nice | grep -v grep ";
	my $ps=`$cmd`;
#	print "$ps";
	my @lines=(split(/\n/,$ps));
	if (@lines>1){
		print "ERROR: another ".@lines." synchronization processes 'sync_cms.pl' instances are running!".qq{

$cmd
$ps
-> program will exit
};
	exit;
	}

}
