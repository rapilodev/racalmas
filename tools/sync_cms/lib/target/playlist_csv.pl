package target; 
use Data::Dumper;
use time;
use warnings;
use strict;

my $settings={};
my $cal = undef;

sub init{
	$target::settings=shift;
	my $access=$target::settings->{access};
	$cal = [];
}

#map event schema to target schema
sub map_to_schema{
	my $event=shift;
	#clone event
	my $target_event={};
	for my $key (keys %{$event}){
		$target_event->{$key}=$event->{$key};
	}
	
	$event->{recurrence}->{number}=0 unless (defined $event->{recurrence} || defined $event->{recurrence}->{number});
	$target_event->{reference}.='['.$event->{recurrence}->{number}.']' if ($event->{recurrence}->{number}>0);
	$target_event->{recurrence}		=> $event->{recurrence}->{number};
	$target_event->{rating}			=> 0;
	$target_event->{visibility}		=> 0;
#	$target_event->{transparency}		=> $event->{transparency};
	
	#set project by project's date range
	for my $project_name (keys %{$target::settings->{projects}}){
		my $project=$target::settings->{projects}->{$project_name};
		my $start=substr($event->{start},0,10);
		if ($start ge $project->{start_date} && $start le $project->{end_date}){
			$target_event->{project}=$project->{name};
		}
	}

	#override settings by target map filter
	for my $key (keys %{$target::settings->{mapping}}){
		$target_event->{$key}=$target::settings->{mapping}->{$key};
	}

	#resolve variables set in mapped values
	for my $mkey (keys %{$target::settings->{mapping}}){
		my $mval=$target_event->{$mkey};
		for my $key (keys %{$target_event}){
			my $val=$target_event->{$key};
			$val=$event->{$key} if($mkey eq $key);
			$target_event->{$mkey}=~s/<TMPL_VAR $key>/$val/g;
		}
	}	

	my $schema={
		event => $target_event
	};

	return $schema;
}

# get a event by an existing reference id, e.g. to check if the event exists in target
sub get_event_by_reference_id{
	my $event_id=shift;
	my $event={};
	return undef;
}

#try to find a event
sub find_event{
	my $event=shift;
	return undef;
}

# insert a new event
sub insert_event{
	my $event=shift;
	my $entity=$event->{event};

	my $time_zone	=$target::settings->{date}->{'time_zone'};
	my $start	=time::get_datetime($entity->{start},$time_zone);
	my $end		=time::get_datetime($entity->{end},$time_zone);
	print "\n" if ($main::debug eq '1');

	main::print_info("insert event") if ($main::debug eq '1');
	push @$cal,{
		start	=> $start,
		end	=> $end,
		title	=> $entity->{title}
	}
	#exit;
}


# update an existing event
sub update_event{
	my $event=shift;
	my $entity=shift;
}
### end of interface implementation ###


sub print_event{
	my $header=shift;
	my $event=shift;

	if ($header eq'google'){
		print "\n===== $header =====";
	}else{
		print "$header\n" if $header ne '';
	} 
#	print qq!$event->{start} $event->{program} : $event->{series_name} - $event->{title}!."\n";
	#content:	>$event->{content}<
};

sub delete_event{
	my $event_id=shift;

}

sub fix_fields{
	my $event=shift;

	for my $attr qw(title){
		my $val=$event->{$attr};
		$val=~s/^\s*(.*?)\s*$/$1/g;
		$val=~s/^[ \t]/ /g;
		if ($event->{$attr} ne $val){
			$event->{$attr}=$val;
#			print Dumper($event->{$attr}).'<>'.Dumper($val)."\n" ;
		}
	}
	return $event;
}

sub pre_sync{
}

sub clean_up{
	my $content='';

	my @cal=sort {$a->{start} cmp $b->{end}} @$cal;
	my @cal2=();
	#print Dumper(\@cal);
	#fill in default
	if (defined $target::settings->{date}->{default_entry}){
		my $from=$main::from;
		if ($from=~/^\d\d\d\d\-\d\d\-\d\dT\d\d$/){
			$from.=':00';
		}
		my $till=$main::till;
		if ($till=~/^\d\d\d\d\-\d\d\-\d\dT\d\d$/){
			$till.=':59';
		}

		my $default=$target::settings->{date}->{default_entry};
		if ($cal[0]->{start} gt $from){
			unshift @cal,{
				start	=> $from,
				end	=> $cal[0]->{start},
				title	=> $default
			}
		}
		if ($cal[-1]->{end} lt $till){
			push @cal,{
				start	=> $cal[-1]->{end},
				end	=> $till,
				title	=> $default
			}
		}
		my $old_event={end=>$from};
		for my $event (@cal){
			if ($event->{start} gt $old_event->{end}){
				push @cal2,{
					start => $old_event->{end},
					end   => $event->{start},
					title => $default
				}
			}
			push @cal2,$event;
			$old_event=$event;
			
		}
	}


	for my $event(@cal2){
		$content.= $event->{start}.";\t".$event->{end}.";\t".$event->{title}."\n";
	}
	log::save_file($target::settings->{access}->{file},$content);
	return;
}

1;
