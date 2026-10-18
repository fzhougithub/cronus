#!/bin/bash

# SELECT * FROM pg_create_physical_replication_slot('for_odshumana_04', true);

# if there is no existing slot on primary, using -C to created it. 
# /usr/pgsql-14/bin/pg_basebackup -D /apps/lib/pgsql/14/data  -X s -R -v -c fast -S for_claimshumana_pg16 -h 10.221.152.82 \

/usr/pgsql-14/bin/pg_basebackup -D /apps/lib/pgsql/14/data  -X s -R -v -c fast -C -S for_claimshumana_pg16 -h 10.221.152.82 

wait

chmod -R 700 /apps/lib/pgsql/14/data

/usr/pgsql-14/bin/pg_ctl -D /apps/lib/pgsql/14/data start
wait
echo "Done"

# /usr/pgsql-14/bin/pg_ctl stop -D /apps/lib/pgsql/14/data
