package template;

use strict;
use warnings;
no warnings 'redefine';
use feature 'state';

use Data::Dumper;
use HTML::Template::Compiled();
use HTML::Template::Compiled::Plugin::XMLEscape();
use HTML::Template::Compiled::Plugin::Hyphen();

use JSON();
use Cwd();
use Digest::MD5 qw(md5_hex);
use config();
use params();
use project();
use log();

our @EXPORT_OK = qw(check process exit_on_missing_permission clear_cache);

# TODO:config
sub process($$$$) {
    my ($config, $output, $filename, $params) = @_;

    #TODO: get config
    for my $key ( keys %{ $config->{locations} } ) {
        $params->{$key} = $config->{locations}->{$key} if ( $key =~ /\_url$/ && $key !~/local/);
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

    if ( ( $filename =~ /json\-p/ ) || (params::isJson) ) {
        my $header = join("\n", (
            "Content-type:application/json; charset=utf-8",
            "Access-Control-Allow-Origin: *",
        )) . "\n\n";
        my $json = JSON->new->pretty(1)->canonical()->encode($params);

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
    my $out = $html_template->output();
    my $version = "?v=".substr(md5_hex(join("",(stat "js",stat "css",stat "image"))),0,8);
    $out =~ s{(src="js/.*\.js)"}{$1$version"}g;
    $out =~ s{(href="css/.*\.css)"}{$1$version"}g;
    $out =~ s{(src="image/.*\.svg)"}{$1$version"}g;
    if ( ( defined $_[1] ) && ( $_[1] eq 'print' ) ) {
        print $out;
    } else {
        $_[1] = $out;
    }
}

sub initTemplate($) {
    my ($filename) = @_;

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
        plugin            => [qw(HTML::Template::Compiled::Plugin::Hyphen)]
    );
}

# set relative urls in nested params structure
sub setRelativeUrls;

sub setRelativeUrls {
    my ($params, $depth) = @_;
    $depth ||= 0;

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

sub check($;$$) {
    my ($config, $template, $default) = @_;

    $template ||= '';
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
    $template .= '.html' unless ( $template =~ /\./ );
    my $dir = "templates";
    my $cwd = Cwd::getcwd();
    my $theme = $config->{locations}->{theme} //= 'default';
    $dir .= "/$theme" if $cwd =~ m{/agenda$} && $theme;
    log::error( $config, "template not found: '$dir'" )
        unless -e "$cwd/$dir/$template";
    $template = "$cwd/$dir/$template";

    return $template;
}

#do not delete last line!
1;
