#! /usr/bin/perl -w

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Encode();
use Data::Dumper;
use MIME::Base64();
use Encode::Locale();
use Scalar::Util qw( blessed );
use Try::Tiny;
use Exception::Class (
    'ParamError',
    'PermissionError'
);

use params();
use config();
use entry();
use log();
use template();
use db();
use auth();
use uac();

use time();
use markup();
use project();
use studios();
use comments();
use localization();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #show header
    if ( ( params::isJson() ) || ( defined $params->{action} ) ) {
        print "Content-Type:text/html; charset=utf-8;\n\n";
    } else {
        my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
        $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );
        print template::process( $config, template::check( $config, 'default.html' ), $headerParams );
        print template::process( $config, template::check( $config, 'comment-header.html' ), $headerParams )
            unless (params::isJson);
    }
    uac::check($config, $params, $user_presets);

    if ( defined $params->{action} ) {
        if ( $params->{action} eq 'get_json' ) {
            getJson( $config, $request );
            return;
        }
        if ( $params->{action} eq 'setLock' ) {
            setLock( $config, $request );
            return;
        }
        if ( $params->{action} eq 'setRead' ) {
            setRead( $config, $request );
            return;
        }
    }
    $config->{access}->{write} = 0;
    showComments( $config, $request );
}

sub showComments {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_comment} == 1 ) {
        PermissionError->throw(error=>'Missing permission to read_comment');
    }

    for my $attr ( 'project_id', 'studio_id' ) {
        unless ( defined $params->{$attr} ) {
            ParamError->throw(error=> "missing $attr to show comment" );
        }
    }

    $config->{access}->{write} = 0;
    my $dbh = db::connect($config);

    my $comment             = $params->{comment};
    my $template_parameters = {};

    #my $nodes={};
    #my $sorted_nodes=[];

    my $results = [];
    if ( $params->{search} ne '' ) {
        $params->{comment}->{search} = $params->{search};
        $results = comments::get_by_event( $dbh, $config, $request );
    } elsif ( $comment->{event_id} ne '' ) {
        $results = comments::get_by_event( $dbh, $config, $request );
    } else {
        $results = comments::get_by_time( $dbh, $config, $comment );
    }

    my $events        = [];
    my $comment_count = 0;
    if ( scalar(@$results) > 0 ) {
        my $comments = modify_comments( $config, $request, $results );

        $comments = comments::sort( $config, $comments );

        $events = comments::get_events( $dbh, $config, $request, $comments );
        my $language = $config->{date}->{language} || 'en';
        for my $event (@$events) {
            $event->{start} = time::date_time_format( $config, $event->{start}, $language );
            $comment_count += $event->{comment_count} if defined $event->{comment_count};
            $event->{widget_render_url} = $config->{locations}->{widget_render_url};
        }
    }
    for my $param (%$comment) {
        $template_parameters->{$param} = $comment->{$param};
    }

    $template_parameters->{search}        = markup::fix_utf8( $request->{params}->{original}->{search} );
    $template_parameters->{events}        = $events;
    $template_parameters->{event_count}   = scalar(@$events);
    $template_parameters->{comment_count} = $comment_count;
    $template_parameters->{is_empty}      = 1 if scalar @$events == 0;
    $template_parameters->{projects}      = project::get_with_dates($config);
    $template_parameters->{controllers}   = $config->{controllers};
    $template_parameters->{allow}         = $permissions;
    $template_parameters->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'comment' } );

    #fill and output template
    print template::process( $config, $params->{template}, $template_parameters );
}

sub modify_comments {
    my ($config, $request, $results) = @_;

    my $language = $config->{date}->{language} || 'en';
    for my $result (@$results) {
        $result->{start_date_name}          = time::date_format( $config, $result->{created_at}, $language );
        $result->{start_time_name}          = time::time_format( $result->{created_at} );
        $result->{ $result->{lock_status} } = 1;
        $result->{ $result->{news_status} } = 1;
    }
    return $results;
}

sub setLock {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{update_comment_status_lock} == 1 ) {
        PermissionError->throw(error=>'Missing permission to update_comment_status_lock');
    }

    my $comment = $params->{comment};
    $comment->{id} = $comment->{comment_id};
    if ( $comment->{id} eq '' ) {
        return;
    }

    #todo change set_news_status to lock_status in comment module
    $comment->{set_lock_status} = $comment->{lockStatus};
    $comment->{set_lock_status} = 'blocked' unless $comment->{set_lock_status} eq 'show';

    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);
    print STDERR "setLock " . Dumper($comment);
    comments::set_lock_status( $dbh, $config, $comment );
    print "done\n";
}

sub setRead {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{update_comment_status_read} == 1 ) {
        PermissionError->throw(error=>'Missing permission to update_comment_status_read');
    }

    $config->{access}->{write} = 1;
    my $dbh = db::connect($config);

    my $comment = $params->{comment};
    $comment->{id} = $comment->{comment_id};
    if ( $comment->{id} eq '' ) {
        return;
    }

    #todo change set_news_status to read_status in comment module
    $comment->{set_news_status} = $comment->{readStatus};
    $comment->{set_news_status} = 'received' unless $comment->{set_news_status} eq 'unread';

    print STDERR "setRead " . Dumper($comment);
    comments::set_news_status( $dbh, $config, $comment );
    print "done\n";
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};

    $checked->{action} = entry::element_of($params->{action},
        [ 'setLock', 'setRead', 'showComment', 'update', 'delete']);

    #template
    my $template = '';
    if ( defined $checked->{action} ) {
        $template = template::check( $config, $params->{template}, 'edit-comment' )
          if $checked->{action} eq 'showComment';
    } else {
        $template = template::check( $config, $params->{template}, 'comments' );
    }
    $checked->{template} = $template;

    entry::set_numbers( $checked, $params, [
        'project_id', 'studio_id', 'default_studio_id']);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    my $comment = {};

    for my $key ('readStatus') {
        my $value = $params->{$key};
        $comment->{$key} = $value if ( defined $value ) && ( $value =~ /^(received|unread)$/ );
    }

    for my $key ('lockStatus') {
        my $value = $params->{$key};
        $comment->{$key} = $value if ( defined $value ) && ( $value =~ /^(blocked|show)$/ );
    }

    $comment->{event_start} = time::check_date( $params->{event_start} ) || '';
    $comment->{from}        = time::check_date( $params->{from} )        || '';
    $comment->{till}        = time::check_date( $params->{till} )        || '';

    my $event_id = $params->{event_id} || '';
    if ( $event_id =~ /^(\d+)$/ ) {
        $comment->{event_id} = $1;
    }
    $comment->{event_id} = '' unless defined $comment->{event_id};

    my $id = $params->{comment_id} || '';
    if ( $id =~ /^(\d+)$/ ) {
        $comment->{comment_id} = $1;
    }
    $comment->{comment_id} = '' unless defined $comment->{comment_id};

    my $age = $params->{age} || '';
    if ( $age =~ /^(\d+)$/ ) {
        $comment->{age} = $1;
    }
    $comment->{age} = '365' unless defined $comment->{age};

    my $search = $params->{search} || '';
    if ( ( defined $search ) && ( $search ne '' ) ) {
        $search = substr( $search, 0, 100 );
        $search =~ s/^\s+//gi;
        $search =~ s/\s+$//gi;
        $search =~ s/\-\-//gi;
        $search =~ s/\;//gi;
        $checked->{search} = $search if $search ne '';
    }
    $checked->{search} = '' unless defined $checked->{search};
    $checked->{comment} = $comment;

    return $checked;
}

