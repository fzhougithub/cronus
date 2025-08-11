SELECT
    n.nspname AS schemaname,
    c.relname AS table_name,
    ic.relname AS index_name,
    pg_size_pretty(pg_relation_size(ic.oid)) AS index_size,
    pg_size_pretty(pg_relation_size(ic.oid) - pg_relation_size(c.oid)) AS estimated_bloat
FROM
    pg_stat_user_indexes ui
JOIN
    pg_index i ON ui.indexrelid = i.indexrelid
JOIN
    pg_class c ON ui.relid = c.oid              -- Table
JOIN
    pg_class ic ON i.indexrelid = ic.oid        -- Index
JOIN
    pg_namespace n ON c.relnamespace = n.oid;

