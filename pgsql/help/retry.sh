 #!/bin/bash
 # Usage: ./retry.sh <custid> <target_table>
 # Example: ./retry.sh 319 datamart_humana.claim

 custid=$1
 table=$2

 if [ -z "$custid" ] || [ -z "$table" ]; then
   echo "Usage: $0 <custid> <target_table>"
   echo "Example: $0 319 datamart_humana.claim_319"
   exit 1
 fi

  failfile="failed_${custid}.txt"
  if [ ! -f "$failfile" ]; then
    echo "Error: $failfile not found."
    exit 1
  fi

  # 1. Get the first failed table to derive the column list
  first_tbl=$(head -n 1 "$failfile")
  if [ -z "$first_tbl" ]; then
    echo "No failed tables to retry."
    exit 0
  fi

  echo "Fetching columns for $first_tbl..."
  # Fetch columns as a comma-separated string to ensure the generated script remains on one line per command
  COLS=$(psql -d ods_domani -At -c "SELECT string_agg(format('%I', attname), ',' ORDER BY attnum) FROM pg_attribute WHERE attrelid = '${first_tbl}'::regclass AND attnum > 0 AND NOT attisdropped;")

  if [ -z "$COLS" ]; then
    echo "Error: Could not fetch columns for $first_tbl. Please check if the table exists."
    exit 1
  fi

  # 2. Generate a new run file for retries
  runfile="run_retry_${custid}"
  echo "#!/bin/bash" > "$runfile"
  echo "set -o pipefail" >> "$runfile"

  while read -r tbl; do
    [ -z "$tbl" ] && continue
    # Add a timestamp log
    printf 'echo $(date +%%Y%%m%%d_%%H%%M) "RETRY COPY %s to %s"\n' "$tbl" "$table" >> "$runfile"
    # Run the copy command; if it fails again, log it to a separate retry_failed file
    echo "psql -d ods_domani -c \"COPY (SELECT $COLS FROM $tbl) TO STDOUT\" | psql -d ods_domani -c \"COPY ${table} ($COLS) FROM STDIN\" || echo \"$tbl\"
  >>retry_failed_${custid}.txt" >> "$runfile"
  done < "$failfile"

  chmod +x "$runfile"
  echo "------------------------------------------------"
  echo "Success! Generated $runfile"
  echo "You can now review and run it: ./${runfile}"
