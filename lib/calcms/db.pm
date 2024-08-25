package db;

use strict;
use warnings;
no warnings 'redefine';
use feature 'state';

use DBD::mysql();
use Digest::MD5 qw();

#use base 'Exporter';
our @EXPORT_OK = qw(
  connect
  get insert put
  next_id get_max_id
  shift_date_by_hours shift_datetime_by_minutes
  get_columns get_columns_hash
  $write
  $read
);

#database control
our $read  = 1;
our $write = 1;

# connect to database
my $database;
state $connection = {};

sub connect($;$) {
    my ($options, $request) = @_;

    my $access_options = $options->{access};
    my $key = Digest::MD5::md5_hex(sort values %$access_options);
    my $cache = $connection->{$key};
    return $cache->{dbh} if defined $cache && ($cache->{expires}//0>time);# && $cache->{dbh}->ping;
    $database = $access_options->{database};
    my $dsn = "DBI:mysql:database=$access_options->{database};host=$access_options->{hostname};port=$access_options->{port};"
            . "mysql_enable_utf8=1;mysql_init_command=SET time_zone='$options->{date}->{time_zone}'";
    my $username = $access_options->{write} ? $access_options->{username_write} : $access_options->{username};
    my $password = $access_options->{write} ? $access_options->{password_write} : $access_options->{password};
    my $dbh = DBI->connect($dsn, $username, $password, {
        RaiseError => 1,
        mysql_enable_utf8 => 1,
        mysql_auto_reconnect => 1,
        mysql_use_result=> 1
    }) or die "could not connect to database: $DBI::errstr";
    $dbh->{HandleError} = sub {
        print STDERR join(",",(caller($_))[0..3])."\n" for (1..2);
        return 0;
    };
    $connection->{$key} = {dbh => $dbh, expires => time + 60};
    return $dbh;
}

# get all database entries of an sql query (as list of hashs)
state $sths = {};
sub get($$;$) {
    my ( $dbh, $sql, $bind_values ) = @_;

    my $sth = $sths->{$sql} // ($sths->{$sql} = $dbh->prepare($sql));
    if (ref($bind_values) eq 'ARRAY') {
        $sth->execute(@$bind_values) or die "db: $DBI::errstr $sql";
    } else {
        $sth->execute() or die "db: $DBI::errstr $sql";
    }
    my $results = $sth->fetchall_arrayref({});
    $sth->finish;
    return $results;
}

# get list of table columns
sub get_columns($$) {
    my ($dbh, $table) = @_;
    my $columns = db::get( $dbh,
        qq{
            select column_name from information_schema.columns
            where table_schema=?
            and table_name = ?
            order by ordinal_position
        },
        [$database, $table]
    );
    return [ map { values %$_ } @$columns ];
}

# get hash with table columns as keys
sub get_columns_hash($$) {
    my ($dbh, $table) = @_;
    my $columns = get_columns($dbh, $table);
    return { map { $_ => 1 } @$columns };
}

#returns last inserted id
sub insert ($$$){
    my ($dbh, $table, $entry) =@_;

    my @keys = sort keys %$entry;
    my $keys = join( ",", map {"`$table`.`$_`"} @keys );
    my $values = join( ",", map { '?' } @keys );
    my @bind_values = map { $entry->{$_} } @keys;

    my $sql = "insert into `$table` \n ($keys) \n values ($values);\n";
    put( $dbh, $sql, \@bind_values );
    my $result = get( $dbh, 'SELECT LAST_INSERT_ID() id;' );
    return $result->[0]->{id} if $result->[0]->{id} > 0;
    return undef;
}

# execute a modifying database command (update,insert,...)
sub put($$$) {
    my ($dbh, $sql, $bind_values) =@_;

    my $sth = $dbh->prepare($sql);
    if ( $write == 1 ) {
        if (ref($bind_values) eq 'ARRAY') {
            $sth->execute(@$bind_values);
        } else {
            $sth->execute();
        }
    }
    $sth->finish;

    my $result = get( $dbh, 'SELECT ROW_COUNT() changes;' );
    return $result->[0]->{changes} if $result->[0]->{changes} > 0;
    return undef;
}

# deprecated
sub quote($$) {
    my ($dbh, $sql) = @_;

    $sql =~ s/\_/\\\_/g;
    return $dbh->quote($sql);
}

#subtract hours, deprecated(!)
sub shift_date_by_hours($$$) {
    my ($dbh, $date, $offset) = @_;

    my $query       = 'select date(? - INTERVAL ? HOUR) date';
    my $bind_values = [ $date, $offset ];
    my $results     = db::get( $dbh, $query, $bind_values );
    return $results->[0]->{date};
}

#add minutes, deprecated(!)
sub shift_datetime_by_minutes($$$) {
    my ($dbh, $datetime, $offset) = @_;

    my $query       = "select ? + INTERVAL ? MINUTE date";
    my $bind_values = [ $datetime, $offset ];
    my $results     = db::get( $dbh, $query, $bind_values );
    return $results->[0]->{date};
}

# get next free id of a database table
sub next_id ($$){
    my ($dbh, $table) = @_;

    my $query = qq{
		select max(id) id
		from $table
		where 1
	};
    my $results = get( $dbh, $query );
    return $results->[0]->{id} + 1;
}

# get max id from table
sub get_max_id($$) {
    my ($dbh, $table) = @_;

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
