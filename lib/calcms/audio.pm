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

sub formatDuration($$$;$) {
    my ($audioDuration, $eventDuration, $value, $mouseOver) = @_;

    return '' unless $audioDuration;
    return '' unless $eventDuration;
    return '' unless $value;

    $audioDuration = durationToSeconds($audioDuration);
    $eventDuration = durationToSeconds($eventDuration);

    my $class = "ok";
    my $title = $mouseOver;

    my $delta = 100 * $audioDuration /($eventDuration+.00000000000001);

    if ($delta > 101) {
        $class = "warn";
        $title = sprintf(
            qq{file is too long! It should be %d minutes, but is %d},
         ($eventDuration+30) / 60,
         ($audioDuration+30) / 60
       );
    }

    if ($delta < 99.97) {
        $class = "error";
        $title = sprintf(
            qq{file is too short! should be %d minutes, but is %d},
         ($eventDuration+30) / 60,
         ($audioDuration+30) / 60
       );

    }

    return sprintf(qq{<div class="badge-%s" title="%s">%s</div>}, $class, $title, $value);
}

sub formatChannels($) {
    my ($channels) = @_;

    return '' unless $channels;
    my $class = "ok";
    $class = "error" if $channels != 2;
    return sprintf(qq{<div class="badge-%s">%d ch.</div>}, $class, $channels);
}

sub formatSamplingRate($) {
    my ($samplingRate) = @_;

    return '' unless $samplingRate;
    my $class = "ok";
    $class = "error" if $samplingRate != 44100;
    return sprintf(qq{<div class="badge-%s">%s Hz</div>}, $class, $samplingRate);
}

sub formatBitrate($) {
    my ($bitrate) = @_;

    return '' unless $bitrate;
    my $class = 'ok';
    $class = 'warn'  if $bitrate >= 200;
    $class = 'error' if $bitrate < 192;
    return sprintf(qq{<div class="badge-%s">%s kBit/s</div>}, $class, $bitrate);
}

sub formatBitrateMode($) {
    my ($mode) = @_;

    return '' unless $mode;
    my $class = 'ok';
    $class = 'error' if $mode ne 'CBR';
    return sprintf(qq{<div class="badge-%s">%s</div>}, $class, $mode);
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

    return qq{<div class="badge-$class">$prefix$value dB</div>};
}

sub formatFile{
    my ($file, $event_id) = @_;

    return '' unless $file;

    my ($id) = $file =~ /id(\d+)/;
    return '' unless $id;
    return '' if $id eq $event_id;
    return qq{<div class="badge-error" title="wrong file at playout: $file">Playout</div>};
}

# do not delete this line
1;
