package time;

use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Time::Local();
use DateTime();
use Date::Calc();
use Date::Manip();
use POSIX qw(strftime);
use Data::Dumper;

use Try::Tiny;
use Scalar::Util qw( blessed );

use config();

our @EXPORT_OK = qw(
  format_datetime format_time
  date_format time_format
  datetime_to_time time_to_datetime time_to_date
  datetime_to_date
  add_days_to_datetime add_hours_to_datetime add_minutes_to_datetime
  add_days_to_date
  datetime_to_array date_to_array array_to_date array_to_datetime array_to_time array_to_time_hm
  date_cond time_cond check_date check_time check_datetime check_year_month
  datetime_to_rfc822 get_datetime datetime_to_utc datetime_to_utc_datetime
  get_duration get_duration_seconds
  getDurations getWeekdayIndex getWeekdayNames getWeekdayNamesShort getMonthNames getMonthNamesShort
);

my $NAMES = {
    'de' => {
        months =>
          [ 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember' ],
        months_abbr => [ 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez' ],
        weekdays      => [ 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag' ],
        weekdays_abbr => [ 'Mo',     'Di',       'Mi',       'Do',         'Fr',      'Sa',      'So' ],
    },
    'en' => {
        months =>
          [ 'January', 'February', 'March', 'April', 'May', 'June', 'Jule', 'August', 'September', 'October', 'November', 'December' ],
        months_abbr   => [ 'Jan',    'Feb',     'Mar',       'Apr',      'May',    'Jun',      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' ],
        weekdays      => [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday' ],
        weekdays_abbr => [ 'Mo',     'Tu',      'We',        'Th',       'Fr',     'Sa',       'Su' ],
    },
};


# map starting with monday=0
my $WEEKDAY_INDEX = {
    '0'  => 0,
    '1'  => 1,
    '2'  => 2,
    '3'  => 3,
    '4'  => 4,
    '5'  => 5,
    '6'  => 6,
    'Mo' => 0,
    'Tu' => 1,
    'Di' => 1,
    'We' => 2,
    'Mi' => 2,
    'Th' => 3,
    'Do' => 3,
    'Fr' => 4,
    'Sa' => 5,
    'Su' => 6,
    'So' => 6
};

my $DURATIONS = [
    0,   5,   10,  15,  20,  30,  40,  45,  50,  60,  70,  75,  80,  90,  100, 105, 110, 115,
    120, 135, 150, 165, 180, 195, 210, 225, 240, 300, 360, 420, 480, 540, 600, 660, 720, 1440
];

sub getDurations() {
    return $DURATIONS;
}

sub getWeekdayNames(;$) {
    my ($language) = @_;
    $language ||= 'en';
    return $NAMES->{$language}->{weekdays};
}

sub getWeekdayNamesShort(;$) {
    my ($language) = @_;
    $language ||= 'en';
    return $NAMES->{$language}->{weekdays_abbr};
}

sub getMonthNames(;$) {
    my ($language) = @_;
    $language ||= 'en';
    return $NAMES->{$language}->{months};
}

sub getMonthNamesShort(;$) {
    my ($language) = @_;
    $language ||= 'en';
    return $NAMES->{$language}->{months_abbr};
}


sub getWeekdayIndex(;$) {
    my ($weekday) = @_;
    $weekday ||= '';
    return $WEEKDAY_INDEX->{$weekday};
}

# map starting with monday=1
sub getWeekdays {
    return {
        1    => 1,
        2    => 2,
        3    => 3,
        4    => 4,
        5    => 5,
        6    => 6,
        7    => 7,
        'Mo' => 1,
        'Tu' => 2,
        'Di' => 2,
        'We' => 3,
        'Mi' => 3,
        'Th' => 4,
        'Do' => 4,
        'Fr' => 5,
        'Sa' => 6,
        'Su' => 7,
        'So' => 7
    };
}

#deprecated, for wordpress sync
sub format_datetime(;$) {
    my ($datetime) = @_;
    return $datetime if ( $datetime eq '' );
    return add_hours_to_datetime( $datetime, 0 );
}

#deprecated
sub format_time($) {
    my $t = $_[0];

    my $year  = $t->[5] + 1900;
    my $month = $t->[4] + 1;
    $month = '0' . $month if ( length($month) == 1 );

    my $day = $t->[3];
    $day = '0' . $day if ( length($day) == 1 );

    my $hour = $t->[2];
    $hour = '0' . $hour if ( length($hour) == 1 );

    my $minute = $t->[1];
    $minute = '0' . $minute if ( length($minute) == 1 );

    return [ $day, $month, $year, $hour, $minute ];
}

# convert datetime to unix time
sub datetime_to_time ($){
    my $datetime = $_[0];

    if ( $datetime =~ /(\d\d\d\d)\-(\d+)\-(\d+)[T\s](\d+)\:(\d+)(\:(\d+))?/ ) {
        my $year   = $1;
        my $month  = $2 - 1;
        my $day    = $3;
        my $hour   = $4;
        my $minute = $5;
        my $second = $8 || 0;
        return (Time::Local::timelocal( $second, $minute, $hour, $day, $month, $year )
            or TimeCalcError->throw(error=> "datetime_to_time: no valid date time found! ($datetime)\n"));

    } else {
        TimeCalcError->throw(error=> "datetime_to_time: no valid date time found! ($datetime)\n");
    }
}

#get rfc822 datetime string from datetime string
sub datetime_to_rfc822($) {
    my $datetime = $_[0];
    my $time     = datetime_to_time($datetime);
    return POSIX::strftime( "%a, %d %b %Y %H:%M:%S %z", localtime($time) );
}

#get seconds from epoch
sub datetime_to_utc($$) {
    my ($datetime, $time_zone) = @_;
    $datetime = get_datetime( $datetime, $time_zone );
    return $datetime->epoch();
}

# get full utc datetime including timezone offset
sub datetime_to_utc_datetime($$) {
    my ($datetime, $time_zone) = @_;
    $datetime = get_datetime( $datetime, $time_zone );
    return $datetime->format_cldr("yyyy-MM-ddTHH:mm:ssZZZZZ");
}

#add hours to datetime string
sub add_hours_to_datetime($;$) {
    my ($datetime, $hours) = @_;
    $hours = 0 unless defined $hours;
    return time_to_datetime( datetime_to_time($datetime) + ( 3600 * $hours ) );
}

#add minutes to datetime string
sub add_minutes_to_datetime($;$) {
    my ($datetime, $minutes) = @_;
    $minutes = 0 unless defined $minutes;
    return time_to_datetime( datetime_to_time($datetime) + ( 60 * $minutes ) );
}

#add days to datetime string
sub add_days_to_datetime($;$) {
    my ($datetime, $days) = @_;
    $days = 0 unless defined $days;
    my $time = datetime_to_array($datetime);

    ( $time->[0], $time->[1], $time->[2] ) = Date::Calc::Add_Delta_Days( $time->[0] + 0, $time->[1] + 0, $time->[2] + 0, $days );
    return array_to_datetime($time);
}

sub add_days_to_date($;$) {
    my ($datetime, $days) = @_;
    $days = 0 unless defined $days;
    my $date = date_to_array($datetime);
    ( $date->[0], $date->[1], $date->[2] ) = Date::Calc::Add_Delta_Days( $date->[0] + 0, $date->[1] + 0, $date->[2] + 0, $days );
    return array_to_date($date);
}

# convert unix time to datetime format
sub time_to_datetime(;$) {
    my ($time) = @_;
    $time = time() unless ( defined $time ) && ( $time ne '' );
    my @t = localtime($time);
    return sprintf( '%04d-%02d-%02d %02d:%02d:%02d', $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0] );
}

# convert unix time to date format
sub time_to_date(;$) {
    my ($time) = @_;
    $time = time() unless ( defined $time ) && ( $time ne '' );
    my @t = localtime($time);
    return sprintf( '%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3] );
}

# convert datetime to a array of date/time values
sub datetime_to_array(;$) {
    my ($datetime) = @_;
    $datetime ||= '';
    if ( $datetime =~ /(\d\d\d\d)\-(\d+)\-(\d+)([T\s]+(\d+)\:(\d+)(\:(\d+))?)?/ ) {
        my $year   = $1;
        my $month  = $2;
        my $day    = $3;
        my $hour   = $5 || '00';
        my $minute = $6 || '00';
        my $second = $8 || '00';
        return [ $year, $month, $day, $hour, $minute, $second ];
    }
    return undef;
}

# convert datetime to date
sub datetime_to_date(;$) {
    my $datetime = $_[0] || '';
    if ( $datetime =~ /(\d\d\d\d)\-(\d+)\-(\d+)/ ) {
        my $year  = $1;
        my $month = $2;
        my $day   = $3;
        return sprintf( "%04d-%02d-%02d", $year, $month, $day );
    }
    return undef;
}

#convert datetime array or single value to datetime string
sub array_to_datetime(;$) {
    my ($date, $month, $day, $hour, $minute, $second) = @_;

    if ( ref($date) eq 'ARRAY' ) {
        return sprintf( "%04d-%02d-%02d %02d:%02d:%02d", $date->[0], $date->[1], $date->[2], $date->[3], $date->[4], $date->[5] );
    }

    $hour ||= '0';
    $minute ||= '0';
    $second ||= '0';
    return sprintf( "%04d-%02d-%02d %02d:%02d:%02d", $date, $month, $day, $hour, $minute, $second );
}

#convert date array or single values to date string
sub array_to_date($;$$) {
    my ($date, $month, $day) = @_;
    if ( ref($date) eq 'ARRAY' ) {
        return sprintf( "%04d-%02d-%02d", $date->[0], $date->[1], $date->[2] );
    }
    return sprintf( "%04d-%02d-%02d", $date, $month, $day );
}

sub array_to_time(;$) {
    my ($date, $minute, $second) = @_;
    if ( ref($date) eq 'ARRAY' ) {
        return sprintf( "%02d:%02d:%02d", $date->[3], $date->[4], $date->[5] );
    }
    $minute ||= '0';
    $second ||= '0';
    return sprintf( "%02d:%02d:%02d", $date, $minute, $second );
}

sub array_to_time_hm(;$) {
    my ($date, $minute) = @_;
    if ( ref($date) eq 'ARRAY' ) {
        return sprintf( "%02d:%02d", $date->[3], $date->[4] );
    }
    $minute ||= '0';
    return sprintf( "%02d:%02d", $date, $minute );
}

# get number of days between two days
sub days_between($$) {
    my ($today, $date) = @_;
    my $delta_days = eval { Date::Calc::Delta_Days( $today->[0], $today->[1], $today->[2], $date->[0], $date->[1], $date->[2] ) };
    return $delta_days;
}

sub dayOfYear($) {
    my ($datetime) = @_;
    if ( $datetime =~ /(\d\d\d\d)\-(\d+)\-(\d+)/ ) {
        my $year  = $1;
        my $month = $2;
        my $day   = $3;
        return Date::Calc::Day_of_Year( $year, $month, $day );
    }
    return undef;
}

# get duration in minutes
sub get_duration($$$) {
    my ($start, $end, $timezone) = @_;
    $start = time::get_datetime( $start, $timezone );
    $end   = time::get_datetime( $end,   $timezone );
    my $duration = $end->epoch() - $start->epoch();
    return $duration / 60;
}

# get duration in seconds
sub get_duration_seconds($$;$) {
    my ($start, $end, $timezone) = @_;
    $timezone ||= 'UTC';

    unless ( defined $start ) {
        TimeCalcError->throw(error=>"time::get_duration_seconds(): start is missing\n");
    }
    unless ( defined $end ) {
        TimeCalcError->throw(error=>"time::get_duration_seconds(): end is missing\n");
    }

    $start = time::get_datetime( $start, $timezone );
    $end   = time::get_datetime( $end,   $timezone );
    unless ( defined $start ) {
        TimeCalcError->throw(error=>"time::get_duration_seconds(): invalid start\n");
    }
    unless ( defined $end ) {
        TimeCalcError->throw(error=>"time::get_duration_seconds(): invalid end\n");
    }
    my $duration = $end->epoch() - $start->epoch();
    return $duration;
}

# convert date string to a array of date values
sub date_to_array($) {
    my $datetime = $_[0];
    if ( $datetime =~ /(\d\d\d\d)\-(\d+)\-(\d+)/ ) {
        my $year  = $1;
        my $month = $2;
        my $day   = $3;
        return [ $year, $month, $day ];
    }
    return undef;
}

# parse date string and return date string
# pass 'today', return '' on parse error
sub date_cond($) {
    my ($date) = @_;

    return '' if ( $date eq '' );
    if ( $date =~ /(\d\d\d\d)\-(\d\d?)\-(\d\d?)/ ) {
        my $year  = $1;
        my $month = $2;
        my $day   = $3;
        return sprintf( "%04d-%02d-%02d", $year, $month, $day );
    }
    return 'today' if ( $date eq 'today' );
    return '';
}

#parse time and return time string hh:mm:ss
#return hh:00 if time is 'now'
sub time_cond($) {
    my ($time) = @_;

    return '' if ( $time eq '' );
    if ( $time =~ /(\d\d?)\:(\d\d?)(\:(\d\d))?/ ) {
        my $hour   = $1;
        my $minute = $2;
        my $second = $4 || '00';
        return sprintf( "%02d:%02d:%02d", $hour, $minute, $second );
    }
    if ( $time eq 'now' ) {
        my $date = datetime_to_array( time_to_datetime( time() ) );
        my $hour = $date->[3] - 2;
        $hour = 0 if ( $hour < 0 );
        $time = sprintf( "%02d:00", $hour );
        return $time;
    }
    return '';
}

#parse date and time string and return yyyy-mm-ddThh:mm:ss
sub datetime_cond($) {
    my ($datetime) = @_;

    return '' if ( $datetime eq '' );
    ( my $date, my $time ) = split /[ T]/, $datetime;
    $date = time::date_cond($date);
    return '' if ( $date eq '' );
    $time = time::time_cond($time);
    return '' if ( $time eq '' );

    return $date . 'T' . $time;
}

sub check_date($) {
    my ($date) = @_;

    return "" if ( !defined $date ) || ( $date eq '' );
    if ( $date =~ /(\d\d\d\d)\-(\d\d?)\-(\d\d?)/ ) {
        return $1 . '-' . $2 . '-' . $3;
    } elsif ( $date =~ /(\d\d?)\.(\d\d?)\.(\d\d\d\d)/ ) {
        return $3 . '-' . $2 . '-' . $1;
    }
    return $date if ( $date eq 'today' || $date eq 'tomorrow' || $date eq 'yesterday' );
    return -1;

    #error("no valid date format given!");
}

sub check_time($) {
    my ($time) = @_;
    return "" if ( !defined $time ) || ( $time eq '' );
    return $time if ( $time eq 'now' ) || ( $time eq 'future' );
    if ( $time =~ /(\d\d?)\:(\d\d?)/ ) {
        return $1 . ':' . $2;
    }
    TimeCalcError->throw(error=>"invalid time\n");
}

sub check_datetime($) {
    my ($date) = @_;

    return "" if ( !defined $date ) || ( $date eq '' );
    if ( $date =~ /(\d\d\d\d)\-(\d\d?)\-(\d\d?)[T ](\d\d?)\:(\d\d?)/ ) {
        return sprintf( "%04d-%02d-%02dT%02d:%02d", $1, $2, $3, $4, $5 );
    }
    TimeCalcError->throw(error=>"invalid datetime\n");
}

sub check_year_month($) {
    my ($date) = @_;
    return -1 unless defined $date;
    return $date if ( $date eq '' );
    if ( $date =~ /(\d\d\d\d)\-(\d\d?)/ ) {
        return $1 . '-' . $2 . '-' . $3;
    }
    TimeCalcError->throw(error=>"invalid year or month\n");
}

#TODO: remove config dependency
sub date_time_format($$;$) {
    my ($config, $datetime, $language) = @_;
    $language ||= $config->{date}->{language} || 'en';
    if ( defined $datetime && $datetime =~ /(\d\d\d\d)\-(\d\d?)\-(\d\d?)[\sT](\d\d?\:\d\d?)/ ) {
        my $time  = $4;
        my $day   = $3;
        my $month = $2;
        my $year  = $1;

        $month = time::getMonthNamesShort($language)->[ $month - 1 ] || '';
        return "$day. $month $year $time";
    }
    return $datetime;
}

#format datetime to date string
#TODO: remove config dependency
sub date_format($$;$) {
    my ($config, $datetime, $language) = @_;
    $language ||= $config->{date}->{language} || 'en';

    if ( defined $datetime && $datetime =~ /(\d\d\d\d)\-(\d\d?)\-(\d\d?)/ ) {
        my $day   = $3;
        my $month = $2;
        my $year  = $1;
        $month = time::getMonthNamesShort($language)->[ $month - 1 ] || '';
        return "$day. $month $year";
    }
    return $datetime;
}

#format datetime to time string
sub time_format($) {
    my ($datetime) = @_;
    if ( defined $datetime && $datetime =~ /(\d\d?\:\d\d?)/ ) {
        return $1;
    }
    return $datetime;
}

#get offset from given time_zone
sub utc_offset($) {
    my ($time_zone) = @_;

    my $datetime = DateTime->now();
    $datetime->set_time_zone($time_zone);
    return $datetime->strftime("%z");
}

#get weekday from (yyyy,mm,dd)
sub weekday($$$) {
    my ( $year, $month, $day ) = @_;
    my $time = Time::Local::timelocal( 0, 0, 0, $day, $month - 1, $year );
    return ( localtime($time) )[6];
}

#get current date, related to starting day_starting_hour
#TODO: remove config dependency
sub get_event_date($) {
    my ($config) = @_;

    my $datetime = time::time_to_datetime( time() );
    my $hour     = ( time::datetime_to_array($datetime) )->[3];

    #today: between 0:00 and starting_hour show last day
    if ( $hour < $config->{date}->{day_starting_hour} ) {
        my $date = time::datetime_to_array( time::add_days_to_datetime( $datetime, -1 ) );
        return join( '-', ( $date->[0], $date->[1], $date->[2] ) );
    } else {

        #today: between starting_hour and end of day show current day
        my $date = time::datetime_to_array( time::time_to_datetime( time() ) );
        return join( '-', ( $date->[0], $date->[1], $date->[2] ) );
    }
}

#get datetime object from datetime string
sub get_datetime(;$$) {
    my ($datetime, $timezone) = @_;

    return unless defined $datetime;
    return if $datetime eq '';
    my @l = @{ time::datetime_to_array($datetime) };
    return undef if scalar(@l) == 0;

    # catch invalid datees
    $datetime = undef;
    eval {
        $datetime = DateTime->new(
            year      => $l[0],
            month     => $l[1],
            day       => $l[2],
            hour      => $l[3],
            minute    => $l[4],
            second    => $l[5],
            time_zone => $timezone
        );
    };
    return undef unless defined $datetime;
    $datetime->set_locale('de_DE');
    return $datetime;
}

#get list of nth weekday in month from start to end
sub get_nth_weekday_in_month(;$$$$) {
    my ($start, $end, $nth, $weekday) = @_;
    #datetime, datetime, every nth week of month, weekday [1..7,'Mo'-'Su','Mo'-'Fr']

    return [] unless defined $start;
    return [] unless defined $end;
    return [] unless defined $nth;
    return [] unless defined $weekday;

    my $weekdays = time::getWeekdays();
    return [] unless defined $weekdays->{$weekday};
    $weekday = $weekdays->{$weekday};

    my $dates = [];

    if ( $start =~ /(\d\d\d\d)-(\d\d)-(\d\d)[ T](\d\d)\:(\d\d)/ ) {
        my $hour = int($4);
        my $min  = int($5);
        my $sec  = 0;
        my @date = Date::Manip::ParseRecur( "0:1*$nth:$weekday:$hour:$min:$sec", "", $start, $end );
        for my $date (@date) {
            if ( $date =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)\:(\d\d)\:(\d\d)/ ) {
                push @$dates, "$1-$2-$3 $4:$5:$6";
            }
        }
    }
    return $dates;
}

#do not delete last line!
1;
