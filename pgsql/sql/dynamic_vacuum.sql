-- This PL/pgSQL DO block iterates over the 10 tables with the highest XID age
-- and runs a mandatory VACUUM (FREEZE) command on each one.
DO $$
DECLARE
-- Variables to hold the table name and schema during iteration
v_schema_name TEXT;
v_table_name TEXT;
v_sql_command TEXT;
v_age BIGINT;
BEGIN
RAISE NOTICE 'Starting aggressive VACUUM (FREEZE) on top 10 oldest tables...';

-- Use a cursor to iterate over the tables returned by the critical XID age query
FOR v_schema_name, v_table_name, v_age IN (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        age(c.relfrozenxid) AS xid_age
    FROM
        pg_class c
    JOIN
        pg_namespace n ON n.oid = c.relnamespace
    WHERE
        c.relkind = 'r' -- regular tables
        AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    ORDER BY
        xid_age DESC
    LIMIT 10
)
LOOP
    -- Construct the dynamic VACUUM FREEZE command
    v_sql_command := format('VACUUM (FREEZE, VERBOSE) %I.%I;', v_schema_name, v_table_name);

    RAISE NOTICE 'Executing VACUUM FREEZE on %.% (Age: %)', v_schema_name, v_table_name, v_age;

    -- Execute the command
    EXECUTE v_sql_command;

END LOOP;

RAISE NOTICE 'Finished aggressive VACUUM (FREEZE) operations.';

END
$$ LANGUAGE plpgsql;

-- After these commands finish, your XID age issue should be resolved for the most critical tables.
