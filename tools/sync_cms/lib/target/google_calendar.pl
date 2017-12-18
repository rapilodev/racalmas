#require 'db.pl';
#use db;
#use markup;

package target; 
use Data::Dumper;
use Net::Google::Calendar;
use time;

my $settings={};
my $cal = undef;
#my $op_count=0;

sub init{
	$target::settings=shift;
	my $access=$target::settings->{access};
	$target::cal = Net::Google::Calendar->new( url => $access->{url} );
	#main::print_info("init\n");
	#main::print_info("new\n");
	#print Dumper($access);

	my $email=$access->{email};
	my $password=$access->{password};
	if ($email ne'' && $password ne''){
		$target::cal->login($email, $password) ;
	#	$target::cal->auth($email, $password) if ($email ne'' && $password ne'');
		main::print_info("loged in");
	}
	#print Dumper($target::cal);

#	for my $c($target::cal->get_calendars) {
#	        print "'".$c->title."'\n";
#	        print $c->id."\n\n";
#	        if ($c->title eq 'petra poss'){
#			$target::cal->set_calendar($c);
#			main::print_info("found matching calendar!");
#		}
#	}
#	exit;

	#set UTF-8
	$XML::Atom::ForceUnicode = 1;
	$XML::Atom::DefaultVersion = "1.0";

}

#map event schema to target schema
sub map_to_schema{
	my $event=shift;

	#clone event
	my $target_event={};
	for my $key (keys %{$event}){
		$target_event->{$key}=$event->{$key};
	}

	$target_event->{reference}.='['.$event->{recurrence}->{number}.']' if ($event->{recurrence}->{number}>0);
	$target_event->{recurrence}		=> $event->{recurrence}->{number}+0;
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
#		print "$event->{start} gt $project->{start_date} $target_event->{project}\n";
	}

	#override settings by target map filter
	for my $key (keys %{$target::settings->{mapping}}){
		$target_event->{$key}=$target::settings->{mapping}->{$key};
	}
	#use Data::Dumper;print Dumper($target_event);

	#resolve variables set in mapped values
	for my $mkey (keys %{$target::settings->{mapping}}){
		my $mval=$target_event->{$mkey};
		for my $key (sort keys %{$target_event}){
			my $val=$target_event->{$key};
			$val=$event->{$key} if($mkey eq $key);
			#print $target_event->{$mkey}."\t".$key."-> $val\n";
			$target_event->{$mkey}=~s/<TMPL_VAR $key>/$val/g;
		}
	}	
	#use Data::Dumper;print Dumper($target_event);#exit;

	#$schema->{event}=fix_fields($schema->{event});

	my $schema={
		event => $target_event
	};

	return $schema;
}

# get a event by an existing google id, e.g. to check if the event exists in target
sub get_event_by_reference_id{
	return undef;
}

#try to find a event, matching to $event from google calendar
sub find_event{
	my $event=shift;
	return undef;

}

sub pre_sync{
	my $event=shift;

	$debug=1;
	return undef if(($target::settings->{date}->{'time_zone'} eq '') || ($event->{start} eq '' ) || ($event->{end} eq ''));

	#delete a span of dates
	print "\n" if ($debug eq '1');
	my $time_zone=$target::settings->{date}->{'time_zone'};
	my $start=time::get_datetime($event->{start},$time_zone);
	$start->set_time_zone('UTC');
	$parameters->{"start-min"} = $start->datetime;
	#$parameters->{"recurrence-expansion-start"}= $start->datetime;

	my $end=time::get_datetime($event->{end},$time_zone);
	$end->set_time_zone('UTC');
	$parameters->{"start-max"} = $end->datetime;
	#$parameters->{"recurrence-expansion-end"}= $end->datetime;

	main::print_info("search target for events from ".$start." to ".$end) if ($debug eq '1');

	my @events=$target::cal->get_events(%$parameters);
	
	for my $event(@events){
		main::print_info("delete ".$event->title) if ($debug eq '1');
		$target::cal->delete_entry($event);
	};
}


# insert a new event
sub insert_event{
	my $event=shift;
	my $entity=$event->{event};

	$entity->{'html_content'}=markup::creole_to_html($entity->{'content'});

	my $time_zone	=$target::settings->{date}->{'time_zone'};
	my $start	=time::get_datetime($entity->{start},$time_zone);
	my $end		=time::get_datetime($entity->{end},$time_zone);
	#print Dumper($start)."\n";
	#print Dumper($end)."\n";
	print "\n" if ($debug eq '1');

	main::print_info("insert event") if ($debug eq '1');
	my $entry = Net::Google::Calendar::Entry->new();
	
	#print Dumper($entity);
	$entry->title($entity->{title});
	$entry->content($entity->{content});
	$entry->location($entity->{location});
	$entry->transparency('transparent');
	$entry->status('confirmed');
	$entry->when($start, $end);
	#print Dumper($entry);

	$target::cal->add_entry($entry);
	#exit;
}


# update an existing event
sub update_event{
	return;
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
	return;

}

sub fix_fields{
	my $event=shift;
	#lower case for upper case titles longer than 4 characters
	for my $attr qw(program series_name title){
		my $val=$event->{$attr};
		my $c=0;
		while ($val=~/\b([A-Z]{5,99})\b/ && $c<10){
			my $word=$1;
			my $lower=lc $word;
			$lower=~s/^([a-z])/\u$1/gi;
			$val=~s/$word/$lower/g;
			$c++;
		}
		if ($event->{$attr} ne $val){
			$event->{$attr}=$val;
#			print Dumper($event->{$attr}).'<>'.Dumper($val)."\n" ;
		}
	}

	for my $attr qw(program series_name title excerpt content ){
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

sub clean_up{
	return;
}

1;
