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

my $r = shift;
print uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    #process header
    my $headerParams = uac::set_template_permissions( $request->{permissions}, $params );
    my $loc = $headerParams->{loc} = localization::get( $config, { user => $session->{user}, file => 'menu.po' } );
    my $out = template::process( $config, template::check( $config, 'default.html' ), $headerParams );
    uac::check($config, $params, $user_presets);

    return $out . qq{
    <link rel="stylesheet" href="../css/help.css" type="text/css" />
    <script src="../js/help.js" type="text/javascript " defer></script>
    <div id="toc" class="sidebar scrollable"><h1 class="hide"></div>
    <div
        data-js-init="calcms.init_help"
        title="$loc->{title}"
        data-region="<TMPL_VAR loc.region escape=js>"
        class="panel scrollable"
    >} . markup::creole_to_html(getHelp($config, $loc->{region})). q{</div>};
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
