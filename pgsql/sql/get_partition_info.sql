SELECT
    n.nspname AS schema_name,
    c.relname AS parent_table,
    CASE p.partstrat
        WHEN 'r' THEN 'RANGE'
        WHEN 'l' THEN 'LIST'
        WHEN 'h' THEN 'HASH'
    END AS partition_strategy,
    pg_get_partkeydef(c.oid) AS partition_key,
    (
        SELECT array_agg(
            pc.relname || ': ' || pg_get_expr(pc.relpartbound, pc.oid)
            ORDER BY pc.relname
        )
        FROM pg_inherits i
        JOIN pg_class pc ON i.inhrelid = pc.oid
        WHERE i.inhparent = c.oid
    ) AS partitions
FROM
    pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_partitioned_table p ON c.oid = p.partrelid
WHERE
    c.relkind = 'p'
    AND n.nspname = 'claimsprocess'
ORDER BY
    n.nspname, c.relname;
