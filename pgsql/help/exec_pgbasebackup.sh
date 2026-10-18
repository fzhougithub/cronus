#!/bin/bash
#

date

/usr/pgsql-14/bin/pg_basebackup -D /apps/lib/pgsql/14/data  -X s -R -v -c fast -S for_claimpsprocess_02 -h 10.221.152.82
wait
/usr/pgsql-14/bin/pg_ctl -D /apps/lib/pgsql/14/data start
wait
echo "Done"

date
