use lib qw(/home/calcms/lib/calcms/);

return 1;
#use B::TerseSize

#load mod_perl modules
#use Apache2;
#use ModPerl::RegistryPrefork;
#use Apache::compat;

#on upload CGI open of tmpfile: Permission denied
#use CGI;	

#load common used modules
#use Data::Dumper;
#use DBI;
use Apache::DBI;
#$Apache::DBI::DEBUG = 2;

use Time::Local;
use Date::Calc;
use Calendar::Simple qw(date_span);

use config;
use log;
use time;
use db;
use cache;
use template;

#do not delete last line!
1;
