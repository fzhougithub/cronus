-- 1. Check active backends
SELECT pid, usename, backend_xmin, xact_start, query
FROM pg_stat_activity
WHERE backend_xmin IS NOT NULL
ORDER BY backend_xmin;

-- 2. Check prepared transactions
SELECT gid, prepared, transaction AS backend_xid
FROM pg_prepared_xacts;

-- 3. Check replication slots (these can hold xmin for logical decoding)
SELECT slot_name, active, xmin, catalog_xmin
FROM pg_replication_slots;

-- 4. Check replication connections (standby feedback)
SELECT pid, usename, backend_xmin, state, application_name
FROM pg_stat_replication;

-- 5. Check autovacuum workers
SELECT pid, relid::regclass, backend_xmin, query
FROM pg_stat_activity
WHERE query LIKE 'autovacuum%';

