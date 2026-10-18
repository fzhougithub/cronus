#!/bin/bash
set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 target_tblname <where_clause> dry/run"
    echo "e.g:"
    echo "  $0 datamart_humana.claim_320_2022 \"customer_id = 320 and fill_dt < '2023-01-01'\" dry"
    exit 1
fi

table=$1
where_clause=$2
act=$3

LOG=load_$(date +%Y%m%d_%H%M).log
runfile=run_${table}

SOURCE_TABLE="datamart_humana.claim"

psql -d ods_domani -At <<SQL > ${table}_cols.txt
SELECT string_agg(format('%I', attname), E',\n' ORDER BY attnum)
FROM pg_attribute
WHERE attrelid = '${table}'::regclass
  AND attnum > 0
  AND NOT attisdropped;
SQL

COLS=$(cat ${table}_cols.txt)

if [ "$act" = "run" ]; then
    echo "Please review generated ${runfile} and run it directly"
elif [ "$act" = "dry" ]; then

    cat > "${runfile}" <<EOF
#!/bin/bash
set -euo pipefail

echo \$(date +%Y%m%d_%H%M) "COPY ${SOURCE_TABLE} to ${table}"

psql -d ods_domani -c "COPY (
    SELECT
        ${COLS}
    FROM ${SOURCE_TABLE}
    WHERE ${where_clause}
) TO STDOUT" | \
psql -d ods_domani -c "COPY ${table} FROM STDIN"

echo \$(date +%Y%m%d_%H%M) "Completed: COPY ${SOURCE_TABLE} to ${table}"

EOF

    chmod +x "${runfile}"

    echo "Please review 2 files:"
    echo "  ${runfile}"
    echo "  ${table}_cols.txt"
    echo
    echo "Generated source query:"
    echo "  SELECT ${COLS}"
    echo "  FROM ${SOURCE_TABLE}"
    echo "  WHERE ${where_clause}"
    echo
    echo "You can run ${runfile} directly"
fi
