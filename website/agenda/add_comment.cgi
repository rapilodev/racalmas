#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;

use params();
use config();
use db();
use markup();
use comments();
use template();
use log();
use time();

binmode STDOUT, ":utf8";

my $r = shift;
my ($params, $error) = params::get($r);

my $config = config::getFromScriptLocation();
my $request = {
    url    => $ENV{QUERY_STRING},
    params => {
        original => $params,
        checked  => check_params($config, $params),
    },
    config => $config,
};
$params = $request->{params}->{checked};

print "Content-Type:text/plain\n\n";

print STDERR "add comment: " . Dumper($params);
my $comment = $params->{comment};

local $config->{access}->{write} = 1;
my $dbh = db::connect($config, undef);

print "ok\n";

$comment->{content} =~ s/(^|\s)((https?\:\/\/)(.*?))(\s|$|\<)/$1\<a href\=\"$2\"\>$2\<\/a\>$5/g;
$comment->{content} =~ s/(^|\s)((https?\:\/\/)(.*?))(\s|$|\<)/$1\<a href\=\"$2\"\>$2\<\/a\>$5/g;
$comment->{content} =~ s/(^|\s)((www\.)(.*?))(\s|$|\<)/$1\<a href\=\"http\:\/\/$2\"\>$2\<\/a\>$5/g;    #"
$comment->{content} =~ s/(^|\s)((www\.)(.*?))(\s|$|\<)/$1\<a href\=\"http\:\/\/$2\"\>$2\<\/a\>$5/g;    #"

if (comments::check($dbh, $config, $comment)) {
    my $nslookup = nslookup();

    if (is_blocked($nslookup)==1){
        send_mail($comment, $nslookup, 'blocked');
        return;
    };

    $comment->{comment_id} = comments::insert($dbh, $config, $comment);
    if ($comment->{comment_id} > 0) {
        comments::update_comment_count($dbh, $config, $comment);
        send_mail($config, $comment, $nslookup, 'new');
    }
}

sub is_blocked {
    my $nslookup = shift;

    my $user_agent = $ENV{HTTP_USER_AGENT};

    # add lock settings here
    # return 1 if
    #    ($user_agent eq 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:35.0) Gecko/20100101 Firefox/35.0')
    #  && ($nslookup =~ /alicedsl/);

    return 0;
}

sub send_mail {
    my $config   = shift;
    my $comment  = shift;
    my $nslookup = shift;
    my $status   = shift || 'new';

    my $ip         = $ENV{REMOTE_ADDR}     || '';
    my $user_agent = $ENV{HTTP_USER_AGENT} || '';
    my $cookie     = $ENV{HTTP_COOKIE}     || '';

    my $locations   = $config->{locations};
    my $base_domain = $locations->{base_domain};
    my $from        = $locations->{email};
    my $to          = $locations->{email};
    my $subject     = "$status comment from '$comment->{author}': $comment->{content}";
    my $content     = qq!$status comment

FROM:    '$comment->{author}'
EMAIL:    $comment->{email}

CONTENT: '$comment->{content}'

view event
$base_domain/programm/sendung/$comment->{event_id}.html#comments
!;

    if ($status eq 'new') {
        $content .= qq!
manage comments:
$base_domain/agenda/planung/comment.cgi?project_id=1&studio_id=1

lock this comment
$base_domain/agenda/planung/comment.cgi?event_id=$comment->{event_id}&comment_id=$comment->{comment_id}&set_lock_status=blocked
!;
    }

    $content .= qq{
-----------------------------------------------------------

SENDER IP:      $ip  ($comment->{ip})
USER AGENT:     $user_agent
COOKIE:         $cookie

$nslookup
};

    use MIME::Lite;
    my $msg = MIME::Lite->new(
        From    => $from,
        To      => $to,
        Subject => $subject,
        Data    => $content
    );

    $msg->send;
}

sub nslookup {
    my $ip       = $ENV{REMOTE_ADDR};
    my $nslookup = '';
    if ($ip =~ /^([\d\.]+)$/) {
        $ip = $1;
        return `nslookup '$ip'`;
    }
    return '';
}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $template = template::check($config, $params->{'template'}, 'comments.html');

    my $comment = {};

    my $event_start = $params->{'event_start'} || '';
    if ($event_start =~ /^(\d\d\d\d\-\d\d\-\d\d[ T]\d\d\:\d\d)(\:\d\d)?$/) {
        $comment->{event_start} = $1;
    } else {
        log::error($config, 'add_comment.cgi: invalid date "' . $event_start . '"');
    }

    my $event_id = $params->{'event_id'} || '';
    if ($event_id =~ /^(\d+)$/) {
        $comment->{event_id} = $1;
    } else {
        log::error($config, 'add_comment.cgi: invalid id');
    }

    my $parent_id = $params->{'parent_id'} || '';
    if ($parent_id =~ /^(\d+)$/) {
        $comment->{parent_id} = $1;
    } else {
        $comment->{parent_id} = 0;
    }

    $comment->{content} = $params->{'content'} || '';
    $comment->{content} = escape_text($comment->{content});
    $comment->{content} = substr($comment->{content}, 0, 1000);
    log::error($config, 'add_comment.cgi: missing body') if $comment->{content} eq '';

    $comment->{author} = $params->{'author'} || '';
    $comment->{author} = escape_text($comment->{author});
    $comment->{author} = substr($comment->{author}, 0, 40);
    log::error($config, 'add_comment.cgi: missing name') if $comment->{author} eq '';

    $comment->{email} = $params->{'email'} || '';
    $comment->{email} = escape_text($comment->{email});
    $comment->{email} = substr($comment->{email}, 0, 40);

    $comment->{title} = $params->{'title'} || '';
    $comment->{title} = escape_text($comment->{title});
    $comment->{title} = substr($comment->{title}, 0, 80);

    $comment->{ip} = $ENV{REMOTE_ADDR} || '';
    log::error($config, 'missing ip') if $comment->{ip} eq '';
    $comment->{ip} = Digest::MD5::md5_base64($comment->{ip});

    my $today      = time::datetime_to_array(time::time_to_datetime());
    my $date       = time::datetime_to_array($comment->{event_start});
    my $delta_days = time::days_between($today, $date);

    log::error($config, 'add_comment.cgi: no comments allowed, yet')
      if $delta_days > $config->{permissions}->{no_new_comments_before};

    log::error($config, 'add_comment.cgi: no comments allowed anymore')
      if $delta_days < -1 * $config->{permissions}->{no_new_comments_after};

    return {
        template => $template,
        comment  => $comment
    };
}

sub escape_text {
    my $s = shift;
    $s =~ s/^\s+//g;
    $s =~ s/\s+$//g;

    #remove broken HTML
    $s =~ s/<[a-z\!\?\[\/][^\>]+?\>//gi;
    $s =~ s/<[a-z\!\?\[\/]\>//gi;

    $s = markup::escapeHtml($s);
    $s =~ s/[\n\r]+/\<br \/\>/g;
    $s =~ s/\<br \/\>/\<br \/\>\n/g;
    $s =~ s/\<br \/\>\s*$//g;
    return $s;
}

