-- step 1: identify the partitioned tables

SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  reloptions
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname = 'claimsprocess'
  AND c.relname LIKE 'claim_core_p1%';

--- check the partition table configuration

SELECT
  n.nspname,
  c.relname,
  current_setting('autovacuum_vacuum_threshold')::int AS global_vac_thresh,
  COALESCE(
    (SELECT (regexp_split_to_array(reloptions::text, ','))[1]::int
     FROM pg_class x WHERE x.oid = c.oid AND reloptions IS NOT NULL
     AND reloptions::text LIKE '%autovacuum_vacuum_threshold%'),
    current_setting('autovacuum_vacuum_threshold')::int
  ) AS effective_vacuum_threshold
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'claimsprocess'
  AND c.relname LIKE 'claim_core_p1%';

-- 3. adjust the auto vacuum setup on partition table level

ALTER TABLE your_schema.your_partition
  SET (
    autovacuum_enabled = true,
    autovacuum_vacuum_threshold = 50,
    autovacuum_vacuum_cost_delay = 10,
    autovacuum_vacuum_cost_limit = 2000,
    autovacuum_naptime = '30s'
  );

-- step 4: keep monitoring the auto vacuum performance

SELECT
  schemaname,
  relname,
  last_autovacuum,
  last_autoanalyze,
  n_dead_tup,
  n_live_tup,
  vacuum_count,
  autovacuum_count
FROM pg_stat_all_tables
WHERE schemaname = 'claimsprocess'
  AND relname LIKE 'claim_core_p1%'
ORDER BY n_dead_tup DESC;


-- Step 5. Auto adjust the auto vacuum setup

psql -d your_db -Atc "
SELECT 'ALTER TABLE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || 
' SET (autovacuum_vacuum_threshold = 50, autovacuum_vacuum_scale_factor = 0.05);'
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname = 'claimsprocess'
  AND c.relname LIKE 'claim_core_p1%';
" | psql -d claimsprocess 





