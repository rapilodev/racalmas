#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;

use Scalar::Util qw( blessed );
use Try::Tiny;

use params();
use config();
use entry();
use log();
use template();
use auth();
use uac();

use series();
use localization();
use user_day_start();

binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};

    $params = $request->{params}->{checked};
    $params = uac::set_template_permissions( $request->{permissions}, $params );
    $params->{loc} = localization::get( $config, { user => $session->{user}, file => 'select-event' } );

    #process header
    print "Content-type:text/text; charset=UTF-8;\n\n";

    uac::check($config, $params, $user_presets);
    set_start_date( $config, $request );
}

sub set_start_date {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ( $permissions->{read_event} == 1 ) {
        PermissionError->throw(error=>'Missing permission to read_event');
        return;
    }

    my $preset = user_day_start::insert_or_update($config, {
        user        => $request->{user},
        project_id  => $params->{project_id},
        studio_id   => $params->{studio_id},
        day_start   => $params->{day_start},
    });
    print "done\n";
    return;
}

sub check_params {
    my ($config, $params) = @_;
    my $checked = {};

    entry::set_numbers($checked, $params, [
        'id', 'project_id', 'studio_id', 'day_start'
    ]);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }
    return $checked;
}

