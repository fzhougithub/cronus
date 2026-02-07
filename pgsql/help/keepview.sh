#!/bin/bash

if [ $# -ne 2 ];then
	echo "Usage: $0 <odsdb> <schema>"
	echo "e.g: $$0 ods_domani claimsprocess_humana"
	exit 1
else
	odsdb=$1
	schema=$2
fi

viewlistFN=/tmp/keepviewlist.txt
viewbodyFN=/tmp/keepviewbody.txt

psql -d $odsdb -q -t -c "
WITH a_objs AS (
  SELECT c.oid
  FROM pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = '${schema}'
    AND c.relkind IN ('r', 'S')
)
SELECT
  --distinct 'SELECT pg_get_viewdef('''||n.nspname ||'.'|| c.relname||'''::regclass, true);'
  distinct n.nspname ||'.'|| c.relname
FROM pg_rewrite r
JOIN pg_class c ON r.ev_class = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_depend d ON d.objid = r.oid
WHERE EXISTS (
  SELECT 1 FROM a_objs ao WHERE ao.oid = d.refobjid
)
  AND c.relkind = 'v';
" > $viewlistFN

echo "--restore views after rebuild schema $schema" > $viewbodyFN

for i in $(cat $viewlistFN);do

echo "" >> $viewbodyFN

s=$(echo $i|cut -d. -f1)
v=$(echo $i|cut -d. -f2)

sqlcmd="
SELECT
  'CREATE OR REPLACE VIEW $i AS ' ||
  pg_get_viewdef(c.oid, true)
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = '$s'
  AND c.relname = '$v'
  AND c.relkind = 'v';
"

psql -d $odsdb -t -A -q -c "$sqlcmd" >> $viewbodyFN

done

cat $viewbodyFN
