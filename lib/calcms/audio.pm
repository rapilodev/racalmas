package audio;
use warnings;
use strict;
use time ();

sub badge {
    my ($class, $content, $title) = @_;
    return qq{<div class="badge-$class"} .
           ($title ? qq{ title="$title"} : '') .
           q{>}.($content//'').q{</div>};
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

# get duration in seconds
sub parse_duration($) {
    my ($s) = @_;
    return unless defined $s;
    return $s if $s =~ /^\d+(\.\d+)?$/;
    if ($s =~ /^\-?(\d{1,2}):(\d{2}):(\d{2})(?:[.,](\d+))?$/o) {
        my $ms = (defined $4 ? "0.$4" : 0);
        return ($1 * 3600) + ($2 * 60) + $3 + $ms;
    }
    die "Invalid duration format: $s";
}

sub formatDuration($$$;$) {
    my ($audioDuration, $eventDuration, $value, $mouseOver) = @_;
    return '' unless $audioDuration && $eventDuration && $value;
    $audioDuration = parse_duration($audioDuration);
    $eventDuration = parse_duration($eventDuration);
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
    return badge('error', 'Playout', 'Cannot find audio file') unless $id;
    return badge("error", "Playout", "Wrong Audio File: $file?") unless $id eq $event_id;
    return '' ;
}

# do not delete this line
1;
