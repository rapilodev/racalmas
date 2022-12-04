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
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu' } );
    my $out = template::process( $config, template::check( $config, 'default.html' ), $headerParams );
    uac::check($config, $params, $user_presets);

    $out .= q{
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
    return $out . compare( $config, $request ) if $params->{action} eq 'diff';
    return $out . show_history( $config, $request );
}

#show existing event history
sub show_history {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    for my $attr ('studio_id') {    # 'series_id','event_id'
    ParamError->throw(error=> "missing " . $attr . " to show changes" ) unless defined $params->{$attr};
    PermissionError->throw(error=>"missing permissions to show changes") unless $permissions->{read_event} == 1;

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

    return template::process( $config, template::check( $config, 'event-history' ), $params );
}

#show existing event history
sub compare {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    for my $attr ( 'project_id', 'studio_id', 'event_id', 'v1', 'v2' ) {
        ParamError->throw(error=> "missing $attr to show changes" ) unless defined $params->{$attr};

    PermissionError->throw(error=>"missing permissions to show changes") unless $permissions->{read_event} == 1;

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
        return "no changes\n";
    }

    my $out = '';
    $out .= '<textarea>' . $t1 . '</textarea>';
    $out .= '<textarea>' . $t2 . '</textarea>';

    my $cmd="/usr/bin/colordiff /tmp/diff-a.txt /tmp/diff-b.txt | ansi2html";
    #print  "$cmd\n";
    log::save_file('/tmp/diff-a.txt', $t1);
    log::save_file('/tmp/diff-b.txt', $t2);
    $out .= qq{
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
    $out .= "$diff\n";

}

sub eventToText {
    my $event = shift;

    my $s = events::get_keys($event)->{full_title} . "\n";
    $s .= $event->{excerpt} . "\n";
    $s .= $event->{user_excerpt} . "\n";
    $s .= $event->{topic} . "\n";
    $s .= $event->{content} . "\n";

    return $s;

}

sub check_params {
    my ($config, $params) = @_;

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

