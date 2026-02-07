#~/bin/bash

while true; do
  total=$(wc -l < partitions_list.txt)
  done=$(wc -l < vacuum_done.log 2>/dev/null || echo 0)
  running=$(psql -d $DBNAME -Atc "SELECT count(*) FROM pg_stat_activity WHERE query LIKE 'VACUUM ANALYZE claimsprocess.claim_core_p1_%' AND state='active';")

  echo "Partitions total: $total"
  echo "Partitions done: $done"
  echo "Partitions running: $running"
  progress=$(( (done + running)*100 / total ))
  echo "Overall progress: $progress%"
  sleep 10
done

