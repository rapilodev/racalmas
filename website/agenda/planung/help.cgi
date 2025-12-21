# !/usr/bin/perl -w

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use Scalar::Util qw( blessed );
use Try::Tiny;

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();
use studios();
use markup();
use localization();
#use utf8;

#binmode STDOUT, ":utf8";

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu.po' } );
    my $out = template::process( $config, template::check( $config, 'default.html' ), $headerParams );
    uac::check($config, $params, $user_presets);

    my $toc = $headerParams->{loc}->{toc};

    $out .= q!
    <style>
    #content h1{
        font-size:1.6em;
    }

    #content h2{
        font-size:1.2em;
        padding-top:1em;
        padding-left:2em;
    }

    #content h3{
        font-size:1em;
        padding-left:4em;
    }

    #content h4{
        font-size:1em;
        padding-left:4em;
    }

    #content p{
        padding-left:6em;
        line-height:1.5em;
}

    #content ul{
        padding-left:7em;
    }

    #content li{
        line-height:1.5em;
    }

    body #content{
        max-width:60em;
    }

    #toc.sidebar {
        flex-wrap: nowrap;
        overflow: auto;
    }
    
    #toc.sidebar ul{
        padding-left:0;
    }

    #toc.sidebar li{
        line-height:1rem;
        padding:0;
        margin:0
    }
    
    </style>

    <script defer>
    set_breadcrumb('<TMPL_VAR .loc.title>');
    
    function addToToc(selector){
        $(selector).each(function(){
               if ($(this).hasClass('hide'))return
            var title=$(this).text();
            var tag=$(this).prop('tagName');
            var span=2;
            if (tag=='H2')span=4;
            if (tag=='H3')span=6;
            if (tag=='H4')span=8;
            var url=title;
            url=url.replace(/[^a-zA-Z]/g,'-')
            url=url.replace(/\-+/g, '-')
            $(this).append('<a name="'+url+'" />');
            $('#toc').append('<li style="margin-left:'+span+'em"><a href="#'+url+'">'+title+'</a></li>')
        });
    }

    document.addEventListener("DOMContentLoaded",function() {
        addToToc('#content h1,#content h2,#content h3,#content h4');
    })
    </script>
    <div id="toc" class="sidebar scrollable"><h1 class="hide"></div>
    <div class="panel scrollable">
    !;

    return $out . markup::creole_to_html( getHelp($config, $headerParams->{loc}->{region} ) );
}

sub getHelp {
    my ($config, $region) = @_;
    return template::process( $config, template::check( $config, 'help-de.html' ), {} ) if $region eq 'de';
    return template::process( $config, template::check( $config, 'help-en.html' ), {} );
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    $checked->{exclude} = 0;
    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'default_studio_id' ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    return $checked;
}

