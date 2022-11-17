#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use config();
use params();
use db();
use events();
use time();
use aggregator();
use markup();
use log();

if ( $0 =~ /aggregate.*?\.cgi$/ ) {
    binmode STDOUT, ":encoding(UTF-8)";

    my $params = {};
    my $r      = shift;
    if ( ref($r) eq '' ) {
        unshift @ARGV, $r;
        for my $arg (@ARGV) {
            my ( $key, $value ) = split( /\=/, $arg, 2 );
            $params->{$key} = $value;
        }
    } else {
        ( my $cgi, $params, my $error ) = params::get($r);
    }

    my $config = config::getFromScriptLocation();

    my $debug    = $config->{system}->{debug};
    my $base_dir = $config->{locations}->{base_dir};

    my $output_header = '';
    if ( exists $ENV{REQUEST_URI} && $ENV{REQUEST_URI} ne '' ) {
        $output_header .= "Content-type:text/html; charset=UTF-8;\n\n";
    }

    $params->{exclude_locations}    = 1;
    $params->{exclude_projects}     = 1;
    $params->{exclude_event_images} = 1;
    $params->{ro} = 1;
    $params->{recordings}           = 1;

    my $request = {
        url    => $ENV{QUERY_STRING},
        params => {
            original => $params,
            checked  => aggregator::check_params( $config, $params ),
        },
    };
    $params = $request->{params}->{checked};

    my $content = load_file( $base_dir . './index.html' );

    #replace HTML escaped calcms_title span by unescaped one
    $content =~
s/\&lt\;span id\=&quot\;calcms_title&quot\;\&gt\;[^\&]*\&lt\;\/span\&gt\;/\<span id=\"calcms_title\" \>\<\/span\>/g;

    my $list = aggregator::get_list( $config, $request );

    my $menu = { content => '' };

    $list->{day} = '' unless defined $list->{day};
    $list->{day} = $params->{date}      if ( defined $params->{date} )      && ( $params->{date} ne '' );
    $list->{day} = $params->{from_date} if ( defined $params->{from_date} ) && ( $params->{from_date} ne '' );
    $list->{day} = 'today'              if $list->{day} eq '';

    $params->{recordings} = 0;
    $menu = aggregator::get_menu( $config, $request, $list->{day}, $list->{results} );

    my $calendar = aggregator::get_calendar( $config, $request, $list->{day} );
    my $newest_comments = aggregator::get_newest_comments( $config, $request );

    #build results list
    my $output = {};
    $output->{calcms_menu}            = \$menu->{content};
    $output->{calcms_list}            = \$list->{content};
    $output->{calcms_calendar}        = \$calendar->{content};
    $output->{calcms_newest_comments} = \$newest_comments->{content};

    my $url = $list->{url};
    my $js  = qq{
        set('preloaded','1');
        set('last_list_url','$url');
    };
    $content =~ s/\/\/\s*(calcms_)?preload/$js/;

    #insert results into page
    for my $key ( keys %$output ) {
        my $val = ${ $output->{$key} };
        my $start = index( $val, "<body>" );
        if ( $start != -1 ) {
            $val = substr( $val, $start + length('<body>') );
        }
        my $end = index( $val, "</body>" );
        if ( $end != -1 ) {
            $val = substr( $val, 0, $end );
        }
        $content =~ s/(<(div|span)\s+id="$key".*?>).*?(<\/(div|span)>)/$1$val$3/g;
    }

    #replace whole element span with id="calcms_title" by value
    $list->{project_title} = '' unless defined $list->{project_title};
    $content =~ s/(<(div|span)\s+id="calcms_title".*?>).*?(<\/(div|span)>)/$list->{project_title}/g;

    my $title = join ' - ', grep {defined $_ and $_ ne ''} ( 
        $list->{'series_name'}, $list->{'title'}, 
        $list->{'location'}, 'Programm ' . $list->{project_title} 
    );
    $content =~ s/(<title>)(.*?)(<\/title>)/$1$title$3/;

    $js = '';
    if ( ( defined $list->{event_id} ) && ( $list->{event_id} ne '' ) ) {
        $js .= qq{showCommentsByEventIdOrEventStart('$list->{event_id}','$list->{start_datetime}')};
    }

    $content =~ s/startCalcms\(\)\;/$js/gi;
    print $output_header;
    print $content;
    $content = undef;
}

sub load_file {
    my ($filename) = @_;
    open my $fh, '<:utf8', $filename or return qq{cannot load '$filename'};
    local $/ = undef;
    my $content = <$fh>;
    close $fh or return qq{cannot load '$filename'};
    return $content;
}

