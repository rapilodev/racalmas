#! /usr/bin/perl -w 

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Encode();
use Data::Dumper;
use MIME::Base64();
use Encode::Locale();

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
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my $debug  = $config->{system}->{debug};
my ( $user, $expires ) = auth::get_user( $config, $params, $cgi );
return if ( !defined $user ) || ( $user eq '' );

my $user_presets = uac::get_user_presets(
    $config,
    {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio( $params, $user_presets );
$params = uac::setDefaultProject( $params, $user_presets );

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params( $config, $params ),
    },
};

#set user at params->presets->user
$request = uac::prepare_request( $request, $user_presets );

$params = $request->{params}->{checked};

#show header
if ( ( params::isJson() ) || ( defined $params->{action} ) ) {
    print "Content-Type:text/html; charset=utf-8;\n\n";
} else {
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
    template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
    print q{
        <script src="js/datetime.js" type="text/javascript"></script>
    } unless (params::isJson);
}
return unless uac::check( $config, $params, $user_presets ) == 1;

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

sub showComments {
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_comment} == 1 ) {
        uac::permissions_denied('read_comment');
        return;
    }

    for my $attr ( 'project_id', 'studio_id' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show comment" );
            return;
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
            $event->{cache_base_url} = $config->{cache}->{base_url};
        }
    }
    for my $param (%$comment) {
        $template_parameters->{$param} = $comment->{$param};
    }

    $template_parameters->{search}        = markup::fix_utf8( $request->{params}->{original}->{search} );
    $template_parameters->{events}        = $events;
    $template_parameters->{debug}         = $config->{system}->{debug};
    $template_parameters->{event_count}   = scalar(@$events);
    $template_parameters->{comment_count} = $comment_count;
    $template_parameters->{is_empty}      = 1 if scalar @$events == 0;
    $template_parameters->{projects}      = project::get_with_dates($config);
    $template_parameters->{controllers}   = $config->{controllers};
    $template_parameters->{allow}         = $permissions;
    $template_parameters->{loc} =
      localization::get( $config, { user => $params->{presets}->{user}, file => 'comment' } );

    #fill and output template
    template::process( $config, 'print', $params->{template}, $template_parameters );
}

sub modify_comments {
    my $config  = shift;
    my $request = shift;
    my $results = shift;

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
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{update_comment_status_lock} == 1 ) {
        uac::permissions_denied('update_comment_status_lock');
        return;
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
    my $config  = shift;
    my $request = shift;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    unless ( $permissions->{update_comment_status_read} == 1 ) {
        uac::permissions_denied('update_comment_status_read');
        return;
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
    my $config = shift;
    my $params = shift;

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

