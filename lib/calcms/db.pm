use warnings "all";
use strict;

use DBD::mysql();

package db;
use Data::Dumper;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
  connect disconnect
  get insert put
  next_id get_max_id
  shift_date_by_hours shift_datetime_by_minutes
  get_columns get_columns_hash
  $write
  $read
);
our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

#debug settings
our $debug_read  = 0;
our $debug_write = 0;

#database control
our $read  = 1;
our $write = 1;

# connect to database
sub connect {
	my $options = shift;
	my $request = shift;

    return $request->{connection} if ( defined $request ) && ( defined $request->{connection} );

	my $access_options = $options->{access};

	my $hostname = $access_options->{hostname};
	my $port     = $access_options->{port};
	my $database = $access_options->{database};
	my $username = $access_options->{username};
	my $password = $access_options->{password};

	if ( ( defined $access_options->{write} ) && ( $access_options->{write} eq '1' ) ) {
		$username = $access_options->{username_write};
		$password = $access_options->{password_write};
	}

	my $dbh = undef;
	my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";

	#	if ($db::utf8dbi eq '1'){
	#		use UTF8DBI;
	#	       $dbh = UTF8DBI->connect( $dsn,$username,$password) || die "Database connection not made: $DBI::errstr"; # \nfor $dsn, $username
	#	}else{
	#		use DBI;
	$dbh = DBI->connect( $dsn, $username, $password, { mysql_enable_utf8 => 1 } )
	  || die "could not connect to database: $DBI::errstr";    # \nfor $dsn, $username

	#	}
	#print STDERR "db connect $username\n" if ($debug_read==1);
	#print STDERR "db connect $username\n";
	$dbh->{RaiseError} = 1;

	$dbh->{'mysql_enable_utf8'} = 1;
	put( $dbh, "set character set utf8" );
	put( $dbh, "set names utf8" );
	put( $dbh, "set time_zone='" . $options->{date}->{time_zone} . "'" );

	$request->{connection} = $dbh;
	return $dbh;
}

sub disconnect {
	my $request = shift;
	my $dbh     = $request->{connection};
	$dbh->disconnect;
	delete $request->{connection};
}

# get all database entries of an sql query (as list of hashs)
sub get {
	my $dbh         = shift;
	my $sql         = shift;
	my $bind_values = shift;

	if ( $debug_read == 1 ) {
		print STDERR $sql . "\n";
		print STDERR Dumper($bind_values) . "\n" if defined $bind_values;
	}

	my $sth = $dbh->prepare($sql);
	if ( ( defined $bind_values ) && ( ref($bind_values) eq 'ARRAY' ) ) {

		#		print STDERR Dumper($bind_values)."\n";
		my $result = $sth->execute(@$bind_values);
		unless ($result) {
			print STDERR $sql . "\n";
			die "db: $DBI::errstr $sql" if ( $read == 1 );
		}
	} else {
		$sth->execute() || die "db: $DBI::errstr $sql" if ( $read == 1 );
	}

	my @results = ();
	while ( my $row = $sth->fetchrow_hashref ) {
		my $result = {};
		foreach my $key ( keys %$row ) {
			$result->{$key} = $row->{$key};
		}
		push @results, $result;
	}

	if ( $debug_read == 1 ) {
		print STDERR Dumper( $results[0] ) . "\n" if ( @results == 1 );
		print STDERR @results . "\n" if ( @results != 1 );
	}

	$sth->finish;
	return \@results;
}

# get list of table columns
sub get_columns {
	my $dbh   = shift;
	my $table = shift;

	my $columns = db::get( $dbh, 'select column_name from information_schema.columns where table_name=?', [$table] );
	my @result = map { $_->{column_name} } (@$columns);
	return \@result;
}

# get hash with table columns as keys
sub get_columns_hash {
	my $dbh   = shift;
	my $table = shift;

	my $columns = db::get_columns( $dbh, $table );
	my $result = {};
	for my $column (@$columns) {
		$result->{$column} = 1;
	}
	return $result;
}

# insert an entry into database (select from where)
sub insert_old {
	my $dbh          = shift;
	my $tablename    = shift;
	my $entry        = shift;
	my $do_not_quote = shift;

	my $keys = join( ",", map { $_ } ( keys %$entry ) );
	my $values = undef;
	if ( defined $do_not_quote && $do_not_quote ne '' ) {
		$values = join( "\n,", map { $entry->{$_} } ( keys %$entry ) );
	} else {
		$values = join( "\n,", map { $dbh->quote( $entry->{$_} ) } ( keys %$entry ) );
	}
	my $sql = "insert into $tablename \n ($keys) \n values  ($values);\n";
	print STDERR $sql . "\n" if ( $debug_write == 1 );
	put( $dbh, $sql );

}

#returns last inserted id
sub insert {
	my $dbh       = shift;
	my $tablename = shift;
	my $entry     = shift;

	#	my $do_not_quote=shift;

	my $keys = join( ",", map { $_ } ( keys %$entry ) );
	my $values = join( ",", map { '?' } ( keys %$entry ) );
	my @bind_values = map { $entry->{$_} } ( keys %$entry );

	my $sql = "insert into $tablename \n ($keys) \n values  ($values);\n";

	if ( $debug_write == 1 ) {
		print STDERR $sql . "\n";
		print STDERR Dumper( \@bind_values ) . "\n" if (@bind_values);
	}

	put( $dbh, $sql, \@bind_values );
	my $result = get( $dbh, 'SELECT LAST_INSERT_ID() id;' );
	return $result->[0]->{id} if $result->[0]->{id} > 0;
	return undef;
}

# execute a modifying database command (update,insert,...)
sub put {
	my $dbh         = shift;
	my $sql         = shift;
	my $bind_values = shift;

	if ( $debug_write == 1 ) {
		print STDERR $sql . "\n";
		print STDERR Dumper($bind_values) . "\n" if defined $bind_values;
	}

	my $sth = $dbh->prepare($sql);
	if ( $write == 1 ) {
		if ( ( defined $bind_values ) && ( ref($bind_values) eq 'ARRAY' ) ) {
			$sth->execute(@$bind_values);
		} else {
			$sth->execute();
		}
	}
	$sth->finish;
	print STDERR "1\n" if ( $debug_write == 1 );

	my $result = get( $dbh, 'SELECT ROW_COUNT() changes;' );
	return $result->[0]->{changes} if $result->[0]->{changes} > 0;
	return undef;
}

sub quote {
	my $dbh = shift;
	my $sql = shift;

	$sql =~ s/\_/\\\_/g;
	return $dbh->quote($sql);
}

#subtract hours, deprecated(!)
sub shift_date_by_hours {
	my $dbh    = shift;
	my $date   = shift;
	my $offset = shift;

	my $query       = 'select date(? - INTERVAL ? HOUR) date';
	my $bind_values = [ $date, $offset ];
	my $results     = db::get( $dbh, $query, $bind_values );
	return $results->[0]->{date};
}

#add minutes, deprecated(!)
sub shift_datetime_by_minutes {
	my $dbh      = shift;
	my $datetime = shift;
	my $offset   = shift;

	my $query       = "select ? + INTERVAL ? MINUTE date";
	my $bind_values = [ $datetime, $offset ];
	my $results     = db::get( $dbh, $query, $bind_values );
	return $results->[0]->{date};
}

# get next free id of a database table
sub next_id {
	my $dbh   = shift;
	my $table = shift;

	my $query = qq{
		select max(id) id
		from $table
		where 1 
	};
	my $results = get( $dbh, $query );
	return $results->[0]->{id} + 1;
}

# get max id from table
sub get_max_id {
	my $dbh   = shift;
	my $table = shift;

	my $query = qq{
		select max(id) id
		from $table
		where 1 
	};
	my $results = get( $dbh, $query );
	return $results->[0]->{id};
}

#do not delete last line!
1;
