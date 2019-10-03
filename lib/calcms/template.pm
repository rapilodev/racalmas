package template;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use HTML::Template::Compiled();
use HTML::Template::Compiled::Plugin::XMLEscape();

#use HTML::Template::JIT();
use JSON();
use Cwd();

use config();
use params();
use project();
use log();
use roles();

use base 'Exporter';
our @EXPORT_OK = qw(check process exit_on_missing_permission clear_cache);

# TODO:config
sub process($$$$) {
    my $config = $_[0];

    #	my $output=$_[1];
    my $filename = $_[2];
    my $params   = $_[3];

    #TODO: get config
    for my $key ( keys %{ $config->{locations} } ) {
        $params->{$key} = $config->{locations}->{$key} if ( $key =~ /\_url$/ );
    }

    # add current project
    unless ( defined $params->{project_title} ) {
        my $projects = project::get_with_dates( $config, { name => $config->{project} } );
        if ( scalar @$projects == 1 ) {
            my $project = $projects->[0];
            foreach my $key ( keys %$project ) {
                $params->{ 'project_' . $key } = $project->{$key};
            }
        }
    }

    $params->{user} = $ENV{REMOTE_USER} unless defined $params->{user};

    my $user_permissions = roles::get_user_permissions($config);
    for my $permission ( keys %$user_permissions ) {
        $params->{$permission} = $user_permissions->{$permission}
          if ( $user_permissions->{$permission} eq '1' );
    }

    $params->{jobs} = roles::get_user_jobs($config);
    if ( ( $filename =~ /json\-p/ ) || (params::isJson) ) {
        my $header = "Content-type:application/json; charset=utf-8\n\n";
        my $json = JSON::to_json( $params, { pretty => 1 } );

        #		$json=$header.$params->{json_callback}.'['.$json.']';
        $json = $header . $params->{json_callback} . $json;
        if ( ( defined $_[1] ) && ( $_[1] eq 'print' ) ) {
            print $json. "\n";
        } else {
            $_[1] = $json . "\n";
        }
        return;
    }

    unless ( -r $filename ) {
        log::error( $config, qq{template "$filename" does not exist} ) unless -e $filename;
        log::error( $config, qq{missing permissions to read "$filename"} );
    }
    my $html_template = initTemplate($filename);

    setRelativeUrls( $params, 0 )
      unless ( defined $params->{extern} ) && ( $params->{extern} eq '1' );

    $html_template->param($params);
    my $output = $html_template->output();
    if ( $filename =~ /html/ ) {
        my ( $header, $content ) = split( /\n\n/, $output, 2 );
        if ($content) {

            #$content =~s/\s+/ /g;
            $output = $header . "\n\n" . $content;
        } else {

            #$output =~s/[ \t]+/ /g;
        }
    }

    if ( ( defined $_[1] ) && ( $_[1] eq 'print' ) ) {
        print $output;
    } else {
        $_[1] = $output;
    }
}

sub initTemplate($) {
    my $filename = shift;

    my $default_escape = 'none';
    $default_escape = 'js'       if ( $filename =~ /\.js$/ );
    $default_escape = 'js'       if ( $filename =~ /\.json$/ );
    $default_escape = 'html_all' if ( $filename =~ /\.html$/ );

    if ( $filename =~ /\.xml$/ ) {
        return HTML::Template::Compiled->new(
            filename          => $filename,
            die_on_bad_params => 1,
            case_sensitive    => 1,
            loop_context_vars => 0,
            global_vars       => 0,
            tagstyle          => '-asp -comment --comment --tt',
            default_escape    => 'XML',
            cache             => 1,
            utf8              => 1,
            plugin            => [qw(HTML::Template::Compiled::Plugin::XMLEscape)],
        );
    }

    return HTML::Template::Compiled->new(
        filename          => $filename,
        die_on_bad_params => 1,
        case_sensitive    => 1,
        loop_context_vars => 0,
        global_vars       => 0,
        tagstyle          => '-asp -comment --comment --tt',
        default_escape    => $default_escape,
        cache             => 1,
        utf8              => 1,

        #pre_chomp => 1,
        #post_chomp => 1,
    );
}

# set relative urls in nested params structure
sub setRelativeUrls;

sub setRelativeUrls {
    my $params = shift;
    my $depth = shift || 0;

    #print STDERR "setRelativeUrls depth:$depth ".ref($params)."\n";

    return unless defined $params;

    if ( $depth > 10 ) {
        print STDERR "prevent deep recursion in template::setRelativeUrls()\n";
        return;
    }

    # set recursive for hash
    if ( ref($params) eq 'HASH' ) {
        for my $key ( keys %$params ) {

            #next unless ($key eq 'icon') || ($key eq 'thumb');
            my $val = $params->{$key};
            next unless defined $val;
            if ( ref($val) eq '' ) {

                # make link relative
                $params->{$key} =~ s/^https?\:(\/\/[^\/]+)/$1/;
            } elsif ( ( ref($val) eq 'HASH' ) || ( ref($val) eq 'ARRAY' ) ) {
                setRelativeUrls( $params->{$key}, $depth + 1 );
            }
        }
        return $params;
    }

    # set recursive for arrays
    if ( ref($params) eq 'ARRAY' ) {
        for my $i ( 0 .. @$params ) {
            my $val = $params->[$i];
            next unless defined $val;
            if ( ( ref($val) eq 'HASH' ) || ( ref($val) eq 'ARRAY' ) ) {
                setRelativeUrls( $params->[$i], $depth + 1 );
            }
        }
        return $params;
    }

    return $params;
}

#requires read config
#TODO:add config
sub check($;$$) {
    my $config   = shift;
    my $template = shift || '';
    my $default  = shift;

    if ( $template =~ /json\-p/ ) {
        $template =~ s/[^a-zA-Z0-9\-\_\.]//g;
        $template =~ s/\.{2,99}/\./g;
        return $template;
    }

    if ( $template eq '' ) {
        $template = $default;
    } else {
        $template =~ s/^\.\///gi;

        #template does use ';' in filename
        log::error( $config, 'invalid template!' ) if ( $template =~ /;/ );

        #template does use '..' in filename
        log::error( $config, 'invalid template!' ) if ( $template =~ /\.\./ );
    }

    $template = ( split( /\//, $template ) )[-1];
    my $cwd = Cwd::getcwd();

    $template .= '.html' unless ( $template =~ /\./ );
    log::error( $config, "template not found: '$cwd/$template'" ) 
        unless -e $cwd . '/templates/' . $template;
    $template = $cwd . '/templates/' . $template;

    return $template;
}

#deprecated (for old admin only)
sub exit_on_missing_permission($$) {
    my $config     = shift;
    my $permission = shift;

    my $user_permissions = roles::get_user_permissions($config);
    if ( $user_permissions->{$permission} ne '1' ) {
        print STDERR "missing permission to $permission\n";
        template::process(
            $config, 'print',
            template::check( $config, 'default.html' ),
            { error => 'sorry, missing permission!' }
        );
        die();
    }
}

#do not delete last line!
1;

__END__
sub clear_cache {
    HTML::Template::Compiled->clear_cache();

    #   return;
    #   my $html_template = HTML::Template::Compiled->new();
    #   $html_template->clear_cache();
}
