#!/bin/bash


if [ $# -ne 4 ]
then
        echo
        echo "Usage: $0 [ods dbname] [source ip] [source dbname] [schemaname]"
        echo
        exit
else
        odsDB="$1"
        remoteHost="$2"
        remoteDB="$3"
        sch="$4"
fi

PGDUMP=/usr/pgsql-14/bin/pg_dump
tmpDumpFN=/tmp/tempdumpfile.txt


echo
echo "-- remote schema section"
echo
> ${tmpDumpFN}
#set -x
$PGDUMP -h ${remoteHost} -s --schema=${sch}  ${remoteDB} >  ${tmpDumpFN}
#set +x
printLines=0
exec < ${tmpDumpFN}
while read line
do
        if [ $printLines -eq 1 ]
        then
                echo "$line"
        else
                if [ "$line" == "" ]
                then
                        continue
                fi

                if [ "$line" == ")" ]
                then
                        continue
                fi

                if [ "$line" == "(" ]
                then
                        continue
                fi

                set - $line

                if [ "$1" == "SET" -a "$2" == "default_tablespace" ]
                then
                        printLines=1
                        echo "$line"
                fi
        fi
done

echo
echo


echo
echo "-- ods GRANT section"
echo
> ${tmpDumpFN}
#set -x
$PGDUMP -s --schema=${sch}  ${odsDB} >  ${tmpDumpFN}
#set +x
printLines=0
exec < ${tmpDumpFN}
while read line
do
        if [ $printLines -eq 1 ]
        then
                echo "$line"
        else
                if [ "$line" == "" ]
                then
                        continue
                fi

                if [ "$line" == ")" ]
                then
                        continue
                fi

                if [ "$line" == "(" ]
                then
                        continue
                fi

                set - $line

                if [ "$1" == "GRANT" -o "$1" == "REVOKE" ]
                then
                        printLines=1
                        echo "$line"
                fi
        fi
done

echo
echo "-- misc schema section"
echo
#set -x
#$PGDUMP -s --schema=misc  ${odsDB}
#set +x

echo
echo "-- keep all views related to schema"

viewlistFN=/tmp/keepviewlist.txt
viewbodyFN=/tmp/keepviewbody.txt

psql -d ${odsDB} -q -t -c "
WITH a_objs AS (
  SELECT c.oid
  FROM pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = '${sch}'
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

echo "--restore views after rebuild schema $sch" > $viewbodyFN

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

psql -d ${odsDB} -t -A -q -c "$sqlcmd" >> $viewbodyFN
done

cat $viewbodyFN
