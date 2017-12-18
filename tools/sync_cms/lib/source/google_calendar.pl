#use markup;
use creole_wiki;
use DateTime;
use Net::Google::Calendar;
use DateTime::Format::ICal;

package source;
#do 'time.pl';
use Data::Dumper;

my $settings={};

sub init{
	$source::settings=shift;
}

#return a list of start_min, start_max request parameters. 
#list is defined as timespan given by start_min and start_max in source::settings
sub split_request{

	return undef if (
  		  (!(defined $source::settings->{start_min})) || ($source::settings->{start_min} eq'')
		||(!(defined $source::settings->{start_max})) || ($source::settings->{start_max} eq'') 
	);

	my $dates=[];

	my $start	=get_datetime($source::settings->{start_min},$source::settings->{date}->{time_zone});
	my $end		=get_datetime($source::settings->{start_max},$source::settings->{date}->{time_zone});
	my $date	=$start;

	#build a list of dates
	my @dates=();
	while ($date < $end){
		push @dates,$date;
		$date=$date->clone->add(days=>7);
	}
	my $duration=$end-$date;
#		print "sec:".($duration->delta_seconds/(60*60))."\n";
	if ($duration->delta_seconds <= 0){
#			pop  @dates;
		push @dates,$end->clone;
	}

	#build a list of parameters from dates
	my $start=shift @dates;
	for my $end (@dates){
		push @$dates,{
			start_min => $start,
			start_max => $end
		};
		$start=$end;
	}

#	for $day(@$dates){print "$day->{start_min} - $day->{start_max}\n";}
	return $dates;

}

#get a hash with per-day-lists days of a google calendar, given by its url defined at $calendar_name
sub get_events{

#	print Dumper($source::settings);
	my $url			=$source::settings->{access}->{url};
	my $email		=$source::settings->{access}->{email};
	my $password		=$source::settings->{access}->{password};

	my $block_number	=$source::settings->{block_number};
	my $block_size		=$source::settings->{block_size};
	my $last_update		=$source::settings->{last_update};

	my $parameters={};
	my $start_index=undef;
	my $stop_index=undef;
	if ($source::settings->{read_blocks}==1){
		my $start_index=$block_number*$block_size+1 ;
		my $stop_index=$start_index+$block_size-1;
		$parameters->{"start-index"} = $start_index; 
		$parameters->{"max-results"} = $block_size;
		$source::settings->{start_index}=$start_index;
		$source::settings->{stop_index}=$stop_index;
	}else{
		$parameters->{"max-results"} = 10000;
	}

	#see http://code.google.com/intl/de/apis/calendar/data/2.0/reference.html
	$parameters->{singleevents}='true';
	$parameters->{orderby}='lastmodified';

	my $more='modified' if (defined $last_update && $source::settings->{modified_events}==1);
	main::print_info("read $more events from google calendar: '".substr($url,0,40)."...".substr($url,length($url)-8)."'");

	#	print "\nblock '$block_number' (events ".$start_index."..".$stop_index.") \n" if (defined $block_number || defined $start_index || defined $stop_index);

	# http://search.cpan.org/~simonw/Net-Google-Calendar-0.97/lib/Net/Google/Calendar.pm#get_events_[_%opts_]

	my $cal = Net::Google::Calendar->new( url => $url );
	#main::print_info("new\n");
	if ($email ne'' && $password ne''){
		$cal->login($email, $password) ;
	#	$cal->auth($email, $password) if ($email ne'' && $password ne'');
	#	main::print_info("login $email $password");
	}
	#print Dumper($cal);

	#set UTF-8
	$XML::Atom::ForceUnicode = 1;
	$XML::Atom::DefaultVersion = "1.0";

#	my $xml=$cal->get_xml();
#	$xml=~s/<content/\n<content/gi;
#	print $xml."\n";
#	exit;

	#set updated-min (using UTC)
	if ((defined $last_update) && ($source::settings->{modified_events}==1)){
		my $datetime=$last_update;
		$datetime=source::get_datetime($datetime,$source::settings->{date}->{time_zone}) if (ref($datetime)eq'');
		$datetime->set_time_zone('UTC');
		$parameters->{"updated-min"} = $datetime->datetime;
		#print "last update\n";
	}
	#set start min (using UTC)
	if ((defined $source::settings->{start_min}) && ($source::settings->{start_min}ne'')){
		my $datetime=$source::settings->{start_min};
		$datetime=source::get_datetime($datetime,$source::settings->{date}->{time_zone}) if (ref($datetime)eq'');
		$datetime->set_time_zone('UTC');
		$parameters->{"start-min"} = $datetime->datetime;
		$parameters->{"recurrence-expansion-start"}= $datetime->datetime;
	}
	#set start max (using UTC)
	if ((defined $source::settings->{start_max})&&($source::settings->{start_max} ne'')){
		my $datetime=$source::settings->{start_max};
		$datetime=source::get_datetime($datetime,$source::settings->{date}->{time_zone}) if (ref($datetime)eq'');
		$datetime->set_time_zone('UTC');
		$parameters->{"start-max"} = $datetime->datetime;
		$parameters->{"recurrence-expansion-end"}= $datetime->datetime;
	}


#	print Dumper($parameters);
	my @events=();
	my @source_events=$cal->get_events(%$parameters);
	main::print_info("found ".@source_events." events");

#	print Dumper($parameters);
#	print Dumper($source::settings);
#	exit;

	for my $source(@source_events) {
		(my $start,my $end)=$source->when;
		$start=	$start->set_time_zone($source::settings->{date}->{time_zone})->datetime if (defined $start);
		$end=	$end->set_time_zone  ($source::settings->{date}->{time_zone})->datetime if (defined $end);
		$source->{calcms_start}	= $start;
		$source->{calcms_end}	= $end;
		$source->{status}	= $source->status;
	}

	#return events by date
	my $sources_by_date={};
	my $old_start='';
#	for my $source (sort{$a->{calcms_start} cmp $b->{calcms_start} }@source_events){
	for my $source (@source_events){
#		if ($source->{status}eq'confirmed'){
			my $key=substr($source->{calcms_start},0,10);
#			if ($old_start eq $source->{calcms_start}){
#				my $source=pop (@{$sources_by_date->{$key}});
#				print STDERR "WARNING: ignore canceled entry in google calendar: ".$source->{calcms_start}."\t".$source->{title}."\t".$source->{id}."\n";
#			}
#
			push @{$sources_by_date->{$key}},$source;
#
#			$old_start=$source->{calcms_start};
#		}
	}
	return $sources_by_date;
}

sub map_to_schema{
	my $event=shift;

	my $params={
		title		=> $event->{title},
		content		=> $event->{content},
		local_media_url	=> '<TMPL_VAR local_media_url>'
	};
    $params->{content}=~s/\x0A\x20/\n/g;
    #print Dumper($params);
    #open FILE,">/tmp/test";
    #print FILE Dumper($params);
    #close FILE;

	#decode event
	$event=creole_wiki::extractEventFromWikiText($params, $event);
    #exit;

	#override settings by source map filter
	for my $key (keys %{$source::settings->{mapping}}){
		$event->{$key}=$source::settings->{mapping}->{$key};
	}

	#resolve variables set in mapped values
	for my $mkey (keys %{$source::settings->{mapping}}){
		for my $key (keys %{$event}){
			my $val=$event->{$key};
			$val=$event->{$key} if($mkey eq $key);
			$event->{$mkey}=~s/<TMPL_VAR $key>/$val/g;
		}
	}
    #print Dumper($event);

	return $event;
}

sub get_event_attributes{
	my $source=shift;

	#print @source_events." ".Dumper($source)."\n";
	#use Data::Dumper;print Dumper($source->when);

	#create an hash with calendar event settings
	my $event={
		start			=> $source->{calcms_start},
		end			    => $source->{calcms_end},
		status			=> $source->{status},
#		recurrence		=> $source->{recurrence},
		reference		=> $source->id,
#		program			=> $program,
#		series_name		=> $series_name,
		title			=> $source->title,
		content			=> $source->content->body,
		author_name		=> $source->author->name,
		author_uri		=> $source->author->uri,
		author_email		=> $source->author->email,
		transparency		=> $source->transparency,
		visibility		=> $source->visibility,
		location		=> $source->location,
#		podcast_url		=> $podcast_url,
#		media_url		=> $media_url,
#		comments		=> $source->comments
#		who_name		=> $source->who->name,
#		who_email		=> $source->who->email,
#		who_attendee_status	=> $source->who->attendee_status,
	};
	#print Dumper($event);

#	if ($source->recurrence){
#		$event->{recurrence}=get_event_recurrence($source,$event);
#	}

	return $event;
}

sub get_event_recurrence{
	my $source=shift;
	my $event=shift;
	#print Dumper();

	my $event_recurrence=$source->recurrence;
	my $properties	= $event_recurrence->properties;
#		print Dumper($properties);

	my $dtstart	= $properties->{dtstart}->[0]->{value};
	my $timezone	= $properties->{dtstart}->[0]->{_parameters}->{TZID};
	my $dtend	= $properties->{dtend}->[0]->{value};
	my $rrule	= $properties->{rrule}->[0]->{value};
#		print $rrule."\n";
	
	#convert timezone from "until=<datetime>" to same datetime as in dtstart
	if ($rrule=~/UNTIL=([\dT]+Z?)/){
		my $ical=$1;

		#convert timezone at ical format
		my $datetime= DateTime::Format::ICal->parse_datetime($ical);
		$datetime=$datetime->set_time_zone($timezone);
		$ical=DateTime::Format::ICal->format_datetime($datetime);
		
		#remove TZID=... from ical, since not implemented at format_datetime
		$ical=~s/[^\:]+\://;
		$rrule=~s/(UNTIL\=)([\dT]+Z?)/$1$ical/g;
#			print $datetime->datetime." --> $ical --> $rrule\n";
	}

	$dtstart	= DateTime::Format::ICal->parse_datetime($dtstart);
	$dtend		= DateTime::Format::ICal->parse_datetime($dtend);#->add(seconds=>3600)->set_time_zone('UTC');

	my $recurrence={
		dtstart	=> $dtstart,
		dtend	=> $dtend,
		rrule	=> $rrule
	};

	#calc duration of the event
	my $duration=$dtend-$dtstart;
	my $duration_min=$duration->delta_minutes;

#		print Dumper($duration_min);
	#print Dumper($recurrence);
	my $recurrence_start	= DateTime::Format::ICal->parse_recurrence(
		recurrence	=>$rrule,
		dtstart		=>$dtstart
	);

	#step through recurrent events and mark if event matchs 
	my $start_iter 	= $recurrence_start->iterator;
	$c=1;
	while (my $start = $start_iter->next ){
#			print "$start eq $event->{start}, $end\n";
		$recurrence->{number}=$c if ($start eq $event->{start});
#			push @dates,{
#				start 	=> $start->set_time_zone($source::settings->{time_zone})->datetime,
#				end	=> $start->set_time_zone($source::settings->{time_zone})->add(minutes=>$duration_min)->datetime
#			};
		$c++;
	}
	$event->{recurrence}=$recurrence;
	#print Dumper($event->{recurrence});

}

sub get_datetime{
	my $datetime=shift;
	my $timezone=shift;

	return if((!defined $datetime) or ($datetime eq ''));
	my @l=@{time::datetime_to_array($datetime)};
	$datetime=DateTime->new(
		year	=>$l[0],
		month	=>$l[1],
		day	=>$l[2],
		hour	=>$l[3],
		minute	=>$l[4],
		second	=>$l[5],
		time_zone=> $timezone
	);
	return $datetime;
}

eof;
