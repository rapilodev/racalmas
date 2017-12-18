#/bin/sh
DATE=`date +%Y-%m-%d_%H-%M-%S | tr -d "\n"`
mysqldump -u calcms_admin -p'taes9Cho' calcms_test > backup-$DATE.sql
