package series; 

use warnings "all";
use strict;
use Data::Dumper;
use events;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    get_columns get insert update delete 
    get_users add_user remove_user 
    get_events get_event get_next_episode search_events 
    get_event_age is_event_older_than_days
    get_images
    assign_event unassign_event 
    add_series_ids_to_events set_event_ids 
    can_user_update_events can_user_create_events 
    is_series_assigned_to_user is_event_assigned_to_user
    update_recurring_events update_recurring_event
);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

#TODO: remove studio_id
#TODO: get project_id, studio_id by join with project_series

sub debug;

# get series columns
sub get_columns{
	my $config=shift;

	my $dbh=db::connect($config);
	my $cols=db::get_columns($dbh, 'calcms_series');
	my $columns={};
	for my $col (@$cols){
		$columns->{$col}=1;
	}
	return $columns;
}

# get series content
sub get{
	my $config=shift;
	my $condition=shift;

	my @conditions=();
	my @bind_values=();

	if ((defined $condition->{series_id}) && ($condition->{series_id} ne '')){
		push @conditions, 'id=?';
		push @bind_values, $condition->{series_id};
	}

	if ((defined $condition->{series_name}) && ($condition->{series_name} ne '')){
		push @conditions, 'series_name=?';
		push @bind_values, $condition->{series_name};
	}

	if ((defined $condition->{title}) && ($condition->{title} ne '')){
		push @conditions, 'title=?';
		push @bind_values, $condition->{title};
	}

	if ((defined $condition->{has_single_events}) && ($condition->{has_single_events} ne '')){
		push @conditions, 'has_single_events=?';
		push @bind_values, $condition->{has_single_events};
	}

	my $search_cond='';
	if ((defined $condition->{search}) && ($condition->{search} ne'')){
		my $search=lc $condition->{search};
		$search=~s/[^a-z0-9\_\.\-\:\!öäüßÖÄÜ \&]/%/;
		$search=~s/\%+/\%/;
		$search=~s/^[\%\s]+//;
		$search=~s/[\%\s]+$//;
		if ($search ne ''){
			$search='%'.$search.'%';
			my @attr=('title', 'series_name', 'excerpt', 'category', 'content');
			push @conditions, "(".join(" or ", map {'lower('.$_.') like ?'} @attr ).")";
			for my $attr (@attr){
				push @bind_values,$search;
			}
		}
	}

	my $query='';
	my $conditions='';
    
    if ((defined $condition->{project_id}) || (defined $condition->{studio_id})){
	    if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')){
		    push @conditions, 'ps.project_id=?';
		    push @bind_values, $condition->{project_id};
	    }

	    if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')){
		    push @conditions, 'ps.studio_id=?';
		    push @bind_values, $condition->{studio_id};
	    }
        push @conditions, 'ps.series_id=s.id';
	    $conditions=" where ".join(" and ",@conditions) if (@conditions>0);
	    $query=qq{
		    select	*
		    from 	calcms_series s, calcms_project_series ps
		    $conditions
		    order by has_single_events desc, series_name, title
	    };
    }else{
        # simple query
	    $conditions=" where ".join(" and ",@conditions) if (@conditions>0);
	    $query=qq{
		    select	*
		    from 	calcms_series
		    $conditions
		    order by has_single_events desc, series_name, title
	    };
    }

	my $dbh=db::connect($config);
	my $series=db::get($dbh, $query, \@bind_values);
    #print STDERR Dumper(time());
	for my $serie (@$series){
		$serie->{series_id}=$serie->{id};
		delete $serie->{id};
	}
	#print STDERR Dumper($series);
	return $series;
}

# insert series
sub insert{
	my $config=shift;
	my $series=shift;

    #print STDERR Dumper($series);
	return undef unless defined $series->{project_id};
	return undef unless defined $series->{studio_id};

    my $project_id=$series->{project_id};
    my $studio_id =$series->{studio_id};

    my $columns=series::get_columns($config);

    my $entry={};
    for my $column (keys %$columns){
        $entry->{$column}=$series->{$column} if defined $series->{$column};
    }

	$entry->{created_at} = time::time_to_datetime(time());
	$entry->{modified_at}= time::time_to_datetime(time());
    #print STDERR Dumper($entry);

	my $dbh=db::connect($config);
	my $series_id=db::insert($dbh, 'calcms_series', $entry);
	
	return undef unless defined $series_id;
	
    my $result=project::assign_series($config, {
        project_id => $project_id,
        studio_id  => $studio_id,
        series_id  => $series_id
    });
    return undef unless defined $result;
    return $series_id;
}

# update series
sub update{
	my $config=shift;
	my $series=shift;

	return undef unless defined $series->{project_id};
	return undef unless defined $series->{studio_id};
	return undef unless defined $series->{series_id};

    my $columns=series::get_columns($config);

    my $entry={};
    for my $column (keys %$columns){
        $entry->{$column}=$series->{$column} if defined $series->{$column};
    }
    $entry->{id}         = $series->{series_id};
	$entry->{modified_at}= time::time_to_datetime(time());

	my $values	=join(",", map {$_.'=?'} (keys %$entry));
	my @bind_values	=map {$entry->{$_}} (keys %$entry);
	push @bind_values, $entry->{id};

	my $query=qq{
		update calcms_series 
		set    $values
		where  id=?
	};
    #print STDERR Dumper($query).Dumper(\@bind_values);

	my $dbh=db::connect($config);
	return db::put($dbh, $query, \@bind_values);
}

# delete series, its schedules and series dates
# unassign its users and events
sub delete{
	my $config=shift;
	my $series=shift;
	
	return undef unless defined $series->{project_id};
	return undef unless defined $series->{studio_id};
	return undef unless defined $series->{series_id};

    my $project_id = $series->{project_id};
    my $studio_id  = $series->{studio_id};
    my $series_id  = $series->{series_id};

    unless(project::is_series_assigned($config, $series)==1){
        print STDERR "series is not assigned to project $project_id and studio $studio_id\n";
        return undef;
    };

    my $query       = undef;
    my $bind_values = undef;
	my $dbh=db::connect($config);

	$bind_values=[$project_id, $studio_id, $series_id];
    #delete schedules
	$query=qq{
		delete from calcms_series_schedule
		where project_id=? and studio_id=? and series_id=?
	};
	db::put($dbh, $query, $bind_values);

    #delete series dates
	$query=qq{
		delete from calcms_series_dates
		where project_id=? and studio_id=? and series_id=?
	};
	db::put($dbh, $query, $bind_values);

    #unassign users
    series::remove_user(
        $config, {
	        project_id => $project_id,
	        studio_id  => $studio_id,
	        series_id  => $series_id
        }
    );

    #unassign events
	$bind_values=[$project_id, $studio_id, $series_id];
	$query=qq{
		delete from calcms_series_events
		where project_id=? and studio_id=? and series_id=?
	};
	#print '<pre>$query'.$query.Dumper($bind_values).'</pre>';
	db::put($dbh, $query, $bind_values);
    
	project::unassign_series($config, {
	    project_id => $project_id,
	    studio_id  => $studio_id,
	    series_id  => $series_id
	});

	#delete series

    my $series_assignments=project::get_series_assignments(
        $config, {
            series_id  => $series_id
        }
    );
	if(@$series_assignments>1){
        print STDERR "do not delete series, due to assigned to other project or studio";
        return;
    }

	$bind_values=[$series_id];
	$query=qq{
	    delete from calcms_series 
	    where  id=?
	};
	#print STDERR $query.$query.Dumper($bind_values);
	db::put($dbh, $query, $bind_values);
}


# get users directly assigned to project, studio, series (editors)
sub get_users{
	my $config	  = shift;
	my $condition = shift;
	
	my @conditions=();
	my @bind_values=();

	if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')){
		push @conditions, 'us.project_id=?';
		push @bind_values, $condition->{project_id};
	}

	if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')){
		push @conditions, 'us.studio_id=?';
		push @bind_values, $condition->{studio_id};
	}

	if ((defined $condition->{series_id}) && ($condition->{series_id} ne '')){
		push @conditions, 'us.series_id=?';
		push @bind_values, $condition->{series_id};
	}

	if ((defined $condition->{name}) && ($condition->{name} ne '')){
		push @conditions, 'u.name=?';
		push @bind_values, $condition->{name};
	}

	my $conditions='';
	$conditions=" and ".join(" and ",@conditions) if (@conditions>0);

	my $query=qq{
		select u.id, u.name, u.full_name, u.email, us.modified_by, us.modified_at
		from   calcms_users u, calcms_user_series us 
		where  us.user_id=u.id
		$conditions
	};
	#print STDERR $query." ".Dumper(\@bind_values)."\n";
	my $dbh	=db::connect($config);
	my $result=db::get($dbh, $query, \@bind_values);
	#print STDERR $query." ".Dumper($result)."\n";
	return $result;
}

# assign user to series
sub add_user{
	my $config	  = shift;
	my $entry     = shift;

	return unless defined $entry->{project_id};
	return unless defined $entry->{studio_id};
	return unless defined $entry->{series_id};
	return unless defined $entry->{user_id};
	return unless defined $entry->{user};

	my $query=qq{
		select	id 
		from	calcms_user_series 
		where 	project_id=? and studio_id=? and series_id=? and user_id=?
	};
	my $bind_values=[$entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{user_id}];

	my $dbh	=db::connect($config);
	my $results=db::get($dbh, $query, $bind_values);
	return unless (@$results==0);

	$query=qq{
		insert calcms_user_series 
		set    project_id=?, studio_id=?, series_id=?, user_id=?, modified_by=?, modified_at=now()
	};
	$bind_values=[$entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{user_id}, $entry->{user}];
	db::put($dbh, $query, $bind_values);
}

# remove user(s) from series.
sub remove_user{
	my $config	  = shift;
	my $condition = shift;
	
	return unless(defined $condition->{project_id});
	return unless(defined $condition->{studio_id});
	return unless(defined $condition->{series_id});

	my @conditions=();
	my @bind_values=();

	if ((defined $condition->{project_id}) && ($condition->{project_id} ne '')){
		push @conditions, 'project_id=?';
		push @bind_values, $condition->{project_id};
	}

	if ((defined $condition->{studio_id}) && ($condition->{studio_id} ne '')){
		push @conditions, 'studio_id=?';
		push @bind_values, $condition->{studio_id};
	}

	if ((defined $condition->{series_id}) && ($condition->{series_id} ne '')){
		push @conditions, 'series_id=?';
		push @bind_values, $condition->{series_id};
	}

	if ((defined $condition->{user_id}) && ($condition->{user_id} ne '')){
		push @conditions, 'user_id=?';
		push @bind_values, $condition->{user_id};
	}

	my $conditions='';
	$conditions=join(" and ",@conditions) if (@conditions>0);

	my $query=qq{
		delete from calcms_user_series 
		where  $conditions
	};
	my $dbh	=db::connect($config);
	db::put($dbh, $query, \@bind_values);
}

#search events by series_name and title (for events not assigned yet) 
#TODO: add location
sub search_events{
    my $config  = shift;
	my $request = shift;
	my $options = shift;

	my $series_name =$options->{series_name}||'';
	my $title       =$options->{title}||'';
    return undef if(($series_name eq '') && ($title eq '') );

	$series_name=~s/[^a-zA-Z0-9 \-]+/\?/g;
	$title      =~s/[^a-zA-Z0-9 \-]+/\?/g;

	$series_name=~s/\?+/\?/g;
	$title      =~s/\?+/\?/g;

	my $params={
		series_name => $series_name,
		title       => $title,
		template    => 'no'
	};
	if (defined $options){
		$params->{from_date} = $options->{from_date}	if (defined $options->{from_date});
		$params->{till_date} = $options->{till_date}	if (defined $options->{till_date});
		$params->{location}	 = $options->{location} 	if (defined $options->{location});
		$params->{limit}	 = $options->{limit} 	    if (defined $options->{limit});
		$params->{archive}	 = $options->{archive} 	    if (defined $options->{archive});
        $params->{get}       = $options->{get}          if (defined $options->{get});
	}

	my $checked_params=events::check_params($config, $params);
	#print STDERR '<pre>'.Dumper($checked_params).'</pre>';
	my $request2={
		params=>{
			checked=>$checked_params
		},
		config      => $request->{config},
		permissions => $request->{permissions}
	};
	#my $debug=1;
	#print STDERR Dumper($request2->{params});
	my $events=events::get($config, $request2);
	#print Dumper($events);
	return $events;
}

#get events (only assigned ones) by project_id,studio_id,series_id,
sub get_events{
	my $config=shift;
	my $options=shift;

	#print STDERR Dumper($options);
	return [] if defined ($options->{series_id}) && ($options->{series_id} <=0);

	my @conditions=();
	my @bind_values=();

	if(defined $options->{project_id}){
		push @conditions, 'se.project_id = ?';
		push @bind_values, $options->{project_id};
	}
	if(defined $options->{studio_id}){
		push @conditions, 'se.studio_id = ?';
		push @bind_values, $options->{studio_id};
	}
	if( (defined $options->{series_id}) && ($options->{series_id}=~/(\d+)/) ){
		push @bind_values, $1;
		push @conditions, 'se.series_id = ?';
	}

	if(defined $options->{event_id}){
		push @bind_values, $options->{event_id};
		push @conditions, 'e.id = ?';
	}

	if( (defined $options->{from_date}) && ($options->{from_date}=~/(\d\d\d\d\-\d\d\-\d\d)/) ){
		push @bind_values, $1;
		push @conditions, 'e.start_date >= ?';
	}
	if( (defined $options->{till_date}) && ($options->{till_date}=~/(\d\d\d\d\-\d\d\-\d\d)/) ){
		push @bind_values, $1;
		push @conditions, 'e.start_date <= ?';
	}
	if(defined $options->{location}){
		push @conditions, 'e.location = ?';
		push @bind_values, $options->{location};
	}
	my $conditions='';
	if (@conditions>0){
		$conditions=' and '.join(' and ', @conditions);
	}
	my $limit='';
	if( (defined $options->{limit}) && ($limit=~/(\d+)/) ){
		$limit='limit '.$1;
	}

	my $query=qq{
		select * 
			,date(start) 		start_date
			,date(end) 			end_date
			,weekday(start) 	weekday
			,weekofyear(start) 	week_of_year
			,dayofyear(start) 	day_of_year
			,start_date         day
			,id					event_id
            ,location           location
		from  calcms_series_events se, calcms_events e
		where se.event_id = e.id
		$conditions
		order by start_date desc
		$limit
	};
	#print STDERR '<pre>'.$query.Dumper(\@bind_values).'</pre>';

	my $dbh=db::connect($config);
	my $results=db::get($dbh, $query, \@bind_values);
	$results=events::modify_results($dbh, $config, {base_url=>'', params=>{checked=>{template=>''}}}, $results);

    #add studio id to events
	my $studios=studios::get($config, $options);

	my $studio_id_by_location={};
	for my $studio (@$studios){
		$studio_id_by_location->{$studio->{location}}=$studio->{id};
	}
    for my $result (@$results){
        $result->{studio_id}=$studio_id_by_location->{$result->{location}};
    }

	#print STDERR Dumper($results);
	return $results;
}

# load event given by studio_id, series_id and event_id
# helper for gui - errors are written to gui output
# return undef on error
sub get_event{
    my $config=shift;
    my $options=shift;

    my $project_id = $options->{project_id}||'';
    my $studio_id  = $options->{studio_id}||'';
    my $series_id  = $options->{series_id}||'';
    my $event_id   = $options->{event_id} ||'';

    unless(defined($options->{allow_any})){
        if ($project_id eq''){
            uac::print_error("missing project_id");
            return undef;
        }
        if ($studio_id eq''){
            uac::print_error("missing studio_id");
            return undef;
        }
        if ($series_id eq''){
            uac::print_error("missing series_id");
            return undef;
        }
    }

    if ($event_id eq''){
        uac::print_error("missing event_id");
        return undef;
    }

    my $queryOptions={};
    $queryOptions->{project_id} = $project_id if $project_id ne '';
    $queryOptions->{studio_id}  = $studio_id  if $studio_id  ne '';
    $queryOptions->{series_id}  = $series_id  if $series_id  ne '';
    $queryOptions->{event_id}   = $event_id   if $event_id   ne '';

    my $events=series::get_events($config, $queryOptions);

    unless (defined $events){
        uac::print_error("error on loading event");
        return undef;
    }

    if(@$events==0){
        uac::print_error("event not found");
        return undef;
    }

    if(@$events>1){
        print STDERR q{multiple assignments found for }
            .q{project_id=}.$options->{project_id}
            .q{, studio_id=}.$options->{studio_id}
            .q{, series_id=}.$options->{series_id}
            .q{, event_id=}.$options->{event_id}
            ."\n";
    }
    my $event=$events->[0];
    return $event;
}

# get name and title of series and age in days ('days_over')
sub get_event_age{
	my $config=shift;
	my $options=shift;

	#print STDERR Dumper($options);
	return undef unless defined $options->{project_id};
	return undef unless defined $options->{studio_id};

	my @conditions=();
	my @bind_values=();

	if( (defined $options->{project_id}) && ($options->{project_id}=~/(\d+)/) ){
		push @bind_values, $1;
		push @conditions, 'ps.project_id = ?';
	}

	if( (defined $options->{studio_id}) && ($options->{studio_id}=~/(\d+)/) ){
		push @bind_values, $1;
		push @conditions, 'ps.studio_id = ?';
	}

	if( (defined $options->{series_id}) && ($options->{series_id}=~/(\d+)/) ){
		push @bind_values, $1;
		push @conditions, 's.id = ?';
	}

	if( (defined $options->{event_id}) && ($options->{event_id}=~/(\d+)/) ){
		push @bind_values, $1;
		push @conditions, 'e.id = ?';
	}

	my $conditions='';
	if (@conditions>0){
		$conditions=join(' and ', @conditions);
	}
    my $query=qq{
        select s.id series_id, s.series_name, s.title, s.has_single_events has_single_events, (to_days(now())-to_days(max(e.start))) days_over 
        from      calcms_project_series ps
        left join calcms_series s         on ps.series_id=s.id 
        left join calcms_series_events se on s.id=se.series_id 
        left join calcms_events e         on e.id=se.event_id
        where  $conditions
        group  by s.id 
        order  by has_single_events desc, days_over
    };
    
    #print STDERR $query." ".Dumper(\@bind_values);
	my $dbh=db::connect($config);
	my $results=db::get($dbh, $query, \@bind_values);

    for my $result (@$results){
        $result->{days_over}=0 unless defined $result->{days_over};
    }
	return $results;
}

# is event older than max_age days
sub is_event_older_than_days{
    my $config=shift;
    my $options=shift;
    #print STDERR Dumper($options);

	return 1 unless defined $options->{project_id};
	return 1 unless defined $options->{studio_id};
	return 1 unless defined $options->{series_id};
	return 1 unless defined $options->{event_id};
	return 1 unless defined $options->{max_age};

    my $events=series::get_event_age($config, {
        project_id => $options->{project_id}, 
        studio_id  => $options->{studio_id}, 
        series_id  => $options->{series_id},
        event_id   => $options->{event_id} 
    });

    if (scalar(@$events)==0){
        print STDERR "series_events::event_over_in_days: event $options->{event_id} is not assigned to project $options->{project_id}, studio $options->{studio_id}, series $options->{series_id}\n";
        return 1;
    }
    my $event=$events->[0];
    #print STDERR Dumper($event);
    return 1 if $event->{days_over} > $options->{max_age};
    return 0;
}

sub get_next_episode{
	my $config=shift;
	my $options=shift;

    return 0 unless defined $options->{project_id};
    return 0 unless defined $options->{studio_id};
    return 0 unless defined $options->{series_id};

    #return if episodes should not be counted for this series
    my $query=q{
        select count_episodes 
        from   calcms_series
        where  id=?
    };
    my $bind_values=[$options->{series_id}];
	my $dbh=db::connect($config);
	my $results=db::get($dbh, $query, $bind_values);
	return 0 if (@$results != 1);
	return 0 if ($results->[0]->{count_episodes}eq'0');
    #print STDERR Dumper($results);

    #get all 
    $query=q{
        select title,episode from calcms_events e, calcms_series_events se
        where se.project_id=? and se.studio_id=? and se.series_id=? and se.event_id=e.id
    };
    $bind_values=[$options->{project_id}, $options->{studio_id}, $options->{series_id}];
	$results=db::get($dbh, $query, $bind_values);
	
    my $max=0;
    for my $result (@$results){
        if ($result->{title}=~/\#(\d+)/){
            my $value=$1;
            $max=$value if $value>$max;
        }
        next unless defined $result->{episode};
        $max=$result->{episode} if $result->{episode}>$max;
    }
    return $max+1;
}

sub get_images{
    my $config=shift;
    my $options=shift;

    return undef unless defined $options->{project_id};
    return undef unless defined $options->{studio_id};
    return undef unless defined $options->{series_id};

    #get images from all events of the series
	my $dbh=db::connect($config);
    my $events=series::get_events( $config, {
        project_id => $options->{project_id}, 
        studio_id  => $options->{studio_id}, 
        series_id  => $options->{series_id}
    });
    my $images={};
    my $found=0;
    for my $event (@$events){
        my $image=$event->{image};
        $image=~s/.*\///;
        $images->{$image}=1;
        $found++;
    }
    
    return undef if $found==0;

    # get all images from database    
    my @cond=();
    my $bind_values=[];
    for my $image (keys %$images){
		push @cond, 'filename=?';
		push @$bind_values, $image;
	}

	my $where='';
	if (@cond>0){
		$where = 'where '.join (' or ', @cond);
	}

    my $limit='';
	if ( (defined $options->{limit}) && ($options->{limit}=~/(\d+)/) ){
		$limit=' limit '.$1;
	}

	my $query=qq{
		select	*
		from 	calcms_images
		$where
		order by created_at desc
		$limit
	};
	#print STDERR Dumper($query).Dumper($bind_values);
	my $results=db::get($dbh, $query, $bind_values);

    #print STDERR @$results."\n";
	return $results;
}

#assign event to series
#TODO: manual assign needs to update automatic one
sub assign_event{
	my $config=shift;
	my $entry=shift;
	
    #print STDERR Dumper($entry);
	return undef unless defined $entry->{project_id};
	return undef unless defined $entry->{studio_id};
	return undef unless defined $entry->{series_id};
	return undef unless defined $entry->{event_id};
    $entry->{manual}=0 unless ((defined $entry->{manual})&&($entry->{manual}eq'1'));

    my $conditions='';
    $conditions='and manual=1' if ($entry->{manual}eq'1');

	my $query=qq{
		select * from calcms_series_events 
		where project_id=? and studio_id=? and series_id=? and event_id=? $conditions
	};
	my $bind_values=[$entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{event_id}];
	my $dbh=db::connect($config);
	my $results=db::get($dbh, $query, $bind_values);

    if(@$results>1){
        print STDERR "multiple assignments of project_id=$entry->{project_id}, studio_id=$entry->{studio_id}, series_id=$entry->{series_id}, event_id=$entry->{event_id}\n";
        return;
    }
    if(@$results==1){
        print STDERR "already assigned: project_id=$entry->{project_id}, studio_id=$entry->{studio_id}, series_id=$entry->{series_id}, event_id=$entry->{event_id}\n";
        return;
    }

	$query=qq{
		insert into calcms_series_events (project_id, studio_id, series_id, event_id, manual)
		values (?,?,?,?,?)
	};
	$bind_values=[$entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{event_id}, $entry->{manual}];
	#print STDERR '<pre>'.$query.Dumper($bind_values).'</pre>';
	return db::put($dbh, $query, $bind_values);
}

#unassign event from series
sub unassign_event{
	my $config=shift;
	my $entry=shift;
	
	return unless defined $entry->{project_id};
	return unless defined $entry->{studio_id};
	return unless defined $entry->{series_id};
	return unless defined $entry->{event_id};

    my $conditions='';
    $conditions='and manual=1' if ((defined $entry->{manual}) && ($entry->{manual}eq'1'));

	my $query=qq{
		delete from calcms_series_events 
		where project_id=? and studio_id=? and series_id=? and event_id=? 
		$conditions
	};
	my $bind_values=[$entry->{project_id}, $entry->{studio_id}, $entry->{series_id}, $entry->{event_id}];
	#print STDERR '<pre>'.$query.Dumper($bind_values).'</pre>';
	my $dbh=db::connect($config);
	return db::put($dbh, $query, $bind_values);
}


# put series id to given events (for legacy handling)
# used by calendar
# TODO: optionally add project_id and studio_id to conditions
sub add_series_ids_to_events{
	my $config=shift;
	my $events=shift;

	#get event ids from given events
	my @event_ids=();
	for my $event (@$events){
		push @event_ids, $event->{event_id};
	}

	return if (@event_ids==0);

	my @bind_values	=@event_ids;
	my $event_ids	=join(',', map {'?'} @event_ids);

	#query series ids
	my $dbh=db::connect($config);
	my $query=qq{
		select project_id, studio_id, series_id, event_id
		from calcms_series_events 
		where event_id in ($event_ids)
	};
	my $results=db::get($dbh, $query, \@bind_values);
	my @results=@$results;
	return [] unless (@results>0);

	#build hash of series ids by event ids
	my $assignments_by_event_id={};
	for my $entry (@$results){
        my $event_id=$entry->{event_id};
		$assignments_by_event_id->{$event_id}=$entry;
	}
	
	#fill in ids into events
	for my $event (@$events){
        my $event_id=$event->{event_id};
        my $assignment=$assignments_by_event_id->{$event_id};
        if (defined $assignment){
	    	$event->{project_id} = $assignment->{project_id};
	    	$event->{studio_id}  = $assignment->{studio_id};
	    	$event->{series_id}  = $assignment->{series_id};
        }
	}

}


# add event_ids to series and remove all event ids from series, not given event_ids
# for scan only, used at series
sub set_event_ids{
	my $config=shift;
	my $project_id=shift;
	my $studio_id=shift;
	my $serie=shift;
	my $event_ids=shift;

	my $serie_id=$serie->{series_id};
	return unless defined $project_id;
	return unless defined $studio_id;
	return unless defined $serie_id;
	return unless defined $event_ids;

	#make lookup table from events
	my $event_id_hash={};
	for my $event_id (@$event_ids){
		$event_id_hash->{$event_id}=1;
	}

	#get series_entries from db
	#my $bind_names=join(',', (map { '?' } @$event_ids));
	my $query=qq{
		select event_id from calcms_series_events
		where project_id=? and studio_id=? and series_id=? 
	};
	my $bind_values=[$project_id, $studio_id, $serie_id];

	my $dbh=db::connect($config);
	my $results=db::get($dbh, $query, $bind_values);

	my $found={};
	#mark events found assigned to series
	my $i=1;
	for my $event (@$results){
		#print "found event $i: $event->{event_id}\n";
		$found->{$event->{event_id}}=1;
		$i++;
	}
	#insert events from list, not found in db
	for my $event_id (@$event_ids){
		#print "insert event_id $event_id\n";
		series::assign_event(
		    $config, {
		        project_id => $project_id,
    		    studio_id  => $studio_id, 
	    	    series_id  => $serie_id, 
	    	    event_id   => $event_id
	    	}
	    ) unless ($found->{$event_id});
	}
	#delete events found in db, but not in list
	for my $event_id (keys %$found){
		#print "delete event_id $event_id\n";
		series::unassign_event(
		    $config, {
		        project_id => $project_id,
    		    studio_id  => $studio_id, 
	    	    series_id  => $serie_id, 
	    	    event_id   => $event_id,
                manual     => 0
            }
        ) unless (defined $event_id_hash->{$event_id});
	}

}

# check if user allowed to update series events
# evaluate permissions and consider editors directly assigned to series
sub can_user_update_events{
	my $request=shift;
	my $options=shift;

	my $config      = $request->{config};
	my $permissions = $request->{permissions};

    return 0 unless defined $request->{user};
    return 0 unless defined $options->{project_id};
    return 0 unless defined $options->{studio_id};
    return 0 unless defined $options->{series_id};

    return 1 if ( (defined $permissions->{update_event_of_others}) && ($permissions->{update_event_of_others}eq'1'));
    return 1 if ( (defined $permissions->{is_admin}) && ($permissions->{is_admin} eq'1'));
    return 0 if ( $permissions->{update_event_of_series}ne'1');

    return is_series_assigned_to_user($request, $options);
}

# check if user allowed to create series events
# evaluate permissions and consider editors directly assigned to series
sub can_user_create_events{
	my $request=shift;
	my $options=shift;

	my $config      = $request->{config};
	my $permissions = $request->{permissions};

    return 0 unless defined $request->{user};
    return 0 unless defined $options->{project_id};
    return 0 unless defined $options->{studio_id};
    return 0 unless defined $options->{series_id};

    return 1 if ( (defined $permissions->{create_event}) && ($permissions->{create_event}eq'1'));
    return 1 if ( (defined $permissions->{is_admin}) && ($permissions->{is_admin} eq'1'));
    return 0 if ( $permissions->{create_event_of_series}ne'1');

    return is_series_assigned_to_user($request, $options);
}

sub is_series_assigned_to_user{
	my $request=shift;
	my $options=shift;

	my $config      = $request->{config};
	my $permissions = $request->{permissions};

    return 0 unless defined $options->{project_id};
    return 0 unless defined $options->{studio_id};
    return 0 unless defined $options->{series_id};
    return 0 unless defined $request->{user};

    my $series_users = series::get_users(
        $config, {
            project_id => $options->{project_id},
            studio_id  => $options->{studio_id}, 
            series_id  => $options->{series_id},
            name       => $request->{user}
        }
    );
	return 0 if (@$series_users==0);
    return 1;
}

# check if user is assigned to studio where location matchs to event
# return 1 on success or error text
sub is_event_assigned_to_user{
	my $request=shift;
	my $options=shift;

	my $config      = $request->{config};

    return "missing user"       unless defined $request->{user};
    return "missing project_id" unless defined $options->{project_id};
    return "missing studio_id"  unless defined $options->{studio_id};
    return "missing series_id"  unless defined $options->{series_id};
    return "missing event_id"   unless defined $options->{event_id};

    #check roles
	my $user_studios=uac::get_studios_by_user(
	    $config, {
            project_id => $options->{project_id}, 
            studio_id  => $options->{studio_id}, 
	        user       => $request->{user}, 
	    }
	);
	return "user is not assigned to studio" if @$user_studios==0;
	my $studio=$user_studios->[0];
	my $location=$studio->{location};
    return "could not get studio location" if $location eq'';

    #TODO: replace legacy support
	my $events=series::get_events(
		$config, {
		    project_id => $options->{project_id},
            studio_id  => $options->{studio_id}, 
            series_id  => $options->{series_id},
            event_id   => $options->{event_id},
			location   => $location,
			limit 	   => 1
		}
	);
	#print STDERR Dumper(@$events);
	return "no event found for"
	    ." project $options->{project_id},"
	    ." studio $options->{studio_id},"
	    ." location $location,"
	    ." series $options->{series_id}"
	    ." and event $options->{event_id}" if @$events==0;
	return 1;
}

# to find multiple recurrences this does not include the recurrence_count 
# use events::get_key to add the recurrence
sub get_event_key{
    my $event=shift;
    
    my $program     = $event->{program} || '';
    my $series_name = $event->{series_name} || '';
    my $title       = $event->{title} || '';
    my $user_title  = $event->{user_title} || '';
    my $episode     = $event->{episode} || '';
    
    my $key='';
    $key.=$series_name  if  $series_name ne '';
    $key.=' - '         if ($series_name ne '') && ($title ne '');
    $key.=$title        if  $title ne '';
    $key.=': '          if ($title ne '') && ($user_title ne '');
    $key.=$user_title   if $user_title ne '';
    $key.=' #'.$episode if $episode ne '';
    return $key;
}

sub update_recurring_events{
	my $config=shift;
	my $options=shift;

    return "missing project_id" unless defined $options->{project_id};
    return "missing studio_id"  unless defined $options->{studio_id};
    return "missing series_id"  unless defined $options->{series_id};
    return "missing event_id"   unless defined $options->{event_id};

	my $events=series::get_events(
		$config, {
		    project_id => $options->{project_id},
            studio_id  => $options->{studio_id}, 
            series_id  => $options->{series_id},
		}
	);
	@$events=sort { $a->{start} cmp $b->{start}} @$events;

    # store events with recurrences by key (series_name, title, user_title, episode)
	my $events_by_key={};
	for my $event (@$events){
	    my $key=get_event_key($event);
	    next unless $key=~/\#\d+$/;
	    $event->{key}=$key;
        push @{$events_by_key->{$key}}, $event;
	}
	
	# handle all events with the same key
	for my $key (keys %$events_by_key){
        my $events=$events_by_key->{$key};
        next unless scalar @$events >0;

        if(scalar @$events ==1){
            # one event found -> check if recurrence is to be removed
            my $event=$events->[0];
            next if $event->{recurrence}==0;
            next if $event->{recurrence_count}==0;
            print STDERR "remove recurrence\t'$event->{event_id}'\t'$event->{start}'\t'$event->{rerun}'\t'$event->{recurrence}'\t'$event->{key}'\n";
            $event->{recurrence}=0;
            $event->{recurrence_count}=0;
            $event->{rerun}=0;
            series::update_recurring_event($config, $event);
            
        }elsif(scalar @$events >1){
            # multiple events found with same key
            # first event is the original
            my $event=$events->[0];
            my $originalId = $event->{event_id};
            print STDERR "0\t'$event->{recurrence_count}'\t'$event->{event_id}'\t'$event->{start}'\t'$event->{rerun}'\t'$event->{recurrence}'\t'$event->{key}'\n";

            # succeeding events are reruns
            for (my $c=1; $c < scalar(@$events); $c++){
                my $event=$events->[$c];
                print STDERR "$c\t'$event->{recurrence_count}'\t'$event->{event_id}'\t'$event->{start}'\t'$event->{rerun}'\t'$event->{recurrence}'\t'$event->{key}'\n";

                my $update=0;
                $update = 1 if $event->{recurrence} ne $originalId;
                $update = 1 if $event->{rerun} ne '1';
                $update = 1 if $event->{recurrence_count} ne $c;
                next if $update == 0;
                
                $event->{recurrence}=$originalId;
                $event->{recurrence_count}=$c;
                $event->{rerun}=1;
                series::update_recurring_event($config, $event);
            }
        }
	}
}

sub update_recurring_event{
    my $config=shift;
    my $event =shift;
    
    return undef unless defined $event->{event_id};
    return undef unless defined $event->{recurrence};
    return undef unless defined $event->{recurrence_count};
    return undef unless defined $event->{rerun};
    
    return unless $event->{event_id}=~/^\d+$/;
    return unless $event->{recurrence}=~/^\d+$/;
    return unless $event->{recurrence_count}=~/^\d+$/;
    return unless $event->{rerun}=~/^\d+$/;

	my $bind_values=[];
	push @$bind_values, $event->{recurrence};
	push @$bind_values, $event->{recurrence_count};
	push @$bind_values, $event->{rerun};
	push @$bind_values, $event->{id};

	my $update_sql=qq{
		update calcms_events
		set 	recurrence=?, recurrence_count=?, rerun=?
		where	id=?
	};
	#print STDERR $update_sql."\n".Dumper($bind_values)."\n";
	my $dbh=db::connect($config);
	db::put($dbh, $update_sql, $bind_values);
}

sub error{
	my $msg=shift;
	print "ERROR: $msg<br/>\n";
}

#do not delete last line!
1;
