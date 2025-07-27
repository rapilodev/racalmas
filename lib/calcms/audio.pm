package audio;
use warnings;
use strict;

sub durationToSeconds($) {
    my ($duration) = @_;
    if ($duration =~ /(\d+):(\d\d):(\d\d).(\d\d)/) {
        return $1 * 3600 + $2 * 60 + $3 + $4 / 100;
    }
    return $duration;
}

sub badge {
    my ($class, $content, $title) = @_;
    return qq{<div class="badge-$class"} .
           ($title ? qq{ title="$title"} : '') .
           qq{>$content</div>};
}

sub named_badge {
    my ($label, $value) = @_;
    return ($value && $label)
        ? badge("ok", join('&nbsp;|&nbsp;', 
            $label ? qq{<b>$label</b>} : (), 
            $value ? $value : ()
          ))
        : '';
}

sub class{
    my ($condition) = @_;
    return $condition ? 'ok' : 'error'
}

sub formatDuration($$$;$) {
    my ($audioDuration, $eventDuration, $value, $mouseOver) = @_;
    return '' unless $audioDuration && $eventDuration && $value;
    $audioDuration = durationToSeconds($audioDuration);
    $eventDuration = durationToSeconds($eventDuration);
    my $class = "ok";
    my $title = $mouseOver;
    my $delta = 100 * $audioDuration / ($eventDuration+.00000000000001);
    if ($delta > 101) {
        $class = "warn";
        $title = sprintf(
            qq{file is too long! It should be %d minutes, but is %d},
            ($eventDuration+30) / 60,
            ($audioDuration+30) / 60
        );
    } elsif ($delta < 99.97) {
        $class = "error";
        $title = sprintf(
            qq{file is too short! should be %d minutes, but is %d},
            ($eventDuration+30) / 60,
            ($audioDuration+30) / 60
        );

    }
    return badge($class, $value, $title);
}

sub formatChannels($) {
    my ($channels) = @_;
    return $channels
        ? badge(class($channels == 2), "$channels ch.")
        : '';
}

sub formatSamplingRate($) {
    my ($samplingRate) = @_;
    return $samplingRate
        ? badge(class($samplingRate == 44100), "$samplingRate Hz") 
        : '';
}

sub formatBitrate($) {
    my ($bitrate) = @_;
    return '' unless $bitrate;
    my $class = 'ok';
    $class = 'warn'  if $bitrate >= 200;
    $class = 'error' if $bitrate < 192;
    return badge($class, "$bitrate kBit/s");
}

sub formatBitrateMode($) {
    my ($mode) = @_;
    return $mode 
        ? badge(class($mode eq 'CBR'), $mode)
        : '';
}

sub formatLoudness {
    my ($value, $prefix, $round) = @_;
    $prefix ||= '';
    $round ||= '';
    return '' unless $value;
    $value = sprintf("%.1f", $value);
    my $class = 'ok';
    $class = 'warn'  if $value > -18.5;
    $class = 'error' if $value > -16.0;
    $class = 'warn'  if $value < -24.0;
    $class = 'error' if $value < -27.0;
    $value = int($value+0.5) if $round;
    return badge($class, "$prefix$value dB");
}

sub formatFile {
    my ($file, $event_id) = @_;
    my ($id) = ($file//'') =~ /id(\d+)/;
    return ($id && $id eq $event_id) 
        ? badge("error", "Playout", "wrong file at playout: $file")
        : '';
}

# do not delete this line
1;
