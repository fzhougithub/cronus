WITH table_stats AS (
  SELECT
    c.oid,
    n.nspname AS schema_name,
    c.relname AS table_name,
    c.reloptions,
    STAT.n_live_tup,
    STAT.n_dead_tup,
    STAT.last_autovacuum,
    STAT.last_autoanalyze,
    STAT.autovacuum_count,
    STAT.autoanalyze_count,
    -- Default autovacuum thresholds (from PostgreSQL globals)
    (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_vacuum_threshold')::int AS default_vacuum_threshold,
    (SELECT setting::float FROM pg_settings WHERE name = 'autovacuum_vacuum_scale_factor')::float AS default_vacuum_scale_factor,
    (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_analyze_threshold')::int AS default_analyze_threshold,
    (SELECT setting::float FROM pg_settings WHERE name = 'autovacuum_analyze_scale_factor')::float AS default_analyze_scale_factor
  FROM pg_class c
  JOIN pg_namespace n ON c.relnamespace = n.oid
  LEFT JOIN pg_stat_user_tables STAT ON c.relname = STAT.relname AND n.nspname = STAT.schemaname
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND c.relkind = 'r'  -- regular tables only
),
evaluated_tables AS (
  SELECT
    oid,
    schema_name,
    table_name,
    reloptions,
    n_live_tup,
    n_dead_tup,
    last_autovacuum,
    last_autoanalyze,
    autovacuum_count,
    autoanalyze_count,
    default_vacuum_threshold,
    default_vacuum_scale_factor,
    default_analyze_threshold,
    default_analyze_scale_factor,
    -- Check if table has any custom autovacuum reloptions
    CASE
      WHEN reloptions IS NOT NULL AND reloptions::text LIKE '%autovacuum_vacuum_threshold%' THEN TRUE
      ELSE FALSE
    END AS has_custom_autovacuum_settings,
    -- Dead tuple flag
    CASE
      WHEN n_dead_tup > 1000 THEN TRUE
      ELSE FALSE
    END AS has_many_dead_tuples,
    -- Large table flag (live > 50k or 100k, adjust as you like)
    CASE
      WHEN n_live_tup > 50000 THEN TRUE
      ELSE FALSE
    END AS is_large_table
  FROM table_stats
)
SELECT
  schema_name,
  table_name,
  n_live_tup,
  n_dead_tup,
  last_autovacuum,
  last_autoanalyze,
  autovacuum_count,
  autoanalyze_count,
  has_custom_autovacuum_settings,
  has_many_dead_tuples,
  is_large_table,
  reloptions,
  CASE
    WHEN NOT has_custom_autovacuum_settings AND (has_many_dead_tuples OR is_large_table) THEN
      format(
        'ALTER TABLE %I.%I SET ('
        '  autovacuum_vacuum_threshold = 50, '
        '  autovacuum_vacuum_scale_factor = %s, '
        '  autovacuum_analyze_threshold = 50, '
        '  autovacuum_analyze_scale_factor = 0.05, '
        '  autovacuum_enabled = true'
        '); -- Reason: %s',
        schema_name,
        table_name,
        CASE
          WHEN is_large_table AND has_many_dead_tuples THEN '0.01'  -- Aggressive for big + dead
          WHEN is_large_table THEN '0.05'                     -- Moderate for large
          ELSE '0.1'                                          -- Default-ish for small
        END,
        CASE
          WHEN is_large_table AND has_many_dead_tuples THEN 'Large table with many dead tuples → aggressive vacuuming'
          WHEN is_large_table THEN 'Large table → tuned scale factor'
          ELSE 'Many dead tuples or no autovacuum settings'
        END
      )
    WHEN NOT has_custom_autovacuum_settings THEN
      format(
        '-- Table %I.%I has no custom autovacuum settings but is low activity (dead: %s, live: %s)',
        schema_name, table_name, n_dead_tup, n_live_tup
      )
    ELSE
      format(
        '-- Table %I.%I already has custom autovacuum settings: %s',
        schema_name, table_name, reloptions
      )
  END AS autovacuum_tuning_command
FROM evaluated_tables
ORDER BY
  CASE
    WHEN NOT has_custom_autovacuum_settings AND has_many_dead_tuples AND is_large_table THEN 1
    WHEN NOT has_custom_autovacuum_settings AND has_many_dead_tuples THEN 2
    WHEN NOT has_custom_autovacuum_settings AND is_large_table THEN 3
    ELSE 4
  END,
  n_dead_tup DESC;
