#!/usr/bin/perl
use strict;
use warnings;
use CGI::Simple;
use feature 'state';
$| = 1;

state $words = q{
heute today
(\d\d)\.(\d\d).(\d\d\d\d)  $3-$2-$1
};

state $lines = q{
^sendungen/heute/               events/today/
^sendungen/                     events/
^sendung/                       event/
^sendereihen/                   series/
^sendereihe/                    serie/
^kalender/                      calendar/
^menu/heute/                    menu/today&$1
^suche/(.*?)/(.*?)/kommende/    search/$1/$2/upcoming/
^suche/(.*?)/(.*?)/vergangene/  search/$1/$2/gone/
^suche/                         search/
^kommentare/                    comments/
^neueste_kommentare/            comments/latest/
^feed_kommentare/               comments/feed/
^kommentar_neu/                 comments/add/
^dashboard/sendung/             dashboard/event/

^events/today/                                         events.cgi?template=event_list.html&date=today& [L]
^events/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/(\d)/  events.cgi?template=event_list.html&from_date=$1&till_date=$2&weekday=$3& [L]
^events/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/       events.cgi?template=event_list.html&from_date=$1&till_date=$2& [L]
^events/(\d{4}-\d{2}-\d{2})/                           events.cgi?template=event_list.html&date=$1& [L]
^events/                                               events.cgi? [L]

^event/(\d+)/[^&]*(&.*)?$    events.cgi?template=event_details.html&event_id=$1& [L]
^event/                 events.cgi? [L]

^playlist/              events.cgi?template=event_playlist.html&time=future&limit=5& [L]
^playlistLong/          events.cgi?template=event_playlist_long.html&time=future&limit=20& [L]
^playlistUtc/           events.cgi?template=event_utc_time.json&limit=1
^playlist_show/         events.cgi?template=event_playlist_show.html&time=future&limit=3& [L]

^running_event/         events.cgi?template=event_running.html&time=now&limit=1& [L]
^running_event_id/      events.cgi?template=event_running_id.html&time=now&limit=1& [L]

^menu/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/(\d)/    events.cgi?template=event_menu.html&from_date=$1&till_date=$2&weekday=$3& [L]
^menu/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/         events.cgi?template=event_menu.html&from_date=$1&till_date=$2& [L]
^menu/(\d{4}-\d{2}-\d{2})/                             events.cgi?template=event_menu.html&date=$1& [L]
^menu/today/                                           events.cgi?template=event_menu.html&date=today& [L]
^menu/                                                 events.cgi? [L]

^series/                                          series_names.cgi? [L]
^serie/(.*?)/(.*?)/upcoming/                      events.cgi?template=event_list.html&project=$1&series_name=$2&archive=coming& [L]
^serie/(.*?)/(.*?)/over/                          events.cgi?template=event_list.html&project=$1&series_name=$2&archive=gone& [L]
^serie/(.*?)/(.*?)/show/$                              events.cgi?template=event_redirect.html&project=$1&series_name=$2&limit=1& [L]
^serie/(.*?)/(.*?)/                               events.cgi?template=event_list.html&project=$1&series_name=$2& [L]
^serie/(.*?)/                                     events.cgi?template=event_list.html&series_name=$1& [L]

^calendar/(\d{4}-\d{2}-\d{2})/$                             cal.cgi?date= [L]
^calendar/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/$         cal.cgi?from_date=$1&till_date= [L]
^calendar/                                             cal.cgi? [L]

^feed/                                                 events.cgi?template=event.atom.xml&time=future&limit=100& [L]
^feed.xml[\?]?                                         events.cgi?template=event.atom.xml&time=future&limit=100& [L]
^atom/                                                 events.cgi?template=event.atom.xml&time=future&limit=100& [L]
^atom.xml[\?]?                                         events.cgi?template=event.atom.xml&time=future&limit=100& [L]
^rss/                                                  events.cgi?template=event.rss.xml&time=future&limit=100& [L]
^rss.xml[\?]?                                          events.cgi?template=event.rss.xml&time=future&limit=100& [L]
^rss-media/                                            events.cgi?last_days=7&only_active_recording=1&template=event_media.rss.xml& [L]

^ical/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/(\d)/     events.cgi?template=event.ics&from_date=$1&till_date=$2&weekday=$3& [L]
^ical/(\d{4}-\d{2}-\d{2})/(\d{4}-\d{2}-\d{2})/          events.cgi?template=event.ics&from_date=$1&till_date=$2& [L]
^ical/(\d{4}-\d{2})/                                   events.cgi?template=event.ics&from_date=$1-01&till_date=$1-31& [L]
^ical/(\d{4}-\d{2}-\d{2})/                              events.cgi?template=event.ics&date=$1& [L]
^ical/(\d+)/(.*)?$                                           events.cgi?template=event.ics&event_id=$1& [L]
^ical/                                                  events.cgi?template=event.ics& [L]
^ical\.ics[\?]?                                         events.cgi?template=event.ics& [L]

^search/(.*?)/(.*?)/coming/        events.cgi?template=event_list.html&project=$1&search=$2&archive=coming& [L]
^search/(.*?)/(.*?)/over/          events.cgi?template=event_list.html&project=$1&search=$2&archive=gone& [L]
^search/(.*?)/(.*?)/               events.cgi?template=event_list.html&project=$1&search=$2& [L]
^search/(.*?)/                     events.cgi?template=event_list.html&search=$1& [L]

^rds/                              events.cgi?template=event_playlist.txt&time=now&limit=1& [L]
^json/                             events.cgi?template=event.json&time=now&limit=15& [L]

^comments/latest/                 comments.cgi?template=comments_newest.html&limit=20&show_max=3&type=list& [L]
^comments/feed/                   comments.cgi?template=comments.xml&limit=20& [L]
^comments/add/                    add_comment.cgi? [L]
^comments/(\d+)/(\d{4}-\d{2}-\d{2}[T\+]\d{2}\:\d{2})(\:\d{2})?/ comments.cgi?template=comments.html&event_id=$1&event_start=$2&sort_order=asc& [L]

# special
^dashboard/event/(\d+)/[^&]*(&.*)?$    events.cgi?template=event_dashboard_details.html&event_id=$1& [L]
^dashboard/date/(\d{4}-\d{2}-\d{2})/   events.cgi?template=event_dashboard.html.js&date=$1& [L]
^dashboard/                       events.cgi?template=event_dashboard.html.js&time=now&limit=1& [L]

^freefm.xml$                           events.cgi?template=event_freefm.xml&location=piradio&limit=40 [L]
^frrapo-programm.html$                 events.cgi?location=potsdam&template=event_frrapo [L]
^upload_playout_piradio$               upload_playout.cgi?project_id=1&studio_id=1 [L]
^redaktionen-piradio$                  series.cgi?project_id=1&location=piradio [L]
^redaktionen-studio-ansage$            series.cgi?project_id=1&location=ansage [L]
^redaktionen-frrapo$                   series.cgi?project_id=1&location=potsdam [L]
^redaktionen-colabo-radio$             series.cgi?project_id=1&location=colabo [L]
^redaktionen-frb$                      series.cgi?project_id=1&location=frb [L]
};

#state $line_regex = qr/^\s*(.*?)\s+(.*?)(?:\s+(.*?)\s*)/;
state $compiled_words = [];
unless (@$compiled_words) {
    for my $line (split /\n+/, $words) {
        next if !$line or $line =~ /^#/;
        push @$compiled_words, [split /\s+/, $line];
    }
}

state $compiled_lines = [];
unless (scalar @$compiled_lines) {
    for my $line (split /\n+/, $lines) {
        next if !$line or $line =~ /^#/;
        my ($k, $v, $last) = split /\s+/, $line;
        if ($k =~ /^\//) {
            my $groups = split /\(/, $k;
            $k .= "(.*)\$";
            $v .= "\&\$$groups";
        }
        push @$compiled_lines, [$k, $v, $last];
    }
}

my $cgi = CGI::Simple->new;
my $url = $cgi->param('url')//'';

my $orig = $url;

$url =~ s/$_->[0]/$_->[1]/g for (@$compiled_words);
$url =~ s/$_->[0]/$_->[1]/g && defined $_->[2] && last for (@$compiled_lines);

print "$url\n";


#if ($orig eq $url) {
#    print $orig;
#    print $cgi->header(-status => 404);
#} else {
#    print $cgi->redirect(-uri => "/agenda/$url");
#}
