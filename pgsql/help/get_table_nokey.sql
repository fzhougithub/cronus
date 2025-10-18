SELECT t.table_schema||'.'||t.table_name
FROM information_schema.tables t
JOIN pg_class c ON c.relname = t.table_name
JOIN pg_namespace n ON n.nspname = t.table_schema AND n.oid = c.relnamespace
JOIN pg_partitioned_table p ON p.partrelid = c.oid
WHERE t.table_type = 'BASE TABLE'
  AND t.table_schema NOT IN ('pg_catalog', 'information_schema')
  AND (
    NOT EXISTS (
      SELECT 1
      FROM information_schema.columns c1
      WHERE c1.table_schema = t.table_schema
        AND c1.table_name = t.table_name
        AND c1.column_name = 'customer_id'
    )
    OR NOT EXISTS (
      SELECT 1
      FROM information_schema.columns c2
      WHERE c2.table_schema = t.table_schema
        AND c2.table_name = t.table_name
        AND c2.column_name = 'claim_id'
    )
  );
