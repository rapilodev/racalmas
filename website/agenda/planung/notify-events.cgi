#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Data::Dumper;
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
use series();
use localization();
use mail();

binmode STDOUT, ":utf8";

my $r = shift;
(my $cgi, my $params, my $error) = params::get($r);

my $config = config::get('../config/config.cgi');
my ($user, $expires) = auth::get_user($config, $params, $cgi);
return if ((!defined $user) || ($user eq ''));

my $user_presets = uac::get_user_presets(
    $config,
    {
        user       => $user,
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id}
    }
);
$params->{default_studio_id} = $user_presets->{studio_id};
$params = uac::setDefaultStudio($params, $user_presets);
$params = uac::setDefaultProject($params, $user_presets);

my $request = {
    url => $ENV{QUERY_STRING} || '',
    params => {
        original => $params,
        checked  => check_params($config, $params),
    },
};

#set user at params->presets->user
$request = uac::prepare_request($request, $user_presets);
$params = $request->{params}->{checked};

#show header
unless (params::is_json() || ($params->{template} =~ /\.txt/) || $params->{action}eq'send') {
    my $headerParams = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc} = localization::get($config, { user => $user, file => 'menu' });
    template::process($config, 'print', template::check($config, 'default.html'), $headerParams);
}
return unless uac::check($config, $params, $user_presets) == 1;

if ($params->{action} eq 'send') {
    sendMail($config, $request);
    return;
}
show_events($config, $request);

#show existing event history
sub show_events {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ('project_id', 'studio_id') {    # 'series_id','event_id'
        unless (defined $params->{$attr}) {
            uac::print_error("missing " . $attr . " to show changes");
            return;
        }
    }

    unless ($permissions->{read_event} == 1) {
        uac::print_error("missing permissions to show changes");
        return;
    }

    # get events
    my $duration = $params->{duration} // 7;
    my $options  = {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        from_date  => time::time_to_date(),
        till_date  => time::time_to_date(time() + $duration * 24 * 60 * 60),
        draft      => 0,
        published  => 1
    };

    my $events = series::get_events($config, $options);

    # get series_users
    for my $event (@$events) {
        my $mail = getMail($config, $request, $event);
        $event->{mail} = $mail;
        $event->{start} = substr($event->{start}, 0, 16);
        $event->{preproduction} = !$event->{live};
    }

    return unless defined $events;
    my @events = sort { $a->{start} cmp $b->{start} } @$events;
    $params->{events} = \@events;

    for my $permission (keys %{$permissions}) {
        $params->{'allow'}->{$permission} = $request->{permissions}->{$permission};
    }

    $params->{loc} = localization::get($config, { user => $params->{presets}->{user}, file => 'notify-events' });
    template::process($config, 'print', $params->{template}, $params);

}

sub sendMail {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};

    for my $attr ('project_id', 'studio_id', 'series_id', 'event_id') {
        unless (defined $params->{$attr}) {
            uac::print_error("missing " . $attr . " to send notification");
            return;
        }
    }

    unless ($permissions->{read_event} == 1) {
        uac::print_error("missing permissions to send notification");
        return;
    }

    my $options = {
        project_id => $params->{project_id},
        studio_id  => $params->{studio_id},
        series_id  => $params->{series_id},
        event_id   => $params->{event_id},
        draft      => 0,
        published  => 0,
    };
    my $events = series::get_events($config, $options);

    unless (scalar(@$events) == 1) {
        uac::print_error("did not found exactly one event");
        return;
    }

    my $mail = getMail($config, $request, $events->[0]);
    $mail->{To}      = $params->{to}      if defined $params->{to};
    $mail->{Cc}      = $params->{cc}      if defined $params->{cc};
    $mail->{Subject} = $params->{subject} if defined $params->{subject};
    $mail->{Data}    = $params->{content} if defined $params->{content};

    try {
        my $result = mail::send($mail);
        print "Content-type:text/plain\n\ndone:$result\n";
    } catch {
        printf "Content-type:text/plain\n\nresult:%s\n", $_->{message} // $_;
    }
}

sub getMail {
    my ($config, $request, $event) = @_;

    my $users = series::get_users(
        $config,
        {
            project_id => $event->{project_id},
            studio_id  => $event->{studio_id},
            series_id  => $event->{series_id}
        }
    );

    my $userNames = [];
    my $userMails = [];
    for my $user (@$users) {
        push @$userNames, (split(/\s+/, $user->{full_name}))[0];
        push @$userMails, $user->{email};
    }
    if (scalar(@$userMails) == 0) {
        $event->{noRecipient} = 1;
        return;
    }
    my $sender = $config->{locations}->{event_sender_email};
    my $mail = {
        'From'     => $sender,
        'To'       => join(', ', @$userMails),
        'Cc'       => $sender,
        'Reply-To' => $sender,
        'Subject'  => substr($event->{start},0,16) . " - $event->{full_title}",
        'Data'     => "Hallo " . join(' und ', @$userNames) . ",\n\n"
    };

    $mail->{Data} .= "nur zur Erinnerung...\n\n";
    $mail->{Data} .= "am $event->{weekday_name} ist die nächste '$event->{series_name}'-Sendung.\n\n";
    $mail->{Data} .=
      "$event->{source_base_url}$event->{widget_render_url}/$config->{controllers}->{event}/$event->{event_id}.html\n\n";
    $mail->{Data} .= "Gruß, $request->{user}\n";
    return $mail;
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
    my $config = shift;
    my $params = shift;

    my $checked  = {};
    my $template = '';
    $checked->{template} = template::check($config, $params->{template}, 'notify-events');

    entry::set_numbers($checked, $params, [
        'event_id', 'project_id', 'studio_id', 'default_studio_id', 'user_id', 'series_id', 'duration'
    ]);

    entry::set_strings($checked, $params, [
        'subject', 'to', 'cc', 'content']);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{action} = entry::element_of($params->{action}, ['send']);
    return $checked;
}

