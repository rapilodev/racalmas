#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;

use HTTP::Request;
use LWP::UserAgent;
use config;
use markup;
use Getopt::Long;

check_running_processes();

my $wget='/usr/local/bin/wget';

my $insertWidgets  = undef;
my $configFile     = undef;
my $help           = undef;
my $output         = undef;

GetOptions (
    "config=s"          => \$configFile,
    "insert_widgets"    => \$insertWidgets,
    "output=s"          => \$output,
    "help"              => \$help
)or die("Error in command line arguments\n");

if(($help) || (!(defined $configFile))){
    print get_usage();
    exit 1;
}
binmode STDOUT, ":encoding(UTF-8)";

my $config = config::get($configFile);

#what to grab from extern CMS
my $source_url_http  = $config->{locations}->{source_url_http};
my $source_url_https = $config->{locations}->{source_url_https};

#external base url (relative links/images are located)
my $source_base_url  = $config->{locations}->{source_base_url};

my $source_base_url_http = $source_base_url;
$source_base_url_http=~s/^http\:\//https\:\//g;

my $source_base_url_https=$source_base_url;
$source_base_url_https=~s/^http\:\//https\:\//g;

# base url to get widgets from /website/agenda/
my $base_url        =$config->{controllers}->{domain};

# location of /website/agenda/
my $base_dir        =$config->{locations}->{base_dir};

unless (defined $source_url_http){
    print STDERR "source_url_http is not configured. Please check config.\n";
    exit 1;
}

#setup UA
my $ua = LWP::UserAgent->new;

our $results={};
my $urls={base => $source_url_http};

#read source url
$results->{base}= http_get($ua,$urls->{base});
my $html_page=$results->{base};

#read widgets
$html_page=load_widgets($ua,$html_page,{
        calcms_calendar         => $base_url."kalender/\$date/",
        calcms_menu             => $base_url."menu/\$date/",
        calcms_list             => $base_url."sendungen/\$date/",
        calcms_categories       => $base_url."kategorien/",
        calcms_series_names     => $base_url."sendereihen/",
        calcms_newest_comments  => $base_url."neueste_kommentare/",
}) if (defined $insertWidgets);

#replace links
$html_page=~s/(href\=\"\/)$source_base_url_http/$1/g;
$html_page=~s/(src\=\"\/)$source_base_url_http/$1/g;
$html_page=~s/(href\=\"\/)$source_base_url_https/$1/g;
$html_page=~s/(src\=\"\/)$source_base_url_https/$1/g;
$html_page=~s/(src\=\"\/)$source_base_url_https/$1/g;

#replace link to uncompressed or compressed drupal (first link in <head>)
my @parts=split(/<\/head>/,$html_page);
$parts[0]=~s|/misc/jquery.js|/agenda_files/js/jquery.js|;
$parts[0]=~s|/sites/default/files/js/[a-z0-9\_]+\.js|/agenda_files/js/jquery.js|;
$html_page=join('</head>',@parts);

#compress output
markup::compress($html_page);

#print result
if(defined $output){
    unless (-w $output){
        print STDERR "cannot write to '$output'\n";
        exit 1;
    }
    print STDERR "write to '$output'\n";
    open my $file,'>'.$output;
    print $file $html_page."\n";
    close $file;
}else{
    print STDERR "write to STDOUT\n";
    print $html_page;
}


sub load_widgets{
    my $ua  =shift;
    my $base=shift;
    my $urls=shift;

    #set current date (or end date if above)
    my @date=localtime(time());
    my $year=    $date[5]+1900;
    my $month=    $date[4]+1;
    my $day    =    $date[3];
    $month    ='0'.$month    if (length($month)<2);
    $day      ='0'.$day    if (length($day)<2);
    my $date=join('-',($year,$month,$day));

    my $project_name=$config->{project};
    my $project=$config->{projects}->{$project_name};

    $date=$project->{start_date}    if ($date lt $project->{start_date});
    $date=$project->{end_date}     if ($date gt $project->{end_date});

    #load widgets
    for my $block (keys %$urls){
        my $url=$urls->{$block};
        $url=~s/\$date/$date/gi;
        $results->{$block}= http_get($ua,$url);
    }

    #set javascript
    my $preload_js=qq{
    set('preloaded','$date');
    set('last_list_url','}.$base_url.qq{sendungen/$date/');
    </script>
    <script>
    };
    $base=~s/(\/\/calcms_preload)/$1\n$preload_js/;

    #replace widget containers
    for my $block (keys %$urls){
        if ($block ne 'base'){
            my $content=$results->{$block};
            $base=~s/(id\=\"$block\".*?\>)(.*?)(\<)/$1$content$3/;
        }
    }
    return $base;
}

sub http_get{
    my $ua=shift;
    my $url=shift;

    print STDERR "read url '$url'\n";
    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);
    return $response->{_content};
}

sub check_running_processes{
    my $cmd=qq{ps -afex 2>/dev/null | grep preload_agenda | grep -v grep | grep -v "$$" };
    my $ps=`$cmd`;
    my @lines=split(/\n/,$ps);
    if (@lines>1){
        print STDERR "ERROR: ".@lines." preload_agenda.pl instances are running!\n"
            ."$cmd\n"
            ."$ps\n"
            ."stop further processing of this preload_agenda.pl instance\n";
        exit 1;
    };
}

sub get_usage{
    return qq{
$0 --config FILE [--insert_widgets] --output FILE

read HTML document from base_url, insert widgets and save result to output file

  --config FILE     path of the config file
  --insert_widgets  insert widgets, optional
  --output FILE     path of output file
  --help            this page
};
}

