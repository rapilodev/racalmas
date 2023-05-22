use lib qw(/home/radio/calcms/calcms/);
use lib qw(/home/calcms/lib/calcms/);

use Apache2::Log;
local *CORE::GLOBAL::warn = \&Apache2::ServerRec::warn;
local $SIG{__WARN__} = \&Apache2::ServerRec::warn;
# ^ use ErrorLog file set at Apache2 configuration
#   see https://perl.apache.org/docs/2.0/api/Apache2/Log.html for details

use Data::Dumper;
#use Apache::DBI();
use Time::Local();
use Date::Calc();
use Calendar::Simple qw(date_span);

use config();
use log();
use time();
use db();
use template();

#do not delete last line!
return 1;
