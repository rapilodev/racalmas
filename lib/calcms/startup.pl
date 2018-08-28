use lib qw(/home/radio/calcms/calcms/);

use Data::Dumper;
use Apache::DBI();
#$Apache::DBI::DEBUG = 2;

use Time::Local();
use Date::Calc();
use Calendar::Simple qw(date_span);

use config();
use log();
use time();
use db();
use cache();
use template();

#do not delete last line!
return 1;
