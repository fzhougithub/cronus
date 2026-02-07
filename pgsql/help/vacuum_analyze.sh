#!/bin/bash
#psql -h claimshddp-db-01-alma8-prod-drx-kc.ssnc-corp.cloud  -d claimsprocess  -Atc "
#  SELECT relname
#  FROM pg_class
#  JOIN pg_inherits ON inhrelid = pg_class.oid
#  JOIN pg_class parent ON inhparent = parent.oid
#  WHERE parent.relname = 'claim_core';
#" | parallel -j 8 "psql -h claimshddp-db-01-alma8-prod-drx-kc.ssnc-corp.cloud -d claimsprocess  -c 'VACUUM ANALYZE {};'"

if [ $# -ne 4 ];then
	echo "Usage: $0 host db schema parent_table"
	echo "e.g: $0  claimshddp-db-01-alma8-prod-drx-kc.ssnc-corp.cloud claimsprocess claimsprocess  claim_core"
	exit 1
else

	HOST=$1
	DBNAME=$2
	SCHEMA=$3
	PARENT=$4
fi

echo $PARENT

listfile=$(pwd)/${PARENT}_partition_list

psql -h $HOST -d "$DBNAME" -Atc "
WITH RECURSIVE partitions AS (
    SELECT c.oid, n.nspname AS schema_name, c.relname AS partition_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '$SCHEMA' AND c.relname = '$PARENT'
    UNION ALL
    SELECT c.oid, n.nspname, c.relname
    FROM pg_inherits i
    JOIN pg_class c ON c.oid = i.inhrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN partitions p ON p.oid = i.inhparent
)
SELECT schema_name || '.' || partition_name
FROM partitions
WHERE oid NOT IN (SELECT inhparent FROM pg_inherits)
ORDER BY 1;
" > $listfile

echo $listfile $listfile.log

parallel --citation >/dev/null 2>&1 &

#parallel --ungroup -j 20 "psql -h $HOST -d $DBNAME -c 'VACUUM ANALYZE {};' && echo {} >> $listfile.log" < $listfile
parallel --termseq SIGTERM,SIGKILL  --line-buffer -j 8 "psql -h $HOST -d $DBNAME -c 'VACUUM ANALYZE {};' && echo {} >> $listfile.log" < $listfile

# pkill -TERM -g <parallel_pid>
# pkill -f 'psql -d your_db -c VACUUM ANALYZE'

