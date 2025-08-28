#!/bin/bash

psql -d your_db -Atc "
SELECT n.nspname || '.' || c.relname || ' ' || i.relname
FROM pg_inherits inh
JOIN pg_class c ON c.oid = inh.inhrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_index idx ON idx.indrelid = c.oid AND idx.indisprimary
JOIN pg_class i ON i.oid = idx.indexrelid
WHERE inh.inhparent = 'claimsprocess.claim_core'::regclass;
" > partitions_pkeys.txt

# Run REINDEX CONCURRENTLY on all in parallel (4 at a time)
cat partitions_pkeys.txt | parallel -j4 --colsep ' ' psql -d your_db -c "REINDEX INDEX CONCURRENTLY {2};"

