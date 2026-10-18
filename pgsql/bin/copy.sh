#!/bin/bash
set -euo pipefail

if [ $# -ne 4 ];then
  echo "Usage: $0 target_tblname customer_id <query_string> dry/run"
  echo "e.g: $0 datamart_humana.claim 830 \"claim_c_830_%_p%\" dry"
  exit 1
else
  table=$1
  custid=$2
  cnd=$3
  act=$4
  LOG=load_$(date +%Y%m%d_%H%M).log
  runfile=run_${custid}
fi

#!/bin/bash
set -euo pipefail

psql -d ods_domani -At <<SQL > ${custid}.list
select 'datamart_humana.'||relname from pg_class where relname like '$cnd';
SQL

first_tbl=$(head -n 1 ${custid}.list)

psql -d ods_domani -At <<SQL > ${custid}_cols.txt
SELECT string_agg(format('%I', attname), E',\n' ORDER BY attnum)
FROM pg_attribute
WHERE attrelid = '${first_tbl}'::regclass
  AND attnum > 0
  AND NOT attisdropped;
SQL

COLS=$(cat ${custid}_cols.txt)

if [ $act == 'run' ];then
  #bash ${runfile}
  echo "you review generated $${runfile} and dierctly run it"
elif [ $act == 'dry' ];then
  echo "#!/bin/bash" > ${runfile}
  echo "set -o pipefail" >> ${runfile}
  while read -r tbl; do
    #echo "echo $(date +%Y%m%d_%H%M)  \"COPY $tbl to ${table}" >> $runfile
    printf 'echo $(date +%%Y%%m%%d_%%H%%M) "COPY %s to %s"\n' "$tbl" "$table" >> "$runfile"
    echo "psql -d ods_domani -c \"COPY (SELECT $COLS FROM $tbl) TO STDOUT\" | psql -d ods_domani -c \"COPY ${table} ($COLS) FROM STDIN\" || echo \"$tbl\" >>failed_${custid}.txt" >>$runfile
  done < ${custid}.list

  echo "Please review 3 files:"
  echo "  ${runfile}"
  echo "  ${custid}_cols.txt"
  echo "  ${custid}.list"
  echo "You can run ${runfile} directly"
fi
