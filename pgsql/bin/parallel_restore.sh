#!/bin/bash

set -m

if [ $# -ne 6 ]; then
	echo "Usage: $0 <sourceIP> <sourceDB> <sourceSchema> <snapshot> <tablefile> <jobs>"
	echo "example: $0 10.222.79.110 claimsprocess claimsprocess_humana 0000006A-000438B3-1 claimsprocess_humana.tablist 20"
	exit 1
else
	DB_HOST=$1
	DB_NAME=$2
	SCHEMA_NAME=$3
	SNAPSHOT=$4
	TABLEFILE=$5
	PARALLEL_JOBS=$6
fi

echo "$(wc -l < tables.txt) tables"

rm -rf restore_logs
mkdir -p restore_logs

process_table() {
    local table=$1
    local log_file="restore_logs/${table}.log"

    echo "$(date): START processing table: $table" | tee -a "$log_file"

    # Dump and restore with error handling
    if pg_dump -h $DB_HOST -d $DB_NAME -t "${table}" --data-only --snapshot="$SNAPSHOT" --format=plain 2>> "$log_file" | \
       psql -d ods_domani -v ON_ERROR_STOP=0 --echo-errors 2>> "$log_file"; then
        echo "$(date): SUCCESS completed table: $table" | tee -a "$log_file"
        return 0
    else
        echo "$(date): FAILED table: $table" | tee -a "$log_file"
        return 1
    fi
}

export -f process_table
export DB_HOST DB_NAME SCHEMA_NAME SNAPSHOT

echo "Starting parallel restore with $PARALLEL_JOBS jobs..."
cat $TABLEFILE | xargs -I {} -P $PARALLEL_JOBS bash -c 'process_table "$@"' _ {}


success_count=$(grep -r "SUCCESS" restore_logs/ | wc -l)
failed_count=$(grep -r "FAILED" restore_logs/ | wc -l)

echo "=== RESTORE COMPLETED ===" > restore_summary.log
echo "Start: $(date -r tables.txt)" >> restore_summary.log
echo "End: $(date)" >> restore_summary.log
echo "Total tables: $TABLE_COUNT" >> restore_summary.log
echo "Successful: $success_count" >> restore_summary.log
echo "Failed: $failed_count" >> restore_summary.log

if [ $failed_count -gt 0 ]; then
    echo "Failed tables:" >> restore_summary.log
    grep -r FAILED restore_logs/* | cut -d':' -f1 >> restore_summary.log
fi

cat restore_summary.log
