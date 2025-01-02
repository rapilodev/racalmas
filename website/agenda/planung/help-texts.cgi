#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use URI::Escape();
use params();
use config();
use entry();
use template();
use auth();
use uac();
use help_texts();
use localization();
use JSON;
binmode STDOUT, ":utf8";

my $r = shift;
uac::init($r, \&check_params, \&main);

sub main {
    my ($config, $session, $params, $user_presets, $request) = @_;
    $params = $request->{params}->{checked};
    return get_help($config, $request) if $params->{action} eq 'get';

    my $headerParams
        = uac::set_template_permissions($request->{permissions}, $params);
    $headerParams->{loc}
        = localization::get($config, {user => $session->{user}, file => 'menu'});
    my $out = template::process($config, template::check($config, 'default.html'),
        $headerParams);
    return unless uac::check($config, $params, $user_presets) == 1;

    my $action = $params->{action};
    if (defined $action) {
        return $out .= save_help( $config, $request, $session->{user}) if $action eq 'save';
        return $out .= delete_help($config, $request, $session->{user}) if $action eq 'delete';
        return $out .= edit_help($config, $request)   if $action eq 'edit';
        return $out .= get_help($config, $request)    if $action eq 'get';
    }
    ActionError->throw(error => "invalid action");

}

sub save_help {
    my ($config, $request, $user) = @_;

    my $params = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{edit_help_texts} == 1) {
        uac::permissions_denied('edit_help_texts');
        return;
    }

    for my $attr ('project_id', 'studio_id', 'table', 'column', 'text') {
        unless (defined $params->{$attr}) {
            uac::print_error($attr . ' not given!');
            return;
        }
    }

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'table', 'column', 'text') {
        $entry->{$attr} = $params->{$attr} if defined $params->{$attr};
    }
    my $user_settings = user_settings::get($config, { user => $user });
    $entry->{lang} = $user_settings->{language} || 'en',
    my $results = help_texts::get($config, {
        project_id => $entry->{project_id},
        studio_id => $entry->{studio_id},
        lang => $entry->{lang},
        table => $entry->{table},
        column => $entry->{column},
    });
    local $config->{access}->{write} = 1;
    if (@$results) {
        help_texts::update($config, $entry);
    } else {
        my $schedule_id = help_texts::insert($config, $entry);
    }
    return uac::json [];
}

sub delete_help {
    my ($config, $request, $user) = @_;
    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{edit_help_texts} == 1) {
        uac::permissions_denied('edit_help_texts');
        return;
    }

    for my $attr ('project_id', 'studio_id', 'table', 'column', 'text') {
        unless (defined $params->{$attr}) {
            uac::print_error($attr . ' not given!');
            return;
        }
    }

    my $entry = {};
    for my $attr ('project_id', 'studio_id', 'table', 'column') {
        $entry->{$attr} = $params->{$attr} if defined $params->{$attr};
    }
    my $user_settings = user_settings::get($config, { user => $user });
    $entry->{lang} = $user_settings->{language} || 'en',

    local $config->{access}->{write} = 1;
    help_texts::delete($config, $entry);
    return uac::json [];
}

sub edit_help {
    my ($config, $request) = @_;

    my $params      = $request->{params}->{checked};
    my $permissions = $request->{permissions};
    unless ($permissions->{edit_help_texts} == 1) {
        uac::permissions_denied('edit_help_texts');
        return;
    }

    for my $param ('project_id', 'studio_id') {
        unless (defined $params->{$param}) {
            uac::print_error("missing $param");
            return;
}
    }

    my $table = "calcms_events";
    my $help_texts = help_texts::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            table => $table
        }
    );
    my %texts_by_column = map { $_->{column} => $_->{text} } @$help_texts;
    my $texts_by_column = \%texts_by_column;

    $params->{tables} = [{
        name => $table,
        columns => [
            {table => $table, column => 'title',         value => ($texts_by_column->{title} // '')       },
            {table => $table, column => 'user_title',    value => ($texts_by_column->{user_title} // '')  },
            {table => $table, column => 'episode',       value => ($texts_by_column->{episode} // '')  },
            {table => $table, column => 'start_date',    value => ($texts_by_column->{start_date} // '')  },
            {table => $table, column => 'end_date',      value => ($texts_by_column->{end_date} // '')  },
            {table => $table, column => 'duration',      value => ($texts_by_column->{duration} // '')  },
            {table => $table, column => 'live',          value => ($texts_by_column->{live} // '')  },
            {table => $table, column => 'published',     value => ($texts_by_column->{published} // '')  },
            {table => $table, column => 'playout',       value => ($texts_by_column->{playout} // '')  },
            {table => $table, column => 'archive',       value => ($texts_by_column->{archive} // '')  },
            {table => $table, column => 'rerun',         value => ($texts_by_column->{rerun} // '')  },
            {table => $table, column => 'draw',          value => ($texts_by_column->{draw} // '')  },
            {table => $table, column => 'excerpt',       value => ($texts_by_column->{excerpt} // '')     },
            {table => $table, column => 'topic',         value => ($texts_by_column->{topic} // '')      },
            {table => $table, column => 'content',       value => ($texts_by_column->{content} // '') },
            {table => $table, column => 'image',         value => ($texts_by_column->{image} // '')      },
            {table => $table, column => 'podcast_url',   value => ($texts_by_column->{podcast_url} // '') },
            {table => $table, column => 'archive_url',   value => ($texts_by_column->{archive_url} // '') },
            {table => $table, column => 'wiki_language', value => ($texts_by_column->{wiki_language} // '') },
        ]
    }];

    $params->{loc} = localization::get($config,
        {user => $params->{presets}->{user}, file => 'edit-help-texts'});
    return template::process($config, $params->{template}, $params);
    }

sub get_help {
    my ($config, $request) = @_;
    my $params = $request->{params}->{checked};
    for my $param ('project_id', 'studio_id') {
        unless (defined $params->{$param}) {
            uac::print_error("missing $param");
            return;
        }
    }

    my $table = "calcms_events";
    my $help_texts = help_texts::get(
        $config,
        {
            project_id => $params->{project_id},
            studio_id  => $params->{studio_id},
            table => $table
        }
    );
    my %texts_by_column = map { $_->{column} => $_->{text}} @$help_texts;
    my $texts_by_column = \%texts_by_column;
    return uac::json($texts_by_column);
}

sub check_params {
    my ($config, $params) = @_;

    my $checked = {};

    $checked->{action} = entry::element_of($params->{action},
        ['get', 'edit', 'save', 'delete']
    );

    entry::set_numbers($checked, $params, ['project_id', 'studio_id']);
    entry::set_strings($checked, $params, ['table', 'column', 'text']);

    if (defined $checked->{studio_id}) {
        $checked->{default_studio_id} = $checked->{studio_id};
    } else {
        $checked->{studio_id} = -1;
    }

    $checked->{template} = template::check($config, $params->{template}, 'edit-help-texts');
    return $checked;
}
