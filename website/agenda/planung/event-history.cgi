#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use URI::Escape();
use Data::Dumper;
use MIME::Base64();
use Scalar::Util qw( blessed );
use Try::Tiny;

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
use studios();
use event_history();
use events();
use series_events();
use localization();
use utf8;
binmode STDOUT, ":utf8";

my $r = shift;
( my $cgi, my $params, my $error ) = params::get($r);

my $config = config::get('../config/config.cgi');
my ($user, $expires) = try {
    auth::get_user($config, $params, $cgi)
} catch {
    auth::show_login_form('',$_->message // $_->error) if blessed $_ and $_->isa('AuthError');
};
return unless $user;
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
my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
$headerParams->{loc} = localization::get( $config, { user => $user, file => 'menu' } );
template::process( $config, 'print', template::check( $config, 'default.html' ), $headerParams );
return unless uac::check( $config, $params, $user_presets ) == 1;

print q{
    <style>
        pre{
            font-family:monospace;
        }
        textarea{
            height:fit-content;
            min-height:500px;
            width:50%;
        }
    </style>
};

$config->{access}->{write} = 0;
if ( $params->{action} eq 'diff' ) {
    compare( $config, $request );
    return;
}
show_history( $config, $request );

#show existing event history
sub show_history {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    for my $attr ('studio_id') {    # 'series_id','event_id'
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show changes" );
            return;
        }
    }

    unless ( $permissions->{read_event} == 1 ) {
        uac::print_error("missing permissions to show changes");
        return;
    }

    my $options = {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        limit      => 200
    };
    $options->{series_id} = $params->{series_id} if defined $params->{series_id};
    $options->{event_id}  = $params->{event_id}  if defined $params->{event_id};

    my $events = event_history::get( $config, $options );

    return unless defined $events;
    $params->{events} = $events;

    for my $permission ( keys %{$permissions} ) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }
    $params->{loc} = localization::get( $config, { user => $params->{presets}->{user}, file => 'event-history' } );

    template::process( $config, 'print', template::check( $config, 'event-history' ), $params );
}

#show existing event history
sub compare {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    for my $attr ( 'project_id', 'studio_id', 'event_id', 'v1', 'v2' ) {
        unless ( defined $params->{$attr} ) {
            uac::print_error( "missing " . $attr . " to show changes" );
            return;
        }
    }

    unless ( $permissions->{read_event} == 1 ) {
        uac::print_error("missing permissions to show changes");
        return;
    }

    if ( $params->{v1} > $params->{v2} ) {
        my $t = $params->{v1};
        $params->{v1} = $params->{v2};
        $params->{v2} = $t;
    }

    my $options = {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        series_id  => $params->{series_id},
        event_id   => $params->{event_id},
        change_id  => $params->{v1},
        limit      => 2
    };

    my $events = event_history::get( $config, $options );
    return unless @$events == 1;
    my $v1 = $events->[0];

    $options->{change_id} = $params->{v2};
    $events = event_history::get( $config, $options );
    return unless @$events == 1;
    my $v2 = $events->[0];

    my $t1 = eventToText($v1);
    my $t2 = eventToText($v2);

    if ( $t1 eq $t2 ) {
        print "no changes\n";
        return;
    }

    print '<textarea>' . $t1 . '</textarea>';
    print '<textarea>' . $t2 . '</textarea>';

    my $cmd="/usr/bin/colordiff /tmp/diff-a.txt /tmp/diff-b.txt | ansi2html";
    #print  "$cmd\n";
    log::save_file('/tmp/diff-a.txt', $t1);
    log::save_file('/tmp/diff-b.txt', $t2);
    print qq{
        <style>
        pre {
    font-weight: normal;
    color: #bbb;
    white-space: -moz-pre-wrap;
    white-space: -o-pre-wrap;
    white-space: -pre-wrap;
    white-space: pre-wrap;
    word-wrap: break-word;
    overflow-wrap: break-word;
}
b {font-weight: normal}
b.BOLD {color: #fff}
b.ITA {font-style: italic}
b.UND {text-decoration: underline}
b.STR {text-decoration: line-through}
b.UNDSTR {text-decoration: underline line-through}
b.BLK {color: #000000}
b.RED {color: #aa0000}
b.GRN {color: #00aa00}
b.YEL {color: #aa5500}
b.BLU {color: #0000aa}
b.MAG {color: #aa00aa}
b.CYN {color: #00aaaa}
b.WHI {color: #aaaaaa}
b.HIK {color: #555555}
b.HIR {color: #ff5555}
b.HIG {color: #55ff55}
b.HIY {color: #ffff55}
b.HIB {color: #5555ff}
b.HIM {color: #ff55ff}
b.HIC {color: #55ffff}
b.HIW {color: #ffffff}
b.BBLK {background-color: #000000}
b.BRED {background-color: #aa0000}
b.BGRN {background-color: #00aa00}
b.BYEL {background-color: #aa5500}
b.BBLU {background-color: #0000aa}
b.BMAG {background-color: #aa00aa}
b.BCYN {background-color: #00aaaa}
b.BWHI {background-color: #aaaaaa}
    </style>        
    };
    my $diff = qx{$cmd};
    $diff = substr($diff, index($diff, "<body>")+6);
    $diff = substr($diff, 0, index($diff, "</body>"));
    print "$diff\n";
    
}

sub eventToText {
    my $event = shift;

    my $s = events::get_keys($event)->{full_title} . "\n";
    $s .= $event->{excerpt} . "\n";
    $s .= $event->{user_excerpt} . "\n";
    $s .= $event->{topic} . "\n";
    $s .= $event->{content} . "\n";

    #print STDERR "DUMP\n$s";
    return $s;

}

sub check_params {
    my $config = shift;
    my $params = shift;

    my $checked  = {};
    my $template = '';
    $checked->{template} = template::check( $config, $params->{template}, 'event-history' );

    #numeric values
    entry::set_numbers( $checked, $params, [
        'id', 'project_id', 'studio_id', 'default_studio_id', 'user_id', 'series_id', 'event_id', 'v1', 'v2'
    ]);

    if ( defined $checked->{studio_id} ) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{action} = entry::element_of($params->{action}, ['show', 'diff']);

    return $checked;
}

