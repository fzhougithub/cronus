SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS data_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    c.reltuples AS row_count -- Approximate row count
FROM
    pg_class c
LEFT JOIN
    pg_namespace n ON n.oid = c.relnamespace
WHERE
    c.relkind = 'r' -- 'r' for regular tables
    AND n.nspname NOT IN ('pg_catalog', 'information_schema') -- Exclude system schemas
    AND n.nspname !~ '^pg_toast' -- Exclude toast tables
ORDER BY
    pg_total_relation_size(c.oid) DESC;
