#require 'db.pl';
#use db;
#use markup;

package target;
use lib '/home/radio/calcms/sync_cms/lib/';
use Data::Dumper;
#use Net::Google::Calendar;
use GoogleCalendarApi;
use time;

my $settings={};
my $cal = undef;
#my $op_count=0;

sub init{
	$target::settings=shift;
	my $access=$target::settings->{access};

    # 1. create service account at https://console.developers.google.com/
    # 2. enable Calendar API
    # 3. share calendar with service account for update permissions

    # see http://search.cpan.org/~shigeta/Google-API-Client-0.13/lib/Google/API/Client.pm

    my $serviceAccount        = $access->{serviceAccount};
    my $serviceAccountKeyFile = $access->{serviceAccountKeyFile};
    my $calendarId            = $access->{calendarId};

    my $serviceAccountKey     = loadFile($serviceAccountKeyFile);

    #print "connect...\n";
    my $calendar = new GoogleCalendarApi({
        'serviceAccount' => $serviceAccount,
        'privateKey'     => $serviceAccountKey,
        'calendarId'     => $calendarId,
        'debug'          => 0
    });
    #print Dumper($calendar);
    $target::cal = $calendar;
    
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

#this is done before sync and allows to delete old events before adding new
sub pre_sync{
	my $event=shift;

	$debug=1;
	return undef if(($target::settings->{date}->{'time_zone'} eq '') || ($event->{start} eq '' ) || ($event->{end} eq ''));

	#delete a span of dates
	print "\n" if ($debug eq '1');

	my $timeZone=$target::settings->{date}->{'time_zone'};

    #get datetime in timezone
	my $start = time::get_datetime($event->{start}, $timeZone);
	my $end   = time::get_datetime($event->{end},   $timeZone);

	main::print_info("search target for events from ".$start." to ".$end) if ($debug eq '1');

    my $events=$target::cal->getEvents({
        #search datetime with same timezone
        timeMin      => $target::cal->getDateTime($start->datetime, $timeZone),
        timeMax      => $target::cal->getDateTime($end->datetime,   $timeZone),
        maxResults   => 50,
        singleEvents => 'true',
        orderBy      => 'startTime'    
    });

    my $now=DateTime->now()->set_time_zone('UTC')->epoch();
    #print Dumper($now->datetime);
    #exit;
	
	for my $event(@{$events->{items}}){
		main::print_info("delete\t$event->{start}->{dateTime}\t".$event->{summary}) if ($debug eq '1');
        #my $updated   = $target::cal->getDateTime($event->{updated},'UTC')->epoch();
        #my $delta  = $now-$updated;
        #print $delta." seconds old\n";
        $target::cal->deleteEvent($event->{id}) 
	};
    #exit;
}


# insert a new event
sub insert_event{
	my $event=shift;
	my $entity=$event->{event};

	$entity->{'html_content'}=markup::creole_to_html($entity->{'content'});

	my $timeZone = $target::settings->{date}->{'time_zone'};
    #print Dumper($timeZone);
    #print Dumper($entity);
	my $start	 = $target::cal->getDateTime($entity->{start}, $timeZone);
	my $end		 = $target::cal->getDateTime($entity->{end},   $timeZone);
	print "\n" if ($debug eq '1');
    #exit;
	main::print_info("insert event\t$start\t$entity->{title}") if ($debug eq '1');
	my $entry = {
        start        => $start,
        end          => $end,
        summary      => $entity->{title},
        description  => $entity->{content},
        location     => $entity->{location},
	    transparency => 'transparent',
        status       => 'confirmed'
    };

    my $result=$target::cal->insertEvent($entry);
    my $id=$result->{id};

	#exit;
}

sub loadFile{
    my $filename=shift;
    my $content='';
    
    open my $file, '<', $filename || die("cannot load $filename"); 
    while(<$file>){
        $content.=$_;
    }
    close $file;
    return $content;
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
