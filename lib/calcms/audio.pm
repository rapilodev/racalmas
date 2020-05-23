package audio;
use warnings;
use strict;

sub durationToSeconds($) {
    my $duration = shift;

    if ( $duration =~ /(\d+):(\d\d):(\d\d).(\d\d)/ ) {
        return $1 * 3600 + $2 * 60 + $3 + $4 / 100;
    }
    return $duration;
}

sub formatDuration($$$;$) {
    my $audioDuration = shift;
    my $eventDuration = shift;
    my $value         = shift;
    my $mouseOver     = shift;

    return '' unless $audioDuration;
    return '' unless $eventDuration;
    return '' unless $value;

    $audioDuration = durationToSeconds($audioDuration);
    $eventDuration = durationToSeconds($eventDuration);

    my $class = "ok";
    my $title = $mouseOver;

    my $delta = 100 * $audioDuration / $eventDuration;

    if ( $delta > 101 ) {
        $class = "warn";
        $title = sprintf(
            qq{file is too long! It should be %d minutes, but is %d},
            ($eventDuration+0.5) / 60,
            ($audioDuration+0.5) / 60
        );
    }

    if ( $delta < 99.98 ) {
        $class = "error";
        $title = sprintf(
            qq{file is too short! should be %d minutes, but is %d},
            ($eventDuration+0.5) / 60,
            ($audioDuration+0.5) / 60
        );

    }

    return sprintf( qq{<div class="badge-%s" title="%s">%s</div>}, $class, $title, $value );
}

sub formatChannels($) {
    my $channels = shift;
    return '' unless $channels;
    my $class = "ok";
    $class = "error" if $channels != 2;
    return sprintf( qq{<div class="badge-%s">%d ch.</div>}, $class, $channels );
}

sub formatSamplingRate($) {
    my $samplingRate = shift;
    return '' unless $samplingRate;
    my $class = "ok";
    $class = "error" if $samplingRate != 44100;
    return sprintf( qq{<div class="badge-%s">%s Hz</div>}, $class, $samplingRate );
}

sub formatBitrate($) {
    my $bitrate = shift;
    return '' unless $bitrate;
    my $class = 'ok';
    $class = 'warn'  if $bitrate >= 200;
    $class = 'error' if $bitrate < 192;
    return sprintf( qq{<div class="badge-%s">%s kBit/s</div>}, $class, $bitrate );
}

sub formatBitrateMode($) {
    my $mode = shift;
    return '' unless $mode;
    my $class = 'ok';
    $class = 'error' if $mode ne 'CBR';
    return sprintf( qq{<div class="badge-%s">%s</div>}, $class, $mode );
}

sub formatLoudness {
    my $value = shift;
    my $prefix = shift || '';
    return '' unless $value;

    $value = sprintf( "%.1f", $value );

    my $class = 'ok';
    $class = 'warn'  if $value > -18.5;
    $class = 'error' if $value > -16.0;
    $class = 'warn'  if $value < -24.0;
    $class = 'error' if $value < -27.0;

    return qq{<div class="badge-$class">$prefix$value dB</div>};
}

sub formatFile{
    my $file     = shift;
    my $event_id = shift;

    return '' unless $file;

    my ($id) = $file =~ /id(\d+)/;
    return '' unless $id;
    return '' if $id eq $event_id;
    return qq{<div class="badge-error" title="wrong file at playout: $file">Playout</div>};
}

# do not delete this line
1;
