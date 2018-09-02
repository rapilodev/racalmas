package roles;
use warnings;
use strict;

use Apache2::Reload();

use config();

use base 'Exporter';
my @EXPORT_OK = qw(get_user get_user_permissions get_template_parameters get_jobs);

my $ROLES = {
    'admin' => {
        access_events     => 1,
        access_images     => 1,
        access_comments   => 1,
        access_sync       => 1,
        access_system     => 1,
        read_event_all    => 1,
        create_event      => 1,
        delete_event      => 1,
        update_comment    => 1,
        create_image      => 1,
        read_image_own    => 1,
        read_image_all    => 1,
        update_image_own  => 1,
        update_image_all  => 1,
        delete_image_own  => 1,
        delete_image_all  => 1,
        sync_own          => 1,
        sync_all          => 1,
        sync_select_range => 1,
        upload_playlist   => 1,
    },
    'dev' => {
        access_events     => 1,
        access_images     => 1,
        access_comments   => 1,
        access_sync       => 1,
        access_system     => 0,
        read_event_all    => 1,
        create_event      => 1,
        delete_event      => 1,
        update_comment    => 1,
        create_image      => 1,
        read_image_own    => 1,
        read_image_all    => 1,
        update_image_own  => 1,
        update_image_all  => 1,
        delete_image_own  => 1,
        delete_image_all  => 1,
        sync_own          => 0,
        sync_all          => 1,
        sync_select_range => 1,
        upload_playlist   => 1,
    },
    'editor' => {
        access_events     => 1,
        access_images     => 1,
        access_comments   => 1,
        access_sync       => 1,
        access_system     => 0,
        read_event_all    => 0,
        create_event      => 1,
        delete_event      => 0,
        update_comment    => 0,
        create_image      => 1,
        read_image_own    => 1,
        read_image_all    => 1,
        update_image_own  => 1,
        update_image_all  => 0,
        delete_image_own  => 1,
        delete_image_all  => 0,
        sync_own          => 1,
        sync_all          => 0,
        sync_select_range => 0,
        upload_playlist   => 1,
    },
    'nobody' => {
        access_events     => 0,
        access_images     => 0,
        access_comments   => 0,
        access_sync       => 0,
        access_system     => 0,
        read_event_all    => 0,
        create_event      => 0,
        delete_event      => 0,
        update_comment    => 0,
        create_image      => 0,
        read_image_own    => 0,
        read_image_all    => 0,
        update_image_own  => 0,
        update_image_all  => 0,
        delete_image_own  => 0,
        delete_image_all  => 0,
        sync_own          => 0,
        sync_all          => 0,
        sync_select_range => 0,
        upload_playlist   => 0,
    }
};

sub get_user($) {
    my $config = shift;
    my $user   = $ENV{REMOTE_USER};
    my $users  = $config->{users};
    return $user if ( defined $users->{$user} );
    return 'nobody';
}

sub get_user_permissions($) {
    my $config = shift;
    my $user   = $ENV{REMOTE_USER} || '';
    my $roles  = $roles::ROLES;
    return $roles->{nobody} unless $user =~ /\S/;
    my $users = $config->{users};
    if ( defined $users->{$user} ) {
        my $role = $users->{$user};
        return $roles->{$role} if defined $roles->{$role};
    }
    return $roles->{nobody};
}

sub get_user_jobs {
    my $config = shift;
    my $user = $ENV{REMOTE_USER} || '';
    return [] unless ( $user =~ /\S/ );
    my $result = [];
    my $jobs   = $config->{jobs}->{job};

    for my $job (@$jobs) {
        for my $job_user ( split /\,/, $job->{users} ) {
            push @$result, $job if ( $user eq $job_user );
        }
    }
    return $result;
}

sub get_jobs($) {
    my $config = shift;
    return $config->{jobs}->{job};
}

sub get_template_parameters($$) {
    my $config           = shift;
    my $user_permissions = shift;
    $user_permissions = roles::get_user_permissions($config) unless defined $user_permissions;
    my @user_permissions = ();
    for my $usecase ( keys %$user_permissions ) {
        push @user_permissions, $usecase if $user_permissions->{$usecase} eq '1';
    }
    return \@user_permissions;
}

return 1;
