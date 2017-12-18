use warnings "all";
use strict;
use events;
use comments;
use calendar;
use project;

package aggregator;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_cache configure_cache put_cache get_list check_params);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

#my $cgi=undef;

sub get_list{
    my $config = shift;
    my $request=shift;
    
    my $params=$request->{params}->{checked};
    my $debug=$config->{system}->{debug};

    #customize prefiltered request parameters
    $request->{params}->{original}->{date}=$request->{params}->{checked}->{date};
    if ($params->{event_id}ne''){
        $request->{params}->{original}->{template}='event_details.html';
    }else{
        $request->{params}->{original}->{template}='event_list.html';
    }
    $request->{params}->{checked} = events::check_params($config, $request->{params}->{original});
    log::write($config, 'params',$request->{params}->{checked}) if ($debug);

    my $content='';
    my $results=events::get($config, $request);
    events::render($content, $config, $request, $results);
#    calendar::get_cached_or_render($content,$request);


    #set url to embed as last loaded url in javascript
    my $date=$params->{date}||'';
    $date='heute' if ($params->{date}eq'today');
    $date=$results->[0]->{day} if ($params->{event_id}ne'');
    my $url='';
    #$config->{controllers}->{events}.'/'.$date.'/';
    if ($params->{from_date}ne'' && $params->{till_date}ne''){
        $url=$config->{controllers}->{events}.'/'.$params->{from_date}.'/'.$params->{till_date} ;
    }else{
        $url=$config->{controllers}->{events}.'/'.$params->{from_date}.'/'.$params->{till_date} ;
    }

    #count most projects
    my $used_projects={};
    for my $result (@$results){
        my $project=$result->{project_title}||'';
        $used_projects->{$project}++;
    }
    my @used_projects=reverse sort {$used_projects->{$a} <=> $used_projects->{$b}} (keys %$used_projects);
    my $most_used_project=$used_projects[0];
    #use Data::Dumper;print STDERR Dumper(\@used_projects);
    
    return {
        day            => $results->[0]->{day},
        start_datetime => $results->[0]->{start_datetime},
        event_id       => $results->[0]->{event_id},
        program        => $results->[0]->{program},
        project_title  => $most_used_project,
        series_name    => $results->[0]->{series_name},
        title          => $results->[0]->{title},
        content        => $content,
        results        => $results,
        url            => $url,
    };
}

sub get_menu{
    my $config = shift;
    my $request=shift;
    my $date=shift;
    my $results=shift;
    
    my $params=$request->{params}->{checked};

    #load details only on demand
    if ($params->{event_id}ne''){
        $request->{params}->{original}->{template}='event_menu.html';
        $request->{params}->{original}->{event_id}=undef;
        $request->{params}->{original}->{date}=$date;
        $request->{params}->{checked} =events::check_params($config, $request->{params}->{original});
        $results=events::get($config, $request);
    }else{
        $request->{params}->{checked}->{template}=template::check('event_menu.html');
    }

    #events menu
    my $output='';
    events::render($output, $config, $request, $results);

    return {
        content    => $output
    };
}

sub get_calendar{
    my $config = shift;
    my $request=shift;
    my $date=shift;
    
    my $params=$request->{params}->{checked};
    my $debug=$config->{system}->{debug};

    $request->{params}->{original}->{template} = 'calendar.html';
    $request->{params}->{original}->{date}     = $date if (defined $date);
    $request->{params}->{checked}              = calendar::check_params($config, $request->{params}->{original});
    $params = $request->{params}->{checked};
    log::write($config, 'params',$params)    if ($debug);

    #set query string for caching 
    my $options=[];
    push (@$options,'date='.$params->{date})            if ($params->{date} ne'');
    push (@$options,'from_date='.$params->{from_date})  if ($params->{from_date} ne'');
    push (@$options,'till_date='.$params->{till_date})  if ($params->{till_date} ne'');
    $ENV{QUERY_STRING}=''.join("&",@$options);

    my $content='';
    calendar::get_cached_or_render($content, $config, $request);

    return {
        content => $content
    };
}

sub get_newest_comments{
    my $config = shift;
    my $request=shift;

    my $params={
        template =>'comments_newest.html',
        limit    => 10,
        type     =>'list',
        show_max => 3
    };
    $request={
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => comments::check_params($config, $params), 
        },
        config       => $config,
        connection   => $request->{connection}
    };
    my $content='';
    comments::get_cached_or_render($content, $config, $request);
    return {
        content => $content
    };
}

sub get_cache{
    my $config  = shift;
    my $request = shift;

    my $params =$request->{params}->{checked};
    my $debug=$config->{system}->{debug};

    if ($config->{cache}->{use_cache} == 1){
        configure_cache($config);
        log::write($config, 'cache_files',cache::get_map()) if ($debug);
        my $cache=cache::load($config, $params);
        log::write($config, 'cache_files',$cache->{action}) if ($debug);
        return $cache;
    }
    return{};
}

sub configure_cache{
    my $config = shift;

    cache::init();
    my $controllers=$config->{controllers};

    my $date_pattern=$cache::date_pattern;
#    cache::add_map(''                            ,'programm/index.html');
    cache::add_map('date=today'                        ,'programm/'.$controllers->{events}.'/today.html');
    cache::add_map('date='.$date_pattern                    ,'programm/'.$controllers->{events}.'/$1-$2-$3.html');
    cache::add_map('from_date='.$date_pattern.'&till_date='.$date_pattern    ,'programm/'.$controllers->{events}.'/$1-$2-$3_$4-$5-$6.html');
    cache::add_map('event_id=(\d+)'                        ,'programm/'.$controllers->{event}.'/$1.html');
}


sub put_cache{
    my $config  = shift;
    my $request = shift;
    my $cache   = shift;

    #write to cache
    if ($config->{cache}->{use_cache} == 1){
        cache::save($cache);
    }
}

sub check_params{
    my $config = shift;
    my $params = shift;

    #get start and stop from projects
    my $range= project::get_date_range($config);
    my $start_date = $range->{start_date};
    my $end_date   = $range->{end_date};
    
#    my $project_name=$config->{project}||'';
#    log::error($config, 'no default project configured') if($project_name eq '');
#    log::error($config, "no configuration found for project '$project_name'") unless(exists($config->{projects}->{$project_name}));
#    my $project=$config->{projects}->{$project_name}||'';
#    log::erorr($config, 'no configuration found for project') if($project eq'');
#    if ((defined $params->{project}) && ($params->{project}=~/(\w+)/)){
#        $project=$config->{projects}->{$1} if exists($config->{projects}->{$1});
#    }

    #filter for date
    my $date=time::check_date($params->{date});
    #print STDERR $date."\n";
    if ($date eq ''){
        $date=time::time_to_date(time()) ;
    }
    #
    if ($date eq 'today'){
        $date=time::get_event_date($config);
    }

#    $date    =$config->{date}->{start_date}        if ($date lt $config->{date}->{start_date});
#    $date    =$config->{date}->{end_date}        if ($date gt $config->{date}->{end_date});
    $date    =$start_date if $date lt $start_date;
    $date    =$end_date   if $date gt $end_date;

    #filter for date
#    my $date=time::check_date($params->{date});
    my $time=time::check_time($params->{time});
    if ((defined $params->{today}) && ($params->{today}eq'1')){
        $date    =time::time_to_date(time());
        $params->{date}=$date;
    };

    my $from_date=time::check_date($params->{from_date});
    my $till_date=time::check_date($params->{till_date});

    my $previous_series=$params->{previous_series} || '';
    if(($previous_series)&&($previous_series=~/(\d+)/)){
        $params->{event_id}=events::get_previous_event_of_series(undef, $config, $1);
    }

    my $next_series=$params->{next_series} || '';
    if(($next_series)&&($next_series=~/(\d+)/)){
        $params->{event_id}=events::get_next_event_of_series(undef, $config, $1);
    }

    my $event_id=$params->{event_id}||'';
    unless ($event_id eq''){
        if ($event_id=~/(\d+)/){
            $event_id=$1;
        }else{
            log::error($config, "invalid event_id");
        }
    }

    my $debug=$params->{debug}||'';
    if ($debug=~/([a-z\_\,]+)/){
        $debug=$1;
    }

    #set query string for caching 
    if ((!exists $ENV{QUERY_STRING}) || ($ENV{QUERY_STRING}eq'')){
        my $options=[];
        push (@$options,'date='.$date)             if $date ne'';
        push (@$options,'from_date='.$from_date)   if $from_date ne'';
        push (@$options,'till_date='.$till_date)   if $till_date ne'';
        push (@$options,'event_id='.$event_id)     if $event_id ne'';
        $ENV{QUERY_STRING}=''.join("&",@$options);
    }

    return {
        date      => $date,
        time      => $time,
        from_date => $from_date,
        till_date => $till_date,
        event_id  => $event_id,
#        project  => $project,
        debug     => $debug,
    };
;
}

#do not delete last line!
1;
