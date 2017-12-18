#! /usr/bin/perl -w 

use warnings "all";
use strict;
use Data::Dumper;

use config;
use params;
use log;
use template;
use auth;
use roles;
use uac;
use studios;
use localization;
binmode STDOUT, ":utf8";

my $r=shift;
(my $cgi, my $params, my $error)=params::get($r);

my $config		=config::get('../config/config.cgi');
my $debug		=$config->{system}->{debug};

my ($user,$expires)  = auth::get_user($cgi, $config);
return if ((!defined $user) || ($user eq ''));

our $actions={
	read 	=> 1,
	update 	=> 2,
	assign 	=> 3,
	remove 	=> 4,
	disable => 5,
	scan    => 6,
	create 	=> 7,
	delete  => 8,
};

my $user_presets=uac::get_user_presets($config, {
    user       => $user, 
    project_id => $params->{project_id}, 
    studio_id  => $params->{studio_id}
});
$params->{default_studio_id}= $user_presets->{studio_id};
$params->{studio_id}        = $params->{default_studio_id} if ((!(defined $params->{action}))||($params->{action}eq'')||($params->{action}eq'login'));
$params->{project_id}       = $user_presets->{project_id};

my $request={
	url	=> $ENV{QUERY_STRING}||'',
	params	=> {
		original => $params,
		checked  => check_params($params), 
	},
};
$request = uac::prepare_request($request, $user_presets);
log::init($request);

$params=$request->{params}->{checked};
#process header
my $headerParams=uac::set_template_permissions($request->{permissions}, $params);
$headerParams->{loc} = localization::get($config, {user=>$user, file=>'menu'});
template::process('print', template::check('roles.html'), $headerParams);
return unless uac::check($config, $params, $user_presets)==1;

if (defined $params->{action}){
	save_roles($config, $request) if ($params->{action}eq 'save');
}
#show current roles
$config->{access}->{write}=0;
show_roles($config,$request);
#print '<pre>'.Dumper($request);
return;

# update roles in database:
# role can be changed only
# role can be changed only if permission "update_role" is assigned to the user at the current studio
# role can be changed only if role level is smaller than user's maximum role level
# new roles will have role level 0 by default
# 
sub save_roles{
	my $config  = shift;
	my $request = shift;

	my $params      = $request->{params}->{checked};
	my $permissions = $request->{permissions};

	unless ($permissions->{update_role}==1){
		uac::permissions_denied('update_role');
		return;
	}

    my $studio_id  = $params->{studio_id};
    my $project_id = $params->{project_id};
    my $roles=uac::get_roles($config, {project_id=>$project_id, studio_id=>$studio_id});

    my $role_by_id={};
    my $role_by_name={};
    for my $role (@$roles){
        $role_by_id->{$role->{id}}=$role;
        $role_by_name->{$role->{role}}=$role;
    }

	my $columns=uac::get_role_columns($config);
	#print '<pre>'.Dumper($columns).'</pre>';
	
	#initialize all value ids (given by params matching to database columns)
	my $values={};
	for my $param (keys %$params){
		if ($param=~/(.+?)\_(\d+)?$/){
			my $column=$1;
			my $id=$2||'';
			next unless defined $columns->{$column};
			$values->{$id}={} if(update_allowed($permissions, $role_by_id, $id))
		}
	}
	#init checkbox values with 0
	for my $id (keys %$values){
		if(update_allowed($permissions, $role_by_id, $id)){
		    for my $column (keys %$columns){
			    next if ($column eq 'level'|| $column eq 'role' || $column eq 'id' || $column eq 'project_id' || $column eq 'studio_id');
			    $values->{$id}->{$column}=0;
		    }
        }
	}

	#set all checkbox values to 1
	for my $param (keys %$params){
		if ($param=~/(.+?)\_(\d+)?$/){
			my $column=$1;
			my $id=$2||'';
			next unless (defined $columns->{$column});
    		if(update_allowed($permissions, $role_by_id, $id)){
			    my $value=$params->{$param}||'';
			    if ($column eq 'level'){
			        if(check_level($permissions,$value)==1){
			            $values->{$id}->{$column}=$value;    
			        }else{
			            uac::permissions_denied("change the level of role!");
			            return;
			        }
			    }elsif($column eq 'role'){
				    $values->{$id}->{$column}=$value;
			    }elsif($column eq 'id' || $column eq 'project_id' || $column eq 'studio_id'){
			        #id and studio id will be set later
			    }else{
				    $values->{$id}->{$column}=1 if ($value=~/^\d+$/);
			    }
            }
		}
	}

    #print STDERR Dumper($values);
	#order roles to update by level
	for my $id(sort {$values->{$a}->{level} <=> $values->{$b}->{level}} keys %$values){
		my $role=$values->{$id};
		$role->{id}         = $id||'';
		$role->{studio_id}  = $studio_id;
		$role->{project_id} = $project_id;

	    #if you are not admin
	    next if check_level($permissions, $role->{level})==0;

		if($role->{project_id}eq''){
			uac::print_error('missing parameter project_id!');
			next;
		}
		if($role->{studio_id}eq''){
			uac::print_error('missing parameter studio_id!');
			next;
		}
		if(($role->{role}eq'')&&($id ne '')){
			uac::print_error('missing parameter role!');
			next;
		}

        my $role_from_db=undef;
        $role_from_db=$role_by_name->{$role->{role}} if defined $role_by_name->{$role->{role}};

		if ($id eq''){
    		#insert role
			next if ($role->{role} eq'');
			if(defined $role_from_db){
				uac::print_error("a role with name '$role->{role}' already exists!");
				next;
			}
			$role->{level}=0;
			print "insert $id $role->{role}<br>\n";
    		$config->{access}->{write}=1;
			uac::insert_role($config, $role);
    		$config->{access}->{write}=0;
		}else{
            #update role
			if((defined $role_from_db)&&($id ne $role_from_db->{id})){
				uac::print_error('you cannot rename role to existing role!'." '$role->{role}' ($id) != '$role_from_db->{role}' ($role_from_db->{id})" );
				next;
			}
			print "update $role->{role}<br>\n";
			#print '<div style="height:3em;overflow:auto;white-space:pre">'.Dumper($role).'</div>';
    		$config->{access}->{write}=1;
			uac::update_role($config, $role);
    		$config->{access}->{write}=0;
		}
	}
	print qq{<div class="ok head">changes saved</div>};

}

#check if update is allowed
sub update_allowed{
	my $permissions=shift;
	my $role_by_id=shift;
    my $id=shift;

    return 0 unless defined $permissions;
    return 0 unless defined $role_by_id;
    return 0 unless defined $id;
    return 1 if $id eq '';
    return 0 unless defined $role_by_id->{$id};
    my $role=$role_by_id->{$id};
    return check_level($permissions, $role->{level});
}

#check if update is allowed
sub check_level{
    my $permissions=shift;
    my $level=shift;
    return 0 unless defined $permissions;
    return 0 unless defined $level;
    return 1 if ($permissions->{is_admin});
    return 1 if ($permissions->{level}>$level);
    return 0;
}

# user has to be assigned to studio
# user needs to have permissions read_role
sub show_roles{
	my $config=shift;
	my $request=shift;

	my $params=$request->{params}->{checked};
	my $permissions=$request->{permissions};
	unless ($permissions->{read_role}==1){
		uac::permissions_denied('read_role');
		return;
	}

	my $studio_id  = $params->{studio_id};
	my $project_id = $params->{project_id};
	my $columns=uac::get_role_columns($config);

	#get user roles 
	my $conditions={};
	$conditions->{studio_id}  = $params->{studio_id}  if ($params->{studio_id}ne'');
    $conditions->{project_id} = $params->{project_id} if ($params->{project_id}ne'');
	my $roles=uac::get_roles($config, $conditions);
	@$roles=reverse sort {$a->{level} cmp $b->{level}} (@$roles);

	#add new role template
	unshift @$roles,{role=>'',level=>'0'};

	#print user role form
	my $out=qq{
	<div id="edit_roles">
	<form method="post">
		<input type="hidden" name="project_id" value="$project_id">
		<input type="hidden" name="studio_id"  value="$studio_id">
	};

	if(defined $permissions->{update_role}){
    	#add new user role button
		$out.=q{
			<button id="add_user_role_button" onclick="add_user_role();return false;">add user role</button>
		}
	}

	$out.='<hr>';
	$out.='<table class="table">';
    my $localization=localization::get($config, {user=>$params->{presets}->{user}, file=>'roles'});
    for my $key (keys %$localization){
        $localization->{$key}=~s/\(/<span class\=\"comment\">/;
        $localization->{$key}=~s/\)/<\/span>/;
    }

	#add role row 
	$out.=qq{<tr>};
	my $description=$localization->{label_role}||'role';
	$out.=qq{<td>$description</td>};

	for my $role (@$roles){
        $role->{active}='';
		$role->{active}=' disabled' if check_level($permissions, $role->{level})==0;
		$role->{active}=' disabled' unless defined $permissions->{update_role};
    }

	for my $role (@$roles){
	    #print Dumper($role);
		my $id=$role->{id}||'';
		my $value=$role->{role}||'';
		my $style='';
		$style=' id="new_user_role" class="editor" style="display:none"' if ($id eq'');
		my $active=$role->{active};
		$out.=qq{<td$style><input name="role_$id" value="$value" class="role$active" title="$value"></td>} ;
	}
	$out.=qq{</tr>};

	#add level row 
	$out.=qq{<tr>};
	$description=$localization->{label_level}||'level';	
	$out.=qq{<td>$description</td>};
	for my $role (@$roles){
		my $id=$role->{id}||'';
		my $value=$role->{level}||'';
		my $style='';
		$style=' id="new_user_level" class="editor" style="display:none"' if ($id eq'');
		my $active=$role->{active};
		$out.=qq{<td$style><input name="level_$id" value="$value" class="role$active" title="$value"></td>} ;
	}
	$out.=qq{</tr>};

	#add permission rows
	$columns=sort_columns($columns);
#    print '<pre>';
#    for my $key (@$columns){
#         printf ("        %-40s => '',\n", "'".$key."'");
#    }
#    print '</pre>';

	for my $key (@$columns){
		next if ($key eq 'level'|| $key eq 'role' || $key eq 'id' || $key eq 'project_id'|| $key eq 'studio_id' ||$key eq 'modified_at' || $key eq 'created_at');
		my $title=$key;
		$title=~s/\_/ /g;
		my $description=$localization->{'label_'.$key}||$key;
		$out.=qq{<tr>};
		$out.=qq{<td title="$title">$description</td>};
		for my $role (@$roles){
			my $value=$role->{$key}||'0';
			my $id=$role->{id}||'';
    		my $active=$role->{active};			
			my $style='';
			$style=' class="editor'.$active.'" style="display:none"' if ($id eq'');
			my $checked='';
			$checked='checked="checked"' if ($value eq'1');
		    $active=~s/\s//g;
			$out.=qq{<td$style>
				<input type="checkbox" name="}.$key.'_'.$id.qq{" value="$value" $checked class="$active">
				</td>
			};
		}
		$out.=qq{</tr>};
	}
	$out.='</table>';
	$out.='<input type="submit" name="action" value="save">' if (defined $permissions->{update_role});
	$out.='</form>';
	$out.='</div>';
	print $out."\n";
}


# sort columns by group and action
sub sort_columns{
	my $columns=shift;

	my $column_level={};
	my $groups=sort_groups($columns);
	for my $column (keys %$columns){
		my @words=split/_/,$column;
		my $action= shift @words;
		my $group = join (' ',@words);
		#print "action:'$action' group:'$group' <br>\n";

		my $index = $groups->{$group}||0;
		$index+=$actions->{$action} if (defined $actions->{$action});
		$column_level->{$column}=$index;
#		print $index."<br>";
	}

	my @columns=sort {$column_level->{$a} <=> $column_level->{$b}} (keys %$column_level);
	return \@columns;
}

# sort columns by group
sub sort_groups{
	my $columns=shift;
	my $groups={};
	#extract groups
	for my $column (keys %$columns){
		my @words=split/_/,$column;
		my $action= shift @words;
		my $group = join (' ',@words);
		$groups->{$group}=1;
	}
	#weigth groups
	my $i=0;
	for my $group (sort keys %$groups){
		$groups->{$group}=$i;
		$i+=100;
	}

    #print "<pre>";
	#for my $group (sort {$groups->{$a} <=> $groups->{$b}} (keys %$groups)){
	#    print "$groups->{$group}\t$group\n";
    #}
    #print "</pre>";

	return $groups;
}

sub check_params{
	my $params=shift;

	my $checked={};

	#template
	my $template='';
	$template=template::check($params->{template},'roles.html');
	$checked->{template}=$template;

	#actions
	if (defined $params->{action}){
		if ($params->{action} eq'save'){
			$checked->{action}=$params->{action};
		}
	}

	#numeric values
	for my $param ('project_id', 'studio_id', 'default_studio_id'){
		if ((defined $params->{$param})&&($params->{$param}=~/^\d+$/)){
			$checked->{$param}=$params->{$param};
		}
	}
    if (defined $checked->{studio_id}){
        $checked->{default_studio_id}=$checked->{studio_id};
    }else{
        $checked->{studio_id}=-1;
    }


	#permission fields
	for my $key (keys %$params){
		$checked->{$key}=$params->{$key} if ($key=~/^[a-z_]+_\d*$/);
	}

	return $checked;
}


