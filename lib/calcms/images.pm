use warnings "all";
use strict;
use config;
use template;

package images; 
use warnings "all";
use strict;
use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);
#our @EXPORT = qw(all);
our @EXPORT_OK = qw(get insert update insert_or_update delete delete_files);
our %EXPORT_TAGS = ( 'all'  => [ @EXPORT_OK ] );

#column 'created_at' will be set at insert
#column 'modified_at' will be set by default (do not update)
my $sql_columns =['filename', 'name', 'description', 'created_by', 'modified_by', 'modified_at', 'studio_id', 'project_id'];

sub get{
    my $config=shift;
    my $options=shift;

	my @cond=();
	my $bind_values=[];
	if ((defined $options->{project_id}) && ($options->{project_id}ne'')){
		push @cond, 'project_id = ?';
		push @$bind_values, $options->{project_id};
	}
	if ((defined $options->{studio_id}) && ($options->{studio_id}ne'')){
		push @cond, 'studio_id = ?';
		push @$bind_values, $options->{studio_id};
	}
	if ((defined $options->{filename}) && ($options->{filename}ne'')){
		push @cond, 'filename = ?';
		push @$bind_values,$options->{filename};
	}
	if ((defined $options->{from}) && ($options->{from}ne'')){
		push @cond, 'date(created_at) >= ?';
		push @$bind_values,$options->{from};
	}
	if ((defined $options->{till}) && ($options->{till}ne'')){
		push @cond, 'date(created_at) <= ?';
		push @$bind_values,$options->{till};
	}
	if ((defined $options->{created_by}) && ($options->{created_by}ne'')){
		push @cond, 'created_by = ?';
		push @$bind_values,$options->{created_by};
	}
	if ((defined $options->{modified_by}) && ($options->{modified_by}ne'')){
		push @cond, 'modified_by = ?';
		push @$bind_values,$options->{modified_by};
	}
	if ((defined $options->{search}) && ($options->{search}ne'')){
		push @cond, '(filename    like ?'
				.' or name        like ?'
				.' or description like ?'
				.' or created_by  like ?'
				.')';
		my $search='%'.$options->{search}.'%';
		push @$bind_values,$search;
		push @$bind_values,$search;
		push @$bind_values,$search;
		push @$bind_values,$search;
#		push @$bind_values,$search;
	}

	my $where='';
	if (@cond>0){
		$where = 'where '.join (' and ', @cond);
	}

    my $limit='';
	if ( (defined $options->{limit}) && ($options->{limit}=~/(\d+)/) ){
		$limit=' limit '.$1;
	}

	my $query=qq{
		select	*
		from 	calcms_images
		$where
		order by created_at desc
		$limit
	};
	#print STDERR Dumper($query).Dumper($bind_values);

	my $dbh=db::connect($config);
	my $results=db::get($dbh, $query, $bind_values);

    #print STDERR @$results."\n";
	return $results;
}

sub insert_or_update{
	my $dbh=shift;
	my $image=shift;

	$image->{name}='new' if ($image->{name}eq'');
	my $entry=get_by_filename($dbh, $image->{filename});
	if (defined $entry){
		update($dbh, $image);
	}else{
		insert($dbh, $image);
	}
}

sub insert{
	my $dbh=shift;
	my $image=shift;

    my @sql_columns=@$sql_columns;

    #set created at timestamp
    push @sql_columns,'created_at';
    $image->{created_at}=time::time_to_datetime();

    unless (defined $image->{created_by}){
        print STDERR "missing created_by at image::insert\n";
        return undef;
    }
    unless (defined $image->{studio_id}){
        print STDERR "missing studio_id at image::insert\n";
        return undef;
    }
    unless (defined $image->{project_id}){
        print STDERR "missing project_id at image::insert\n";
        return undef;
    }
    
	my $query=q{
		insert into calcms_images(
			}.join(',',@sql_columns).qq{
		)
		values( }.join(', ', (map {'?'} @sql_columns)).q{ )
	};
	my @bind_values=map { $image->{$_} } @sql_columns;

	#print STDERR Dumper($query).Dumper(\@bind_values);
    return db::put($dbh, $query, \@bind_values);
}


sub update{
	my $dbh=shift;
	my $image=shift;

    unless (defined $image->{studio_id}){
        print STDERR "missing studio_id at images::update\n";
        return undef;
    }
    unless (defined $image->{project_id}){
        print STDERR "missing project_id at image::update\n";
        return undef;
    }

    $image->{modified_at}=time::time_to_datetime();

	my @set=();
	my $bind_values=[];
	for my $column (@$sql_columns){
		if (defined $image->{$column}){
			push @set, $column.' = ?';
			push @$bind_values,$image->{$column};
		}
	}

    #conditions
	my $conditions=['filename=?'];
	push @$bind_values,$image->{filename};

    push @$conditions,  'project_id=?';
    push @$bind_values, $image->{project_id}||0;

    push @$conditions,  'studio_id=?';
    push @$bind_values, $image->{studio_id}||0;

	return if (@set==0);
	
	my $set=join (",",@set);
    $conditions=join(' and ', @$conditions);
	my $query=qq{
		update calcms_images 
		set	   $set
		where  $conditions
	};
	#print STDERR Dumper($query).Dumper($bind_values);
	return db::put($dbh,$query,$bind_values);
}

sub delete{
	my $dbh=shift;
	my $image=shift;

    unless (defined $image->{project_id}){
        print STDERR "missing project_id at images::delete\n";
        return undef;
    }
    unless (defined $image->{project_id}){
        print STDERR "missing project_id at images::delete\n";
        return undef;
    }
    unless (defined $image->{filename}){
        print STDERR "missing filename at images::delete\n";
        return undef;
    }
    
    my $project_id = $image->{project_id};
    my $studio_id = $image->{studio_id};
    my $filename  = $image->{filename};

    my $conditions  = ['filename=?'];
	my $bind_values = [$filename];
    
    push @$conditions, 'project_id=?';
    push @$bind_values, $studio_id;

    push @$conditions, 'studio_id=?';
    push @$bind_values, $project_id;

    $conditions=join(' and ', @$conditions);
	my $query=qq{
		delete from calcms_images 
		where  $conditions
	};
	#print STDERR Dumper($query).Dumper($bind_values);
	return db::put($dbh, $query, $bind_values);	
}

# deactivated
sub delete_files{
    my $config          = $_[0];
	my $local_media_dir	= $_[1];
	my $filename		= $_[2];
	my $action_result	= $_[3];
	my $errors	        = $_[4];

    return undef;
    
	print log::error($config, 'missing permissions on writing into local media dir')unless(-w $local_media_dir);

	if ($filename=~/[^a-zA-Z0-9\.\_\-]/){
		log::error($config, "invalid filename: '$filename'");
		return;
	}
	if ($filename=~/\.\./ || $filename=~/^\// || $filename=~/\//){
		log::error($config, "invalid filename: '$filename'");
		return;
	}

	log::error($config, 'missing permissions on writing into local_media_dir/images/')unless(-w $local_media_dir.'images/');
	log::error($config, 'missing permissions on writing into local_media_dir/thumbs/')unless(-w $local_media_dir.'thumbs/');
	log::error($config, 'missing permissions on writing into local_media_dir/icons/') unless(-w $local_media_dir.'icons/');

	my $path=$local_media_dir.'/upload/'.$filename;
	#delete_file($path,"Upload $filename",$action_result,$errors);

	$path=$local_media_dir.'/images/'.$filename;
	delete_file($path,"Image $filename",$action_result,$errors);

	$path=$local_media_dir.'/thumbs/'.$filename;
	delete_file($path,"Thumb $filename",$action_result,$errors);

	$path=$local_media_dir.'/icons/'.$filename;
	delete_file($path,"Icon $filename",$action_result,$errors);
}

# deactivated
sub delete_file{
	my $path		  = $_[0];
	my $type		  = $_[1];
	my $action_result = $_[2];
	my $errors		  = $_[3];

    return undef;

	unless (-e $path){
		$errors.= qq{Error: File does not exist!<br>};
		return;
	}

	unless (-w $path){
		$errors.= qq{Error: Cannot write $type<br>};
		return;
	}

	unlink($path);
	if ($?==0){
		$action_result.= qq{$type deleted<br>};
	}else{
		$errors.= qq{Error on deleting $type<br>};
	}
}


#do not delete last line!
1;
