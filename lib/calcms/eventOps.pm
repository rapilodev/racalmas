package eventOps; 
use warnings "all";
use strict;

use series;
use series_dates;
use time;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    setAttributesFromSeriesTemplate 
    setAttributesFromSchedule 
    setAttributesFromOtherEvent 
    setAttributesForCurrentTime 
    getRecurrenceBaseId
);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

# functions: to be separated
sub setAttributesFromSeriesTemplate{
    my $config=shift;
    my $params=shift;
    my $event=shift;
    
    #get attributes from series
    my $series=series::get(
        $config,{
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            series_id  => $params->{series_id},
        }
    );
    if(@$series!=1){
        uac::print_error("series not found");
        return undef;
    }

    #copy fields from series template
    my $serie=$series->[0];
    for my $attr(
        'program','series_name','title',
        'excerpt', 'topic', 'content', 'html_content', 
        'project','category','location','image', 'live',
        'archive_url', 'podcast_url'
    ){
        $event->{$attr}=$serie->{$attr};
    }
    return $serie;
}

sub setAttributesFromSchedule{
    my $config=shift;
    my $params=shift;
    my $event=shift;

    #set attributes from schedule
    my $schedules=series_dates::get(
        $config, {
            project_id => $params->{project_id},
            studio_id   => $params->{studio_id},
            series_id   => $params->{series_id},
            start_at    => $params->{start_date}
        }
    );

    if(@$schedules!=1){
        uac::print_error("schedule not found");
        return undef;
    }

    my $schedule=$schedules->[0];    
    for my $attr(
        'start','end', 
        'day', 'weekday',
        'start_date', 'end_date'
    ){
        $event->{$attr}=$schedule->{$attr};
    }

    my $timezone=$config->{date}->{time_zone};
    $event->{duration}  = time::get_duration($event->{start}, $event->{end}, $timezone);

    return $event;
}

sub setAttributesFromOtherEvent{
    my $config=shift;
    my $params=shift;
    my $event=shift;

    my $event2=series::get_event($config, {
        allow_any  => 1,
        #project_id => $params->{project_id}, 
        #studio_id  => $params->{studio_id},
        #series_id  => $params->{series_id},
        event_id   => $params->{source_event_id}
    });
    if (defined $event2){
        for my $attr ('title', 'user_title', 'excerpt', 'user_excerpt', 'content', 'html_content', 'topics', 'image', 'live', 'no_event_sync', 'podcast_url', 'archive_url'){
            $event->{$attr}=$event2->{$attr};
        }
        $event->{rerun}=1;
        $event->{recurrence}=getRecurrenceBaseId($event2);
    }

    return $event;
}

sub setAttributesForCurrentTime{
    my $serie=shift;
    my $event=shift;
    
    #on new event not from schedule use current time    
    if($event->{start}eq''){
        $event->{start}=time::time_to_datetime();
        if ($event->{start}=~/(\d\d\d\d\-\d\d\-\d\d \d\d)/){
            $event->{start}=$1.':00';
        }
    }
    $event->{duration}=$serie->{duration}||60;
    $event->{end}     =time::add_minutes_to_datetime($event->{start}, $event->{duration});
    $event->{end}=~s/(\d\d:\d\d)\:\d\d/$1/;

    return $event;
}

# get recurrence base id 
sub getRecurrenceBaseId{
    my $event    = shift;
    return $event->{recurrence} if (defined $event->{recurrence}) && ($event->{recurrence} ne '') && ($event->{recurrence} ne '0');
    return $event->{event_id};
}

