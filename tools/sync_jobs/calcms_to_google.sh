#!/bin/sh

from=$1
till=$2
project=$3

#. /etc/profile
set LC_ALL="de_DE.utf8"
export LC_ALL="de_DE.utf8"
set LANGUAGE="de_DE.utf8"
export LANGUAGE="de_DE.utf8"

cd /home/radio/calcms/sync_cms

echo "nice -n 10 perl sync_cms.pl --update --all --from=$from --till=$till --source=config/source/calcms_$project.cfg --target=config/target/88vier_$project.cfg 2>&1"
nice -n 10 perl sync_cms.pl  --update --all --from=$from --till=$till --source=config/source/calcms_$project.cfg --target=config/target/88vier_$project.cfg 2>&1


