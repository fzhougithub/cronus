select a.table_schema||'.'||a.table_name as tablename, b.table_schema||'.'||b.table_name as table_with_ids from information_schema.columns a left join (select table_schema,table_name,table_schema||'.'||table_name tableb from information_schema.columns where column_name in ('customer_id','claim_id') order by 1) b on a.table_schema=b.table_schema and a.table_name=b.table_name;

-- Remove partition table and only keep parent tables
SELECT t.table_schema, t.table_name
FROM information_schema.tables t
JOIN pg_class c ON c.relname = t.table_name
JOIN pg_namespace n ON n.nspname = t.table_schema AND n.oid = c.relnamespace
JOIN pg_partitioned_table p ON p.partrelid = c.oid  -- partition parent only
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
  )
ORDER BY t.table_schema, t.table_name;


-- check all tables
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c1
    WHERE c1.table_schema = tables.table_schema
      AND c1.table_name = tables.table_name
      AND c1.column_name = 'customer_id'
  )
  OR NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c2
    WHERE c2.table_schema = tables.table_schema
      AND c2.table_name = tables.table_name
      AND c2.column_name = 'claim_id'
  )
ORDER BY table_schema, table_name;


