 WITH RECURSIVE partitions AS (

    SELECT
        c.oid,
        c.relname AS partition_name,
        n.nspname AS schema_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'claimsprocess'
      AND c.relname = 'claim_core'

    UNION ALL


    SELECT
        c.oid,
        c.relname AS partition_name,
        n.nspname AS schema_name
    FROM pg_inherits i
    JOIN pg_class c ON c.oid = i.inhrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN partitions p ON p.oid = i.inhparent
)
SELECT 'vacuum analyze'|| schema_name||'.'||partition_name||';'
FROM partitions
WHERE oid NOT IN (SELECT inhparent FROM pg_inherits)
ORDER BY schema_name, partition_name;
