#use markup;
use creole_wiki;
use DateTime;
use events;
use time;
use config;
#use DateTime::Format::ICal;

package source;
use Data::Dumper;

my $settings={};

sub init{
	$source::settings=shift;
    #print STDERR Dumper($source::settings);
}

#return a list of start_min, start_max request parameters. list is defined as timespan given by start_min and start_max in source_options
sub split_request{

	return undef if (
  		  (!(defined $source::settings->{start_min})) || ($source::settings->{start_min} eq'')
		||(!(defined $source::settings->{start_max})) || ($source::settings->{start_max} eq'') 
	);

	#print Dumper($source_options);
	my $dates=[];

	my $start	=time::get_datetime($source::settings->{start_min},$source::settings->{date}->{time_zone});
	my $end		=time::get_datetime($source::settings->{start_max},$source::settings->{date}->{time_zone});
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
	my $block_number	=$source::settings->{block_number};
	my $block_size		=$source::settings->{block_size};
	my $last_update		=$source::settings->{last_update};

	#print Dumper($request);

	my $request_parameters={
		from_date	=> $source::settings->{start_min},
		till_date	=> $source::settings->{start_max},
		archive		=> 'all',
		project 	=> $source::settings->{project},
		template	=> 'no'
	};
	$request_parameters->{location}=$source::settings->{location} if ($source::settings->{location}ne'');

    my $config = $source::settings;
	my $request={
		url	=> $ENV{QUERY_STRING},
		params	=> {
			original 	=> \%params,
			checked  	=> events::check_params($config,
				$request_parameters,
				$source::settings
			), 
		},
	};
	#print Dumper($request);

	my $source_events=events::get($config, $request, $source::settings);
	#print Dumper($source_events);

	#return events by date
	my $sources_by_date={};
	my $old_start='';
	for my $source (@$source_events){
		$source->{calcms_start}=$source->{start};
		my $key=substr($source->{start},0,10);
		push @{$sources_by_date->{$key}},$source;
	}
	return $sources_by_date;
}

sub get_event_attributes{
	my $source=shift;
	return $source;
}

sub map_to_schema{
	my $event=shift;
#	print Dumper($source_options);
#	exit;

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

	return $event;
}

eof;
