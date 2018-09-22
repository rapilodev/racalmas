#!/bin/sh

from=$1
till=$2
project=$3

export LC_ALL="de_DE.utf8"
export LANGUAGE="de_DE.utf8"

set -x
cd /home/radio/calcms/sync_cms
nice -n 10 perl sync_cms.pl --from=$from --till=$till --source=config/source/calcms_$project.cfg --target=config/target/88vier_$project.cfg 2>&1

