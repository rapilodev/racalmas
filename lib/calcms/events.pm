package events;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
$Data::Dumper::Sortkeys=1;
use MIME::Base64();
use Encode();
use Storable 'dclone';
use DBI();
use template();
use config();
use time();
use db();
use Datetime::Hash;

use markup();
use log();
use project();
use studios();

our @EXPORT_OK = qw(
  init
  get_cached_or_render
  get
  modify_results
  get_query
  render
  get_running_event_id
  delete
  check_params
  configure_cache
  get_duration
  calc_dates
  get_keys
  add_recordings
);

sub init {
}

sub get_cached_or_render($$) {
    my ($config, $request) = @_;
    my $params = $request->{params}->{checked};
    my $results = events::get($config, $request);
    return events::render($config, $request, $results);
}

sub get_prev{
    my ($config, $event) = @_;
    my $params = {
        till_date => time::check_date($event->{start}),
        till_time => time::check_time($event->{start}),
        phase     => 'all',
        order     => 'desc',
        limit     => 1,
        exclude_locations => 1,
        exclude_projects  => 1,
    };
    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original  => $params,
            checked  => events::check_params($config, $params),
        }
    };
    $request->{params}->{checked}->{stop_nav} = 1;
    my $results = events::get($config, $request);
    return $results->[0];
}

sub get_next{
    my ($config, $event) = @_;

    my $params = {
        from_date => time::check_date($event->{end}),
        from_time => time::check_time($event->{end}),
        phase     => 'all',
        order     => 'asc',
        limit     => 1,
        exclude_locations => 1,
        exclude_projects  => 1,
    };
    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => events::check_params($config, $params),
        },
    };
    $request->{params}->{checked}->{stop_nav} = 1;
    my $results = events::get($config, $request);
    return $results->[0];
}

sub get($$);
sub get($$) {
    my ($config, $request) = @_;
    my $dbh = db::connect($config, $request);
    (my $query, my $bind_values) = events::get_query($dbh, $config, $request);
    my $results = db::get($dbh, $$query, $bind_values);
    $results = events::add_recordings($dbh, $config, $request, $results) if $request->{params}->{checked}->{all_recordings};
    $results = events::modify_results($dbh, $config, $request, $results);

    # get prev and next event
    if (@$results==1
        and !$request->{params}->{checked}->{stop_nav}  #< prevent recursion!
        and  my $event_id = $request->{params}->{original}->{event_id}
    ){
        my $event = $results->[0];
        $event->{prev_event_id} = (get_prev($config, $event)//{})->{event_id};
        $event->{next_event_id} = (get_next($config, $event)//{})->{event_id};
    }

    return $results;
}

sub modify_results ($$$$) {
    my ($dbh, $config, $request, $results) = @_;
    my $params = $request->{params}->{checked};
    my $projects         = {};
    my $studios          = {};
    my $running_event_id = @$results ? events::get_running_event_id($dbh) : 0;
    if (@$results) {
        $results->[0]->{__first__} = 1;
        $results->[-1]->{__last__} = 1;
    }

    my $previous_result = { start_date => '' };
    my $counter = 1;
    my $is_ics = $params->{template} =~ /\.ics$/;
    my $is_atom = $params->{template} =~ /\.atom\.xml/;
    my $is_rss_xml = $params->{template} =~ /\.rss\.xml/;
    my $time_zone = $config->{date}->{time_zone};
    
    for my $result (@$results) {
        if (defined $params->{template}) {
            if ($is_ics) {
                markup::plain_to_ical($result, qw(content title user_title excerpt user_excerpt series_name));
                $result->{created_at} = time::datetime_to_rfc5545($result->{created_at});
                $result->{modified_at} = time::datetime_to_rfc5545($result->{modified_at});

            } elsif ($is_atom) {
                $result->{excerpt} ||= "lass dich ueberraschen";
                $result->{created_at} = time::datetime_to_utc_datetime($result->{created_at}, $time_zone);
                $result->{modified_at} = time::datetime_to_utc_datetime($result->{modified_at}, $time_zone);
            } elsif ($is_rss_xml) {
                $result->{excerpt} ||= "lass dich ueberraschen";
                $result->{modified_at} = time::datetime_to_rfc822($result->{modified_at});
                $result->{created_at} =
                  $result->{created_at} =~ /[1-9]/
                  ? time::datetime_to_rfc822($result->{created_at})
                  : $result->{modified_at};
            }
        }
        $result->{series_name} ||= '';
        $result->{series_name} = '' if $result->{series_name} eq '_single_';
        $result->{rerun} //= '';
        $result->{title} ||= '';
        if ($result->{title} =~ /\#(\d+)([a-z])?\s*$/) {
            $result->{episode} //= $1;
            $result->{rerun} = $2 || '' unless $result->{rerun} =~ /\d/;
            $result->{title} =~ s/\#\d+[a-z]?\s*$//;
            $result->{title} =~ s/\s+$//;
        }
        $result->{rerun} = '' if ($result->{rerun} eq '0');

        if (defined $result->{recurrence_count} && $result->{recurrence_count} > 0) {
            $result->{recurrence_count_alpha} = markup::base26($result->{recurrence_count} + 1);
            $result->{recurrence_id} = $result->{recurrence};
        } else {
            $result->{recurrence_count_alpha} = '';
            $result->{recurrence_count}       = '';
        }

        # set title keys
        my $keys = get_keys($result);
        @{$result}{keys %$keys} = values %$keys;
        $result = calc_dates($config, $result, $params);
        add_first_last_of_day($result, $previous_result);
        get_listen_key($config, $result) unless $params->{set_no_listen_keys};

        $result->{event_uri} = join('-', grep { $_ ne '' } $result->{program} // '', $result->{series_name} // '', $result->{title} // '');
        $result->{event_uri} =~ s/\#/Nr./g;
        $result->{event_uri} =~ s/\&/und/g;
        $result->{event_uri} =~ s/\//\%2f/g;
        $result->{event_uri} =~ s/[?]//g;

        $result->{rds_title} = $result->{event_uri};
        $result->{rds_title} =~ s/[^a-zA-Z0-9\-]/\_/gi;
        $result->{rds_title} =~ s/\_{2,99}/\_/gi;
        $result->{rds_title} = substr($result->{rds_title}, 0, 63);

        #$result->{event_id}=$result->{id};

        $result->{base_url}         = $request->{base_url};
        $result->{base_domain}      = $config->{locations}->{base_domain};
        $result->{static_files_url} = $config->{locations}->{static_files_url};
        $result->{source_base_url}  = $config->{locations}->{source_base_url};
        $result->{local_base_url}   = $config->{locations}->{local_base_url};
        $result->{widget_render_url}= $config->{locations}->{widget_render_url};

        $result->{is_running} = 1 if $running_event_id
            && $result->{event_id}
            && $running_event_id eq $result->{event_id};

        if (defined $result->{comment_count}){
            $result->{one_comment} = 1 if $result->{comment_count} == 1;
            $result->{no_comment}  = 1 if $result->{comment_count} == 0;
        }

        {
            my $url   = $config->{locations}->{local_media_url} // '';
            my $image = $result->{image};
            my $conf  = $config->{locations};
            my $basic_url = "$url/images/";

            if (defined $result->{image}) {
                $result->{thumb_url} = ($conf->{thumbs_url} // $basic_url) . $image;
                $result->{icon_url}  = ($conf->{icons_url}  // $basic_url) . $image;
                $result->{image_url} = ($conf->{images_url} // $basic_url) . $image;
            }

            if (defined $result->{series_image}) {
                $result->{series_thumb_url} = ($conf->{thumbs_url} // $basic_url) . $image;
                $result->{series_icon_url}  = ($conf->{icons_url}  // $basic_url) . $image;
                $result->{series_image_url} = ($conf->{images_url} // $basic_url) . $image;
            }
        }

        $result->{location_css} = $result->{location} || '';
        $result->{location_css} = lc($result->{location_css});
        $result->{location_css} =~ s/\.//g;
        $result->{location_css} =~ s/\s//g;
        $result->{ 'location_label_' . $result->{location_css} } = 1;

        # add project by name
        my $project_name = $result->{project};
        if (defined $project_name) {
            unless (defined $projects->{$project_name}) {
                my $results = project::get($config, { name => $project_name });
                $projects->{$project_name} = $results->[0] || {};
            }
            my $project = $projects->{$project_name};
            for my $key (keys %$project) {
                $result->{ 'project_' . $key } = $project->{$key};
            }
        } else {
            printf STDERR "events::get - unknown project for event %s\n", $result->{id} // "undef";
        }

        #if project_id is set add columns from project (cached)
        my $project_id = $result->{project_id};
        if (defined $project_id) {
            unless (defined $projects->{$project_id}) {
                my $results = project::get($config, { project_id => $project_id });
                $projects->{$project_id} = $results->[0] || {};
            }
            my $project = $projects->{$project_id};
            for my $key (keys %$project) {
                $result->{ 'project_' . $key } = $project->{$key};
            }
        }

        #if studio_id is set add columns from studio (cached)
        my $studio_id = $result->{studio_id};
        if (defined $studio_id) {
            unless (defined $studios->{$studio_id}) {
                my $results = studios::get($config, { studio_id => $studio_id });
                $studios->{$studio_id} = $results->[0] || {};
            }
            my $studio = $studios->{$studio_id};
            for my $key (keys %$studio) {
                $result->{ 'studio_' . $key } = $studio->{$key};
            }
        }

        for my $name (keys %{ $config->{mapping}->{events} }) {
            if (defined $result->{$name} && defined $config->{mapping}->{events}->{$name}) {
                my $val = $config->{mapping}->{events}->{$name}->{$result->{$name}};
                $result->{ $name . '_mapped' } = $val if $val;
            }
        }
        $previous_result = $result;

        $result->{ 'counter_' . $counter } = 1;
        $counter++;

        if (($params->{excerpt}//'') eq 'summary') {
            for my $field (qw(excerpt user_excerpt)) {
                $result->{$field} = substr($result->{$field}, 0, 250) . '...'
                    if length $result->{$field} > 250;
            }
        }

        if (($params->{description}//'') eq 'html') {
            for my $field (qw(content topic)) {
                $result->{"html_$field"} = events::format($result, $field) if defined $result->{$field};
            }
        }

        #detect if images are in content or topic field
        my $image_in_text = 0;
        $image_in_text = 1
          if (defined $result->{content})
          && ($result->{content} =~ /<img /);
        $image_in_text = 1
          if (defined $result->{topic})
          && ($result->{topic} =~ /<img /);
        $result->{no_image_in_text} = 1 if $image_in_text == 0;

        if (defined $params->{template} && (
                $params->{template} =~ /event_perl\.txt$/
             or $params->{template} =~ /event_file_export\.txt$/)
        ) {
            $result->{$_} =~ s/\|/\\\|/g for (grep {defined $result->{$_}} keys %$result);
        }

    }    # end for results
    add_recurrence_dates($config, $results);
    return $results;
}

sub format {
    my ($event, $field) = @_;
    if (($event->{content_format}//'') eq 'markdown'){
        $event->{$field} =  markup::markdown_to_html($event->{$field});
    } else {
        $event->{$field} = markup::fix_line_ends($event->{$field});
        $event->{$field} = markup::creole_to_html($event->{$field});
    }
    return $event->{$field};
}

sub add_recurrence_dates {
    my ($config, $results) = @_;

    # get unique list of recurrence ids from results
    my $recurrence_dates = {};
    for my $result (@$results) {
        next unless defined $result->{recurrence};
        next if $result->{recurrence} == 0;
        $recurrence_dates->{ $result->{recurrence} } = 0;
    }

    my @event_ids = keys %$recurrence_dates;
    return if @event_ids == 0;

    # query start date of recurrences
    my $conditions  = [];
    my $bind_values = [];
    for my $id (@event_ids) {
        push @$conditions,  '?';
        push @$bind_values, $id;
    }
    $conditions = join(',', @$conditions);

    my $query = qq{
        select id event_id, start
        from   calcms_events
        where  id in ($conditions)
    };
    my $dbh = db::connect($config);
    my $events = db::get($dbh, $query, $bind_values);

    # store start dates by recurrence id
    for my $event (@$events) {
        $recurrence_dates->{ $event->{event_id} } = $event->{start};
    }

    # set start dates to results
    my $language = $config->{date}->{language} || 'en';
    for my $result (@$results) {
        next unless defined $result->{recurrence};
        next if $result->{recurrence} == 0;
        my $rdate = $recurrence_dates->{ $result->{recurrence} };
        if ($rdate){
            $result->{recurrence_date} = $rdate;
            $result->{recurrence_date_name} = time::date_format($config, $rdate, $language);
            ($result->{recurrence_time_name}) = $rdate =~ m/(\d\d\:\d\d)\:\d\d/ ;
            my $ymd = time::date_to_array($rdate);
            my $weekdayIndex = time::weekday($ymd->[0], $ymd->[1], $ymd->[2]);
            $result->{recurrence_weekday_name}       = time::getWeekdayNames($language)->[$weekdayIndex];
            $result->{recurrence_weekday_short_name} = time::getWeekdayNamesShort($language)->[$weekdayIndex];
        }
    }
}

sub calc_dates {
    my ($config, $result, $params) = @_;

    $params ||= {};
    my $time_zone = $config->{date}->{time_zone};
    my $language = $config->{date}->{language} || 'en';
    my $locale = $language eq 'de' ? 'de_DE' : 'en_US';
    $result->{time_zone} = $time_zone;
    #warn $locale;

    my $start = Datetime::Hash::format_datetime_cached($result->{start}, $time_zone, $language);
    #warn Dumper($start);
    $result->{start_datetime} = $start->{datetime};
    $result->{start_epoch} = $start->{epoch};
    $result->{start_datetime_utc} = $start->{rfc3339};
    $result->{dtstart} = $start->{iso8601_basic};

    my $end = Datetime::Hash::format_datetime_cached($result->{end}, $time_zone, $language);
    $result->{end_datetime} = $end->{datetime};
    $result->{end_epoch} = $end->{epoch};
    $result->{end_datetime_utc} = $end->{rfc3339};
    $result->{dtend} = $end->{iso8601_basic};

    $result->{start_year} = $start->{year};
    $result->{start_month} = $start->{month};
    $result->{start_day} = $start->{day};
    $result->{start_hour} = $start->{hour};
    $result->{start_minute} = $start->{minute};
    $result->{start_second} = $start->{second};
    
    $result->{day} = time::datetime_to_array($result->{start})->[3] < 6
        ? time::add_days_to_date($result->{start}, -1)
        : time::datetime_to_date($result->{start})
        unless defined $result->{day};

    $result->{start_date} = $start->{date};
    $result->{start_time} = $start->{'time'};
    $result->{start_date_name} = $start->{date_name};

    $result->{end_date} = $end->{date};
    $result->{end_time} = $result->{end_time} = $end->{'time'};
    $result->{end_date_name} = $end->{date_name};

    $result->{weekday} = $start->{dow};
    $result->{weekday_name} = $start->{dow};
    $result->{weekday_short_name} = $start->{dow};
    $result->{weekday_name} = $start->{weekday_long};
    $result->{weekday_short_name} = $start->{weekday_short};
    
    #print STDERR Dumper($result);
    return $result;
}

sub calc_dates_old {
    my ($config, $result, $params) = @_;

    $params ||= {};
    my $language = $config->{date}->{language} || 'en';
    my $locale = $language eq 'de' ? 'de_DE' : 'en_US';
    my $time_zone = $config->{date}->{time_zone};
    $result->{time_zone} = $time_zone;
    
    $result->{start_datetime} = $result->{start} =~ tr/ /T/r;
    $result->{start_epoch} = time::datetime_to_epoch($result->{start_datetime}, $time_zone);
    $result->{start_datetime_utc} = time::epoch_to_utc_datetime($result->{start_epoch});

    $result->{end_datetime} = $result->{end} =~ tr/ /T/r;
    $result->{end_epoch} = time::datetime_to_epoch($result->{end_datetime}, $time_zone);
    $result->{end_datetime_utc} = time::epoch_to_utc_datetime($result->{end_epoch});
    #warn Dumper($result);

    $result->{dtstart} = $result->{start_datetime} =~ tr/:-//rd;
    $result->{dtend} = $result->{end_datetime} =~ tr/:-//rd;

    if ($result->{start_datetime} =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/) {
        @{$result}{qw(start_year start_month start_day start_hour start_minute)} = ($1, $2, $3, $4, $5);
    }
    $result->{day} = time::datetime_to_array($result->{start})->[3] < 6
        ? time::add_days_to_date($result->{start}, -1)
        : time::datetime_to_date($result->{start})
        unless defined $result->{day};

    $result->{start_date} ||= time::datetime_to_date($result->{start});
    $result->{start_time} = $1 if $result->{start} =~ /(\d{2}:\d{2}):\d{2}/;

    $result->{end_date} ||= time::datetime_to_date($result->{end});
    $result->{end_time} = $result->{end_time} = $1 if $result->{end} =~ /(\d{2}:\d{2}):\d{2}/;

    #my $language = $config->{date}->{language} || 'en';
    $result->{start_date_name} = time::date_format($config, $result->{start_date}, $language);
    $result->{end_date_name} = time::date_format($config, $result->{end_date}, $language);
    if (defined $result->{weekday}) {
        my $weekdayIndex = time::getWeekdayIndex($result->{weekday}) || 0;
        $result->{weekday_name} = time::getWeekdayNames($language)->[$weekdayIndex];
        $result->{weekday_short_name} = time::getWeekdayNamesShort($language)->[$weekdayIndex];
    }
    #print STDERR Dumper($result);
    return $result;
}

sub add_first_last_of_day($$){
    my ($entry, $prev) = @_;
    if ($entry->{start_date} && ($entry->{start_date} ne ($prev->{start_date}//''))) {
        $entry->{is_first_of_day} = 1;
        $prev->{is_last_of_day} = 1 if defined $prev->{start_date};
    }
}

sub get_listen_key($$){
    my ($config, $event) =@_;

    my $time_zone = $config->{date}->{time_zone};
    #warn Dumper($event);
    my $over_since = time() - time::datetime_to_epoch($event->{start_datetime}, $time_zone);

    return if $over_since < 0;
    return if $over_since > 7*24*60*60;

    my $archive_dir = $config->{locations}->{local_archive_dir};
    my $archive_url = $config->{locations}->{listen_url};
    return $event->{listen_url} = $archive_url . '/' . $event->{listen_key} if
        defined $event->{listen_key} && -l $archive_dir .'/'. $event->{listen_key};
    set_listen_key($config, $event) unless $event->{listen_key};
}

sub set_listen_key{
    my ($config, $event) =@_;
    my $archive_dir = $config->{locations}->{local_archive_dir};
    my $archive_url = $config->{locations}->{listen_url};
    my $datetime = $event->{start_datetime};
    if ($datetime =~ /(\d\d\d\d\-\d\d\-\d\d)[ T](\d\d)\:(\d\d)/) {
        $datetime = $1 . '\ ' . $2 . '_' . $3;
    } else {
        print STDERR "update_recording_link: no valid datetime found $datetime\n";
        return;
    }
    my @files = glob($archive_dir . '/' . $datetime . '*.mp3');
    return if @files <= 0;

    my $key  = int(rand(99999999999999999));
    $key = MIME::Base64::encode_base64($key);
    $key =~ s/[^a-zA-Z0-9]//g;
    $key .='.mp3';

    my $audio_file = Encode::decode("UTF-8", $files[0]);
    my $link = $archive_dir . '/' . $key;
    symlink $audio_file, $link or die "cannot create $link, $!";
    $event->{listen_url} = $archive_url . '/' . $key;
    $event->{listen_key} = $key;

    return undef unless defined $event->{event_id};
    return undef unless defined $event->{listen_key};
    my $bindValues = [ $event->{listen_key}, $event->{event_id} ];

    my $query = qq{
        update calcms_events
        set listen_key=?
        where id=?;
    };
    local $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    my $recordings = db::put($dbh, $query, $bindValues);
}

sub set_upload_status($$){
    my ($config, $event) = @_;

    for ('event_id', 'upload_status') {
        ParamError->throw(error => "missing $_") unless defined $event->{$_}
    };

    my $bindValues = [ $event->{upload_status}, $event->{event_id}, $event->{upload_status} ];

    my $query = qq{
        update calcms_events
        set upload_status=?
        where id=? and upload_status!=?;
    };
    local $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    my $recordings = db::put($dbh, $query, $bindValues);
}

sub add_recordings($$$$) {
    my ($dbh, $config, $request, $events) = @_;

    return $events unless defined $events;

    my $eventsById = { map { $_->{event_id} => $_ } @$events };
    my $qms        = join ', ', map { '?' } @$events;
    my $bindValues = [map {$_->{event_id}} @$events];

    my $query = qq{
        select  *
        from    calcms_audio_recordings
        where   event_id in ($qms)
        order by created_at;
    };

    $dbh = db::connect($config) unless defined $dbh;
    my $recordings = db::get($dbh, $query, $bindValues);
    push @{ $eventsById->{$_->{event_id}}->{recordings} }, $_ for @$recordings;

    return $events;
}

sub getDateQueryConditions ($$$) {
    my ($config, $params, $bind_values) = @_;

    # conditions by date
    my $date_conds = [];
    my $date_range_include = $params->{date_range_include};
    my $day_starting_hour  = $config->{date}->{day_starting_hour};

    my $date = ($params->{date} ne '') ? time::date_cond($params->{date}) : '';
    if ($date eq 'today') {
        my $date = time::get_event_date($config);
        push @$date_conds,  ' (start_date = ?) ';
        push @$bind_values, $date;
        return $date_conds;
    }

    # given date
    my $start = time::datetime_cond($date . 'T00:00:00');
    if ($start ne '') {
        $start = time::add_hours_to_datetime($start, $day_starting_hour);
        my $end = time::add_hours_to_datetime($start, 24);
        if ($date_range_include eq '1') {
            push @$date_conds,  ' end > ? ';
            push @$bind_values, $start;
        } else {
            push @$date_conds,  ' start >= ? ';
            push @$bind_values, $start;
        }
        push @$date_conds,  ' start < ? ';
        push @$bind_values, $end;
        return $date_conds;
    }

    if ($params->{phase} eq 'ongoing') {
        push @$date_conds, qq{
           (
             (unix_timestamp(end)   >  unix_timestamp(now()))
             and
             (unix_timestamp(start) <= unix_timestamp(now()))
           )
        };
        return $date_conds;
    }

    my $from_date = ($params->{from_date} ne '') ? time::date_cond($params->{from_date}) : '';
    my $from_time = ($params->{from_time} ne '') ? time::time_cond($params->{from_time}) : '';
    if ($from_date ne '' && $from_time ne '') {
        if ((my $datetime = time::datetime_cond($from_date . 'T' . $from_time)) ne '') {
            if ($date_range_include eq '1') {
                push @$date_conds,  ' end > ? ';
                push @$bind_values, $datetime;
                $from_date = '';
            } else {
                push @$date_conds,  ' start >= ? ';
                push @$bind_values, $datetime;
                $from_date = '';
            }
        }
    }

    # after start of daily broadcast
    if ($from_date ne '' && $from_time eq '') {
        my $start = time::datetime_cond($from_date . 'T00:00:00');
        $start = time::add_hours_to_datetime($start, $day_starting_hour);
        if ($date_range_include eq '1') {
            ## end is after start
            push @$date_conds,  ' (end >= ?)';
            push @$bind_values, $start;
        } else {
            push @$date_conds,  ' (start >= ?) ';
            push @$bind_values, $start;
        }
    }

    my $till_date = ($params->{till_date} ne '') ? time::date_cond($params->{till_date}) : '';
    my $till_time = ($params->{till_time} ne '') ? time::time_cond($params->{till_time}) : '';
    #till_date and till_time is defined
    if ($till_date ne '' && $till_time ne '') {
        if ((my $datetime = time::datetime_cond($till_date . 'T' . $till_time)) ne '') {
            push @$date_conds,  ' start < ? ';
            push @$bind_values, $datetime;
            $till_date = '';
        }
    }

    # before end of daily broadcast
    if ($till_date ne '' && $till_time eq '') {
        my $end = time::datetime_cond($till_date . 'T00:00:00');
        $end = time::add_hours_to_datetime($end, $day_starting_hour);
        if ($date_range_include eq '1') {
            ## start is before end
            push @$date_conds,  ' (start <= ?)';
            push @$bind_values, $end;
        } else {
            push @$date_conds,  ' (end <= ?) ';
            push @$bind_values, $end;
        }
    }

    if ($params->{weekday} ne '') {
        my $weekday = int($params->{weekday});
        $weekday += 1;
        $weekday -= 7 if $weekday > 7;
        push @$date_conds,  ' (dayofweek(start)= ?) ';
        push @$bind_values, $weekday;
    }

    if ($params->{last_days}) {
        my $d = int $params->{last_days};
        push @$date_conds,  qq{ (end between date_sub(now(),INTERVAL $d DAY) and now()) };
    } elsif ($params->{next_days}) {
        my $d = int $params->{next_days};
        push @$date_conds,  qq{ (end between now() and date_add(now(),INTERVAL $d DAY)) };
    } elsif ($params->{phase} eq 'past') {
        if ((my $date = time::get_event_date($config)) ne '') {
            push @$date_conds,  ' (start < ?) ';
            push @$bind_values, $date;
        } else {die}
    } elsif ($params->{phase} eq 'future') {
        if ((my $date = time::get_event_date($config)) ne '') {
            push @$date_conds,  ' (end >= ?) ';
            push @$bind_values, $date;
        } else {die}
    }
    return $date_conds;
}

# if "all_recordings" is set in params, all event recordings will be included
# if "active_recording" is set in params, recordings date and path will be included
my $invalid = qr/[^a-zA-Z0-9\-\_,]/;
sub get_query($$$) {
    my ($dbh, $config, $request) = @_;

    my $params = $request->{params}->{checked};
    $params->{all_recordings} //= '';
    $params->{active_recording} //= '';
    $params->{only_active_recording} //= '';

    my $bind_values = [];
    my $where_cond  = [];
    my $order_cond  = '';
    my $limit_cond  = '';

    if ($params->{event_id} ne '') {
        push @$where_cond, 'e.id=?';
        $bind_values = [ $params->{event_id} ];

        #filter by published, default=1 to see published only, set published='all' to see all
        if (($params->{published} // '1') =~ /^([01])$/) {
            push @$where_cond, 'published=?';
            push @$bind_values, $1;
        }

        #filter by draft, default=0 to see drafts only, set draft='all' to see all
        if (($params->{draft} // '0') =~ /^([01])$/) {
            push @$where_cond, 'draft=?';
            push @$bind_values, $1;
        }
    } else {
        my $date_conds = getDateQueryConditions($config, $params, $bind_values);
        my $date_cond = join " and ", @$date_conds;
        push @$where_cond, $date_cond if $date_cond ne '';
    }

    # location
    my $location_cond = '';
    if (my @locations = grep {$_ ne ''} split /,/, $params->{location} =~ s/$invalid/%/gr) {
        $location_cond = ' location in (' . join(',', ('?') x @locations) . ')';
        push @$bind_values, @locations;
    }

    # exclude location
    my $exclude_location_cond = '';
    if ($params->{exclude_locations} eq '1' &&
        (my @locations = grep {$_ ne ''} split /,/, $params->{locations_to_exclude} =~ s/$invalid/%/gr)
    ) {
        $exclude_location_cond = 'location not in (' . join(',', ('?')x @locations) . ')';
        push @$bind_values, @locations;
    }

    # exclude project
    my $exclude_project_cond = '';
    if ($params->{exclude_projects} eq '1' &&  $params->{projects_to_exclude} ne '') {
        my @projects_to_exclude = split /,/, $params->{projects_to_exclude} =~s/$invalid/%/gr;
        $exclude_project_cond = 'project not in (' . join(",", ('?') x @projects_to_exclude) . ')';
        push @$bind_values, @projects_to_exclude;
    }

    my $series_name_cond = '';
    if ($params->{series_name} ne '' &&
        (my $series_name = (split(/\,/, $params->{series_name} =~ s/$invalid/%/gr))[0])
    ) {
        $series_name_cond = ' series_name like ? ';
        push @$bind_values, $series_name;
    }

    #filter for tags
    my $tag_cond = '';
    my @tags = split /\,/, $params->{tag};
    if (scalar @tags > 0) {
        my $tags = join ",", (map { '?' } @tags);
        push @$bind_values, @tags;
        $tag_cond = qq{
            id in(
                select event_id from calcms_tags
                where name in($tags)
            )
        };
    }

    my $title_cond = '';
    if ($params->{title}) {
        my $title = $params->{title};
        $title = (split /,/, $title)[0];
        $title =~ s/[^a-zA-Z0-9]+/%/g;
        $title =~ s/^%|%$//g;
        if ($title) {
            $title_cond = ' title LIKE ? ';
            push @$bind_values, "%$title%";
        }
    }

    my $search_cond = '';
    if ($params->{search} ne '') {
        my $search = lc $params->{search};
        $search =~ s/([\\%_])/\\$1/g;
        $search =~ s/^[\%\s]+|[\%\s]+$//g;
        $search = "%$search%";
        my @attributes = qw(title series_name excerpt content topic);
        $search_cond = '(' . join(' OR ', map { "lower($_) LIKE ?" } @attributes) . ')';
        push @$bind_values, ($search) x @attributes;
    }

    my $project_name = (($params || {})->{project} || {})->{name} || '';
    my $project_cond = ($project_name && $project_name ne 'all') ? '(project=?)' : '';
    push @$bind_values, $project_name if $project_cond;

    #filter by published, default =1, set to 'all' to see all
    my $published_cond = '';
    if (($params->{published} // '1') =~ /^([01])$/) {
        $published_cond = 'published=?';
        push @$bind_values, $1;
    }

    #filter by draft, default=0, set to 'all' to see all
    my $draft_cond = '';
    if (($params->{draft} // '0') =~ /^([01])$/) {
        $draft_cond = 'draft=?';
        push @$bind_values, $1;
    }

    #combine date, location, series_name, tag, search and project
    push @$where_cond, grep {length $_} ($location_cond, $exclude_location_cond, $exclude_project_cond,
        $series_name_cond, $tag_cond, $title_cond, $search_cond, $project_cond, $published_cond,
        $draft_cond
    );

    #order is forced
    if ($params->{order} eq 'asc') {
        $order_cond = 'order by start';
    } elsif ($params->{order} eq 'desc') {
        $order_cond = 'order by start desc';
    } else {
        if ($params->{phase} eq 'past') {
            $order_cond = 'order by start desc';
        } else {
            $order_cond = 'order by start';
        }
    }

    $limit_cond = 'limit ' . $params->{limit} if $params->{limit};

    my $query = qq{
        select
             date(e.start)        start_date
            ,date(e.end)          end_date
            ,weekday(e.start)     weekday
            ,weekofyear(e.start)  week_of_year
            ,dayofyear(e.start)   day_of_year
            ,e.start_date         day
            ,e.id                 event_id
            ,e.start
            ,e.end
            ,TIMEDIFF(e.end,e.start)      duration
            ,e.program
            ,e.series_name
            ,e.title
            ,e.modified_at
            ,e.created_at
            ,e.modified_by
            ,e.comment_count
            ,e.image
            ,e.image_label
            ,e.series_image
            ,e.series_image_label
            ,e.reference
            ,e.recurrence
            ,e.recurrence_count
            ,e.podcast_url
            ,e.archive_url
            ,e.media_url
            ,e.status
            ,e.location
            ,e.project
            ,e.user_title
            ,e.published
            ,e.draft
            ,e.playout
            ,e.archived
            ,e.rerun
            ,e.live
            ,e.episode
            ,e.listen_key
            ,e.upload_status
            ,e.content_format
    };
    my $template = $params->{template} || '';

    $query .= ',e.excerpt, e.user_excerpt' if $params->{excerpt} =~/summary|detailed/;
    $query .= ', e.content, e.topic, e.html_content, e.html_topic'
        if $params->{description} eq 'html';
    $query .= ', e.content, e.topic'
        if $params->{description} eq 'text';

    # add project id and series id
    for my $field (grep {$params->{$_} =~ /^\d+$/ } ('project_id', 'studio_id')) {
        push @$where_cond, "se.$field = ?";
        push @$bind_values, $params->{$field};
        $query .= ", se.$field";
    }

    # add recordings field and conditions
    if ($params->{active_recording} || $params->{only_active_recording}) {
        $query .= ', ar.path';
        $query .= ', ar.size';
        $query .= ', ar.created_by uploaded_by';
        $query .= ', ar.modified_at uploaded_at';
    }

    $query .= "\n from";

    # filter / join by project and studio
    if ($params->{project_id}=~/^\d+$/ or $params->{studio_id}=~/^\d+$/) {
        $query .= "\n calcms_series_events se inner join calcms_events e on se.event_id=e.id";
    } else {
        $query .= "\n calcms_events e";
    }

    # add recordings table
    if ($params->{active_recording} || $params->{only_active_recording}) {
        my $type = $params->{only_active_recording} ? 'inner' : 'left';
        $query .= "\n $type join calcms_audio_recordings ar on e.id=ar.event_id and ar.active=1";
    }

    $query .= "\nwhere " . join(' and ', @$where_cond) if scalar @$where_cond > 0;
    $query .= "\n" . $order_cond if $order_cond ne '';
    $query .= "\n" . $limit_cond if $limit_cond ne '';

    return (\$query, $bind_values);
}

sub render($$$;$) {
    my ($config, $request, $results, $root_params) = @_;

    my $params = $request->{params}->{checked};
    if (ref($root_params) eq 'HASH') {
        for my $param (keys %$root_params) {
            $params->{$param} = $root_params->{$param};
        }
    }
    my %tparams = %$params;
    my $tparams = \%tparams;
    $tparams->{events}       = $results;

    if (scalar @$results > 0) {
        my $result = $results->[0];
        $tparams->{event_id}      = $result->{event_id};
        $tparams->{event_dtstart} = $result->{dtstart};
        $tparams->{first_date}    = $results->[0]->{start_date};
        $tparams->{last_date}     = $results->[-1]->{start_date};
    }

    #    $tparams->{print}            =1 if ($params->{print} eq '1');
    $tparams->{base_url}       = $config->{locations}->{base_url};
    $tparams->{base_domain}    = $config->{locations}->{base_domain};
    $tparams->{local_base_url} = $config->{locations}->{local_base_url};
    $tparams->{widget_render_url} = $config->{locations}->{widget_render_url};
    $tparams->{modified_at}    = time::time_to_datetime(time());
    if ((defined $params->{template})
        && ($params->{template} =~ /(\.xml)/))
    {
        $tparams->{modified_at_datetime_utc} =
          time::datetime_to_utc_datetime($tparams->{modified_at}, $config->{date}->{time_zone});
    }

    #$tparams->{tags}        = $tags;

    if (scalar @$results == 0) {
        if (($params->{search} ne '')
            || ($params->{series_name} ne ''))
        {
            $tparams->{no_search_result} = '1';
        } else {
            $tparams->{no_result} = '1';
        }
    } else {
        if ((!defined $params->{event_id}) || ($params->{event_id} eq '')) {
            $tparams->{event_count}   = scalar @$results . '';
            $tparams->{first_of_list} = $results->[0]->{event_id};
        }
        my $start = $results->[0]->{start_datetime} || '';
        if ($start =~ /(\d{4}\-\d{2})/) {
            $tparams->{month} = $1;
        }
    }

    my $timezone = $config->{date}->{time_zone};
    $tparams->{time_zone}  = $timezone;
    #warn Dumper($tparams->{modified_at});
    if ($params->{template} =~ /\.atom\.xml/) {
        $tparams->{modified_at} = time::datetime_to_rfc3339($tparams->{modified_at}, $timezone);
    } elsif ($params->{template} =~ /\.rss\.xml/) {
        $tparams->{modified_at} = time::datetime_to_rfc822($tparams->{modified_at});
    } elsif ($params->{template} =~ /\.txt/) {
        $tparams->{modified_at_utc} = time::datetime_to_epoch($tparams->{modified_at}, $timezone);
    }

    my $project = $params->{default_project};
    foreach my $key (keys %$project) {
        $tparams->{ 'project_' . $key } = $project->{$key};
    }
    $tparams->{ 'project_' . $project->{name} } = 1
      if ($project->{name} ne '');

    $tparams->{controllers}       = $config->{controllers};
    $tparams->{hide_event_images} = 1
      if (defined $config->{permissions}->{hide_event_images})
      && ($config->{permissions}->{hide_event_images} == 1);

    for my $attr (qw(no_result events_title events_description)){
        $tparams->{$attr} = $config->{$attr};
    }

    return template::process($config, $params->{template}, $tparams);
}

sub get_running_event_id($) {
    my ($dbh) = @_;

    my $query = qq{
        select id event_id, start, title
        from calcms_events
        where
    (
        (unix_timestamp(start) <= unix_timestamp(now()))
        and
        (unix_timestamp(end) > unix_timestamp(now()))
        and
        (unix_timestamp(end) - unix_timestamp(now())) < 24*3600
    )

        order by start
        limit 1
    };

    my $running_events = db::get($dbh, $query);
    my @running_events = @$running_events;

    return $running_events->[0]->{event_id} if (scalar @running_events > 0);
    return 0;
}

# add filters to query
sub setDefaultEventConditions ($$$$) {
    my ($config, $conditions, $bind_values, $options) = @_;

    $options = {} unless defined $options;

    # exclude projects
    if ((defined $options->{exclude_projects})
        && ($options->{exclude_projects} == 1)
        && (defined $config->{filter})
        && (defined $config->{filter}->{projects_to_exclude}))
    {
        my @projects_to_exclude =
          split(/,/, $config->{filter}->{projects_to_exclude});
        push @$conditions, 'project not in (' . join(",", map { '?' } @projects_to_exclude) . ')';
        for my $project (@projects_to_exclude) {
            push @$bind_values, $project;
        }
    }

    # exclude locations
    if ((defined $options->{exclude_locations})
        && ($options->{exclude_locations} == 1)
        && (defined $config->{filter})
        && (defined $config->{filter}->{locations_to_exclude}))
    {
        my @locations_to_exclude =
          split(/,/, $config->{filter}->{locations_to_exclude});
        push @$conditions, 'location not in (' . join(",", map { '?' } @locations_to_exclude) . ')';
        for my $location (@locations_to_exclude) {
            push @$bind_values, $location;
        }
    }

}

# for local use only or add support for exclude_projects and exclude_locations
sub getEventById ($$$$) {
    my ($dbh, $config, $event_id, $options) = @_;

    $dbh = db::connect($config) unless defined $dbh;

    my $conditions  = [];
    my $bind_values = [];

    push @$conditions,  "id=?";
    push @$bind_values, $event_id;

    setDefaultEventConditions($config, $conditions, $bind_values, $options);
    $conditions = join(' and ', @$conditions);

    my $query = qq{
        select  *
        from    calcms_events
        where   $conditions
    };

    my $events = db::get($dbh, $query, $bind_values);
    return $events;
}

sub get_next_event_of_series ($$$) {
    my ($dbh, $config, $options) = @_;

    my $eventId = $options->{event_id};
    return undef unless defined $eventId;

    $dbh = db::connect($config) unless defined $dbh;

    my $events = getEventById($dbh, $config, $eventId, $options);
    return undef unless scalar(@$events) == 1;
    my $event = $events->[0];

    my $conditions  = [];
    my $bind_values = [];

    push @$conditions,  "start>?";
    push @$bind_values, $event->{start};

    push @$conditions,  "series_name=?";
    push @$bind_values, $event->{series_name};

    setDefaultEventConditions($config, $conditions, $bind_values, $options);
    $conditions = join(' and ', @$conditions);

    my $query = qq{
        select  id
        from    calcms_events
        where   $conditions
        order by start
        limit 1
    };

    $events = db::get($dbh, $query, $bind_values);
    return undef unless scalar @$events == 1;

    return $events->[0]->{id};
}

sub get_previous_event_of_series($$$) {
    my ($dbh, $config, $options) = @_;

    my $eventId = $options->{event_id};
    return undef unless defined $eventId;

    $dbh = db::connect($config) unless defined $dbh;
    my $events = getEventById($dbh, $config, $eventId, $options);
    return undef unless scalar(@$events) == 1;
    my $event = $events->[0];

    my $conditions  = [];
    my $bind_values = [];

    push @$conditions,  "start<?";
    push @$bind_values, $event->{start};

    push @$conditions,  "series_name=?";
    push @$bind_values, $event->{series_name};

    setDefaultEventConditions($config, $conditions, $bind_values, $options);
    $conditions = join(' and ', @$conditions);

    my $query = qq{
        select id from calcms_events
        where     $conditions
        order by  start desc
        limit 1
    };
    $events = db::get($dbh, $query, $bind_values);

    return undef unless scalar(@$events) == 1;
    return $events->[0]->{id};
}

# used by calendar
sub get_by_date_range ($$$$$) {
    my ($dbh, $config, $start_date, $end_date, $options) = @_;

    my $day_starting_hour = $config->{date}->{day_starting_hour};

    my $start = time::datetime_cond($start_date . 'T00:00:00');
    $start = time::add_hours_to_datetime($start, $day_starting_hour);

    my $end = time::datetime_cond($end_date . 'T00:00:00');
    $end = time::add_hours_to_datetime($end, $day_starting_hour);

    my $conditions = [];
    push @$conditions, 'published = 1';
    push @$conditions, 'start between ? and ?';
    my $bind_values = [ $start, $end ];

    setDefaultEventConditions($config, $conditions, $bind_values, $options);

    $conditions = join(' and ', @$conditions);

    my $select = qq{distinct date(start) 'start_date'};
    $select = qq{distinct date(DATE_SUB(start, INTERVAL $day_starting_hour HOUR)) 'start_date'}
      if defined $day_starting_hour;

    my $query = qq{
        select   $select
        from     calcms_events
        where    $conditions
    };

    my $events = db::get($dbh, $query, $bind_values);

    return $events;
}

sub get_by_image ($$$) {
    my ($dbh, $config, $filename) = @_;

    my $query = qq{
        select * from calcms_events
        where content like ?
        order by start desc
        limit 1
    };
    my $bind_values = [ '%' . $filename . '%' ];

    my $events = db::get($dbh, $query, $bind_values);

    return undef if scalar @$events == 0;
    return $events->[0];
}

# deleting an event is currently disabled
sub delete ($$$) {
    return;
    my ($request, $config, $event_id) = @_;

    my $params = $request->{params}->{checked};
    my $dbh = db::connect($config);

    my $query = 'delete from calcms_events where id=?';
    db::put($dbh, $query, [$event_id]);

    $query = 'delete from calcms_categories where id=?';
    db::put($dbh, $query, [$event_id]);

    $query = 'delete from calcms_tags where id=?';
    db::put($dbh, $query, [$event_id]);

    $query = 'delete from calcms_series_events where event_id=?';
    db::put($dbh, $query, [$event_id]);

}

sub get_duration ($$) {
    my ($config, $event) = @_;

    my $timezone = $config->{date}->{time_zone};
    my $start    = time::get_datetime($event->{start}, $timezone);
    return undef unless defined $start;
    my $end      = time::get_datetime($event->{end}, $timezone);
    return undef unless defined $end;
    my $duration = $end->epoch() - $start->epoch();
    return $duration / 60;
}

sub check_params ($$) {
    my ($config, $params) = @_;

    #define running at
    my $running_at = $params->{running_at} // '';
    if ($running_at) {
        my $run_date = time::check_date($running_at);
        my $run_time = time::check_time($running_at);
        if (($run_date ne '') && ($run_time ne '')) {
            $params->{till_date} = $run_date;
            $params->{till_time} = $run_time;
            $params->{order}     = 'asc';
            $params->{limit}     = 1;
            $params->{phase}   = 'all';
        }
    }

    #set time
    my $from_time = time::check_time($params->{from_time});
    my $till_time = time::check_time($params->{till_time});

    #set date
    my $from_date = time::check_date($params->{from_date});
    my $till_date = time::check_date($params->{till_date});
    my $date = ($from_date eq '' && $till_date eq '') ? time::check_date($params->{date}) : '';

    #set date interval (including)
    my $date_range_include = ($params->{date_range_include}//'') eq '1' ? 1 : 0;

    my $order = '';
    if (defined $params->{order}) {
        $order = 'desc' if $params->{order} eq 'desc';
        $order = 'asc'  if $params->{order} eq 'asc';
    }

    my $weekday = $params->{weekday} // '';
    if ($weekday) {
        if ($weekday =~ /\d/) {
            $weekday = int($weekday);
            log::error($config, 'invalid weekday') if $weekday < 1 or $weekday > 7;
        } else {
            log::error($config, 'invalid weekday');
        }
    }

    my $tag = $params->{tag} // '';
    if ($tag) {
        log::error($config, "invalid tag") if $tag =~ /\s/;
        log::error($config, "invalid tag") if $tag =~ /\;/;
        $tag =~ s/\'//gi;
    }

    my $series_name = $params->{series_name} // '';
    if ($series_name) {
        log::error($config, "invalid series_name")
          if ($series_name =~ /\;/);
        $series_name =~ s/^\s+//gi;
        $series_name =~ s/\s+$//gi;
        $series_name =~ s/\'//gi;
    }

    my $title = $params->{title} // '';
    if ($title) {
        log::error($config, "invalid title") if $title =~ /\;/;
        $title =~ s/^\s+//gi;
        $title =~ s/\s+$//gi;
        $title =~ s/\'//gi;
    }

    my $location = $params->{location} // '';
    if ($location) {
        log::error($config, "invalid location") if $location =~ /\;/;
        $location =~ s/^\s+//gi;
        $location =~ s/\s+$//gi;
        $location =~ s/\'//gi;
    }

    #if no location is set, use exclude location filter from default config
    my $locations_to_exclude = '';
    if (($location eq '')
        && (defined $config->{filter})
        && (defined $config->{filter}->{locations_to_exclude}))
    {
        $locations_to_exclude = $config->{filter}->{locations_to_exclude} || '';
        $locations_to_exclude =~ s/\s+/ /g;
    }

    my $projects_to_exclude = '';
    if ((defined $config->{filter})
        && (defined $config->{filter}->{projects_to_exclude}))
    {
        $projects_to_exclude = $config->{filter}->{projects_to_exclude} || '';
        $projects_to_exclude =~ s/\s+/ /g;
    }

    #enable exclude locations filter
    my $exclude_locations = (($params->{exclude_locations}//'') eq '1') ?1:0;
    my $exclude_projects = (($params->{exclude_projects}//'') eq '1') ?1:0;
    my $exclude_event_images = (($params->{exclude_event_images}//'') eq '1') ?1:0;

    #show future events by default
    my $phase = $params->{phase} // (defined $params->{time} ? time::check_time($params->{time}) : 'future');
    if ($phase =~ /^(?:future|upcoming)$/) {
        $phase = 'future';
    } elsif ($phase =~/^(?:ongoing|running)$/) {
        $phase = 'ongoing';
    } elsif ($phase eq 'all' or ($from_date ne '' && $till_date ne '')) {
        $phase = 'all';
    } elsif ($phase =~ /^(?:past|completed)$/) {
        $phase = 'past'    ;
    } else {
        die "invalid phase";
    }
    #show all on defined timespans

    my $last_days = defined $params->{last_days} ? int($params->{last_days}) : 0;
    my $next_days = defined $params->{next_days} ? int($params->{next_days}) : 0;

    my $event_id = '';
    if ($params->{event_id}) {
        if (($params->{event_id} // '') =~ /(\d+)/)  {
            $event_id = $1;
        } else {
            log::error($config, "invalid event_id");
        }
    }

    my $excerpt = $params->{excerpt}//'detailed';
    die "invalid excerpt" unless $excerpt =~ /^(?:none|summary|detailed)$/;

    my $description = $params->{description}//'text';
    die "invalid description" unless $description =~ /^(?:none|text|html)$/;

    my $search = $params->{search} // '';
    if ($search) {
        $search = substr $search, 0, 100;
        $search =~ s/^\s+//gi;
        $search =~ s/\s+$//gi;
    }

    my $template = '.html';
    if (($params->{template}//'') eq 'no') {
        $template = 'no';
    } elsif (($params->{template}//'') eq 'html') {
        $template = 'html';
    } else {
        $template = template::check($config, $params->{template}, 'event_list.html');
    }

    my $limit_config = $config->{permissions}->{result_limit} || 100;
    my $limit = $params->{limit} || $limit_config;
    log::error($config, "invalid limit $limit.") if ($limit =~ /\D/);
    $limit = $limit_config if ($limit_config < $limit);

    #read project from configuration file
    my $project_name = $config->{project} // '';
    log::error($config, 'no default project configured') if $project_name eq '';

    #get default project
    my $default_project = undef;
    my $projects = project::get($config, { name => $project_name });
    log::error($config, "no configuration found for project '$project_name'")
      unless scalar(@$projects) == 1;
    $default_project = $projects->[0];

    # get project from parameter (by name)
    my $project = '';
    if ((defined $params->{project})
        && ($params->{project} =~ /\w+/)
        && ($params->{project} ne 'all')
    ) {
        my $project_name = $params->{project};
        my $projects = project::get($config, { name => $project_name });
        log::error($config, 'invalid project ' . $project_name) unless scalar(@$projects) == 1;
        $project = $projects->[0];
    }
    $project_name = $params->{project_name} || '';
    my $studio_name = $params->{studio_name} || '';
    my $project_id = $params->{project_id} || '';
    my $studio_id  = $params->{studio_id}  || '';
    my $json_callback = ($params->{json_callback}//'') =~ s/[^a-zA-Z0-9\_]//gr;

    # use relative links
    my $extern = (($params->{extern}//'') eq '1') ? 1:0;

    my $all_recordings = $params->{all_recordings};
    my $active_recording = $params->{active_recording} // '';
    my $only_active_recording = $params->{only_active_recording} // '';
    my $set_no_listen_keys = !($active_recording or $only_active_recording);

    my $checked = {
        date                 => $date,
#        time                 => $time,
        from_date            => $from_date,
        till_date            => $till_date,
        date_range_include   => $date_range_include,
        from_time            => $from_time,
        till_time            => $till_time,
        weekday              => $weekday,
        limit                => $limit,
        template             => $template,
        location             => $location,
        series_name          => $series_name,
        tag                  => $tag,
        title                => $title,
        event_id             => $event_id,
        search               => $search,
        phase                => $phase,
        last_days            => $last_days,
        next_days            => $next_days,
        order                => $order,
        project              => $project,
        default_project      => $default_project,
        project_name         => $project_name,
        project_id           => $project_id,
        studio_name          => $studio_name,
        studio_id            => $studio_id,
        json_callback        => $json_callback,
        excerpt              => $excerpt,
        description          => $description,
        locations_to_exclude => $locations_to_exclude,
        projects_to_exclude  => $projects_to_exclude,
        exclude_locations    => $exclude_locations,
        exclude_projects     => $exclude_projects,
        exclude_event_images => $exclude_event_images,
        extern               => $extern,
        all_recordings       => $all_recordings,
        active_recording     => $active_recording,
        only_active_recordings => $only_active_recording,
        set_no_listen_keys   => $set_no_listen_keys,
        ro                   => ($params->{ro}//'') ? 1 : 0
    };
    return $checked;
}

sub l($){
    my ($word) = @_;
    return length $word ? $word : ();
}

sub get_keys($) {
    my ($event) = @_;
    my $series_name            = $event->{series_name}            // '';
    my $title                  = $event->{title}                  // '';
    my $user_title             = $event->{user_title}             // '';
    my $episode                = $event->{episode}                // '';
    my $recurrence_count_alpha = $event->{recurrence_count_alpha} // '';

    # "<title>: <user-title>"
    my $tkey = join (': ', (l($title), l($user_title)));

    # episode "#123c"
    my $ekey = join '', (
        (length $episode) ? '#'.$episode : '',
        $recurrence_count_alpha
    );

    # "<title> <episode>"
    my $te = join " ", (l($tkey), l($ekey));

    # separation between <series> and <title>
    my $stkey = (length($series_name) and length($te)) ? ' - ' : '';
    return {
        skey                            => $series_name,
        stkey                           => $stkey,
        tkey                            => $tkey,
        ekey                            => $ekey,
        full_title                      => $series_name . $stkey . $te,
        full_title_no_series            => $te,
    };
}

#do not delete last line!
1;
