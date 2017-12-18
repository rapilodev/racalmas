#!/bin/sh

perl -I /home/calcms/lib/calcms update_program.pl

exit;

##clear cache
##echo "cd /home/radio/radio/agenda/admin;perl clear_cache.cgi online=0"
#cd /home/radio/radio/agenda/admin
#perl clear_cache.cgi online=0

##get current layout
##cd /home/radio/calcms
##perl preload_agenda.pl read /home/radio/radio/agenda/index.html

##cd /home/radio/calcms/
##perl preload_agenda.pl replace /home/radio/radio/sites/default/files/programm.html;
##perl preload_agenda.pl replace /home/radio/radio/programm.html;
#
##update cache (important for night hours!)
##echo "cd /home/radio/radio/agenda;perl aggregate.cgi date=today 2>/dev/null > /home/radio/radio/agenda/programm.html "
#cd /home/radio/radio/agenda; 
#perl -I /home/radio/calcms/calcms aggregate.cgi date=today 2>/dev/null > /home/radio/radio/agenda/programm.html
#
#find /home/radio/radio/agenda/cache/ -type f -exec chmod 664 {} \; 2>/dev/null
#find /home/radio/radio/agenda/cache/ -type f -exec chgrp www-data {} \; 2>/dev/null
#

