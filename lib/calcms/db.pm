package db;

use strict;
use warnings;
no warnings 'redefine';
use feature 'state';

use DBD::mysql();
use Digest::MD5 qw();
use Data::Dumper;
use Try::Tiny;
use Exception::Class (
    'DatabaseError',
);
use Scalar::Util qw( blessed );

#use base 'Exporter';
our @EXPORT_OK = qw(
  connect disconnect
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

my $database;
# connect to database
my $database;
sub connect($;$) {
    my ($options, $request) = @_;

    return $request->{connection} if defined $request and defined $request->{connection};

    my $access_options = $options->{access};
    my $hostname = $access_options->{hostname};
    my $port     = $access_options->{port};
    $database    = $access_options->{database};
    my $username = $access_options->{username};
    my $password = $access_options->{password};

    if ( ( defined $access_options->{write} ) && ( $access_options->{write} eq '1' ) ) {
        $username = $access_options->{username_write};
        $password = $access_options->{password_write};
    }

    my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
    my $key = Digest::MD5::md5_hex($dsn.$username.$password);
    return $options->{connections}->{$key} if defined $options->{connections}->{$key};    state $connections = {};
    return $connections->{$key} if defined $connections->{$key} and $connections->{$key}->ping;

    my $dbh = DBI->connect( $dsn, $username, $password, { mysql_enable_utf8 => 1 } )
      || DatabaseError->throw(error => "could not connect to database: $DBI::errstr");
    $dbh->{RaiseError} = 1;
    $dbh->{HandleError} = sub{
        print STDERR join(",",(caller($_))[0..3])."\n" for (1..2);
        return 0;
    };
    $dbh->{'mysql_enable_utf8'} = 1;
    put( $dbh, "set character set utf8", undef );
    put( $dbh, "set names utf8", undef );
    put( $dbh, "set time_zone='" . $options->{date}->{time_zone} . "'", undef );
    $request->{connection} = $dbh;
    #$options->{connections}->{$key} = $dbh;
    $connections->{$key} = $dbh;
    return $dbh;
}

sub disconnect ($){
    my ($request) = @_;
    my $dbh     = $request->{connection};
    $dbh->disconnect;
    delete $request->{connection};
    return;
}

# get all database entries of an sql query (as list of hashs)
sub get($$;$) {
    my ( $dbh, $sql, $bind_values ) = @_;

    my $sth = $dbh->prepare($sql);
    if ( ( defined $bind_values ) && ( ref($bind_values) eq 'ARRAY' ) ) {
        my $result = $sth->execute(@$bind_values);
        unless ($result) {
            print STDERR $sql . "\n";
            DatabaseError->throw(error => "db: $DBI::errstr $sql") if ( $read == 1 );
        }
    } else {
        $sth->execute() or DatabaseError->throw(error => "db: $DBI::errstr $sql") if $read == 1;
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
        if ( ( defined $bind_values ) && ( ref($bind_values) eq 'ARRAY' ) ) {
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
		where 1	};
    my $results = get( $dbh, $query );
    return $results->[0]->{id} + 1;
}

# get max id from table
sub get_max_id($$) {
    my ($dbh, $table) = @_;

    my $query = qq{
		select max(id) id
		from $table
		where 1	};
    my $results = get( $dbh, $query );
    return $results->[0]->{id};
}

#do not delete last line!
1;
