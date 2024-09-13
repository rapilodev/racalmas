package images;

use strict;
use warnings;
no warnings 'redefine';

use config();
use template();

our @EXPORT_OK = qw(get insert update insert_or_update delete delete_files);

#column 'created_at' will be set at insert
#column 'modified_at' will be set by default (do not update)
my $sql_columns = [
    'filename',  'name',       'description', 'created_by', 'modified_by', 'modified_at',
    'studio_id', 'project_id', 'public',      'licence'
];

sub get($$) {
    my ($config, $options) = @_;

    my @cond        = ();
    my $bind_values = [];
    if ((defined $options->{project_id}) && ($options->{project_id} ne '')) {
        push @cond,         'project_id = ?';
        push @$bind_values, $options->{project_id};
    }
    if ((defined $options->{studio_id}) && ($options->{studio_id} ne '')) {
        push @cond,         'studio_id = ?';
        push @$bind_values, $options->{studio_id};
    }
    if ((defined $options->{filename}) && ($options->{filename} ne '')) {
        push @cond,         'filename = ?';
        push @$bind_values, $options->{filename};
    }
    if ((defined $options->{from}) && ($options->{from} ne '')) {
        push @cond,         'date(created_at) >= ?';
        push @$bind_values, $options->{from};
    }
    if ((defined $options->{till}) && ($options->{till} ne '')) {
        push @cond,         'date(created_at) <= ?';
        push @$bind_values, $options->{till};
    }
    if ((defined $options->{created_by}) && ($options->{created_by} ne '')) {
        push @cond,         'created_by = ?';
        push @$bind_values, $options->{created_by};
    }
    if ((defined $options->{modified_by}) && ($options->{modified_by} ne '')) {
        push @cond,         'modified_by = ?';
        push @$bind_values, $options->{modified_by};
    }
    if ((defined $options->{licence}) && ($options->{licence} ne '')) {
        push @cond,         'licence = ?';
        push @$bind_values, $options->{licence};
    }
    if ((defined $options->{public}) && ($options->{public} ne '')) {
        push @cond,         'public = ?';
        push @$bind_values, $options->{public};
    }

    if ((defined $options->{search}) && ($options->{search} ne '')) {
        push @cond,
          '(filename    like ?' . ' or name        like ?' . ' or description like ?' . ' or created_by  like ?' . ')';
        my $search = '%' . $options->{search} . '%';
        push @$bind_values, $search;
        push @$bind_values, $search;
        push @$bind_values, $search;
        push @$bind_values, $search;

        #        push @$bind_values,$search;
    }

    my $where = '';
    if (@cond > 0) {
        $where = 'where ' . join(' and ', @cond);
    }

    my $limit = '';
    if ((defined $options->{limit}) && ($options->{limit} =~ /(\d+)/)) {
        $limit = ' limit ' . $1;
    }

    my $query = qq{
        select    *
        from     calcms_images
        $where
        order by created_at desc
        $limit
    };

    my $dbh = db::connect($config);
    my $results = db::get($dbh, $query, $bind_values);

    #print STDERR @$results."\n";
    return $results;
}

sub insert_or_update($$) {
    my ($dbh, $image) = @_;

    $image->{name} = 'new' if $image->{name} eq '';
    my $entry = get_by_filename($dbh, $image->{filename});
    if (defined $entry) {
        update($dbh, $image);
    } else {
        insert($dbh, $image);
    }
}

sub insert ($$) {
    my ($dbh, $image) = @_;

    my @sql_columns = @$sql_columns;

    #set created at timestamp
    push @sql_columns, 'created_at';
    $image->{created_at} = time::time_to_datetime();

    unless (defined $image->{created_by}) {
        print STDERR "missing created_by at image::insert\n";
        return undef;
    }
    unless (defined $image->{studio_id}) {
        print STDERR "missing studio_id at image::insert\n";
        return undef;
    }
    unless (defined $image->{project_id}) {
        print STDERR "missing project_id at image::insert\n";
        return undef;
    }

    for my $attr ('public') {
        $image->{$attr} = 0 unless (defined $image->{$attr}) && ($image->{$attr} eq '1');
    }

    my $query = q{
        insert into calcms_images(
            } . join(',', @sql_columns) . qq{
        )
        values(} . join(', ', (map { '?' } @sql_columns)) . q{)
    };
    my @bind_values = map { $image->{$_} } @sql_columns;
    my $result = db::put($dbh, $query, \@bind_values);

    images::setSeriesLabels($dbh, $image);
    images::setEventLabels($dbh, $image);

    return $result;
}

sub update($$) {
    my ($dbh, $image) = @_;

    for ('studio_id', 'project_id', 'filename') {
        ParamError->throw(error => "missing $_") unless defined $image->{$_}
    };

    $image->{modified_at} = time::time_to_datetime();

    for my $attr ('public') {
        $image->{$attr} = 0 unless (defined $image->{$attr}) && ($image->{$attr} eq '1');
    }

    my @set         = ();
    my $bind_values = [];
    for my $column (@$sql_columns) {
        if (defined $image->{$column}) {
            push @set,          $column . ' = ?';
            push @$bind_values, $image->{$column};
        }
    }

    #conditions
    my $conditions = ['filename=?'];
    push @$bind_values, $image->{filename};

    push @$conditions, 'project_id=?';
    push @$bind_values, $image->{project_id} || 0;

    push @$conditions, 'studio_id=?';
    push @$bind_values, $image->{studio_id} || 0;

    return if (@set == 0);

    my $set = join(",", @set);
    $conditions = join(' and ', @$conditions);
    my $query = qq{
        update calcms_images
        set       $set
        where  $conditions
    };
    my $result = db::put($dbh, $query, $bind_values);

    images::setSeriesLabels($dbh, $image);
    images::setEventLabels($dbh, $image);

    return $result;
}

sub delete($$) {
    my ($dbh, $image) = @_;

    for ('studio_id', 'project_id', 'filename') {
        ParamError->throw(error => "missing $_") unless defined $image->{$_}
    };

    my $project_id = $image->{project_id};
    my $studio_id  = $image->{studio_id};
    my $filename   = $image->{filename};

    my $conditions  = ['filename=?'];
    my $bind_values = [$filename];

    push @$conditions,  'project_id=?';
    push @$bind_values, $studio_id;

    push @$conditions,  'studio_id=?';
    push @$bind_values, $project_id;

    $conditions = join(' and ', @$conditions);
    my $query = qq{
        delete from calcms_images
        where  $conditions
    };
    return db::put($dbh, $query, $bind_values);
}

# deactivated
sub delete_files($$$$$) {
    my ($config, $local_media_dir, $filename, $action_result, $errors) = @_;

    return undef;

    print log::error($config, 'missing permissions on writing into local media dir') unless (-w $local_media_dir);

    if ($filename =~ /[^a-zA-Z0-9\.\_\-]/) {
        log::error($config, "invalid filename: '$filename'");
        return;
    }
    if ($filename =~ /\.\./ || $filename =~ /^\// || $filename =~ /\//) {
        log::error($config, "invalid filename: '$filename'");
        return;
    }

    log::error($config, 'missing permissions on writing into local_media_dir/images/')
      unless (-w $local_media_dir . 'images/');
    log::error($config, 'missing permissions on writing into local_media_dir/thumbs/')
      unless (-w $local_media_dir . 'thumbs/');
    log::error($config, 'missing permissions on writing into local_media_dir/icons/')
      unless (-w $local_media_dir . 'icons/');

    my $path = $local_media_dir . '/upload/' . $filename;

    #delete_file($path,"Upload $filename",$action_result,$errors);

    $path = $local_media_dir . '/images/' . $filename;
    delete_file($path, "Image $filename", $action_result, $errors);

    $path = $local_media_dir . '/thumbs/' . $filename;
    delete_file($path, "Thumb $filename", $action_result, $errors);

    $path = $local_media_dir . '/icons/' . $filename;
    delete_file($path, "Icon $filename", $action_result, $errors);
}

# deactivated
sub delete_file ($$$$) {
    my $path          = $_[0];
    my $type          = $_[1];
    my $action_result = $_[2];
    my $errors        = $_[3];

    return undef;

    unless (-e $path) {
        $errors .= qq{Error: File does not exist!<br>};
        return;
    }

    unless (-w $path) {
        $errors .= qq{Error: Cannot write $type<br>};
        return;
    }

    unlink($path);
    if ($? == 0) {
        $action_result .= qq{$type deleted<br>};
    } else {
        $errors .= qq{Error on deleting $type<br>};
    }
}

sub getPath {
    my ($config, $options) = @_;

    my $dir = $config->{locations}->{local_media_dir};
    return undef unless defined $dir;
    return undef unless -e $dir;

    my $filename = $options->{filename};
    return undef unless defined $filename;
    $filename =~ s/^.*\///g;

    my $type = 'thumbs';
    $type = $options->{type} if (defined $options->{type}) && ($options->{type} =~ /^(images|thumbs|icons)$/);

    my $path = $dir . '/' . $type . '/' . $filename;
    $path =~ s/\/+/\//g;
    return $path;
}

sub getInternalPath ($$) {
    my ($config, $options) = @_;

    my $dir = $config->{locations}->{local_media_dir};
    return undef unless defined $dir;
    return undef unless -e $dir;

    my $filename = $options->{filename};
    return undef unless defined $filename;
    $filename =~ s/^.*\///g;

    my $type = 'thumbs';
    $type = $options->{type} if (defined $options->{type}) && ($options->{type} =~ /^(images|thumbs|icons)$/);

    my $path = $dir . '/internal/' . $type . '/' . $filename;
    $path =~ s/\/+/\//g;
    return $path;
}

sub normalizeName (;$) {
    my ($name) = @_;

    return undef unless defined $name;
    $name =~ s/.*\///g;
    return $name;
}

sub readFile($) {
    my ($path) = @_;

    my $content = '';

    print STDERR "read '$path'\n";
    return { error => "source '$path' does not exist" } unless -e $path;
    return { error => "cannot read source '$path'" }    unless -r $path;

    open my $file, '< :raw', $path or return { error => 'could not open image file. ' . $! . " $path" };
    binmode $file;
    $content = join("", <$file>);
    close $file;
    return { content => $content };
}

sub writeFile ($$) {
    my ($path, $content) = @_;

    print STDERR "save '$path'\n";
    open my $fh, '> :raw', $path or return { error => 'could not save image. ' . $! . " $path" };
    binmode $fh;
    print $fh $content;
    close $fh;
    return {};
}

sub deleteFile($) {
    my ($path) = @_;

    return { error => "source '$path' does not exist" } unless -e $path;

    #unlink $path;
    return {};

}

sub copyFile ($$$) {
    my ($source, $target, $errors) = @_;

    my $read = images::readFile($source);
    return $read if defined $read->{error};

    my $write = images::writeFile($target, $read->{content});
    return $write;
}

sub publish($$) {
    my ($config, $filename) = @_;

    print STDERR "publish\n";
    return undef unless defined $config;
    return undef unless defined $filename;
    my $errors = [];
    for my $type ('images', 'thumbs', 'icons') {
        my $source = getInternalPath($config, { filename => $filename, type => $type });
        my $target = getPath($config, { filename => $filename, type => $type });
        my $result = copyFile($source, $target, $errors);
        if (defined $result->{error}) {
            push @$errors, $result->{error};
            print STDERR "error on copy '$source' to '$target': $result->{error}\n";
        }
    }
    return $errors;
}

sub depublish ($$) {
    my ($config, $filename) = @_;

    print STDERR "depublish\n";
    return undef unless defined $config;
    return undef unless defined $filename;
    my $errors = [];
    for my $type ('images', 'thumbs', 'icons') {
        my $path = getPath($config, { filename => $filename, type => $type });
        next unless defined $path;
        print STDERR "remove '$path'\n";
        unlink $path;

        #push @$errors, $result->{error} if defined $result->{error};
    }
    return $errors;
}

sub checkLicence ($$) {
    my ($config, $result) = @_;

    print STDERR "depublish\n";
    return undef unless defined $config;
    return undef unless defined $result;

    return if $result->{licence} =~ /\S/;
    if ((defined $result->{public}) && ($result->{public} eq '1')) {
        depublish($config, $result->{filename});
        $result->{public} = 0;
    }
}

sub setEventLabels($$) {
    my ($dbh, $image) = @_;

    unless (defined $image->{project_id}) {
        print STDERR "missing project_id at images::setEventLabels\n";
        return undef;
    }
    unless (defined $image->{studio_id}) {
        print STDERR "missing studio_id at images::setEventLabels\n";
        return undef;
    }
    unless (defined $image->{filename}) {
        print STDERR "missing filename at images::setEventLabels\n";
        return undef;
    }

    my $query = qq{
        update calcms_events
        set    image_label=?
        where  image=?
    };
    my $bind_values = [ $image->{licence}, $image->{filename} ];
    my $results = db::put($dbh, $query, $bind_values);
    return $results;
}

sub setSeriesLabels($$) {
    my ($dbh, $image) = @_;

    unless (defined $image->{project_id}) {
        print STDERR "missing project_id at images::setSeriesLabels\n";
        return undef;
    }
    unless (defined $image->{studio_id}) {
        print STDERR "missing studio_id at images::setSeriesLabels\n";
        return undef;
    }
    unless (defined $image->{filename}) {
        print STDERR "missing filename at images::setSeriesLabels\n";
        return undef;
    }

    my $query = qq{
        update calcms_events
        set    series_image_label=?
        where  series_image=?
    };
    my $bind_values = [ $image->{licence}, $image->{filename} ];
    my $results = db::put($dbh, $query, $bind_values);
    return $results;
}

#do not delete last line!
1;
