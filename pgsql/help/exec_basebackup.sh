#!/bin/bash

/usr/pgsql-14/bin/pg_basebackup -D /apps/lib/pgsql/14/data  -X s -R -v -c fast -S for_claimshumana_pg16 -h 10.221.152.82 \
   --tablespace-mapping=/pg_tblspc1=/pg_tblspc_01 \
  --tablespace-mapping=/pg_tblspc2=/pg_tblspc_02 \
  --tablespace-mapping=/pg_tblspc3=/pg_tblspc_03 \
  --tablespace-mapping=/pg_tblspc4=/pg_tblspc_04 \
  --tablespace-mapping=/pg_tblspc5=/pg_tblspc_05 \
  --tablespace-mapping=/pg_tblspc6=/pg_tblspc_06 \
  --tablespace-mapping=/pg_tblspc7=/pg_tblspc_07 \
  --tablespace-mapping=/pg_tblspc8=/pg_tblspc_08 \
  --tablespace-mapping=/pg_tblspc9=/pg_tblspc_09 \
  --tablespace-mapping=/pg_tblspc10=/pg_tblspc_10 \
  --tablespace-mapping=/pg_tblspc11=/pg_tblspc_11 \
  --tablespace-mapping=/pg_tblspc12=/pg_tblspc_12

wait

chmod -R 700 /apps/lib/pgsql/14/data

/usr/pgsql-14/bin/pg_ctl -D /apps/lib/pgsql/14/data start
wait
echo "Done"
