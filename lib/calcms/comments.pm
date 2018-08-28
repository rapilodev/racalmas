use warnings "all";
use strict;
use Data::Dumper;
use config();
use template();
use time();

package comments;
use warnings "all";
use strict;
use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);

#our @EXPORT = qw(all);
our @EXPORT_OK =
  qw(init get_cached_or_render get modify_results render configure_cache get_query get_by_event get_level get_events check insert set_lock_status set_news_status lock update_comment_count sort);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

sub init {
}

sub get_cached_or_render {

	#    my $response=$_[0];
	my $config      = $_[1];
	my $request     = $_[2];
	my $mark_locked = $_[3];

	my $params = $request->{params}->{checked};

	#print STDERR Dumper($params);
	$config->{app_name} = $config->{controllers}->{comments};

	my $comment = $request->{params}->{checked};

	my $filename = '';
	my $cache    = {};

	my $results = comments::get( $config, $request );

	if ( ( defined $mark_locked ) && ( $mark_locked eq 'mark_locked' ) ) {
		for my $result (@$results) {
			if ( $result->{lock_status} ne 'show' ) {
				$result->{author}  = 'Zensur';
				$result->{content} = 'Dieser Eintrag wurde gel&ouml;scht.';
			}
		}
	} elsif ( ( defined $mark_locked ) && ( $mark_locked eq 'filter_locked' ) ) {
		my @results2 = ();
		for my $result (@$results) {
			push @results2, $result if ( $result->{lock_status} eq 'show' );
		}
		$results = \@results2;
	}

	comments::modify_results( $results, $config, $request );

	#print STDERR Dumper($results);
	$results = comments::sort( $config, $results ) if ( $comment->{type} eq 'tree' );

	#print STDERR Dumper($results);
	#    if ($comment->{sort_order}eq'desc'){
	#        my @results= reverse(@$results);
	#        $results=\@results;
	#    }

	if (   ( $params->{show_max} ne '' )
		&& ( $params->{limit} ne '' )
		&& ( $params->{show_max} < $params->{limit} ) )
	{
		my @results2 = ();
		my $c        = 0;
		for my $result (@$results) {
			push @results2, $result;
			$c++;
			last if ( $c >= $params->{show_max} );
		}
		$results = \@results2;
	}

	comments::render( $_[0], $config, $request, $results );

}

sub get {
	my $config  = shift;
	my $request = shift;

	my $params = $request->{params}->{checked};

	my $dbh = db::connect( $config, $request );

	( my $query, my $bind_values ) = comments::get_query( $dbh, $config, $request );

	#print STDERR Dumper($$query);
	#print STDERR Dumper($bind_values);
	my $results = db::get( $dbh, $$query, $bind_values );

	#print STDERR Dumper($results);
	return $results;
}

sub get_query {
	my $dbh     = shift;
	my $config  = shift;
	my $request = shift;

	my $params = $request->{params}->{checked};

	my $event_id    = undef;
	my $event_start = undef;
	my $from        = 'calcms_comments c';
	my $where       = '';
	my $limit       = '';
	my @conditions  = ();
	my $bind_values = [];

	#exclude comments from config filter/locations_to_exclude
	if (   ( defined $config->{filter} )
		&& ( defined $config->{filter}->{locations_to_exclude} ) )
	{
		my @locations_to_exclude = split( /[,\s]+/, $config->{filter}->{locations_to_exclude} );
		my $locations_to_exclude = join( ', ', map { '?' } @locations_to_exclude );

		$from .= ',calcms_events e';
		push @conditions, 'e.id=c.event_id';
		push @conditions, 'e.location not in (' . $locations_to_exclude . ')';
		for my $location (@locations_to_exclude) {
			push @$bind_values, $location;
		}
	}

	if (   ( defined $params->{event_id} && $params->{event_id} ne '' )
		&& ( defined $params->{event_start} && $params->{event_start} ne '' ) )
	{
		#$where        =qq{ and (event_id=? or event_start=?) };
		push @conditions,   q{ (event_id=? or event_start=?) };
		push @$bind_values, $params->{event_id};
		push @$bind_values, $params->{event_start};
	}

	my $sort_order = $params->{sort_order};

	if ( $params->{limit} ne '' ) {
		$limit = 'limit ?';
		push @$bind_values, $params->{limit};
	}

	if ( @conditions > 0 ) {
		$where = 'where ' . join( ' and ', @conditions );
	}

	my $dbcols = [
		'id',         'event_start', 'event_id',  'content', 'ip',          'author', 'email', 'lock_status',
		'created_at', 'title',       'parent_id', 'level',   'news_status', 'project'
	];
	my $cols = join( ', ', map { 'c.' . $_ } @$dbcols );
	my $query = qq{
        select    $cols
        from      $from
        $where
        order by  created_at $sort_order
        $limit
    };

	#        where     lock_status='show'
	#    use Data::Dumper;print STDERR Dumper($query);

	return ( \$query, $bind_values );
}

sub modify_results {
	my $results = $_[0];
	my $config  = $_[1];
	my $request = $_[2];

	my $params = $request->{params}->{checked};

	my $time_diff = '';
	if ( $params->{template} =~ /\.xml/ ) {
		$time_diff = time::utc_offset( $config->{date}->{time_zone} );
		$time_diff =~ s/(\d\d)(\d\d)/$1\:$2/g;
	}

	my $language = $config->{date}->{language} || 'en';

	for my $result (@$results) {
		$result->{allow}->{new_comments} = 1 if ( $params->{allow}->{new_comments} );
		$result->{start_date_name} = time::date_format( $result->{created_at}, $language );
		$result->{start_time_name} = time::time_format( $result->{created_at} );
		my $comment_limit = 100;
		if ( length( $result->{content} ) > $comment_limit ) {
			$result->{short_content} = substr( $result->{content}, 0, $comment_limit ) . '...';
		} else {
			$result->{short_content} = $result->{content};
		}
		$result->{base_url}       = $config->{locations}->{base_url};
		$result->{cache_base_url} = $config->{cache}->{base_url};

		if ( $params->{template} =~ /\.xml/ ) {

			#            $result->{content}    =~s/(\[\[.*?\]\])//gi;
			#            $result->{content}    =markup::plain_to_xml($result->{content});
			#            $result->{content}    =$result->{html_content};

			$result->{content}       = markup::html_to_plain( $result->{html_content} );
			$result->{short_content} = markup::html_to_plain( $result->{short_content} );
			$result->{excerpt}       = "lass dich ueberraschen" if ( ( defined $result->{excerpt} ) && ( $result->{excerpt} eq '' ) );
			$result->{excerpt}       = markup::html_to_plain( $result->{excerpt} );
			$result->{title}         = markup::html_to_plain( $result->{title} );
			$result->{series_name}   = markup::html_to_plain( $result->{series_name} );
			$result->{program}       = markup::html_to_plain( $result->{program} );

			if ( defined $result->{created_at} ) {
				$result->{created_at} =~ s/ /T/gi;
				$result->{created_at} .= $time_diff;
			}

			if ( defined $result->{modified_at} ) {
				$result->{modified_at} =~ s/ /T/gi;
				$result->{modified_at} .= $time_diff;
			}
		}
	}
	return $results;
}

sub render {

	#    my $response    =$_[0];
	my $config  = $_[1];
	my $request = $_[2];
	my $results = $_[3];

	my $params = $request->{params}->{checked};

	my %template_parameters = %$params;
	my $template_parameters = \%template_parameters;

	$template_parameters->{comments}      = $results;
	$template_parameters->{comment_count} = (@$results) + 0;
	$template_parameters->{one_result}    = 1 if ( $template_parameters->{comment_count} == 1 );
	$template_parameters->{allow}->{new_comments} = 1 if ( $params->{allow}->{new_comments} );

	$template_parameters->{event_id}    = $params->{event_id};
	$template_parameters->{event_start} = $params->{event_start};

	$template_parameters->{server_cache}     = $config->{cache}->{server_cache}     if ( $config->{cache}->{server_cache} );
	$template_parameters->{use_client_cache} = $config->{cache}->{use_client_cache} if ( $config->{cache}->{use_client_cache} );
	$template_parameters->{controllers}      = $config->{controllers};
	template::process( $_[0], $params->{template}, $template_parameters );
}

#check if comment exists already
sub check {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	my $query = qq{
        select  id
        from    calcms_comments
        where (
            event_start=?
            or  event_id=?
            )
            and parent_id=?
            and author=?
            and ip=?
            and content=?
    };
	my $bind_values =
	  [ $comment->{event_start}, $comment->{event_id}, $comment->{parent_id}, $comment->{author}, $comment->{ip}, $comment->{content} ];

	my $comments = db::get( $dbh, $query, $bind_values );

	my @comments = @$comments;
	return 0 if ( @comments > 0 );
	return 1;
}

#used for insert
sub get_level {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	my $parent_id = $comment->{parent_id};
	return 0 unless defined $parent_id;
	if ( $parent_id =~ /(\d+)/ ) {
		$parent_id = $1;
	}
	return 0 unless $parent_id =~ /^\d+$/;
	return 0 if $parent_id == 0;

	#get level from parent node
	my $query = qq{
        select  level
        from    calcms_comments
        where (
                event_start=?
                or event_id=?
            )
        and id=?
        limit 1
    };
	my $bind_values = [ $comment->{event_start}, $comment->{event_id}, $parent_id ];

	my $comments = db::get( $dbh, $query, $bind_values );

	my @comments = @$comments;
	if ( @comments > 0 ) {
		return $comments->[0]->{level} + 1;
	}
	return 0;
}

sub get_by_event {
	my $dbh     = shift;
	my $config  = shift;
	my $request = $_[0];

	my $params = $request->{params}->{checked}->{comment};

	my $event_id    = undef;
	my $search      = undef;
	my $where       = '';
	my $limit       = '';
	my $bind_values = [];

	if ( $params->{event_id} ne '' ) {
		$where       = qq{ event_id=? };
		$bind_values = [ $params->{event_id} ];
	}

	if ( ( defined $params->{search} ) && ( $params->{search} ne '' ) ) {
		$search      = '%' . $params->{search} . '%';
		$where       = qq{ (content like ?) or (email like ?) or (author like ?) or (ip like ?)};
		$bind_values = [ $search, $search, $search, $search ];
	}

	my $sort_order = $params->{sort_order} || 'desc';

	if ( ( defined $params->{limit} ) && ( $params->{limit} ne '' ) ) {
		$limit = 'limit ?';
		push @$bind_values, $params->{limit};
	}

	my $query = qq{
        select    *
        from      calcms_comments
        where     $where
        order by  created_at $sort_order
        $limit
    };

	#print STDERR $query."\n";
	my $comments = db::get( $dbh, $query, $bind_values );

	return $comments;
}

sub get_by_time {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	my $where       = '';
	my $bind_values = [];
	if ( $comment->{age} ne '' ) {
		$where = qq{
            where event_id in (
                select   distinct event_id
                from     calcms_comments
                where    (
                    unix_timestamp(now()) - ?   < unix_timestamp(created_at) 
                ) 
            )
        };
		$bind_values = [ $comment->{age} * 3600, ];
	} elsif ( ( $comment->{from} ne '' ) && ( $comment->{till} ne '' ) ) {
		$where = qq{
            where event_id in (
                select  distinct event_id
                from    calcms_comments
                where   created_at >= ?
                and     created_at <= ?
            )
        };
		$bind_values = [ $comment->{from}, $comment->{till} ];
	}
	my $query = qq{
        select   *
        from     calcms_comments
        $where
        order by event_id, id
    };
	my $comments = db::get( $dbh, $query, $bind_values );
	return $comments;
}

sub get_events {
	my $dbh      = shift;
	my $config   = shift;
	my $request  = shift;
	my $comments = shift;

	my $params = $request->{params}->{checked}->{comment};

	#get event_ids from comments
	my $event_ids = {};
	for my $comment (@$comments) {
		my $event_id = $comment->{event_id};
		$event_ids->{$event_id} = 1;
	}

	#get events from comment's event ids
	return [] if ( ( keys %{$event_ids} ) == 0 );

	#my $quoted_event_ids=join "," ,(map {$dbh->quote($_)}(keys %{$event_ids}));
	my @bind_values = keys %{$event_ids};
	my $event_id_values = join ",", ( map { '?' } ( keys %{$event_ids} ) );

	my $query = qq{
        select   id, start, program, series_name, title, excerpt
        from     calcms_events
        where    id in ($event_id_values) 
    };

	my $events = db::get( $dbh, $query, \@bind_values );

	#build lookup table for events by id
	my $events_by_id = {};
	for my $event (@$events) {
		$events_by_id->{ $event->{id} } = $event;
		$event->{max_comment_id} = 0;
	}

	#add unassigned events
	#    for my $event_id (keys %{$event_ids}){
	#        if ($events_by_id->{$event_id}eq''){
	#            my $event={
	#                title        => "not assigned",
	#                max_comment_id    => 0
	#
	#            };
	#            push @$events,$event;
	#            $events_by_id->{$event_id}=$event;
	#        }
	#    }

	for my $comment (@$comments) {
		my $event_id = $comment->{event_id};
		my $event    = $events_by_id->{$event_id};
		next unless ( defined $event );
		$event->{comment_count}++;
		push @{ $event->{comments} }, $comment;    # if ($params->{event_id}ne'');
		$event->{max_comment_id} = $comment->{id} if ( $comment->{id} > $event->{max_comment_id} );
		for my $name ( keys %{ $config->{controllers} } ) {
			$comment->{ "controller_" . $name } = $config->{controllers}->{$name} || '';

			#            $event->{"controller_$name"}=$config->{controllers}->{$name};
		}
	}
	my @sorted_events = reverse sort { $a->{max_comment_id} <=> $b->{max_comment_id} } @$events;
	return \@sorted_events;
}

sub insert {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	$comment->{level} = comments::get_level( $dbh, $config, $comment );

	my $entry = {
		event_start => $comment->{event_start},
		event_id    => $comment->{event_id},
		parent_id   => $comment->{parent_id},
		level       => $comment->{level},
		title       => $comment->{title},
		content     => $comment->{content},
		author      => $comment->{author},
		email       => $comment->{email},
		ip          => $comment->{ip}
	};

	my $comment_id = db::insert( $dbh, 'calcms_comments', $entry );
	return $comment_id;
}

sub set_lock_status {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	my $id          = $comment->{id};
	my $lock_status = $comment->{set_lock_status};
	my $query       = qq{
        update  calcms_comments
        set     lock_status = ?
        where   id = ?
    };
	my $bind_values = [ $lock_status, $id ];
	db::put( $dbh, $query, $bind_values );

	$query = qq{
        select  event_id 
        from    calcms_comments
        where   id=?
    };
	$bind_values = [$id];
	my $comments = db::get( $dbh, $query, $bind_values );
	if ( @$comments > 0 ) {
		$comment->{event_id} = $comments->[0]->{event_id};
		update_comment_count( $dbh, $comment );
	}
}

sub set_news_status {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	my $id          = $comment->{id};
	my $news_status = $comment->{set_news_status};
	my $query       = qq{
        update  calcms_comments
        set     news_status= ? 
        where   id = ?
    };
	my $bind_values = [ $news_status, $id ];
	db::put( $dbh, $query, $bind_values );
}

sub update_comment_count {
	my $dbh     = shift;
	my $config  = shift;
	my $comment = shift;

	my $query = qq{
        select  count(id) count
        from    calcms_comments
        where   lock_status='show'
                and event_id=?
    };
	my $bind_values = [ $comment->{event_id} ];
	my $comments = db::get( $dbh, $query, $bind_values );

	my $count = 0;
	$count = $comments->[0]->{count} if ( @$comments > 0 );
	$query = qq{
        update  calcms_events 
        set     comment_count=?
        where   id=?
    };
	$bind_values = [ $count, $comment->{event_id} ];
	db::put( $dbh, $query, $bind_values );
}

#precondition: results are presorted by creation date (by sql)
sub sort {
	my $config  = shift;
	my $results = shift;

	#define parent nodes
	my $nodes = {};
	for my $node (@$results) {
		$nodes->{ $node->{id} } = $node;
	}
	my @root_nodes = ();
	for my $node (@$results) {

		#fill childs into parent nodes
		push @{ $nodes->{ $node->{parent_id} }->{childs} }, $node;

		#define root nodes
		push @root_nodes, $node if ( $node->{level} == 0 );
	}

	#print STDERR Dumper(\@root_nodes);

	#sort root nodes from newest to oldest
	my $sorted_nodes = [];
	for my $node (@root_nodes) {

		#for my $node (reverse @root_nodes){
		sort_childs( $node, $nodes, $sorted_nodes );
	}
	return $sorted_nodes;
}

sub sort_childs {
	my $node         = shift;
	my $nodes        = shift;
	my $sorted_nodes = shift;

	#push node into list of sorted nodes
	push @{$sorted_nodes}, $node;

	#return if node is leaf
	return $sorted_nodes unless ( defined $node->{childs} );

	#process child nodes
	for my $child ( @{ $node->{childs} } ) {
		$sorted_nodes = sort_childs( $child, $nodes, $sorted_nodes );
	}
	return $sorted_nodes;
}

sub configure_cache {
	my $config = shift;

	cache::init();

	my $date_pattern     = $cache::date_pattern;
	my $datetime_pattern = $cache::datetime_pattern;
	my $controllers      = $config->{controllers};

	cache::add_map( 'template=comments_newest&limit=3&type=list', $controllers->{comments} . '/neueste.html' );
	cache::add_map( 'template=comments_atom.xml&limit=20',        $controllers->{comments} . '/feed.xml' );
	cache::add_map( 'template=comments.html&event_id=(\d+)&event_start=' . $datetime_pattern,
		$controllers->{comments} . '/$1_$2-$3-$4_$5-$6.html' );
}

sub check_params {
	my $config = shift;
	my $params = shift;

	my $comment = {};

	$comment->{event_start} = '';
	if ( ( defined $params->{event_start} ) && ( $params->{event_start} =~ /(\d\d\d\d\-\d\d\-\d\d[T ]\d\d\:\d\d)(\:\d\d)?/ ) ) {
		$comment->{event_start} = $1;
	}

	$comment->{sort_order} = 'desc';
	$comment->{limit}      = '';
	if ( ( defined $params->{limit} ) && ( $params->{limit} =~ /(\d+)/ ) ) {
		$comment->{limit} = $1;
	}

	$comment->{show_max} = '';
	if ( ( defined $params->{show_max} ) && ( $params->{show_max} =~ /(\d+)/ ) ) {
		$comment->{show_max} = $1;
	}

	if ( ( defined $params->{sort_order} ) && ( $params->{sort_order} eq 'asc' ) ) {
		$comment->{sort_order} = 'asc';
	}

	$comment->{event_id} = '';
	if ( ( defined $params->{event_id} ) && ( $params->{event_id} =~ /(\d+)/ ) ) {
		$comment->{event_id} = $1;
	}

	if ( ( defined $params->{parent_id} ) && ( $params->{parent_id} =~ /(\d+)/ ) ) {
		$comment->{parent_id} = $1;
	}

	if ( ( defined $params->{type} ) && ( $params->{type} eq 'list' ) ) {
		$comment->{type} = 'list';
	} else {
		$comment->{type} = 'tree';
	}

	my $debug = $params->{debug} || '';
	if ( $debug =~ /([a-z\_\,]+)/ ) {
		$comment->{debug} = $1;
	}

	log::error( $config, 'missing parameter a' ) if ( ( defined $params->{limit} )       && ( $comment->{limit} eq '' ) );
	log::error( $config, 'missing parameter b' ) if ( ( defined $params->{event_id} )    && ( $comment->{event_id} eq '' ) );
	log::error( $config, 'missing parameter c' ) if ( ( defined $params->{event_start} ) && ( $comment->{event_start} eq '' ) );

	my $delta_days = 1;
	if ( $comment->{event_start} ne '' ) {
		my $today = time::datetime_to_array( time::time_to_datetime() );
		my $date  = time::datetime_to_array( $comment->{event_start} );
		$delta_days = time::days_between( $today, $date );
	}
	if (   ( $delta_days > $config->{permissions}->{no_new_comments_before} )
		|| ( $delta_days < -1 * $config->{permissions}->{no_new_comments_after} ) )
	{
		$comment->{allow}->{new_comments} = 0;
	} else {
		$comment->{allow}->{new_comments} = 1;
	}

	$comment->{template} = template::check( $params->{template}, 'comments.html' );

	return $comment;
}

#do not delete last line!
1;
